module webull.client;

import webull.signer;

import requests;

import std.json : JSONValue, JSONType, parseJSON;
import std.datetime;
import std.stdio : writeln;
import std.array : array;
import std.algorithm : filter, map;
import core.thread;
import core.time;

enum Status : string
{
    INVALID = "INVALID",
    NORMAL = "NORMAL",
    EXPIRED = "EXPIRED",
    PENDING = "PENDING"
}

enum Permissions : uint
{
    NONE = 0,
    BARS = 1 << 0,
    TICKS = 1 << 1,
    QUOTES = 1 << 2,
    SNAPSHOTS = 1 << 3,
    FOOTPRINT = 1 << 4,
    ACCOUNTS = 1 << 5,
    ALL = BARS | TICKS | QUOTES | SNAPSHOTS | FOOTPRINT | ACCOUNTS
}

struct Token
{
    string token;
    long expires;
    Status status;
}

// TODO: Must verify the key and secret have been set.
static class Client
{
    static string key;
    static string secret;
    static string endpoint = "https://api.webull.com";
    static Token token;
    static Permissions permissions = Permissions.NONE;
    static string[] _accounts;

    static JSONValue get(
        string path,
        string[string] queryParams = null,
        string apiVersion = "v1",
    )
    {
        string[string] headers = signRequest(
            endpoint,
            path,
            queryParams,
            JSONValue.emptyObject,
            key,
            secret,
            apiVersion,
        );

        string url = composeURL(endpoint, path)~buildQueryString(queryParams);

        Request req = Request();
        req.addHeaders(headers);
        Response response = req.get(url);
        return checkAndParse(response);
    }

    static JSONValue post(
        string path,
        string[string] queryParams = null,
        JSONValue bodyParams = JSONValue.emptyObject,
        string apiVersion = "v1",
    )
    {
        string[string] headers = signRequest(
            endpoint,
            path,
            queryParams,
            bodyParams,
            key,
            secret,
            apiVersion,
        );

        string url = composeURL(endpoint, path)~buildQueryString(queryParams);
        string payload = bodyParams.type == JSONType.null_ ? "" : bodyParams.toString;

        Request req = Request();
        req.addHeaders(headers);
        req.addHeaders(["Content-Type": "application/json"]);
        Response response = req.post(url, payload, "application/json");
        return checkAndParse(response);
    }

    static void createToken(void delegate(Status) poll = null)
    {
        JSONValue json = post(
            "/openapi/auth/token/create",
            null,
            JSONValue.emptyObject,
            "v2",
        );

        if ("token" !in json)
            throw new Exception("Token not found in response "~json.toString());
        if ("expires" !in json)
            throw new Exception("Expires not found in response "~json.toString());

        token.token = json["token"].str;
        token.expires = json["expires"].integer;
        token.status = Status.PENDING;

        // Poll for token status until it's NORMAL (MFA)
        while (token.status == Status.PENDING)
        {
            if (poll !is null)
                poll(token.status);

            Thread.sleep(dur!"msecs"(5000));
            checkToken();
        }

        if (token.status == Status.INVALID || token.status == Status.EXPIRED)
            throw new Exception("Token creation failed with status: "~cast(string)token.status);
    }

    static void checkToken()
    {
        JSONValue json = post(
            "/openapi/auth/token/check",
            null,
            JSONValue(["token": token.token]),
            "v2",
        );

        if ("status" !in json)
            throw new Exception("Status not found in response "~json.toString());

        if ("expires" in json)
            token.expires = json["expires"].integer;

        token.status = cast(Status)json["status"].str;
    }

    static void detectPermissions()
    {
        permissions = Permissions.NONE;

        JSONValue json;

        json = JSONValue(null);
        try
            json = get("/openapi/market-data/stock/bars",
                ["symbol": "AAPL", "category": "US_STOCK", "timespan": "M1", "real_time_required": "true"], "v2");
        catch (Exception)
            json = JSONValue(null);

        if (json.type != JSONType.object || "error_code" !in json)
            permissions |= Permissions.BARS;

        json = JSONValue(null);
        try
            json = get("/openapi/market-data/stock/tick",
                ["symbol": "AAPL", "category": "US_STOCK"], "v2");
        catch (Exception)
            json = JSONValue(null);

        if (json.type != JSONType.object || "error_code" !in json)
            permissions |= Permissions.TICKS;

        json = JSONValue(null);
        try
            json = get("/openapi/market-data/stock/quotes",
                ["symbol": "AAPL", "category": "US_STOCK", "depth": "1", "overnight_required": "false"], "v2");
        catch (Exception)
            json = JSONValue(null);

        if (json.type != JSONType.object || "error_code" !in json)
            permissions |= Permissions.QUOTES;

        json = JSONValue(null);
        try
            json = get("/market-data/snapshot",
                ["symbols": "AAPL", "category": "US_STOCK"]);
        catch (Exception)
            json = JSONValue(null);

        if (json.type != JSONType.object || "error_code" !in json)
            permissions |= Permissions.SNAPSHOTS;

        json = JSONValue(null);
        try
            json = get("/openapi/market-data/stock/footprint",
                ["symbol": "AAPL", "category": "US_STOCK", "timespan": "M1", "count": "1"], "v2");
        catch (Exception)
            json = JSONValue(null);

        if (json.type != JSONType.object || "error_code" !in json)
            permissions |= Permissions.FOOTPRINT;

        json = JSONValue(null);
        try
            json = get("/openapi/account/list", null, "v2");
        catch (Exception)
        {
            json = JSONValue(null);
            try
                json = get("/app/subscriptions/list", null, "v2");
            catch (Exception)
                json = JSONValue(null);
        }

        if (json.type != JSONType.object || "error_code" !in json)
            permissions |= Permissions.ACCOUNTS;
    }

    static string[] accounts()
    {
        if (_accounts.length == 0)
        {
            if (!(permissions & Permissions.ACCOUNTS))
                throw new Exception("Accounts API not available - permission denied");

            JSONValue json;
            try
                json = get("/openapi/account/list", null, "v2");
            catch (Exception)
                json = get("/app/subscriptions/list", null, "v2");

            JSONValue[] entries;
            if (json.type == JSONType.array)
                entries = json.array.dup;
            else if (json.type == JSONType.object)
            {
                if ("result" in json && json["result"].type == JSONType.array)
                    entries = json["result"].array.dup;
                else if ("data" in json && json["data"].type == JSONType.array)
                    entries = json["data"].array.dup;
                else if ("accounts" in json && json["accounts"].type == JSONType.array)
                    entries = json["accounts"].array.dup;
            }

            _accounts = entries
                .map!(item => "account_id" in item ? item["account_id"].str : null)
                .array;
            _accounts = _accounts.filter!(value => value !is null && value.length > 0).array;
        }

        return _accounts;
    }

private:
    static JSONValue checkAndParse(Response response)
    {
        string body = cast(string)response.responseBody.data;
        if (body.length == 0)
            return JSONValue.emptyObject;

        JSONValue ret;
        try
            ret = parseJSON(body);
        catch (Exception)
        {
            if (response.code >= 200 && response.code < 300)
                return JSONValue.emptyObject;

            throw new Exception("HTTP request failed: "~body);
        }

        if (response.code >= 400)
            throw new Exception("HTTP request failed: "~body);

        return ret;
    }
}
