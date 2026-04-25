module webull.client;

import webull.orchestrate;
import std.json;
import std.string : assumeUTF;
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

    static void createToken(void delegate(Status) poll = null)
    {
        JSONValue json;
        orchestrate!"v2"(
            endpoint,
            "/openapi/auth/token/create"
        ).post(
            (ubyte[] data) {
                json = parseJSON(data.assumeUTF);
            },
            (ubyte[] data) {
                throw new Exception("HTTP request failed: "~cast(string)data.assumeUTF);
            }
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
        JSONValue json;
        orchestrate!"v2"(
            endpoint,
            "/openapi/auth/token/check",
            null,
            JSONValue(["token" : token.token])
        ).post(
            (ubyte[] data) {
                json = parseJSON(data.assumeUTF);
            },
            (ubyte[] data) {
                throw new Exception("HTTP request failed: "~cast(string)data.assumeUTF);
            },
            JSONValue(["token" : token.token])
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
        orchestrate!"v2"(endpoint, "/openapi/market-data/stock/bars",
            ["symbol": "AAPL", "category": "US_STOCK", "timespan": "M1", "real_time_required": "true"])
            .get((ubyte[] data) { json = parseJSON(data.assumeUTF); },
                    (ubyte[] data) { });
                    
        if (json.type != JSONType.object || "error_code" !in json)
            permissions |= Permissions.BARS;
        
        json = JSONValue(null);
        orchestrate!"v2"(endpoint, "/openapi/market-data/stock/tick",
            ["symbol": "AAPL", "category": "US_STOCK"])
            .get((ubyte[] data) { json = parseJSON(data.assumeUTF); },
                    (ubyte[] data) { });

        if (json.type != JSONType.object || "error_code" !in json)
            permissions |= Permissions.TICKS;
        
        json = JSONValue(null);
        orchestrate!"v2"(endpoint, "/openapi/market-data/stock/quotes",
            ["symbol": "AAPL", "category": "US_STOCK", "depth": "1", "overnight_required": "false"])
            .get((ubyte[] data) { json = parseJSON(data.assumeUTF); },
                    (ubyte[] data) { });

        if (json.type != JSONType.object || "error_code" !in json)
            permissions |= Permissions.QUOTES;
        
        json = JSONValue(null);
        orchestrate(endpoint, "/market-data/snapshot",
            ["symbols": "AAPL", "category": "US_STOCK"])
            .get((ubyte[] data) { json = parseJSON(data.assumeUTF); },
                    (ubyte[] data) { });

        if (json.type != JSONType.object || "error_code" !in json)
            permissions |= Permissions.SNAPSHOTS;
        
        json = JSONValue(null);
        orchestrate!"v2"(endpoint, "/openapi/market-data/stock/footprint",
            ["symbol": "AAPL", "category": "US_STOCK", "timespan": "M1", "count": "1"])
            .get((ubyte[] data) { json = parseJSON(data.assumeUTF); },
                    (ubyte[] data) { });
                    
        if (json.type != JSONType.object || "error_code" !in json)
            permissions |= Permissions.FOOTPRINT;

        json = JSONValue(null);
        try
        {
            orchestrate!"v2"(endpoint, "/openapi/account/list")
                .get((ubyte[] data) { json = parseJSON(data.assumeUTF); },
                        (ubyte[] data) { throw new Exception(cast(string)data.assumeUTF); });
        }
        catch (Exception)
        {
            json = JSONValue(null);
            orchestrate!"v2"(endpoint, "/app/subscriptions/list")
                .get((ubyte[] data) { json = parseJSON(data.assumeUTF); },
                        (ubyte[] data) { });
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
            {
                orchestrate!"v2"(endpoint, "/openapi/account/list").get(
                    (ubyte[] data) {
                        json = parseJSON(data.assumeUTF);
                    },
                    (ubyte[] data) {
                        throw new Exception("HTTP request failed: "~cast(string)data.assumeUTF);
                    }
                );
            }
            catch (Exception)
            {
                orchestrate!"v2"(endpoint, "/app/subscriptions/list").get(
                    (ubyte[] data) {
                        json = parseJSON(data.assumeUTF);
                    },
                    (ubyte[] data) {
                        throw new Exception("HTTP request failed: "~cast(string)data.assumeUTF);
                    }
                );
            }

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
}
