module webull.client;

import webull.composer;
import std.json;
import std.string : assumeUTF;
import std.datetime;
import std.stdio : writeln;
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
    ALL = BARS | TICKS | QUOTES | SNAPSHOTS | FOOTPRINT
}

struct Token
{
    string token;
    long expires;
    Status status;
}

static class Client
{
    static string key;
    static string secret;
    static Token token;
    static Permissions permissions = Permissions.NONE;

    static void createToken(void delegate(Status) poll = null)
    {
        JSONValue json;
        orchestrate!"v2"(
            "api.webull.com", 
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
            "api.webull.com", 
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
        orchestrate!"v2"("api.webull.com", "/openapi/market-data/stock/bars", 
            ["symbol": "AAPL", "category": "US_STOCK", "timespan": "M1", "real_time_required": "true"])
            .get((ubyte[] data) { json = parseJSON(data.assumeUTF); },
                    (ubyte[] data) { });
                    
        if (json.type != JSONType.object || "error_code" !in json)
            permissions |= Permissions.BARS;
        
        orchestrate!"v2"("api.webull.com", "/openapi/market-data/stock/tick",
            ["symbol": "AAPL", "category": "US_STOCK"])
            .get((ubyte[] data) { json = parseJSON(data.assumeUTF); },
                    (ubyte[] data) { });

        if (json.type != JSONType.object || "error_code" !in json)
            permissions |= Permissions.TICKS;
        
        orchestrate!"v2"("api.webull.com", "/openapi/market-data/stock/quotes",
            ["symbol": "AAPL", "category": "US_STOCK", "depth": "1", "overnight_required": "false"])
            .get((ubyte[] data) { json = parseJSON(data.assumeUTF); },
                    (ubyte[] data) { });

        if (json.type != JSONType.object || "error_code" !in json)
            permissions |= Permissions.QUOTES;
        
        orchestrate("api.webull.com", "/market-data/snapshot",
            ["symbols": "AAPL", "category": "US_STOCK"])
            .get((ubyte[] data) { json = parseJSON(data.assumeUTF); },
                    (ubyte[] data) { });

        if (json.type != JSONType.object || "error_code" !in json)
            permissions |= Permissions.SNAPSHOTS;
        
        orchestrate!"v2"("api.webull.com", "/openapi/market-data/stock/footprint",
            ["symbol": "AAPL", "category": "US_STOCK", "timespan": "M1", "count": "1"])
            .get((ubyte[] data) { json = parseJSON(data.assumeUTF); },
                    (ubyte[] data) { });
                    
        if (json.type != JSONType.object || "error_code" !in json)
            permissions |= Permissions.FOOTPRINT;
    }
}