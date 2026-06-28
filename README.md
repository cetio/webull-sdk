# Webull

[![License](https://img.shields.io/badge/License-AGPL--3-blue)](LICENSE.txt)
[![DUB Package](https://img.shields.io/badge/dub-package-red)](https://code.dlang.org/packages/webull-sdk)

Webull is a D library for the Webull OpenAPI, providing authenticated access to market data plus typed account access for account lists, balances, profiles, and positions.

## Features

### Authentication
- **HMAC-SHA1 Signing** - Automatic request signing with app key/secret
- **Token Lifecycle** - Create, poll, and cache authentication tokens with MFA support
- **Permission Detection** - Runtime probing of available API permissions
- **Configurable Endpoint** - Switch between production, UAT, or local dummy endpoints via `Client.endpoint`

### Market Data
- **Bars** - OHLCV candlestick data with configurable timespans (M1 through yearly)
- **Snapshots** - Real-time price, volume, and change data with extended/overnight hours
- **Order Book** - Level-2 quotes with configurable depth
- **Ticks** - Individual trade records with volume and direction
- **Footprint** - Delta volume analysis with buy/sell level breakdowns

### Accounts
- **Account List** - Discover all accounts available to the app key
- **Account Profile** - Fetch static account metadata like account number, type, and status
- **Account Balance** - Retrieve total assets, buying power, and per-currency balances
- **Account Positions** - Auto-paginate holdings into typed position records

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
import webull.account;

// Configure credentials
Client.key = "your_app_key";
Client.secret = "your_app_secret";
Client.endpoint = "https://api.webull.com";

// Access accounts
auto accounts = getAccounts();
foreach (account; accounts)
{
    getAccountProfile(account);
    getAccountBalance(account, "USD");
    getAccountPositions(account, 100);
    writeln(account.accountId, " => ", account.balance("USD").totalAsset);
}
```

## API Overview

### Client
- `createToken()` - Initiate authentication with optional polling callback
- `checkToken()` - Validate current token status
- `detectPermissions()` - Probe available API endpoints
- `accounts()` - Convenience helper that returns account IDs
- `endpoint` - Override the API base URL, e.g. `https://api.webull.com`

### Security
- `autoUpdate` - Automatic refresh of cached market data
- `bars()` - Retrieve OHLCV history
- `snapshot()` - Current quote data
- `orderBook()` - Bid/ask levels
- `ticks()` - Recent trades

### Account
- `getAccounts()` - Retrieve typed account objects
- `getAccountProfile()` - Populate static account metadata
- `getAccountBalance()` - Populate balance and per-currency asset details
- `getAccountPositions()` - Retrieve all holdings with pagination handled internally
- `Account.profile()` / `Account.balance()` / `Account.positions()` - Lazy convenience accessors

### Market Functions
- `getBars()` - Single or batch bar retrieval
- `getSnapshot()` - Single or batch snapshots
- `getOrderBook()` - Level-2 market depth
- `getTicks()` - Trade tick history
- `getFootprint()` - Volume delta analysis

## Architecture

- `webull.client` - Authentication state and token management
- `webull.account` - Typed account, balance, profile, and position access
- `webull.security` - Security objects with auto-updating data accessors
- `webull.market` - Market data endpoints (bars, quotes, ticks, snapshots, footprint)
- `webull.orchestrate` - HMAC-SHA1 request signing and HTTP orchestration

## Examples And Tests

- Run the account console demo: `dub run -c account-console-demo`
- Force the demo into simulated screenshot mode: `WEBULL_DEMO_MODE=simulate dub run -c account-console-demo`
- Render a specific screenshot-ready view: `WEBULL_DEMO_MODE=simulate WEBULL_DEMO_VIEW=overview dub run -c account-console-demo`
- Available views: `overview`, `margin`, `cash`, `holdings`
- Unmask digits in the demo output: `WEBULL_MASK_NUMBERS=0 dub run -c account-console-demo`
- Run dummy tests against the local validation server: `dub test -c dummy-tests`
- Run live tests if you have credentials available: `dub test -c live-tests`
- Run both suites together: `dub test -c full-tests`

## Roadmap

- [x] HMAC-SHA1 authentication
- [x] Token lifecycle management
- [x] Bars API (single + batch)
- [x] Snapshots API (single + batch)
- [x] Order book API
- [x] Tick data API
- [x] Footprint API
- [x] Account list API
- [x] Account balance API
- [x] Account profile API
- [x] Account positions API
- [ ] WebSocket streaming
- [ ] Order placement API

## License

Webull-SDK is licensed under [AGPL-3.0](LICENSE.txt).
