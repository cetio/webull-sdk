# Webull

Webull is a D library for the Webull OpenAPI, providing authenticated access to market data including real-time quotes, OHLCV bars, tick data, and order book depth for equities, options, crypto, and futures.

## Features

### Authentication
- **HMAC-SHA1 Signing** - Automatic request signing with app key/secret
- **Token Lifecycle** - Create, poll, and cache authentication tokens with MFA support
- **Permission Detection** - Runtime probing of available API permissions

### Market Data
- **Bars** - OHLCV candlestick data with configurable timespans (M1 through yearly)
- **Snapshots** - Real-time price, volume, and change data with extended/overnight hours
- **Order Book** - Level-2 quotes with configurable depth
- **Ticks** - Individual trade records with volume and direction
- **Footprint** - Delta volume analysis with buy/sell level breakdowns

### Security Types
- US Stocks - `US_STOCK`
- US Options - `US_OPTION`
- Hong Kong Stocks - `HK_STOCK`
- China Stocks - `CN_STOCK`
- Cryptocurrency - `CRYPTO`
- Futures - `FUTURES`

## Quick Start

**Requirements:**
- D compiler (DMD/LDC)
- Webull OpenAPI credentials (key + secret)

**Setup:**
```d
import webull.client;
import webull.security;
import webull.market;

// Configure credentials
Client.key = "your_app_key";
Client.secret = "your_app_secret";

// Create and authenticate token
Client.createToken((status) {
    writeln("Waiting for MFA approval...");
});

// Access market data
auto aapl = new Security("AAPL", Category.US_STOCK);
auto snap = aapl.snapshot();
writeln("AAPL: $", snap.price, " (", snap.changeRatio, "%)");
```

## API Overview

### Client
- `createToken()` - Initiate authentication with optional polling callback
- `checkToken()` - Validate current token status
- `detectPermissions()` - Probe available API endpoints

### Security
- `autoUpdate` - Automatic refresh of cached market data
- `bars()` - Retrieve OHLCV history
- `snapshot()` - Current quote data
- `orderBook()` - Bid/ask levels
- `ticks()` - Recent trades

### Market Functions
- `getBars()` - Single or batch bar retrieval
- `getSnapshot()` - Single or batch snapshots
- `getOrderBook()` - Level-2 market depth
- `getTicks()` - Trade tick history
- `getFootprint()` - Volume delta analysis

## Architecture

- `webull.client` - Authentication state and token management
- `webull.security` - Security objects with auto-updating data accessors
- `webull.market` - Market data endpoints (bars, quotes, ticks, snapshots, footprint)
- `webull.orchestrate` - HMAC-SHA1 request signing and HTTP orchestration

## Roadmap

- [x] HMAC-SHA1 authentication
- [x] Token lifecycle management
- [x] Bars API (single + batch)
- [x] Snapshots API (single + batch)
- [x] Order book API
- [x] Tick data API
- [x] Footprint API
- [ ] WebSocket streaming
- [ ] Order placement API
- [ ] Account/position queries

## License

Webull is licensed under the [AGPL-3.0 license](LICENSE.txt).
