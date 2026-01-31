import std.stdio;
import std.json;
import std.file : read, write, exists;
import webull.composer;
import webull.quote;
import webull.client;
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
