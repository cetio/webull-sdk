module webull.security;

import webull.composer;
import std.json;
import std.string : assumeUTF;
import std.algorithm : map;
import std.array : join;
import std.exception : enforce;

enum Category : string
{
    US_STOCK = "US_STOCK",
    US_OPTION = "US_OPTION",
    HK_STOCK = "HK_STOCK",
    CN_STOCK = "CN_STOCK",
    CRYPTO = "CRYPTO",
    FUTURES = "FUTURES"
}

struct Security
{
    string symbol;
    string instrumentId;
    string name;
    string exchange;
    string currency;
    string status;
    Category category;

    this(string symbol, Category category)
    {
        this.symbol = symbol;
        this.category = category;
        
        JSONValue json;
        orchestrate(
            "api.webull.com",
            "/instrument/list",
            [
                "symbols": symbol,
                "category": cast(string)category
            ]
        ).get(
            (ubyte[] data) {
                json = parseJSON(data.assumeUTF);
            },
            (ubyte[] data) {
                throw new Exception("Failed to fetch instrument: "~cast(string)data.assumeUTF);
            }
        );

        if (json.type == JSONType.object)
        {
            if ("instrument_id" in json) this.instrumentId = json["instrument_id"].str;
            if ("name" in json) this.name = json["name"].str;
            if ("exchange" in json) this.exchange = json["exchange"].str;
            if ("currency" in json) this.currency = json["currency"].str;
            if ("status" in json) this.status = json["status"].str;
        }
        else if (json.type == JSONType.array && json.array.length > 0)
        {
            JSONValue item = json.array[0];
            if ("instrument_id" in item) this.instrumentId = item["instrument_id"].str;
            if ("name" in item) this.name = item["name"].str;
            if ("exchange" in item) this.exchange = item["exchange"].str;
            if ("currency" in item) this.currency = item["currency"].str;
            if ("status" in item) this.status = item["status"].str;
        }
    }
}

