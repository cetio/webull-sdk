module examples.account_console;

version (WebullSdkExampleAccountConsole)
{
    import std.algorithm : map, sort;
    import std.array : array, join;
    import std.conv : to;
    import std.exception : enforce;
    import std.format : format;
    import std.math : fabs;
    import std.process : environment;
    import std.stdio : writeln;
    import std.string : indexOf, toLower;
    import webull.account;
    import webull.client;

    enum DemoView : string
    {
        all = "all",
        overview = "overview",
        margin = "margin",
        cash = "cash",
        holdings = "holdings",
    }

    struct DemoPosition
    {
        string symbol;
        string instrumentType;
        string currency;
        double quantity;
        double lastPrice;
        double marketValue;
        double unrealizedProfitLoss;
        double holdingProportion;
    }

    struct DemoAccount
    {
        string tag;
        string accountId;
        string accountNumber;
        string accountType;
        string accountStatus;
        string totalAssetCurrency;
        double totalAsset;
        double totalCashBalance;
        double totalMarketValue;
        double marginUtilizationRate;
        DemoPosition[] positions;
    }

    struct DemoData
    {
        bool simulated;
        string modeLabel;
        DemoAccount[] accounts;
    }

    struct RenderConfig
    {
        bool maskNumbers = true;
    }

    struct PortfolioHolding
    {
        string symbol;
        string accountTag;
        string currency;
        double quantity;
        double lastPrice;
        double marketValue;
        double unrealizedProfitLoss;
        double holdingProportion;
    }

    private bool truthy(string value)
    {
        if (value is null)
            return false;

        switch (value.toLower())
        {
        case "1":
        case "true":
        case "yes":
        case "y":
        case "on":
            return true;

        default:
            return false;
        }
    }

    private bool falsy(string value)
    {
        if (value is null)
            return false;

        switch (value.toLower())
        {
        case "0":
        case "false":
        case "no":
        case "n":
        case "off":
            return true;

        default:
            return false;
        }
    }

    private bool hasCredentials()
    {
        string key = environment.get("WEBULL_APP_KEY", null);
        string secret = environment.get("WEBULL_APP_SECRET", null);
        return key !is null && key.length > 0 && secret !is null && secret.length > 0;
    }

    private string repeat(string token, size_t count)
    {
        string result;
        result.reserve(token.length * count);
        foreach (_; 0 .. count)
            result ~= token;
        return result;
    }

    private string spaces(size_t count)
        => repeat(" ", count);

    private string visibleSlice(string text, size_t limit)
    {
        if (text.length <= limit)
            return text;

        if (limit <= 1)
            return text[0 .. limit];

        return text[0 .. limit - 1] ~ "…";
    }

    private string padRight(string text, size_t length)
    {
        string clipped = visibleSlice(text, length);
        if (clipped.length >= length)
            return clipped;

        return clipped ~ spaces(length - clipped.length);
    }

    private string padLeft(string text, size_t length)
    {
        string clipped = visibleSlice(text, length);
        if (clipped.length >= length)
            return clipped;

        return spaces(length - clipped.length) ~ clipped;
    }

    private string maskDigits(string text)
    {
        char[] output;
        output.reserve(text.length);
        foreach (dchar ch; text)
        {
            if (ch >= '0' && ch <= '9')
                output ~= '*';
            else
                output ~= cast(char)ch;
        }
        return cast(string)output;
    }

    private string maybeMask(RenderConfig config, string text)
        => config.maskNumbers ? maskDigits(text) : text;

    private string withCommas(string digits)
    {
        if (digits.length <= 3)
            return digits;

        string result;
        size_t remainder = digits.length % 3;
        if (remainder > 0)
            result ~= digits[0 .. remainder];

        for (size_t i = remainder; i < digits.length; i += 3)
        {
            if (result.length > 0)
                result ~= ",";
            result ~= digits[i .. i + 3];
        }

        return result;
    }

    private string formatFixed(double value, int precision = 2)
    {
        string raw = format("%.*f", precision, value);
        ptrdiff_t dot = raw.indexOf(".");
        if (dot < 0)
            return raw;

        string whole = raw[0 .. dot];
        string fractional = raw[dot .. $];

        bool negative = whole.length > 0 && whole[0] == '-';
        if (negative)
            whole = whole[1 .. $];

        string formatted = withCommas(whole) ~ fractional;
        return negative ? "-" ~ formatted : formatted;
    }

    private string formatQuantity(double value)
    {
        if (fabs(value - cast(long)value) < 0.000001)
            return withCommas((cast(long)value).to!string);

        return formatFixed(value, value < 10 ? 4 : 2);
    }

    private string formatMoney(RenderConfig config, double value, string currency = "USD")
    {
        string prefix = currency == "USD" ? "$" : currency ~ " ";
        if (value < 0)
            return maybeMask(config, "-" ~ prefix ~ formatFixed(-value, 2));

        return maybeMask(config, prefix ~ formatFixed(value, 2));
    }

    private string formatPercent(RenderConfig config, double value)
        => maybeMask(config, formatFixed(value * 100, 2) ~ "%");

    private string formatRawNumber(RenderConfig config, double value)
        => maybeMask(config, formatQuantity(value));

    private string formatKeyValue(string label, string value, size_t labelWidth = 13)
        => padRight(label, labelWidth) ~ value;

    private string formatStatusLine(DemoData data, RenderConfig config)
        => "mode: " ~ data.modeLabel.toLower() ~ "   privacy: " ~ (config.maskNumbers ? "masked" : "visible");

    private string normalizedTag(string accountType, size_t fallbackIndex)
    {
        string lowered = accountType.toLower();
        if (lowered.length == 0)
            return "account" ~ fallbackIndex.to!string;

        if (lowered.indexOf("margin") >= 0)
            return "margin";
        if (lowered.indexOf("cash") >= 0)
            return "cash";

        return visibleSlice(lowered, 10);
    }

    private DemoData simulatedData()
    {
        DemoData data = DemoData.init;
        data.simulated = true;
        data.modeLabel = "SIMULATED";

        DemoAccount margin = DemoAccount.init;
        margin.tag = "margin";
        margin.accountId = "QJHO3P1PR9425Q6UAT7QLJTEKB";
        margin.accountNumber = "5MV06064";
        margin.accountType = "MARGIN";
        margin.accountStatus = "NORMAL";
        margin.totalAssetCurrency = "USD";
        margin.totalAsset = 428_945.37;
        margin.totalCashBalance = 91_806.14;
        margin.totalMarketValue = 337_139.23;
        margin.marginUtilizationRate = 0.1824;
        margin.positions = [
            DemoPosition("NVDA", "EQUITY", "USD", 220, 947.12, 208_366.40, 62_801.20, 0.4860),
            DemoPosition("AAPL", "EQUITY", "USD", 145, 212.64, 30_832.80, 7_201.55, 0.0719),
            DemoPosition("META", "EQUITY", "USD", 58, 531.26, 30_813.08, 9_345.02, 0.0718),
            DemoPosition("TSLA", "EQUITY", "USD", 74, 179.31, 13_268.94, -1_844.66, 0.0309),
            DemoPosition("AMD", "EQUITY", "USD", 402, 134.03, 53_880.06, 11_420.44, 0.1256),
        ];

        DemoAccount cash = DemoAccount.init;
        cash.tag = "cash";
        cash.accountId = "FUTR8M2UX3Q7B91YPLN4C6KD0";
        cash.accountNumber = "8HV11208";
        cash.accountType = "CASH";
        cash.accountStatus = "NORMAL";
        cash.totalAssetCurrency = "USD";
        cash.totalAsset = 96_384.92;
        cash.totalCashBalance = 14_505.52;
        cash.totalMarketValue = 81_879.40;
        cash.marginUtilizationRate = 0;
        cash.positions = [
            DemoPosition("MSFT", "EQUITY", "USD", 88, 428.34, 37_693.92, 6_118.20, 0.3911),
            DemoPosition("AMZN", "EQUITY", "USD", 122, 186.44, 22_745.68, 3_522.18, 0.2359),
            DemoPosition("GOOGL", "EQUITY", "USD", 77, 165.41, 12_736.57, 1_845.44, 0.1321),
            DemoPosition("UBER", "EQUITY", "USD", 144, 60.44, 8_703.36, 1_214.77, 0.0903),
        ];

        data.accounts = [margin, cash];
        return data;
    }

    private DemoData liveData()
    {
        DemoData data = DemoData.init;
        data.simulated = false;
        data.modeLabel = "LIVE";

        Client.key = environment.get("WEBULL_APP_KEY", null);
        Client.secret = environment.get("WEBULL_APP_SECRET", null);

        string endpoint = environment.get("WEBULL_API_ENDPOINT", null);
        if (endpoint !is null && endpoint.length > 0)
            Client.endpoint = endpoint;

        Account[] accounts = getAccounts();
        foreach (i, Account account; accounts)
        {
            account.autoUpdate = false;

            getAccountProfile(account);
            getAccountBalance(account, "USD");
            getAccountPositions(account, 100);

            AccountBalance balance = account.balance("USD");
            AccountPosition[] positions = account.positions(100).dup;
            positions.sort!((a, b) => a.marketValue > b.marketValue);

            DemoAccount demo = DemoAccount.init;
            demo.tag = normalizedTag(account.accountType, i + 1);
            demo.accountId = account.accountId;
            demo.accountNumber = account.accountNumber;
            demo.accountType = account.accountType;
            demo.accountStatus = account.accountStatus;
            demo.totalAssetCurrency = balance.totalAssetCurrency;
            demo.totalAsset = balance.totalAsset;
            demo.totalCashBalance = balance.totalCashBalance;
            demo.totalMarketValue = balance.totalMarketValue;
            demo.marginUtilizationRate = balance.marginUtilizationRate;

            foreach (AccountPosition position; positions)
            {
                demo.positions ~= DemoPosition(
                    position.symbol,
                    position.instrumentType.length > 0 ? position.instrumentType : "ASSET",
                    position.currency.length > 0 ? position.currency : balance.totalAssetCurrency,
                    position.quantity,
                    position.lastPrice,
                    position.marketValue,
                    position.unrealizedProfitLoss,
                    position.holdingProportion,
                );
            }

            data.accounts ~= demo;
        }

        data.accounts.sort!((a, b) => a.totalAsset > b.totalAsset);
        return data;
    }

    private DemoData loadData()
    {
        string requestedMode = environment.get("WEBULL_DEMO_MODE", "auto").toLower();
        if (requestedMode == "simulate" || requestedMode == "simulated")
            return simulatedData();

        if (requestedMode == "live" || hasCredentials())
        {
            try
            {
                DemoData data = liveData();
                if (data.accounts.length > 0)
                    return data;
            }
            catch (Exception)
            {
            }
        }

        return simulatedData();
    }

    private DemoView parseView()
    {
        string value = environment.get("WEBULL_DEMO_VIEW", cast(string)DemoView.all).toLower();
        foreach (view; __traits(allMembers, DemoView))
        {
            enum current = __traits(getMember, DemoView, view);
            if (value == cast(string)current)
                return current;
        }

        throw new Exception("Unsupported WEBULL_DEMO_VIEW: " ~ value);
    }

    private string maskedId(RenderConfig config, string value, size_t width = 24)
        => visibleSlice(maybeMask(config, value), width);

    private DemoAccount pickMarginAccount(DemoData data)
    {
        foreach (DemoAccount account; data.accounts)
        {
            if (account.accountType.toLower().indexOf("margin") >= 0 || account.tag == "margin")
                return account;
        }

        enforce(data.accounts.length > 0, "No accounts available.");
        return data.accounts[0];
    }

    private DemoAccount pickCashAccount(DemoData data)
    {
        DemoAccount margin = pickMarginAccount(data);

        foreach (DemoAccount account; data.accounts)
        {
            if (account.accountId == margin.accountId)
                continue;

            if (account.accountType.toLower().indexOf("cash") >= 0 || account.tag == "cash")
                return account;
        }

        foreach (DemoAccount account; data.accounts)
        {
            if (account.accountId != margin.accountId)
                return account;
        }

        return margin;
    }

    private PortfolioHolding[] combinedHoldings(DemoData data)
    {
        PortfolioHolding[] holdings = null;
        foreach (DemoAccount account; data.accounts)
        {
            foreach (DemoPosition position; account.positions)
            {
                holdings ~= PortfolioHolding(
                    position.symbol,
                    account.tag,
                    position.currency,
                    position.quantity,
                    position.lastPrice,
                    position.marketValue,
                    position.unrealizedProfitLoss,
                    position.holdingProportion,
                );
            }
        }

        holdings.sort!((a, b) => a.marketValue > b.marketValue);
        return holdings;
    }

    private string topSymbols(DemoData data)
    {
        PortfolioHolding[] holdings = combinedHoldings(data);
        size_t count = holdings.length > 4 ? 4 : holdings.length;
        return holdings[0 .. count].map!(holding => holding.symbol).array.join("  ");
    }

    private string[] renderOverview(DemoData data, RenderConfig config)
    {
        double totalAssets = 0;
        double totalCash = 0;
        double totalMarketValue = 0;
        size_t totalPositions = 0;
        foreach (DemoAccount account; data.accounts)
        {
            totalAssets += account.totalAsset;
            totalCash += account.totalCashBalance;
            totalMarketValue += account.totalMarketValue;
            totalPositions += account.positions.length;
        }

        return [
            "webull account console",
            formatStatusLine(data, config),
            "",
            "portfolio overview",
            "------------------",
            formatKeyValue("accounts", maybeMask(config, data.accounts.length.to!string)),
            formatKeyValue("positions", maybeMask(config, totalPositions.to!string)),
            formatKeyValue("total assets", formatMoney(config, totalAssets)),
            formatKeyValue("cash balance", formatMoney(config, totalCash)),
            formatKeyValue("market value", formatMoney(config, totalMarketValue)),
            formatKeyValue("top symbols", topSymbols(data)),
            "",
            "accounts",
            "--------",
            padRight(pickMarginAccount(data).tag, 8) ~ maybeMask(config, pickMarginAccount(data).accountNumber) ~ "  " ~ pickMarginAccount(data).accountStatus.toLower(),
            padRight(pickCashAccount(data).tag, 8) ~ maybeMask(config, pickCashAccount(data).accountNumber) ~ "  " ~ pickCashAccount(data).accountStatus.toLower(),
        ];
    }

    private string[] renderAccountView(DemoAccount account, RenderConfig config, size_t rows)
    {
        string[] lines = [
            account.tag ~ " account",
            repeat("-", account.tag.length + 8),
            formatKeyValue("number", maybeMask(config, account.accountNumber)),
            formatKeyValue("status", account.accountStatus.toLower()),
            formatKeyValue("account id", maskedId(config, account.accountId)),
            formatKeyValue("currency", account.totalAssetCurrency),
            formatKeyValue("total assets", formatMoney(config, account.totalAsset, account.totalAssetCurrency)),
            formatKeyValue("cash", formatMoney(config, account.totalCashBalance, account.totalAssetCurrency)),
            formatKeyValue("market value", formatMoney(config, account.totalMarketValue, account.totalAssetCurrency)),
            formatKeyValue("utilization", formatPercent(config, account.marginUtilizationRate)),
            "",
            "holdings",
            "--------",
            padRight("symbol", 8) ~ padLeft("qty", 8) ~ " " ~ padLeft("last", 9) ~ " " ~ padLeft("value", 11) ~ " " ~ padLeft("p/l", 11),
        ];

        size_t count = account.positions.length > rows ? rows : account.positions.length;
        foreach (DemoPosition position; account.positions[0 .. count])
        {
            lines ~= padRight(position.symbol, 8) ~
                padLeft(formatRawNumber(config, position.quantity), 8) ~ " " ~
                padLeft(formatMoney(config, position.lastPrice, position.currency), 9) ~ " " ~
                padLeft(formatMoney(config, position.marketValue, position.currency), 11) ~ " " ~
                padLeft(formatMoney(config, position.unrealizedProfitLoss, position.currency), 11);
        }

        return lines;
    }

    private string[] renderHoldings(DemoData data, RenderConfig config)
    {
        PortfolioHolding[] holdings = combinedHoldings(data);

        double totalMarketValue = 0;
        foreach (DemoAccount account; data.accounts)
            totalMarketValue += account.totalMarketValue;

        string[] lines = [
            "holdings snapshot",
            "-----------------",
            formatKeyValue("mode", data.modeLabel.toLower()),
            formatKeyValue("accounts", maybeMask(config, data.accounts.length.to!string)),
            formatKeyValue("positions", maybeMask(config, holdings.length.to!string)),
            formatKeyValue("market value", formatMoney(config, totalMarketValue)),
            "",
            "leaders",
            "-------",
            padRight("symbol", 7) ~ " " ~ padRight("acct", 7) ~ " " ~ padLeft("qty", 7) ~ " " ~ padLeft("value", 11) ~ " " ~ padLeft("p/l", 11) ~ " " ~ padLeft("wt", 7),
        ];

        size_t count = holdings.length > 6 ? 6 : holdings.length;
        foreach (PortfolioHolding holding; holdings[0 .. count])
        {
            lines ~= padRight(holding.symbol, 7) ~ " " ~
                padRight(holding.accountTag, 7) ~ " " ~
                padLeft(formatRawNumber(config, holding.quantity), 7) ~ " " ~
                padLeft(formatMoney(config, holding.marketValue, holding.currency), 11) ~ " " ~
                padLeft(formatMoney(config, holding.unrealizedProfitLoss, holding.currency), 11) ~ " " ~
                padLeft(formatPercent(config, holding.holdingProportion), 7);
        }

        return lines;
    }

    private void printLines(string[] lines)
    {
        foreach (string line; lines)
            writeln(line);
    }

    void main()
    {
        RenderConfig config = RenderConfig.init;
        string maskSetting = environment.get("WEBULL_MASK_NUMBERS", null);
        config.maskNumbers = !falsy(maskSetting);

        DemoData data = loadData();
        enforce(data.accounts.length > 0, "The account demo has no data to render.");

        DemoView view = parseView();
        final switch (view)
        {
        case DemoView.overview:
            printLines(renderOverview(data, config));
            break;

        case DemoView.margin:
            printLines(renderAccountView(pickMarginAccount(data), config, 3));
            break;

        case DemoView.cash:
            printLines(renderAccountView(pickCashAccount(data), config, 3));
            break;

        case DemoView.holdings:
            printLines(renderHoldings(data, config));
            break;

        case DemoView.all:
            printLines(renderOverview(data, config));
            writeln();
            printLines(renderAccountView(pickMarginAccount(data), config, 3));
            writeln();
            printLines(renderAccountView(pickCashAccount(data), config, 3));
            writeln();
            printLines(renderHoldings(data, config));
            break;
        }
    }
}
