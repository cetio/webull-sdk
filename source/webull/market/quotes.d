module webull.market.quotes;

import webull.composer;
import webull.market.types;
import std.json;
import std.string : assumeUTF;
import std.conv : to;

OrderBook getOrderBook(Security security, int depth = 5, bool overnight = false)
{
    if (!(Client.permissions & Permissions.QUOTES))
        throw new Exception("Quotes API not available - permission denied");
    
    JSONValue json;
    string[string] params = [
        "symbol": security.symbol,
        "category": cast(string)security.category,
        "depth": depth.to!string,
        "overnight_required": overnight.to!string
    ];

    orchestrate!"v2"(
        "api.webull.com",
        "/openapi/market-data/stock/quotes",
        params
    ).get(
        (ubyte[] data) { json = parseJSON(data.assumeUTF); },
        (ubyte[] data) { throw new Exception("HTTP request failed: "~cast(string)data.assumeUTF); }
    );
    
    return parseOrderBook(json, security);
}


OrderBook parseOrderBook(JSONValue json, Security security)
{
    OrderBook ob;
    ob.security = security;

    if ("quote_time" in json) ob.timestamp = json["quote_time"].str.to!long;

    if ("bids" in json && json["bids"].type == JSONType.array)
    {
        foreach (JSONValue level; json["bids"].array)
            ob.bids ~= parseBookLevel(level);
    }

    if ("asks" in json && json["asks"].type == JSONType.array)
    {
        foreach (JSONValue level; json["asks"].array)
            ob.asks ~= parseBookLevel(level);
    }

    return ob;
}

BookLevel parseBookLevel(JSONValue json)
{
    BookLevel level;

    if ("price" in json) level.price = json["price"].str.to!double;
    if ("size" in json) level.size = json["size"].str.to!long;

    if ("order" in json && json["order"].type == JSONType.array)
    {
        foreach (JSONValue order; json["order"].array)
        {
            if ("mpid" in order)
                level.mpids ~= order["mpid"].str;
        }
    }

    return level;
}
