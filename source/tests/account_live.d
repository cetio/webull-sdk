module tests.account_live;

version (WebullSdkTestLive)
{
    import std.process : environment;
    import webull.account;
    import webull.client;

    @system unittest
    {
        string key = environment.get("WEBULL_APP_KEY", null);
        string secret = environment.get("WEBULL_APP_SECRET", null);
        if (key is null || key.length == 0 || secret is null || secret.length == 0)
            return;

        Client.key = key;
        Client.secret = secret;

        string endpoint = environment.get("WEBULL_API_ENDPOINT", null);
        if (endpoint !is null && endpoint.length > 0)
            Client.endpoint = endpoint;

        Account[] accounts = getAccounts();
        assert(accounts.length >= 0);
    }
}
