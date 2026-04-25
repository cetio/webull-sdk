module webull.account.types;

struct AccountSummary
{
    string subscriptionId;
    string userId;
    string accountId;
    string accountNumber;
    string accountType;
    string accountStatus;
}

struct AccountProfile
{
    string accountId;
    string accountNumber;
    string accountType;
    string accountStatus;
}

struct AccountCurrencyAsset
{
    string currency;
    double netLiquidationValue;
    double positionsMarketValue;
    double cashBalance;
    double marginPower;
    double cashPower;
    double pendingIncoming;
    double cashFrozen;
    double availableWithdrawal;
    double interestsUnpaid;
}

struct AccountBalance
{
    string accountId;
    string totalAssetCurrency;
    double totalAsset;
    double totalMarketValue;
    double totalCashBalance;
    double marginUtilizationRate;
    AccountCurrencyAsset[] accountCurrencyAssets;
}

struct AccountPosition
{
    string instrumentId;
    string symbol;
    string instrumentType;
    string currency;
    double unitCost;
    double quantity;
    double totalCost;
    double lastPrice;
    double marketValue;
    double unrealizedProfitLoss;
    double unrealizedProfitLossRate;
    double holdingProportion;
}

struct AccountPositionPage
{
    bool hasNext;
    string lastInstrumentId;
    AccountPosition[] holdings;
}
