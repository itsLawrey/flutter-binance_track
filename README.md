# Binance Profit Tracker

A cross-platform Flutter application that connects to your **Binance** account and calculates **unrealized profit & loss (P/L)** for every spot asset you hold — all in real time.

> **Live demo:** Deployed on Firebase Hosting with CI/CD via GitHub Actions.

---

## Features Overview

| Feature | Details |
|---|---|
| **Real-time P/L** | Fetches your full trade history and live prices from the Binance API to compute per-asset and total unrealized profit/loss. |
| **FIFO Cost-Basis Accounting** | Calculates average buy price by processing buys and sells chronologically, reducing cost basis proportionally on each sale. |
| **Multi-Currency Display** | Converts all values from USD to 12+ fiat currencies (EUR, GBP, JPY, CHF…) using live exchange rates from the **European Central Bank**. |
| **Configurable Quote Assets** | Users can add/remove trading pair quote assets (e.g. USDC, USDT, BUSD) to control which markets are scanned. |
| **Portfolio Summary** | Aggregated dashboard card showing total portfolio value, total P/L in your chosen currency, and overall percentage change. |
| **Secure API Key Storage** | API credentials are stored locally on-device via `SharedPreferences` — never transmitted to any third-party server. |
| **Binance-Themed Dark UI** | Custom dark theme built from Binance's brand palette (Shark Black `#1E2329`, Bright Sun Yellow `#FCD535`, Binance Green/Red). |
| **Cross-Platform** | Runs on Android, iOS, Web, Windows, macOS, and Linux from a single codebase. |
| **Firebase Web Deployment** | Production web builds are proxied through Firebase Cloud Functions to bypass browser CORS restrictions. |
| **CI/CD Pipeline** | GitHub Actions workflow automatically builds and deploys to Firebase Hosting on every push to `main`. |

---

## How It Works

1. Open the app and tap the **⚙️ Settings** gear icon.
2. Enter your **Binance API Key** and **Secret Key** (keys are stored locally only).
3. Choose your **display currency** (USD, EUR, GBP, etc.).
4. Optionally add/remove **quote assets** (USDC, USDT, etc.).
5. Tap **Scan Portfolio** to fetch your holdings.

## Behind the Scenes

### 1. Authenticated Binance API Access
Every request to the Binance API is **HMAC-SHA256 signed** on the client side using Dart's `crypto` package. The app creates a query string with a timestamp, generates a signature from your secret key, and attaches it to the request — exactly how Binance's REST API expects authenticated calls.

```dart
// Signature generation (simplified)
var hmacSha256 = Hmac(sha256, utf8.encode(apiSecret));
var signature  = hmacSha256.convert(utf8.encode(queryString));
```

### 2. Portfolio Calculation Engine
The core algorithm in `BinanceApiService.calculatePortfolio()`:

1. **Fetch account balances** — identifies all spot assets with a non-zero balance.
2. **For each asset, scan all configured quote pairs** (e.g. BTC → BTCUSDC, BTCUSDT).
3. **Parse trade history** — walks through up to 1,000 trades per pair, building a running cost basis:
   - **Buys** → add to total cost and quantity (minus any commission paid in the base asset).
   - **Sells** → reduce cost basis proportionally using the current average price (FIFO-style).
4. **Fetch live price** for each valid pair.
5. **Apportion the wallet balance** across pairs by trade-volume ratio, then compute P/L:
   - `Unrealized P/L = (Current Price − Avg Buy Price) × Quantity Held`
   - `P/L % = Unrealized P/L / Total Cost × 100`

### 3. Multi-Currency Conversion
The `CurrencyService` fetches daily exchange rates from the **European Central Bank's XML feed**, parses them, and caches the rates in memory. Conversions go through EUR as the pivot currency:

```
USD → EUR (÷ USD/EUR rate) → Target Currency (× Target/EUR rate)
```

### 4. CORS Proxy (Firebase Cloud Functions)
Browsers block direct calls to `api.binance.com` due to CORS. For production web builds, two **Firebase Cloud Functions** (Node.js) act as transparent proxies:

- **`binanceProxy`** — forwards requests to `api.binance.com`, preserving the `X-MBX-APIKEY` header.
- **`ecbProxy`** — fetches the ECB daily exchange rate XML.

The app automatically switches between direct API calls (mobile/desktop) and proxied calls (web release) using `kIsWeb && kReleaseMode`.

### 5. CI/CD
A **GitHub Actions** workflow triggers on every push to `main`:

1. Checks out the code
2. Sets up Flutter (stable channel)
3. Runs `flutter pub get` + `flutter build web --release`
4. Installs Cloud Functions dependencies (`npm ci`)
5. Deploys both Hosting and Functions to Firebase

---

## Tech Stack

| Layer | Technology |
|---|---|
| **Framework** | Flutter 3.9+ / Dart |
| **State Management** | `setState` (single-screen app) |
| **HTTP** | `http` package |
| **Cryptography** | `crypto` (HMAC-SHA256) |
| **XML Parsing** | `xml` (ECB exchange rate feed) |
| **Local Storage** | `shared_preferences` |
| **Backend Proxy** | Firebase Cloud Functions (Node.js) |
| **Hosting** | Firebase Hosting |
| **CI/CD** | GitHub Actions |

---

## Security

- **API keys never leave your device.** They are stored via `SharedPreferences` and used only to sign requests client-side.
- The Binance API key only requires **read** permissions — the app never places orders or withdraws funds.
- The Firebase proxy forwards requests without inspecting or storing credentials.
