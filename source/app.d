import std.stdio;
import std.json;
import std.file : read, write, exists;
import webull.composer;
import webull.client;
import webull.security;
import webull.market;
import core.thread;
import core.time;
import std.datetime;

void main()
{
    string envJson = cast(string) read("env.json");
    JSONValue env = parseJSON(envJson);
    Client.key = env["key"].str;
    Client.secret = env["secret"].str;
    
    writeln("App credentials loaded.");
    
    if (exists("token.json"))
    {
        try
        {
            JSONValue json = (cast(string)read("token.json")).parseJSON();
            
            Client.token.token = json["token"].str;
            Client.token.expires = json["expires"].integer;
            Client.checkToken();
            
            writeln("Loaded cached token with status: ", Client.token.status);
        }
        catch (Exception e)
        {
            writeln("Failed to load cached token: ", e.msg);
        }
    }
    
    // writeln("\n=== Getting instruments for AAPL and TSLA ===");
    // try
    // {
    //     JSONValue[] instruments = Quote.getInstruments(["AAPL", "TSLA"]);
    //     writeln("Found ", instruments.length, " instruments:");
    //     foreach (i, inst; instruments)
    //     {
    //         writeln("\nInstrument ", i, ":");
    //         writeln(inst.toString());
    //     }
    // }
    // catch (Exception e)
    // {
    //     writeln("Error getting instruments: ", e.msg);
    // }
    
    // writeln("\n=== Getting quote for AAPL ===");
    // try
    // {
    //     JSONValue quote = Quote.getQuote("AAPL");
    //     writeln("Quote data:");
    //     writeln(quote.toString());
    // }
    // catch (Exception e)
    // {
    //     writeln("Error getting quote: ", e.msg);
    // }
    
    // Create new token with polling callback
    if (Client.token.status != Status.NORMAL)
    {
        Client.createToken((Status status) {
            writeln("Token status: ", status, " - waiting for approval...");
        });

        saveToken();
        writeln("Token created successfully with status: ", Client.token.status);
    }
    
    // Detect available permissions
    writeln("\n=== Detecting API Permissions ===");
    Client.detectPermissions();
    writeln("Available permissions: ", Client.permissions);

    // Example usage of new Security struct and market data API
    writeln("\n=== Market Data API Examples ===");

    // Create a Security using the constructor with compile-time category
    auto aapl = Security("AAPL", Category.US_STOCK);
    writeln("Created Security for: ", aapl.symbol, " (ID: ", aapl.instrumentId, ")");

    writeln("\n--- Getting snapshot for AAPL ---");
    try
    {
        Snapshot snap = getSnapshot(aapl);
        writeln("Symbol: ", snap.security.symbol);
        writeln("Price: $", snap.price);
        writeln("Open: $", snap.open);
        writeln("High: $", snap.high);
        writeln("Low: $", snap.low);
        writeln("Volume: ", snap.volume);
        writeln("Change: $", snap.change, " (", snap.changeRatio, "%)");
    }
    catch (Exception e)
    {
        writeln("Error getting snapshot: ", e.msg);
    }

    writeln("\n--- Getting 5-minute bars for AAPL ---");
    try {
        Bar[] bars = getBars(aapl, Timespan.M5, 10);
        writeln("Got ", bars.length, " bars:");
        foreach (bar; bars) {
            writeln(bar.time, ": O=", bar.open, " H=", bar.high,
                    " L=", bar.low, " C=", bar.close, " V=", bar.volume);
        }
    }
    catch (Exception e) {
        writeln("Error getting bars: ", e.msg);
    }

    writeln("\n--- Getting order book for AAPL ---");
    try
    {
        OrderBook book = getOrderBook(aapl, 5);
        writeln("Bids:");
        foreach (level; book.bids)
        {
            writeln("  $", level.price, " x ", level.size);
        }
        writeln("Asks:");
        foreach (level; book.asks)
        {
            writeln("  $", level.price, " x ", level.size);
        }
    }
    catch (Exception e)
    {
        writeln("Error getting order book: ", e.msg);
    }

    writeln("\n--- Getting tick data for AAPL ---");
    try {
        TickData[] ticks = getTicks(aapl, [Session.RTH]);
        writeln("Got ", ticks.length, " ticks");
        size_t start = ticks.length > 5 ? ticks.length - 5 : 0;
        foreach (tick; ticks[start .. $]) {
            writeln("  ", tick.time, ": $", tick.price, " x ", tick.volume, " (", tick.side, ")");
        }
    }
    catch (Exception e) {
        writeln("Error getting tick data: ", e.msg);
    }

    writeln("\n--- Batch snapshot for multiple symbols ---");
    try {
        Security[] securities = [Security("AAPL", Category.US_STOCK),
                               Security("TSLA", Category.US_STOCK),
                               Security("GOOGL", Category.US_STOCK)];
        Snapshot[] snaps = getSnapshots(securities);
        foreach (snap; snaps) {
            writeln(snap.security.symbol, ": $", snap.price, " (", snap.changeRatio, "%)");
        }
    }
    catch (Exception e) {
        writeln("Error getting batch snapshots: ", e.msg);
    }
}

void saveToken()
{
    JSONValue json = JSONValue.emptyObject;
    json["token"] = Client.token.token;
    json["expires"] = Client.token.expires;
    json["status"] = cast(string)Client.token.status;
    
    write("token.json", json.toString());
    writeln("Token saved to token.json");
}
