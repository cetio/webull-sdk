module webull.market.quotes;

import webull.market.types;
import webull.client : Client, Permissions;
import std.json;
import std.conv : to;

void getOrderBook(
    Security security, 
    int depth = 5, 
    bool overnight = false
)
{
    if (!(Client.permissions & Permissions.QUOTES))
        throw new Exception("Quotes API not available - permission denied");
    
    JSONValue json = Client.get(
        "/openapi/market-data/stock/quotes",
        [
            "symbol": security.symbol,
            "category": cast(string)security.category,
            "depth": depth.to!string,
            "overnight_required": overnight.to!string
        ],
        "v2",
    );
    
    security._orderBook = parseOrderBook(json);
}

package:

OrderBook parseOrderBook(JSONValue json)
{
    if ("quote_time" !in json)
        throw new Exception("Orderbook quotes invalid: "~json.toString);
        
    OrderBook ret;
    ret.time = json["quote_time"].str.to!long;

    if ("bids" in json && json["bids"].type == JSONType.array)
    {
        foreach (JSONValue level; json["bids"].array)
            ret.bids ~= parseBookLevel(level);
    }

    if ("asks" in json && json["asks"].type == JSONType.array)
    {
        foreach (JSONValue level; json["asks"].array)
            ret.asks ~= parseBookLevel(level);
    }

    return ret;
}

BookLevel parseBookLevel(JSONValue json)
{
    // NOTE: I would rather this use the constructor with named args, but the linter hates that.
    BookLevel level;
    level.price = json["price"].str.to!double;
    level.size = json["size"].str.to!long;

    // if ("order" in json && json["order"].type == JSONType.array)
    // {
    //     foreach (JSONValue order; json["order"].array)
    //     {
    //         if ("mpid" in order)
    //             level.mpids~= order["mpid"].str;
    //     }
    // }

    return level;
}
