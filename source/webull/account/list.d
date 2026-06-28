module webull.account.list;

import std.array : array;
import std.algorithm : map;
import std.json;
import webull.account.account;
import webull.account.internal;
import webull.account.types;

Account[] getAccounts(string subscriptionId = null)
{
    enforceAccountsPermission();

    JSONValue json;
    if (subscriptionId !is null && subscriptionId.length > 0)
    {
        json = requestJson(
            "/app/subscriptions/list",
            ["subscription_id": subscriptionId],
        );
    }
    else
        json = requestJsonWithFallback(listEndpoints());

    Account[] accounts;
    foreach (AccountSummary summary; parseAccountSummaries(json))
        accounts ~= Account.fromSummary(summary);

    return accounts;
}

string[] getAccountIds(string subscriptionId = null)
{
    return getAccounts(subscriptionId).map!(account => account.accountId).array;
}

package:

AccountSummary[] parseAccountSummaries(JSONValue json)
{
    JSONValue[] entries = arrayValue(
        json,
        [
            "result",
            "data",
            "accounts",
            "account_list",
        ],
    );

    AccountSummary[] summaries;
    foreach (JSONValue entry; entries)
    {
        AccountSummary summary;
        summary.subscriptionId = textValue(entry, "subscription_id", "subscriptionId");
        summary.userId = textValue(entry, "user_id", "userId");
        summary.accountId = textValue(entry, "account_id", "accountId");
        summary.accountNumber = textValue(entry, "account_number", "accountNumber");
        summary.accountType = textValue(entry, "account_type", "accountType");
        summary.accountStatus = textValue(entry, "account_status", "accountStatus");

        if (summary.accountId.length == 0)
            continue;

        summaries ~= summary;
    }

    return summaries;
}
