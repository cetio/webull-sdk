module webull.market.types;

public import webull.security : Security, Category;

enum Timespan : string
{
    M1 = "M1",
    M5 = "M5",
    M15 = "M15",
    M30 = "M30",
    M60 = "M60",
    M120 = "M120",
    M240 = "M240",
    D = "D",
    W = "W",
    M = "M",
    Y = "Y"
}

enum Session : string
{
    PRE = "PRE",
    RTH = "RTH",
    ATH = "ATH",
    OVN = "OVN"
}

enum Direction : string
{
    BUY = "B",
    SELL = "S",
    NEUTRAL = "N"
}

struct Bar
{
    Security security;
    long time;
    double open;
    double high;
    double low;
    double close;
    long volume;
    string tradingSession;
}

struct TickData
{
    Security security;
    long time;
    double price;
    long volume;
    Direction side;
}

struct Snapshot
{
    Security security;
    long lastTradeTime;
    double price;
    double open;
    double high;
    double low;
    double close;
    double preClose;
    long volume;
    double change;
    double changeRatio;
    double ask;
    long askSize;
    double bid;
    long bidSize;

    // Extended hours (pre/post market)
    double extendHourLastPrice;
    double extendHourHigh;
    double extendHourLow;
    double extendHourChange;
    double extendHourChangeRatio;
    long extendHourVolume;
    long extendHourLastTradeTime;

    // Overnight
    double ovnPrice;
    double ovnHigh;
    double ovnLow;
    long ovnVolume;
    double ovnChange;
    double ovnChangeRatio;
    long ovnLastTradeTime;
    double ovnAsk;
    long ovnAskSize;
    double ovnBid;
    long ovnBidSize;
}

struct BookLevel
{
    double price;
    long size;
    string[] mpids;
}

struct OrderBook
{
    Security security;
    long timestamp;
    BookLevel[] bids;
    BookLevel[] asks;
}

struct FootprintLevel
{
    double price;
    long volume;
}

struct FootprintBar
{
    Security security;
    long time;
    string tradingSession;
    long total;
    long delta;
    long buyTotal;
    long sellTotal;
    FootprintLevel[] buyDetail;
    FootprintLevel[] sellDetail;
}
