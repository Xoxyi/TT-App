# TT Piciulin in the browser

The same Flutter code runs on Android, iOS and the web. The only difference on
the web is how FITeT pages are downloaded: `portale.fitet.org` sends no CORS
headers, so a browser may not read its pages directly. The web build sends its
requests to a small **FITeT proxy** instead, which forwards them to the portal.

| | Android / iOS | Web |
|---|---|---|
| FITeT requests | direct (`lib/data/fitet_http_io.dart`) | via proxy (`lib/data/fitet_http_web.dart`) |
| Saved data | JSON files in the app folder (`store_io.dart`) | browser localStorage (`store_web.dart`), per browser |

The proxy only forwards to `portale.fitet.org`, only the pages the app uses,
and only for allowed origins. Browsers cannot set `Referer`, `Cookie` or
`User-Agent`, so the app sends them as `X-Fitet-<name>` headers and the proxy
turns them back into the real ones (the athlete sheet needs the XHR headers).

## Run it on your PC

Two terminals, from the `app` folder:

```bash
dart run tool/fitet_proxy.dart
```

```bash
flutter run -d chrome
```

The local proxy listens on `http://localhost:8787` (the web build's default),
accepts only `localhost` pages, and sends one request at a time with a 500 ms
pause. Use `-d edge` if Chrome isn't installed.

## Put it online

1. **Proxy**: create a free Cloudflare Worker, paste `web_proxy/worker.js`,
   and add the variable `ALLOWED_ORIGINS` with the address of the site (step 2),
   e.g. `https://tt-piciulin.pages.dev`. The Worker caches pages for 10 minutes,
   so several people using the site don't multiply the traffic to FITeT.
2. **Site**: build with the Worker's address and upload `build/web` to any
   static host (Cloudflare Pages, GitHub Pages, Firebase Hosting):

   ```bash
   flutter build web --release --dart-define=FITET_PROXY=https://fitet-proxy.<your-account>.workers.dev
   ```

   For GitHub Pages under `/<repo>/`, also pass `--base-href /<repo>/`.

Notes:
- Data lives in each browser separately; clearing site data resets the app.
- A private/incognito window may block localStorage: the app still opens,
  without saving.
- On iPhone, Safari → Share → "Add to Home Screen" gives an app-like icon.
