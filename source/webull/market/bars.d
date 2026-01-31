module webull.market.bars;

import webull.composer;
import webull.market.types;
import std.json;
import std.string : assumeUTF;
import std.conv : to;
import std.exception : enforce;

Bar[] getBars(Security security, Timespan timespan, int count = 100)
{
    if (!(Client.permissions & Permissions.BARS))
        throw new Exception("Bars API not available - permission denied");
    
    JSONValue json;
    string[string] params = [
        "symbol": security.symbol,
        "category": cast(string)security.category,
        "timespan": cast(string)timespan,
        "count": count.to!string
    ];

    orchestrate!"v2"(
        "api.webull.com",
        "/openapi/market-data/stock/bars",
        params
    ).get(
        (ubyte[] data) { json = parseJSON(data.assumeUTF); },
        (ubyte[] data) { throw new Exception("HTTP request failed: "~cast(string)data.assumeUTF); }
    );
    
    return parseBars(json, security);
}

Bar[][string] getBatchBars(Security[] securities, Timespan timespan, int count = 100)
{
    if (!(Client.permissions & Permissions.BARS))
        throw new Exception("Batch bars API not available - permission denied");
    
    string[] symbols;
    Security[string] secMap;
    foreach (s; securities)
    {
        symbols ~= s.symbol;
        secMap[s.symbol] = s;
    }
    
    JSONValue json;
    JSONValue pbody = JSONValue.emptyObject;
    pbody["symbols"] = JSONValue(symbols);
    pbody["category"] = cast(string)securities[0].category;
    pbody["timespan"] = cast(string)timespan;
    pbody["count"] = count;

    orchestrate!"v2"(
        "api.webull.com",
        "/openapi/market-data/stock/batch-bars",
        null,
        pbody
    ).post(
        (ubyte[] data) { json = parseJSON(data.assumeUTF); },
        (ubyte[] data) { throw new Exception("HTTP request failed: "~cast(string)data.assumeUTF); },
        pbody
    );
    
    return parseBatchBars(json, securities[0].category, secMap);
}


Bar[][string] parseBatchBars(JSONValue json, Category category, Security[string] secMap = null)
{
    Bar[][string] ret;
    
    // Handle documented batch format: { "result": [ { "symbol": "...", "result": [...] } ] }
    if (json.type == JSONType.object && "result" in json && json["result"].type == JSONType.array)
    {
        foreach (JSONValue item; json["result"].array)
        {
            if ("symbol" in item && "result" in item && item["result"].type == JSONType.array)
            {
                string symbol = item["symbol"].str;
                Security sec;
                if (secMap !is null && symbol in secMap)
                    sec = secMap[symbol];
                else
                {
                    sec.symbol = symbol;
                    sec.category = category;
                }
                ret[symbol] = parseBars(item["result"], sec);
            }
        }
    }
    // Fallback: legacy symbol-keyed format
    else if (json.type == JSONType.object)
    {
        foreach (string sym, JSONValue barData; json.object)
        {
            Security sec;
            if (secMap !is null && sym in secMap)
                sec = secMap[sym];
            else
            {
                sec.symbol = sym;
                sec.category = category;
            }
            ret[sym] = parseBars(barData, sec);
        }
    }
    
    return ret;
}

Bar[] parseBars(JSONValue json, Security security)
{
    Bar[] bars;

    // Handle single bars format (direct array)
    if (json.type == JSONType.array)
    {
        foreach (JSONValue item; json.array)
            bars ~= parseBar(item, security);
    }
    // Handle single bars format (wrapped object)
    else if (json.type == JSONType.object)
    {
        if ("data" in json) json = json["data"];
        else if ("list" in json) json = json["list"];
        else if ("records" in json) json = json["records"];
        else if ("bars" in json) json = json["bars"];
        
        if (json.type == JSONType.array)
        {
            foreach (JSONValue item; json.array)
                bars ~= parseBar(item, security);
        }
    }

    return bars;
}

Bar parseBar(JSONValue item, Security security)
{
    Bar bar;
    bar.security = security;
    if ("time" in item) bar.time = item["time"].str.to!long;
    if ("open" in item) bar.open = item["open"].str.to!double;
    if ("high" in item) bar.high = item["high"].str.to!double;
    if ("low" in item) bar.low = item["low"].str.to!double;
    if ("close" in item) bar.close = item["close"].str.to!double;
    if ("volume" in item) bar.volume = item["volume"].str.to!long;
    if ("trading_session" in item) bar.tradingSession = item["trading_session"].str;
    return bar;
}
