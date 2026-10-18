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

## Put it online (GitHub Pages)

The workflow `.github/workflows/pages.yml` builds the site and publishes it at
**https://xoxyi.github.io/TT-App/** on every push to `main` (or by hand from
the Actions tab → "GitHub Pages" → Run workflow).

One-time setup:

1. **Proxy** (done: https://fitet-proxy.tt-piciulin.workers.dev; to update it,
   run `npx wrangler deploy` from `web_proxy/`): create a free Cloudflare
   account and a Worker, paste `web_proxy/worker.js`, and add the Worker variable
   `ALLOWED_ORIGINS` = `https://xoxyi.github.io`. Deploy and note its address,
   e.g. `https://fitet-proxy.<your-account>.workers.dev`. The Worker caches
   pages for 10 minutes, so several people using the site don't multiply the
   traffic to FITeT.
2. **Repository variable**: GitHub → Settings → Secrets and variables →
   Actions → Variables → New: `FITET_PROXY` = the Worker address.
   The workflow stops with an error if it is missing.
3. **Pages**: GitHub → Settings → Pages → Source: **GitHub Actions**.
   A private repository needs a paid plan (GitHub Pro) for Pages; on the free
   plan the repository has to be public. Either way the **site is public**:
   anyone with the link sees the players' names and results.

Other static hosts work too: build with
`flutter build web --release --dart-define=FITET_PROXY=<worker address>`
(plus `--base-href /<folder>/` when the site is not at the domain root) and
upload `build/web`.

Notes:
- Data lives in each browser separately; clearing site data resets the app.
- A private/incognito window may block localStorage: the app still opens,
  without saving.
- On iPhone, Safari → Share → "Add to Home Screen" gives an app-like icon.
