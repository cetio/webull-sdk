module webull.account.positions;

import std.conv : to;
import std.json;
import webull.account.account;
import webull.account.internal;
import webull.account.types;

void getAccountPositions(Account account, int pageSize = 100)
{
    enforceAccountsPermission();

    if (pageSize <= 0)
        pageSize = 100;

    AccountPosition[] holdings;
    string lastInstrumentId;

    while (true)
    {
        AccountPositionPage page = getAccountPositionsPage(account, pageSize, lastInstrumentId);
        holdings~= page.holdings;

        if (!page.hasNext || page.holdings.length == 0)
            break;

        if (page.lastInstrumentId.length > 0)
            lastInstrumentId = page.lastInstrumentId;
        else
            lastInstrumentId = page.holdings[$ - 1].instrumentId;
    }

    account._positions = holdings;
}

AccountPositionPage getAccountPositionsPage(
    Account account,
    int pageSize = 100,
    string lastInstrumentId = null,
)
{
    enforceAccountsPermission();

    string[string] query = ["account_id": account.accountId];
    if (pageSize > 0)
        query["page_size"] = pageSize.to!string;
    if (lastInstrumentId !is null && lastInstrumentId.length > 0)
        query["last_instrument_id"] = lastInstrumentId;

    JSONValue json = requestJson("/openapi/assets/positions", query);
    return parseAccountPositionPage(json);
}

package:

AccountPositionPage parseAccountPositionPage(JSONValue json)
{
    AccountPositionPage page;
    page.hasNext = boolValue(json, "has_next", "hasNext");
    page.lastInstrumentId = textValue(json, "last_instrument_id", "lastInstrumentId");

    JSONValue[] holdings = arrayValue(
        json,
        [
            "holdings",
            "result",
            "data",
        ],
    );

    foreach (JSONValue entry; holdings)
    {
        AccountPosition position;
        position.instrumentId = textValue(entry, "instrument_id", "instrumentId");
        position.symbol = textValue(entry, "symbol");
        position.instrumentType = textValue(entry, "instrument_type", "instrumentType");
        position.currency = textValue(entry, "currency");
        position.unitCost = doubleValue(entry, "unit_cost", "unitCost");
        position.quantity = doubleValue(entry, "qty", "quantity");
        position.totalCost = doubleValue(entry, "total_cost", "totalCost");
        position.lastPrice = doubleValue(entry, "last_price", "lastPrice");
        position.marketValue = doubleValue(entry, "market_value", "marketValue");
        position.unrealizedProfitLoss = doubleValue(
            entry,
            "unrealized_profit_loss",
            "unrealizedProfitLoss",
        );
        position.unrealizedProfitLossRate = doubleValue(
            entry,
            "unrealized_profit_loss_rate",
            "unrealizedProfitLossRate",
        );
        position.holdingProportion = doubleValue(
            entry,
            "holding_proportion",
            "holdingProportion",
        );
        page.holdings ~= position;
    }

    if (page.lastInstrumentId.length == 0 && page.holdings.length > 0)
        page.lastInstrumentId = page.holdings[$ - 1].instrumentId;

    return page;
}
