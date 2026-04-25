module tests.account_dummy;

version (WebullSdkTestDummy)
{
    import conductor.query : parseQuery;
    import core.thread : Thread;
    import std.algorithm.searching : canFind;
    import std.conv : to;
    import std.socket;
    import std.string : indexOf, split, splitLines;
    import std.uni : toLower;
    import webull.account;
    import webull.client;

    struct ExpectedResponse
    {
        ushort status = 200;
        string reason = "OK";
        string contentType = "application/json";
        string body;
    }

    struct CapturedRequest
    {
        string method;
        string path;
        string queryString;
        string[string] query;
        string[string] headers;
    }

    class DummyServer
    {
    private:
        Socket _listener;
        Thread _thread;
        ExpectedResponse[] _responses;
        CapturedRequest[] _requests;
        ushort _port;

    public:
        this(ExpectedResponse[] responses)
        {
            _responses = responses.dup;

            _listener = new Socket(AddressFamily.INET, SocketType.STREAM);
            _listener.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, true);
            _listener.bind(new InternetAddress("127.0.0.1", 0));
            _listener.listen(8);
            _port = (cast(InternetAddress)_listener.localAddress).port;
        }

       ~this()
        {
            if (_listener !is null)
                _listener.close();
        }

        ushort port() const
            => _port;

        void start()
        {
            _thread = new Thread({
                foreach (ExpectedResponse response; _responses)
                {
                    auto connection = _listener.accept();
                    scope (exit) connection.close();

                    _requests~= readRequest(connection);
                    writeResponse(connection, response);
                }
            });
            _thread.start();
        }

        void join()
        {
            if (_thread !is null)
            {
                _thread.join();
                _thread = null;
            }

            if (_listener !is null)
            {
                _listener.close();
                _listener = null;
            }
        }

        CapturedRequest[] requests()
            => _requests.dup;

    private:
        CapturedRequest readRequest(Socket connection)
        {
            ubyte[4096] buffer = void;
            string raw;
            while (!raw.canFind("\r\n\r\n"))
            {
                ptrdiff_t received = connection.receive(buffer[]);
                if (received <= 0)
                    break;

                raw ~= cast(string)buffer[0 .. received].idup;
            }

            string[] lines = splitLines(raw);
            assert(lines.length > 0, "Expected an HTTP request.");

            string[] requestLine = lines[0].split(" ");
            assert(requestLine.length >= 2, "Malformed HTTP request line.");

            CapturedRequest request;
            request.method = requestLine[0];

            string target = requestLine[1];
            ptrdiff_t question = target.indexOf('?');
            if (question < 0)
                request.path = target;
            else
            {
                request.path = target[0 .. question];
                request.queryString = target[question + 1 .. $];
                request.query = parseQuery(request.queryString);
            }

            foreach (string line; lines[1 .. $])
            {
                if (line.length == 0)
                    break;

                ptrdiff_t separator = line.indexOf(": ");
                if (separator <= 0)
                    continue;

                request.headers[toLower(line[0 .. separator])] = line[separator + 2 .. $];
            }

            return request;
        }

        void writeResponse(Socket connection, ExpectedResponse response)
        {
            string payload = response.body is null ? "" : response.body;
            string header =
                "HTTP/1.1 "~response.status.to!string~" "~response.reason~"\r\n"~
                "Content-Type: "~response.contentType~"\r\n"~
                "Content-Length: "~payload.length.to!string~"\r\n"~
                "Connection: close\r\n\r\n";

            connection.send(cast(const(ubyte)[])header);
            if (payload.length > 0)
                connection.send(cast(const(ubyte)[])payload);
        }
    }

    private void resetState()
    {
        Client.key = "dummy-key";
        Client.secret = "dummy-secret";
        Client.endpoint = "https://api.webull.com";
        Client.permissions = Permissions.ACCOUNTS;
        Client._accounts.length = 0;
        Account.registry = null;
    }

    @system unittest
    {
        resetState();

        DummyServer server = new DummyServer([
            ExpectedResponse(404, "Not Found", "application/json", `{"error_code":"missing"}`),
            ExpectedResponse(200, "OK", "application/json", `[
                {
                    "subscription_id": "1643264151319",
                    "user_id": "1111702234",
                    "account_id": "QJHO3P1PR9425Q6UAT7QLJTEKB",
                    "account_number": "5MV06064",
                    "account_type": "CASH"
                }
            ]`),
        ]);
        server.start();
        scope (exit) server.join();

        Client.endpoint = "http://127.0.0.1:"~server.port.to!string;
        Account[] accounts = getAccounts();

        assert(accounts.length == 1);
        assert(accounts[0].accountId == "QJHO3P1PR9425Q6UAT7QLJTEKB");
        assert(accounts[0].accountNumber == "5MV06064");
        assert(accounts[0].accountType == "CASH");

        CapturedRequest[] requests = server.requests();
        assert(requests.length == 2);
        assert(requests[0].path == "/openapi/account/list");
        assert(requests[1].path == "/app/subscriptions/list");
        assert(requests[1].headers.get("x-app-key", null) == "dummy-key");
        assert("x-signature" in requests[1].headers);
        assert(requests[1].headers.get("host", null) == "127.0.0.1:"~server.port.to!string);
    }

    @system unittest
    {
        resetState();

        DummyServer server = new DummyServer([
            ExpectedResponse(200, "OK", "application/json", `{
                "account_number": "5MV06064",
                "account_type": "CASH",
                "account_status": "NORMAL"
            }`),
            ExpectedResponse(200, "OK", "application/json", `{
                "account_id": "acct-1",
                "total_asset_currency": "USD",
                "total_asset": "1247724759.52",
                "total_market_value": "89038914.52",
                "total_cash_balance": "1158685845.00",
                "margin_utilization_rate": "1.00",
                "account_currency_assets": [
                    {
                        "currency": "USD",
                        "net_liquidation_value": "458809435.44",
                        "positions_market_value": "153208546.14",
                        "cash_balance": "305600889.30",
                        "margin_power": "305587431.94",
                        "cash_power": "305587431.94",
                        "pending_incoming": "0.00",
                        "cash_frozen": "13457.36",
                        "available_withdrawal": "305587431.94",
                        "interests_unpaid": "0.00"
                    }
                ]
            }`),
        ]);
        server.start();
        scope (exit) server.join();

        Client.endpoint = "http://127.0.0.1:"~server.port.to!string;

        Account account = Account.fromSummary(AccountSummary("", "", "acct-1", "", "", ""));
        account.autoUpdate = false;

        getAccountProfile(account);
        getAccountBalance(account, "USD");
        AccountBalance balance = account.balance("USD");

        assert(account.accountNumber == "5MV06064");
        assert(account.accountType == "CASH");
        assert(account.accountStatus == "NORMAL");
        assert(balance.totalAssetCurrency == "USD");
        assert(balance.totalAsset == 1247724759.52);
        assert(balance.accountCurrencyAssets.length == 1);
        assert(balance.accountCurrencyAssets[0].currency == "USD");

        CapturedRequest[] requests = server.requests();
        assert(requests.length == 2);
        assert(requests[0].path == "/account/profile");
        assert(requests[0].query.get("account_id", null) == "acct-1");
        assert(requests[1].path == "/openapi/assets/balance");
        assert(requests[1].query.get("account_id", null) == "acct-1");
        assert(requests[1].query.get("total_asset_currency", null) == "USD");
    }

    @system unittest
    {
        resetState();

        DummyServer server = new DummyServer([
            ExpectedResponse(200, "OK", "application/json", `{
                "has_next": true,
                "holdings": [
                    {
                        "instrument_id": "913256135",
                        "symbol": "AAPL",
                        "instrument_type": "STOCK",
                        "currency": "USD",
                        "unit_cost": "9.54",
                        "qty": "11000.0",
                        "total_cost": "105006.00",
                        "last_price": "52.250",
                        "market_value": "574750.00",
                        "unrealized_profit_loss": "469744.00",
                        "unrealized_profit_loss_rate": "4.4700",
                        "holding_proportion": "0.9800"
                    }
                ]
            }`),
            ExpectedResponse(200, "OK", "application/json", `{
                "has_next": false,
                "holdings": [
                    {
                        "instrument_id": "202202180001",
                        "symbol": "TSLA",
                        "instrument_type": "STOCK",
                        "currency": "USD",
                        "unit_cost": "18.10",
                        "qty": "2.5",
                        "total_cost": "45.25",
                        "last_price": "182.50",
                        "market_value": "456.25",
                        "unrealized_profit_loss": "411.00",
                        "unrealized_profit_loss_rate": "9.0828",
                        "holding_proportion": "0.0200"
                    }
                ]
            }`),
        ]);
        server.start();
        scope (exit) server.join();

        Client.endpoint = "http://127.0.0.1:"~server.port.to!string;

        Account account = Account.fromSummary(AccountSummary("", "", "acct-1", "", "", ""));
        account.autoUpdate = false;

        getAccountPositions(account, 1);
        AccountPosition[] positions = account.positions(1);

        assert(positions.length == 2);
        assert(positions[0].symbol == "AAPL");
        assert(positions[0].quantity == 11000.0);
        assert(positions[1].symbol == "TSLA");
        assert(positions[1].quantity == 2.5);

        CapturedRequest[] requests = server.requests();
        assert(requests.length == 2);
        assert(requests[0].path == "/openapi/assets/positions");
        assert(requests[0].query.get("page_size", null) == "1");
        assert(requests[1].query.get("last_instrument_id", null) == "913256135");
    }

    @system unittest
    {
        resetState();
        Account first = Account.fromSummary(AccountSummary("", "", "acct-1", "1111", "CASH", ""));
        Account second = Account.fromSummary(AccountSummary("sub-1", "user-1", "acct-1", "", "", "NORMAL"));

        assert(first is second);
        assert(second.accountNumber == "1111");
        assert(second.subscriptionId == "sub-1");
        assert(second.userId == "user-1");
        assert(second.accountStatus == "NORMAL");
    }
}
