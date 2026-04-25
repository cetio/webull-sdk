module webull.account.profile;

import std.json;
import webull.account.account;
import webull.account.internal;
import webull.account.types;

void getAccountProfile(Account account)
{
    enforceAccountsPermission();

    JSONValue json = requestJson(
        "/account/profile",
        ["account_id": account.accountId],
    );

    account._profile = parseAccountProfile(account.accountId, json);
    account.accountNumber = account._profile.accountNumber;
    account.accountType = account._profile.accountType;
    account.accountStatus = account._profile.accountStatus;
}

package:

AccountProfile parseAccountProfile(string accountId, JSONValue json)
{
    AccountProfile profile;
    profile.accountId = accountId.length > 0 ? accountId : textValue(json, "account_id", "accountId");
    profile.accountNumber = textValue(json, "account_number", "accountNumber");
    profile.accountType = textValue(json, "account_type", "accountType");
    profile.accountStatus = textValue(json, "account_status", "accountStatus");
    return profile;
}
