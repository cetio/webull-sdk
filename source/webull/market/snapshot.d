module webull.market.snapshot;

import webull.market.types;
import webull.client : Client, Permissions;
import std.json;
import std.conv : to;
import std.algorithm : map;
import std.array : join, array;

void getSnapshot(
    Security security, 
    bool extendedHours = false, 
    bool overnight = false
)
{
    if (!(Client.permissions & Permissions.SNAPSHOTS))
        throw new Exception("Snapshots API not available - permission denied");
    
    JSONValue json = Client.get(
        "/market-data/snapshot",
        [
            "symbols": security.symbol,
            "category": cast(string)security.category,
            "extended_hour_required": extendedHours.to!string,
            "overnight_required": overnight.to!string
        ],
    );
    
    if (json.type == JSONType.array && json.array.length > 0)
        security._snapshot = parseSnapshot(json.array[0]);
    else if (json.type == JSONType.object)
        security._snapshot = parseSnapshot(json);
    else
        throw new Exception("Unexpected snapshot response format");
}

Snapshot[] getSnapshot(
    Security[] securities, 
    bool extendedHours = false, 
    bool overnight = false
)
{
    if (!(Client.permissions & Permissions.SNAPSHOTS))
        throw new Exception("Snapshots API not available - permission denied");

    JSONValue json = Client.get(
        "/market-data/snapshot",
        [
            "symbols": securities.map!(x => x.symbol).array.join(","),
            "category": cast(string)securities[0].category,
            "extended_hour_required": extendedHours.to!string,
            "overnight_required": overnight.to!string
        ],
    );
    
    Snapshot[] snapshots;
    if (json.type == JSONType.array)
    {
        foreach (i, obj; json.array)
            snapshots ~= parseSnapshot(obj);
    }
    else if (json.type == JSONType.object)
        snapshots ~= parseSnapshot(json);

    return snapshots;
}

package:

Snapshot parseSnapshot(JSONValue json)
{
    if ("symbol" !in json)
        throw new Exception("Snapshot invalid: "~json.toString);

    Snapshot s;
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
