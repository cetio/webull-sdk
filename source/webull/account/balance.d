module webull.account.balance;

import std.json;
import webull.account.account;
import webull.account.internal;
import webull.account.types;

void getAccountBalance(Account account, string totalAssetCurrency = "USD")
{
    enforceAccountsPermission();

    string[string] query = ["account_id": account.accountId];
    if (totalAssetCurrency !is null && totalAssetCurrency.length > 0)
        query["total_asset_currency"] = totalAssetCurrency;

    JSONValue json = requestJson("/openapi/assets/balance", query);
    account._balance = parseAccountBalance(json);
    account._balanceCurrency = account._balance.totalAssetCurrency;
}

package:

AccountBalance parseAccountBalance(JSONValue json)
{
    AccountBalance balance;
    balance.accountId = textValue(json, "account_id", "accountId");
    balance.totalAssetCurrency = textValue(json, "total_asset_currency", "totalAssetCurrency");
    balance.totalAsset = doubleValue(json, "total_asset", "totalAsset");
    balance.totalMarketValue = doubleValue(json, "total_market_value", "totalMarketValue");
    balance.totalCashBalance = doubleValue(json, "total_cash_balance", "totalCashBalance");
    balance.marginUtilizationRate = doubleValue(
        json,
        "margin_utilization_rate",
        "marginUtilizationRate",
    );

    JSONValue[] currencyAssets = arrayValue(
        json,
        [
            "account_currency_assets",
            "accountCurrencyAssets",
        ],
    );

    foreach (JSONValue entry; currencyAssets)
    {
        AccountCurrencyAsset asset;
        asset.currency = textValue(entry, "currency");
        asset.netLiquidationValue = doubleValue(
            entry,
            "net_liquidation_value",
            "netLiquidationValue",
        );
        asset.positionsMarketValue = doubleValue(
            entry,
            "positions_market_value",
            "positionsMarketValue",
        );
        asset.cashBalance = doubleValue(entry, "cash_balance", "cashBalance");
        asset.marginPower = doubleValue(entry, "margin_power", "marginPower");
        asset.cashPower = doubleValue(entry, "cash_power", "cashPower");
        asset.pendingIncoming = doubleValue(entry, "pending_incoming", "pendingIncoming");
        asset.cashFrozen = doubleValue(entry, "cash_frozen", "cashFrozen");
        asset.availableWithdrawal = doubleValue(
            entry,
            "available_withdrawal",
            "availableWithdrawal",
        );
        asset.interestsUnpaid = doubleValue(entry, "interests_unpaid", "interestsUnpaid");
        balance.accountCurrencyAssets ~= asset;
    }

    return balance;
}
