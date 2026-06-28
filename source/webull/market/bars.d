module webull.market.bars;

import webull.market.types;
import webull.client : Client, Permissions;
import std.json;
import std.conv : to;
import std.algorithm : map;
import std.array : join, array;

// TODO: Bars and footprint are NOT properly unified and is annoying to use and has redundancy!
void getBars(
    Security security,
    Timespan timespan, 
    int count = 200, 
    bool realTime = true, 
    Session[] sessions = [Session.PRE, Session.RTH, Session.ATH]
)
{
    if (!(Client.permissions & Permissions.BARS))
        throw new Exception("Bars API not available - permission denied");
    
    JSONValue json = Client.get(
        "/openapi/market-data/stock/bars",
        [
            "symbol": security.symbol,
            "category": cast(string)security.category,
            "timespan": cast(string)timespan,
            "count": count.to!string,
            "real_time_required": realTime.to!string,
            "trading_sessions": sessions.map!(s => cast(string)s).array.join(",")
        ],
        "v2",
    );
    
    security._bars = parseBars(json);
}

void getBars(
    Security[] securities, 
    Timespan timespan, 
    int count = 200, 
    bool realTime = true, 
    Session[] sessions = [Session.PRE, Session.RTH, Session.ATH]
)
{
    if (!(Client.permissions & Permissions.BARS))
        throw new Exception("Batch bars API not available - permission denied");
    
    JSONValue params = JSONValue.emptyObject;
    params["symbols"] = JSONValue(securities.map!(x => x.symbol).join(","));
    params["category"] = cast(string)securities[0].category;
    params["timespan"] = cast(string)timespan;
    params["count"] = count;
    params["real_time_required"] = realTime.to!string;
    params["trading_sessions"] = sessions.map!(s => cast(string)s).array.join(",");

    JSONValue json = Client.post(
        "/openapi/market-data/stock/batch-bars",
        null,
        params,
        "v2",
    );
    
    Bar[][string] bars = parseBatchBars(json);
    foreach (security; securities)
        security._bars = bars[security.symbol];
}

package:

Bar[][string] parseBatchBars(JSONValue json)
{
    if ("result" !in json || json["result"].type != JSONType.array)
        throw new Exception("Bars list invalid: "~json.toString);
    
    Bar[][string] ret;
    foreach (JSONValue obj; json["result"].array)
        ret[obj["symbol"].str] = parseBars(obj["bars"]);
        
    return ret;
}

Bar[] parseBars(JSONValue json)
{
    if (json.type != JSONType.array)
        throw new Exception("Bars list invalid: "~json.toString);
        
    Bar[] bars;
    foreach (JSONValue obj; json.array)
    {
        Bar bar;
        if ("time" in obj) bar.time = obj["time"].str;
        if ("open" in obj) bar.open = obj["open"].str.to!double;
        if ("high" in obj) bar.high = obj["high"].str.to!double;
        if ("low" in obj) bar.low = obj["low"].str.to!double;
        if ("close" in obj) bar.close = obj["close"].str.to!double;
        if ("volume" in obj) bar.volume = obj["volume"].str.to!long;
        if ("trading_session" in obj) bar.tradingSession = obj["trading_session"].str;
        bars ~= bar;
    }

    return bars;
}