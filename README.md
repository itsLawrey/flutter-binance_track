# Binance Profit Tracker

> A cross-platform Flutter application that calculates and synchronizes unrealized profit and loss for your Binance spot assets in real time.

[![Live Demo](https://img.shields.io/badge/Live_Demo-Link-blue)](https://itslawrey-binance-tracker.web.app/) 

## Visuals


https://github.com/user-attachments/assets/312b8b23-88d0-4ca2-8352-6d3e9ed18e7d

<img width="75%" height="auto" alt="binance" src="https://github.com/user-attachments/assets/eef393c4-ab1a-463a-95a9-b3c51b762e1b" />


## Tech Stack

* **Frontend:** Flutter / Dart 3.9+
* **Backend/BaaS:** Firebase Cloud Functions & Hosting 
* **Local Storage:** SharedPreferences
* **State Management:** Stateful Widgets (`setState`)
* **Key Libraries:** `http`, `crypto`, `xml`

## Core Features

* **Real-time Synchronization:** Fetches live prices and wallet balances dynamically from the official Binance API.
* **Automated Profit Calculation:** Accurately determines average cost basis and real-time unrealized P/L using a FIFO model parsing trade history.
* **Multi-Currency Display:** Uses the European Central Bank (ECB) feed to seamlessly convert portfolio values from USD to over 12 diverse fiat currencies.
* **Configurable Quote Assets:** Allows users to add or remove custom quote assets (e.g., USDT, USDC) to control scanned markets.
* **Secure Storage:** API credentials are saved locally via `SharedPreferences`, ensuring they never reach third-party servers.
* **Cross-Platform:** Runs natively on Android, iOS, Windows, macOS, Linux, and web browsers.
* **Binance-Themed Aesthetics:** Features a dark-mode UI mirroring Binance's aesthetic for a familiar UX.

## Technical Architecture & Challenges

### State Management & Data Flow
The app uses `setState` but strictly separates UI logic in `PortfolioScreen` from heavy-lifting in `BinanceApiService` and `CurrencyService`. To avoid memory leaks, heavy portfolio computations update the UI judiciously instead of redrawing the asset list during API loops. Local preferences load instantly to populate the UI before network requests finish.

### API Integration & Rate Limiting
Securely integrating the Binance REST API client-side required generating HMAC-SHA256 signatures via Dart's `crypto` library to keep Secret Keys hidden. To prevent rate-limit bans when parsing extensive trade histories, requests are sequentially paced using `Future.delayed`. For web deployment, browser CORS restrictions are bypassed by proxying requests through Firebase Cloud Functions.

### Multi-Currency Conversion
Converting to fiat involved calling the daily European Central Bank (ECB) XML feed and caching the rates. A pivot formula converts USD to EUR (the base ECB currency) first, then to the target fiat currency, ensuring reliable localized portfolio views.

## Installation & Local Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/itsLawrey/flutter-binance_track.git
   cd flutter-binance_track
   ```

2. **Fetch dependencies and run:**
   ```bash
   flutter pub get
   flutter run
   ```
