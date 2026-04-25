module webull.market.footprint;

import webull.orchestrate;
import webull.market.types;
import webull.client : Client, Permissions;
import std.json;
import std.string : assumeUTF;
import std.algorithm : map;
import std.array : join, array;
import std.conv : to;

// OVN session not supported
void getFootprint(
    Security security, 
    Timespan timespan, 
    int count = 200, 
    bool realTime = true, 
    Session[] sessions = [Session.PRE, Session.RTH, Session.ATH]
)
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
            "count": count.to!string,
            "real_time_required": realTime.to!string,
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
    
    security._bars = parseFootprintBars(json);
}

package:

Bar[] parseFootprintBars(JSONValue json)
{
    if (json.type != JSONType.array)
        throw new Exception("Footprint invalid: "~json.toString);

    Bar[] bars;
    foreach (JSONValue item; json.array)
    {
        if ("result" !in item)
            continue;

        foreach (JSONValue obj; item["result"].array)
        {
            Bar bar;
            if ("time" in obj) bar.time = obj["time"].str;
            if ("trading_session" in obj) bar.tradingSession = obj["trading_session"].str;
            if ("total" in obj) bar.total = obj["total"].str.to!long;
            if ("delta" in obj) bar.delta = obj["delta"].str.to!long;
            if ("buy_total" in obj) bar.buyTotal = obj["buy_total"].str.to!long;
            if ("sell_total" in obj) bar.sellTotal = obj["sell_total"].str.to!long;

            if ("buy_detail" in obj)
            {
                foreach (string price, JSONValue volume; obj["buy_detail"].object)
                {
                    BookLevel level;
                    level.price = price.to!double;
                    level.size = volume.str.to!long;
                    bar.buyDetail~= level;
                }
            }

            if ("sell_detail" in obj)
            {
                foreach (string price, JSONValue volume; obj["sell_detail"].object)
                {
                    BookLevel level;
                    level.price = price.to!double;
                    level.size = volume.str.to!long;
                    bar.sellDetail~= level;
                }
            }

            bars~= bar;
        }
    }
    return bars;
}
