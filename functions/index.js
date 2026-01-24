/**
 * Firebase Cloud Functions - CORS Proxy for Binance API and ECB
 *
 * These functions act as a proxy to bypass CORS restrictions when
 * the Flutter web app is hosted on Firebase.
 */

const {onRequest} = require("firebase-functions/v2/https");
const cors = require("cors")({origin: true});
const fetch = require("node-fetch");

/**
 * Proxy for Binance API
 * Forwards all requests to api.binance.com preserving headers and query params
 */
exports.binanceProxy = onRequest({maxInstances: 10}, (req, res) => {
  return cors(req, res, async () => {
    try {
      // Get the path after /binanceProxy/
      const binancePath = req.url.substring(1); // Remove leading /
      const binanceUrl = `https://api.binance.com/${binancePath}`;

      // Forward important headers (especially for signed requests)
      const headers = {};
      if (req.headers["x-mbx-apikey"]) {
        headers["X-MBX-APIKEY"] = req.headers["x-mbx-apikey"];
      }

      // Make the proxied request
      const response = await fetch(binanceUrl, {
        method: req.method,
        headers: headers,
      });

      const data = await response.text();
      res.status(response.status).send(data);
    } catch (error) {
      console.error("Binance Proxy Error:", error);
      res.status(500).json({error: error.message});
    }
  });
});

/**
 * Proxy for European Central Bank Exchange Rates
 * Fetches daily exchange rates XML
 */
exports.ecbProxy = onRequest({maxInstances: 5}, (req, res) => {
  return cors(req, res, async () => {
    try {
      const response = await fetch(
          "https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml",
      );

      const data = await response.text();
      res.status(200).set("Content-Type", "application/xml").send(data);
    } catch (error) {
      console.error("ECB Proxy Error:", error);
      res.status(500).json({error: error.message});
    }
  });
});
