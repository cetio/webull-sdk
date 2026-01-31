module webull.quote;

import webull.composer;
import std.json;
import std.string;
import std.conv;
import std.exception;
import std.algorithm;

class Quote
{
    static JSONValue[] getInstruments(string[] symbols, string category = "US_STOCK")
    {
        JSONValue[] ret;
        orchestrate(
            "api.webull.com",
            "/instrument/list",
            [
                "symbols": symbols.join(","),
                "category": category
            ]
        ).get(
            (ubyte[] data) {
                JSONValue json = parseJSON(data.assumeUTF);
                if (json.type == JSONType.array)
                    ret = json.array;
                else
                    ret = [json];
            },
            (ubyte[] data) {
                throw new Exception("HTTP request failed: "~cast(string)data.assumeUTF);
            }
        );
        return ret;
    }
    
    static JSONValue getQuote(string symbol, string category = "US_STOCK")
    {
        JSONValue[] quotes = getQuotes([symbol], category);
        if (quotes.length == 0)
            throw new Exception("No quote data returned for symbol: "~symbol);
        return quotes[0];
    }
    
    static JSONValue[] getQuotes(string[] symbols, string category = "US_STOCK")
    {
        JSONValue[] ret;
        orchestrate(
            "api.webull.com",
            "/market-data/snapshot",
            [
                "symbols": symbols.join(","),
                "category": category
            ]
        ).get(
            (ubyte[] data) {
                JSONValue json = parseJSON(data.assumeUTF);
                if (json.type == JSONType.array)
                    ret = json.array;
                else
                    ret = [json];
            },
            (ubyte[] data) {
                throw new Exception("HTTP request failed: "~cast(string)data.assumeUTF);
            }
        );
        return ret;
    }
    
    static JSONValue getInstrument(string symbol, string category = "US_STOCK")
    {
        JSONValue[] instruments = getInstruments([symbol], category);
        if (instruments.length == 0)
            throw new Exception("Symbol not found: "~symbol);
        return instruments[0];
    }
    
    static string getTickerId(string symbol)
    {
        JSONValue[] instruments = getInstruments([symbol]);
        if (instruments.length == 0)
            throw new Exception("Symbol not found: "~symbol);
        
        foreach (JSONValue inst; instruments)
        {
            if (inst.type == JSONType.object)
            {
                if ("symbol" in inst && inst["symbol"].str == symbol)
                {
                    if ("instrument_id" in inst)
                        return inst["instrument_id"].str;
                    if ("tickerId" in inst)
                        return inst["tickerId"].str;
                }
            }
        }
        
        if ("instrument_id" in instruments[0])
            return instruments[0]["instrument_id"].str;
        if ("tickerId" in instruments[0])
            return instruments[0]["tickerId"].str;
            
        throw new Exception("Could not find ticker ID for symbol: "~symbol);
    }
}
