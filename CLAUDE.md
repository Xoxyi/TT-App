# TT Piciulin — project notes for Claude Code

Flutter app (Android, iOS and web) that follows a few table-tennis players
and imports their results from the FITeT portal (portale.fitet.org).
Owner: Andrea Zito ("Xoxyi"), FITeT athlete 792524, team TT.Torino B (Serie C/2 Gir.D).
The FITeT president (who works at the club) approved automated, low-volume access.

## Environment
- Windows PC, project at `C:\dev\Table tennis App\app`; Python tools in `..\tools`.
- Flutter 3.47.7 / Dart 3.13. Test phone: Motorola edge 50 fusion.
- Run: `flutter pub get`, `flutter test`, `flutter run --release`.
- Dependencies: `google_fonts`, `html`, `http` + `web` (web build only). **No `shared_preferences`**: it crashed in
  release builds (R8 / kotlin `Result` class). Storage is pure Dart: `lib/data/store.dart` picks `store_io.dart`
  (JSON files) or `store_web.dart` (localStorage) by conditional import.
- Android release: minify/shrink off, `proguard-rules.pro`; INTERNET permission;
  label "TT Piciulin". Release signing reads `android/key.properties`
  (template `android/key.properties.example`, keystore outside the repo);
  without it, release builds use the debug key.
- App ID: Android `com.andreazito.table_tennis_app` (locked: already uploaded
  to Play Console), iOS `com.andreazito.ttpiciulin` (not yet registered with Apple).

## Code map
- `lib/models/models.dart` — Player (toJson/fromJson, nickname), Competition
  (standings, fixtures, roster, fitetCam/fitetTeam/fitetYear/myTeam, copyWith),
  StandingRow, Fixture, Match (sets or scoreMine/scoreTheirs, giornata, source
  'fitet'), LeagueGame (set scores per championship game), PlayerStats.
- `lib/data/fitet.dart` — parsers for every FITeT page + `FitetClient`
  (`_send` with 20 s total timeout, cookie jar, latin1/UTF-8 decoding).
- `lib/data/fitet_http.dart` — transport: `fitet_http_io.dart` (dart:io, direct)
  or `fitet_http_web.dart` (through the FITeT proxy, `--dart-define=FITET_PROXY=`,
  default `http://localhost:8787`; headers sent as `X-Fitet-<name>`).
- `tool/fitet_proxy.dart` (local proxy) and `web_proxy/worker.js` (Cloudflare
  Worker, 10-min cache) — needed because the portal sends no CORS headers.
  See `WEB_GUIDE.md`.
- `lib/data/app_state.dart` — `AppState` (ChangeNotifier, exposed via `AppScope`),
  persistence keys `*_v1`, built-in players (Isabella 762651, Andrea 792524,
  Gabriele no id, Alin 762636), `syncFitet()`, `linkChampionship()`, add/remove players.
- `lib/data/built_in_results.dart` — Serie C2 Gir.D (CAM 204, SQUADRA 38782,
  ANNO 41) + round 1 matches.
- `lib/screens/` — home (Next match card, FITeT status line), players (+ add
  player via FITeT search), player, championship (standings / fixtures /
  players, "Link to FITeT"), tournament, events, stats, add match/player.
- `lib/widgets/common.dart` — shared widgets, Emblem logo, `FitetStatusLine`.
- Tests: `test/fitet_test.dart`, `fitet_league_test.dart`,
  `fitet_discovery_test.dart`, `widget_test.dart`; fake client in
  `test/fake_fitet.dart`; real saved pages in `test/fitet/` and `test/fitet_sample.html`.

## FITeT portal (details in the project doc "fitet-portal-map")
- Matches: `GET risultati/incontri_atleta_acc.php?ATLETA=` (scores, no sets).
- Athlete season sheet with championships: `GET scheda_unica_i.php?ATLETA=`
  **only works with XHR headers** (`X-Requested-With: XMLHttpRequest`,
  `Referer: https://portale.fitet.org/risultati/scheda_atleti.php`); plain GET
  returns a stub, POST returns empty. Isabella: CAM 19 = A/2 Gir.B, CAM 204 = C/2 Gir.D.
- `dettaglioatleta_unica.php` is only a ranking card (no championships).
- Championship: `classifica_squadre.php?CAM=` (standings), `Calendario.asp?ANNO=&CAM=`
  (fixtures, return legs numbered after first legs), `percentuali.php?CAM=&SQUADRA=`
  (roster with IDA), `dettaglio_percentuali.php?CAM=&SQUADRA=&IDA=` (set scores,
  points from Atleta1's side), `statistiche_atleti.php?CAM=` (athlete → team name),
  `testa_campionati.php?CAM=&CONC=0` (title + ANNO).
- Name search JSON `/ajax.php?term=` (confirmed 2026-10-18; `/risultati/ajax.php`
  is 404 and kept only as fallback).
- ANNO = season start year − 1985 (41 = 2026/27).

## Sync (`AppState.syncFitet`)
Startup + pull-to-refresh; one request at a time, 800 ms pause, 3-minute cap,
1-hour throttle (forced on refresh). Steps: 1) leagues with CAM: standings,
calendar, roster; 2) missing player ids: roster name match, then name search
(only if exactly one exact match; daily); 3) per player: set-score pages for
leagues whose roster has them, then matches page (`applyFitetSheet` dedupes
against manual/built-in matches, uses calendar dates); 4) per player daily:
athlete sheet → discover new championships (`_discoverLeague` attaches to the
imported competition with the same name, finds team id from standings) →
`_completeLeague`.

## Status / open items
- Compiles; `flutter test` and `flutter analyze` clean (2026-10-18).
- Verified in the web build and on the phone, release APK (2026-10-18):
  A/2 Gir.B (CAM 19, SQUADRA 12019) gets standings, fixtures, roster and set
  scores; Gabriele Piciulin found as 707200 (championships CAM 3 and CAM 47);
  data persists across restarts and the 1-hour throttle holds.
- To update the phone without losing data use `adb install -r` with the APK
  (`flutter install` uninstalls first and wipes the app's data).
- `_discoverLeague` + `_completeLeague` fetch the same standings page twice.
- Distribution: Play internal testing guide `PLAY_INTERNAL_TESTING.md`;
  iOS Ad Hoc via Codemagic + Firebase: `codemagic.yaml`, `IOS_ADHOC_GUIDE.md`
  (untested). Web: live at https://xoxyi.github.io/TT-App/ (GitHub Pages,
  `.github/workflows/pages.yml`, deploys on push to `main`). FITeT proxy:
  Cloudflare Worker https://fitet-proxy.tt-piciulin.workers.dev (deploy with
  `npx wrangler deploy` from `web_proxy/`), set as repo variable `FITET_PROXY`.
- Code: public GitHub repo `Xoxyi/TT-App`.

## Rules
- Keep FITeT traffic low (sequential requests, pauses, throttles).
- Never store birth dates from the FITeT search (show only to disambiguate).
  Some tracked players are young: keep personal data minimal.
- Don't commit `key.properties`, keystores, API keys or service-account JSON.
- UI: dark theme, WTT-like palette (black, orange-red #FF5A1F, white), English UI text.
