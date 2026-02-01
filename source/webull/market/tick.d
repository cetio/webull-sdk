module webull.market.tick;

import webull.composer;
import webull.market.types;
import webull.client : Client, Permissions;
import std.json;
import std.string : assumeUTF;
import std.conv : to;
import std.algorithm : map;
import std.array : array, join;

void getTicks(
    Security security, 
    int count = 30, 
    Session[] sessions = [Session.PRE, Session.RTH, Session.ATH]
)
{
    if (!(Client.permissions & Permissions.TICKS))
        throw new Exception("Ticks API not available - permission denied");
    
    JSONValue json;
    orchestrate!"v2"(
        "api.webull.com",
        "/openapi/market-data/stock/tick",
        [
            "symbol": security.symbol,
            "category": cast(string)security.category,
            "count": count.to!string,
            "trading_sessions": sessions.map!(s => cast(string)s).array.join(",")
        ]
    ).get(
        (ubyte[] data) { 
            json = parseJSON(data.assumeUTF); 
        },
        (ubyte[] data) { 
            throw new Exception("HTTP request failed: "~cast(string)data.assumeUTF); 
        }
    );
    
    security._ticks = parseTicks(json);
}

package:

Tick[] parseTicks(JSONValue json)
{
    if ("result" !in json || json["result"].type != JSONType.array)
        throw new Exception("Ticks invalid: "~json.toString);

    Tick[] ticks;
    foreach (JSONValue obj; json["result"].array)
    {
        Tick tick;
        if ("time" in obj) tick.time = obj["time"].str;
        if ("price" in obj) tick.price = obj["price"].str.to!double;
        if ("volume" in obj) tick.volume = obj["volume"].str.to!long;
        if ("side" in obj) tick.side = cast(Direction)obj["side"].str;
        ticks ~= tick;
    }
    return ticks;
}
