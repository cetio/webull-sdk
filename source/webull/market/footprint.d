module webull.market.footprint;

import webull.composer;
import webull.market.types;
import std.json;
import std.string : assumeUTF;
import std.conv : to;

FootprintBar[] getFootprint(Security security, Timespan timespan, int count = 100)
{
    if (!(Client.permissions & Permissions.FOOTPRINT))
        throw new Exception("Footprint API not available - permission denied");
    
    JSONValue json;
    orchestrate!"v2"(
        "api.webull.com",
        "/openapi/market-data/stock/footprint",
        [
            "symbol": security.symbol,
            "category": cast(string)security.category,
            "timespan": cast(string)timespan,
            "count": count.to!string
        ]
    ).get(
        (ubyte[] data) { json = parseJSON(data.assumeUTF); },
        (ubyte[] data) { throw new Exception("HTTP request failed: "~cast(string)data.assumeUTF); }
    );
    
    return parseFootprintBars(json, security);
}


FootprintBar[] parseFootprintBars(JSONValue json, Security security)
{
    FootprintBar[] bars;

    if (json.type != JSONType.array)
        return bars;

    foreach (JSONValue item; json.array)
    {
        if ("result" in item && item["result"].type == JSONType.array)
        {
            foreach (JSONValue barItem; item["result"].array)
            {
                FootprintBar bar;
                bar.security = security;
                if ("time" in barItem) bar.time = barItem["time"].str.to!long;
                if ("trading_session" in barItem) bar.tradingSession = barItem["trading_session"].str;
                if ("total" in barItem) bar.total = barItem["total"].str.to!long;
                if ("delta" in barItem) bar.delta = barItem["delta"].str.to!long;
                if ("buy_total" in barItem) bar.buyTotal = barItem["buy_total"].str.to!long;
                if ("sell_total" in barItem) bar.sellTotal = barItem["sell_total"].str.to!long;

                if ("buy_detail" in barItem && barItem["buy_detail"].type == JSONType.object)
                {
                    foreach (string price, JSONValue volume; barItem["buy_detail"].object)
                    {
                        FootprintLevel level;
                        level.price = price.to!double;
                        level.volume = volume.str.to!long;
                        bar.buyDetail ~= level;
                    }
                }

                if ("sell_detail" in barItem && barItem["sell_detail"].type == JSONType.object)
                {
                    foreach (string price, JSONValue volume; barItem["sell_detail"].object)
                    {
                        FootprintLevel level;
                        level.price = price.to!double;
                        level.volume = volume.str.to!long;
                        bar.sellDetail ~= level;
                    }
                }

                bars ~= bar;
            }
        }
    }

    return bars;
}
