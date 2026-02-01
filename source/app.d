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

    writeln("\n=== Market Data API Examples ===");

    auto aapl = new Security("AAPL", Category.US_STOCK);
    aapl.autoUpdate = false;
    writeln("Created Security for: ", aapl.symbol, " (ID: ", aapl.instrumentId, ")");

    runExample("Snapshot for " ~ aapl.symbol, {
        getSnapshot(aapl);
        auto snap = aapl.snapshot();
        writeln("Symbol: ", aapl.symbol);
        writeln("Price: $", snap.price);
        writeln("Open: $", snap.open);
        writeln("High: $", snap.high);
        writeln("Low: $", snap.low);
        writeln("Volume: ", snap.volume);
        writeln("Change: $", snap.change, " (", snap.changeRatio, "%)");
    });

    runExample("M5 bars for " ~ aapl.symbol, {
        getBars(aapl, Timespan.M5, 10);
        auto bars = aapl.bars();
        writeln("Got ", bars.length, " bars:");
        foreach (bar; bars)
        {
            writeln(bar.time, ": O=", bar.open, " H=", bar.high,
                    " L=", bar.low, " C=", bar.close, " V=", bar.volume);
        }
    });

    runExample("Order book for " ~ aapl.symbol, {
        getOrderBook(aapl, 5);
        auto book = aapl.orderBook();
        writeln("Bids:");
        foreach (level; book.bids)
            writeln("  $", level.price, " x ", level.size);
        writeln("Asks:");
        foreach (level; book.asks)
            writeln("  $", level.price, " x ", level.size);
    });

    runExample("Recent ticks for " ~ aapl.symbol, {
        getTicks(aapl, 30, [Session.RTH]);
        auto ticks = aapl.ticks();
        writeln("Got ", ticks.length, " ticks");
        size_t start = ticks.length > 5 ? ticks.length - 5 : 0;
        foreach (tick; ticks[start .. $])
            writeln("  ", tick.time, ": $", tick.price, " x ", tick.volume, " (", tick.side, ")");
    });

    runExample("Batch snapshots", {
        Security[] securities = [
            new Security("AAPL", Category.US_STOCK),
            new Security("TSLA", Category.US_STOCK),
            new Security("GOOGL", Category.US_STOCK)
        ];
        foreach (sec; securities)
            sec.autoUpdate = false;
        auto snaps = getSnapshot(securities);
        foreach (i, snap; snaps)
            writeln(securities[i].symbol, ": $", snap.price, " (", snap.changeRatio, "%)");
    });
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

void runExample(string title, void delegate() action)
{
    writeln("\n--- ", title, " ---");
    try
    {
        action();
    }
    catch (Exception e)
    {
        writeln("Error: ", e.msg);
    }
}
