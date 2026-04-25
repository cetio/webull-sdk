module webull.account.account;

import webull.account.types;

class Account
{
    static Account[string] registry;

    static Account getOrCreate(string accountId)
    {
        if (accountId.length == 0)
            throw new Exception("Account ID must not be empty.");

        if (auto existing = accountId in registry)
            return *existing;

        Account account = new Account(accountId);
        registry[accountId] = account;
        return account;
    }

    static Account fromSummary(AccountSummary summary)
    {
        Account account = getOrCreate(summary.accountId);
        account.apply(summary);
        return account;
    }

package:
    this(string accountId)
    {
        this.accountId = accountId;
    }

    AccountProfile _profile;
    AccountBalance _balance;
    string _balanceCurrency = "USD";
    AccountPosition[] _positions;

public:
    string subscriptionId;
    string userId;
    string accountId;
    string accountNumber;
    string accountType;
    string accountStatus;
    bool autoUpdate = true;
    int defaultPageSize = 100;
    string defaultCurrency = "USD";

    void apply(AccountSummary summary)
    {
        if (summary.subscriptionId.length > 0)
            subscriptionId = summary.subscriptionId;
        if (summary.userId.length > 0)
            userId = summary.userId;
        if (summary.accountId.length > 0)
            accountId = summary.accountId;
        if (summary.accountNumber.length > 0)
            accountNumber = summary.accountNumber;
        if (summary.accountType.length > 0)
            accountType = summary.accountType;
        if (summary.accountStatus.length > 0)
            accountStatus = summary.accountStatus;
    }

    ref AccountProfile profile()
    {
        import webull.account.profile : getAccountProfile;

        if (autoUpdate || _profile.accountId.length == 0)
            getAccountProfile(this);

        return _profile;
    }

    ref AccountBalance balance(string currency = "USD")
    {
        import webull.account.balance : getAccountBalance;

        if (currency.length == 0)
            currency = defaultCurrency;

        if (
            autoUpdate ||
            _balance.accountId.length == 0 ||
            _balanceCurrency != currency
        )
            getAccountBalance(this, currency);

        return _balance;
    }

    AccountPosition[] positions(int pageSize = 100)
    {
        import webull.account.positions : getAccountPositions;

        if (pageSize <= 0)
            pageSize = defaultPageSize;

        if (autoUpdate || _positions.length == 0)
            getAccountPositions(this, pageSize);

        return _positions;
    }
}
