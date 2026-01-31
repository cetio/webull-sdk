module webull.market.tick;

import webull.composer;
import webull.market.types;
import std.json;
import std.string : assumeUTF;
import std.conv : to;
import std.algorithm : map;
import std.array : array, join;

TickData[] getTicks(Security security, Session[] sessions = [Session.RTH])
{
    if (!(Client.permissions & Permissions.TICKS))
        throw new Exception("Ticks API not available - permission denied");
    
    JSONValue json;
    string[string] params = [
        "symbol": security.symbol,
        "category": cast(string)security.category
    ];

    if (sessions.length > 0)
        params["trading_sessions"] = sessions.map!(s => cast(string)s).array.join(",");

    orchestrate!"v2"(
        "api.webull.com",
        "/openapi/market-data/stock/tick",
        params
    ).get(
        (ubyte[] data) { json = parseJSON(data.assumeUTF); },
        (ubyte[] data) { throw new Exception("HTTP request failed: "~cast(string)data.assumeUTF); }
    );
    
    return parseTicks(json, security);
}


TickData[] parseTicks(JSONValue json, Security security)
{
    TickData[] ticks;

    JSONValue tickArray = json;
    if (json.type == JSONType.object && "result" in json)
        tickArray = json["result"];

    if (tickArray.type != JSONType.array)
        return ticks;

    foreach (JSONValue item; tickArray.array)
    {
        TickData tick;
        tick.security = security;
        if ("time" in item) tick.time = item["time"].str.to!long;
        if ("price" in item) tick.price = item["price"].str.to!double;
        if ("volume" in item) tick.volume = item["volume"].str.to!long;
        if ("side" in item)
        {
            string side = item["side"].str;
            if (side == "B") tick.side = Direction.BUY;
            else if (side == "S") tick.side = Direction.SELL;
            else tick.side = Direction.NEUTRAL;
        }
        ticks ~= tick;
    }

    return ticks;
}
