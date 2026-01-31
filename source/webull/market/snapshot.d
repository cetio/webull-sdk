module webull.market.snapshot;

import webull.composer;
import webull.market.types;
import std.json;
import std.string : assumeUTF;
import std.conv : to;
import std.algorithm : map;
import std.array : join;

Snapshot getSnapshot(Security security, bool extendedHours = false, bool overnight = false)
{
    if (!(Client.permissions & Permissions.SNAPSHOTS))
        throw new Exception("Snapshots API not available - permission denied");
    
    JSONValue json;
    string[string] params = [
        "symbols": security.symbol,
        "category": cast(string)security.category
    ];

    if (extendedHours)
        params["extend_hour_required"] = "true";
    if (overnight)
        params["overnight_required"] = "true";

    orchestrate(
        "api.webull.com",
        "/market-data/snapshot",
        params
    ).get(
        (ubyte[] data) { json = parseJSON(data.assumeUTF); },
        (ubyte[] data) { throw new Exception("HTTP request failed: "~cast(string)data.assumeUTF); }
    );
    
    if (json.type == JSONType.array && json.array.length > 0)
        return parseSnapshot(json.array[0], security);
    else if (json.type == JSONType.object)
        return parseSnapshot(json, security);
    else
        throw new Exception("Unexpected snapshot response format");
}

Snapshot[] getSnapshots(Security[] securities, bool extendedHours = false, bool overnight = false)
{
    if (!(Client.permissions & Permissions.SNAPSHOTS))
        throw new Exception("Snapshots API not available - permission denied");
    
    string[] symbols;
    foreach (s; securities) symbols ~= s.symbol;
    JSONValue json;
    string[string] params = [
        "symbols": symbols.join(","),
        "category": cast(string)securities[0].category
    ];

    if (extendedHours)
        params["extend_hour_required"] = "true";
    if (overnight)
        params["overnight_required"] = "true";

    orchestrate(
        "api.webull.com",
        "/market-data/snapshot",
        params
    ).get(
        (ubyte[] data) { json = parseJSON(data.assumeUTF); },
        (ubyte[] data) { throw new Exception("HTTP request failed: "~cast(string)data.assumeUTF); }
    );
    
    Snapshot[] snapshots;
    if (json.type == JSONType.array)
    {
        foreach (size_t i, JSONValue item; json.array)
            snapshots ~= parseSnapshot(item, securities[i]);
    }
    else if (json.type == JSONType.object)
    {
        snapshots ~= parseSnapshot(json, securities[0]);
    }
    
    return snapshots;
}


Snapshot parseSnapshot(JSONValue json, Security security)
{
    Snapshot s;
    s.security = security;

    if ("last_trade_time" in json) s.lastTradeTime = json["last_trade_time"].integer;
    if ("price" in json) s.price = json["price"].str.to!double;
    if ("open" in json) s.open = json["open"].str.to!double;
    if ("high" in json) s.high = json["high"].str.to!double;
    if ("low" in json) s.low = json["low"].str.to!double;
    if ("close" in json) s.close = json["close"].str.to!double;
    if ("pre_close" in json) s.preClose = json["pre_close"].str.to!double;
    if ("volume" in json) s.volume = json["volume"].str.to!long;
    if ("change" in json) s.change = json["change"].str.to!double;
    if ("change_ratio" in json) s.changeRatio = json["change_ratio"].str.to!double;
    if ("ask" in json) s.ask = json["ask"].str.to!double;
    if ("ask_size" in json) s.askSize = json["ask_size"].str.to!long;
    if ("bid" in json) s.bid = json["bid"].str.to!double;
    if ("bid_size" in json) s.bidSize = json["bid_size"].str.to!long;

    // Extended hours
    if ("extend_hour_last_price" in json)
        s.extendHourLastPrice = json["extend_hour_last_price"].str.to!double;
    if ("extend_hour_high" in json)
        s.extendHourHigh = json["extend_hour_high"].str.to!double;
    if ("extend_hour_low" in json)
        s.extendHourLow = json["extend_hour_low"].str.to!double;
    if ("extend_hour_change" in json)
        s.extendHourChange = json["extend_hour_change"].str.to!double;
    if ("extend_hour_change_ratio" in json)
        s.extendHourChangeRatio = json["extend_hour_change_ratio"].str.to!double;
    if ("extend_hour_volume" in json)
        s.extendHourVolume = json["extend_hour_volume"].str.to!long;
    if ("extend_hour_last_trade_time" in json)
        s.extendHourLastTradeTime = json["extend_hour_last_trade_time"].integer;

    // Overnight
    if ("ovn_price" in json) s.ovnPrice = json["ovn_price"].str.to!double;
    if ("ovn_high" in json) s.ovnHigh = json["ovn_high"].str.to!double;
    if ("ovn_low" in json) s.ovnLow = json["ovn_low"].str.to!double;
    if ("ovn_volume" in json) s.ovnVolume = json["ovn_volume"].str.to!long;
    if ("ovn_change" in json) s.ovnChange = json["ovn_change"].str.to!double;
    if ("ovn_change_ratio" in json) s.ovnChangeRatio = json["ovn_change_ratio"].str.to!double;
    if ("ovn_last_trade_time" in json)
        s.ovnLastTradeTime = json["ovn_last_trade_time"].integer;
    if ("ovn_ask" in json) s.ovnAsk = json["ovn_ask"].str.to!double;
    if ("ovn_ask_size" in json) s.ovnAskSize = json["ovn_ask_size"].str.to!long;
    if ("ovn_bid" in json) s.ovnBid = json["ovn_bid"].str.to!double;
    if ("ovn_bid_size" in json) s.ovnBidSize = json["ovn_bid_size"].str.to!long;

    return s;
}
