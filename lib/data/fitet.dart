import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../models/models.dart';
import 'fitet_http.dart';

/// One match row from a FITeT "Scheda incontri" page, seen from the athlete's side.
class FitetMatchRow {
  const FitetMatchRow({
    required this.section,
    required this.competition,
    required this.opponent,
    required this.setsWon,
    required this.setsLost,
    required this.validForRanking,
    this.date,
    this.location,
    this.event,
    this.roundCode,
    this.giornata,
  });

  /// 'tournament', 'team' or 'playoff'.
  final String section;

  /// Tournament name, or championship name such as "C/2 Gir.D".
  final String competition;
  final DateTime? date;
  final String? location;
  final String? event;

  /// Raw FITeT round code: GQ, OF, QF, SF, F, 4T...
  final String? roundCode;
  final int? giornata;
  final String opponent;
  final int setsWon;
  final int setsLost;
  final bool validForRanking;

  bool get won => setsWon > setsLost;
}

class FitetSheet {
  const FitetSheet({required this.athlete, required this.matches, this.season, this.warnings = const <String>[]});

  final String athlete;
  final String? season;
  final List<FitetMatchRow> matches;
  final List<String> warnings;
}

String _clean(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

int _score(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) throw FormatException('not a score: "$text"');
  return int.parse(digits);
}

String? _iconName(Element td) {
  final src = td.querySelector('img')?.attributes['src'];
  if (src == null) return null;
  return src.split('/').last.toLowerCase();
}

/// Parses the HTML of incontri_atleta_acc.php (FITeT athlete matches page).
FitetSheet parseFitetMatches(String html) {
  final doc = html_parser.parse(html);

  String? athlete;
  String? season;
  for (final p in doc.querySelectorAll('p')) {
    final t = _clean(p.text);
    final b = p.querySelector('b');
    if (t.contains('Scheda incontri') && b != null) athlete = _clean(b.text);
    final m = RegExp(r'Stagione agonistica\s+(\d{4}/\d{2})').firstMatch(t);
    if (m != null) season = m.group(1);
  }
  if (athlete == null) {
    throw const FormatException('Athlete name not found: not a FITeT "Scheda incontri" page');
  }
  final me = athlete.toUpperCase();

  final rows = <FitetMatchRow>[];
  final warnings = <String>[];

  for (final panel in doc.querySelectorAll('div.panel')) {
    final heading = panel.querySelector('.panel-heading');
    final title = heading == null ? '' : _clean(heading.text).toLowerCase();
    final String? section = title.contains('tornei individuali')
        ? 'tournament'
        : title.contains('campionati a squadre')
            ? 'team'
            : title.contains('play off')
                ? 'playoff'
                : null;
    if (section == null) continue;

    String? tName;
    DateTime? tDate;
    String? tPlace;

    for (final row in panel.querySelectorAll('tr')) {
      final tds = row.children.where((e) => e.localName == 'td').toList();
      if (tds.isEmpty) continue;

      // Tournament header: one wide cell, "Name del dd/mm/yyyy a Place".
      if (tds.length == 1 && tds.first.attributes.containsKey('colspan')) {
        final text = _clean(tds.first.text);
        final m = RegExp(r'^(.*?)\s+del\s+(\d{2})/(\d{2})/(\d{4})\s+a\s+(.*)$').firstMatch(text);
        if (m != null) {
          tName = m.group(1)!.trim();
          tDate = DateTime(int.parse(m.group(4)!), int.parse(m.group(3)!), int.parse(m.group(2)!));
          tPlace = m.group(5)!.trim();
        } else {
          tName = text;
          tDate = null;
          tPlace = null;
        }
        continue;
      }
      if (tds.length < 7) continue;

      final texts = tds.map((td) => _clean(td.text)).toList();
      final p1 = texts[2].toUpperCase();
      final p2 = texts[3].toUpperCase();
      int s1;
      int s2;
      try {
        s1 = _score(texts[4]);
        s2 = _score(texts[5]);
      } on FormatException catch (e) {
        warnings.add('Skipped a row: ${e.message}');
        continue;
      }

      final bool mineFirst;
      if (p1 == me) {
        mineFirst = true;
      } else if (p2 == me) {
        mineFirst = false;
      } else {
        warnings.add('$athlete not found in: $p1 vs $p2');
        continue;
      }
      final mine = mineFirst ? s1 : s2;
      final theirs = mineFirst ? s2 : s1;
      final opponent = mineFirst ? texts[3] : texts[2];

      // Cross-check with the page's result icon (color3 = win, color4 = loss).
      final icon = _iconName(tds[6]);
      final expected = icon == 'color3.gif' ? true : icon == 'color4.jpg' ? false : null;
      if (expected != null && expected != (mine > theirs)) {
        warnings.add('Result icon disagrees with the score: $p1 $s1-$s2 $p2');
      }

      final valid = _iconName(tds[0]) != 'cancel.gif';

      if (section == 'tournament') {
        final em = RegExp(r'^(.*?)-\(([^)]+)\)\s*$').firstMatch(texts[1]);
        rows.add(FitetMatchRow(
          section: section,
          competition: tName ?? 'Torneo',
          date: tDate,
          location: tPlace,
          event: em?.group(1)?.trim() ?? texts[1],
          roundCode: em?.group(2)?.trim(),
          opponent: opponent,
          setsWon: mine,
          setsLost: theirs,
          validForRanking: valid,
        ));
      } else {
        final lm = RegExp(r'^(.*?)\s*\((\d+)\^\s*gior\.?\)\s*$').firstMatch(texts[1]);
        rows.add(FitetMatchRow(
          section: section,
          competition: lm?.group(1)?.trim() ?? texts[1],
          giornata: lm == null ? null : int.parse(lm.group(2)!),
          opponent: opponent,
          setsWon: mine,
          setsLost: theirs,
          validForRanking: valid,
        ));
      }
    }
  }

  return FitetSheet(athlete: athlete, season: season, matches: rows, warnings: warnings);
}

/// "MASPES ANDREA" and "Andrea Maspes" give the same key.
String fitetNameKey(String s) {
  final words = s.toLowerCase().replaceAll(RegExp(r'[^a-zà-ÿ ]'), ' ').split(' ')
    ..removeWhere((w) => w.isEmpty)
    ..sort();
  return words.join(' ');
}

List<Element> _cells(Element row) => row.children.where((e) => e.localName == 'td').toList();

// -----------------------------------------------------------------------------
// Athlete search (ajax.php?term=...)
// -----------------------------------------------------------------------------

/// An athlete found with the FITeT name search.
class FitetAthleteHit {
  const FitetAthleteHit({required this.id, required this.name, this.birthDate});

  final String id;

  /// "SURNAME NAME" as FITeT writes it.
  final String name;

  /// dd/mm/yyyy: shown only to tell namesakes apart, never stored.
  final String? birthDate;
}

/// Parses the JSON answer of the athlete search:
/// [{"id":"792524","label":"<span>ZITO</span> ... (31/03/2001)","value":"ZITO ANDREA"}]
List<FitetAthleteHit> parseFitetSearch(String body) {
  final text = body.trim();
  if (text.isEmpty || text == 'null') return const <FitetAthleteHit>[];
  final dynamic data = jsonDecode(text);
  if (data is! List) throw const FormatException('Unexpected answer from the FITeT search');
  final hits = <FitetAthleteHit>[];
  for (final dynamic item in data) {
    if (item is! Map) continue;
    final id = '${item['id'] ?? ''}'.trim();
    if (!RegExp(r'^\d+$').hasMatch(id)) continue;
    final label = _clean('${item['label'] ?? ''}'
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&#39;', "'")
        .replaceAll('&amp;', '&'));
    final birth = RegExp(r'\((\d{2}/\d{2}/\d{4})\)').firstMatch(label)?.group(1);
    final value = _clean('${item['value'] ?? ''}');
    final name = value.isNotEmpty ? value : _clean(label.replaceAll(RegExp(r'\(.*?\)'), ''));
    if (name.isEmpty) continue;
    hits.add(FitetAthleteHit(id: id, name: name, birthDate: birth));
  }
  return hits;
}

/// Splits "DE LUCA MARCO" into last name "De Luca" and first name "Marco".
({String firstName, String lastName}) splitFitetName(String fitetName) {
  const particles = <String>{
    'DA', 'DAL', 'DALLA', 'DALLE', 'DE', 'DEL', 'DELLA', 'DELLE', 'DEI', 'DEGLI',
    'DI', 'D', 'LA', 'LE', 'LO', 'LI', 'VAN', 'VON', 'SAN', 'SANTA', 'MC',
  };
  final words = _clean(fitetName).split(' ').where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return (firstName: '', lastName: '');
  if (words.length == 1) return (firstName: '', lastName: _title(words.first));
  var cut = 1;
  while (cut < words.length - 1 && particles.contains(words[cut - 1].toUpperCase().replaceAll("'", ''))) {
    cut++;
  }
  return (
    firstName: _title(words.sublist(cut).join(' ')),
    lastName: _title(words.sublist(0, cut).join(' ')),
  );
}

String _title(String s) => s
    .toLowerCase()
    .split(' ')
    .where((w) => w.isNotEmpty)
    .map((w) => w.split("'").map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1)).join("'"))
    .join(' ');

// -----------------------------------------------------------------------------
// Championship pages (risultati/campionati/...)
// -----------------------------------------------------------------------------

/// Parses classifica_squadre.php?CAM=...: one row per team, best first.
List<StandingRow> parseFitetStandings(String html) {
  final doc = html_parser.parse(html);
  final rows = <StandingRow>[];
  for (final tr in doc.querySelectorAll('tr')) {
    final tds = _cells(tr);
    if (tds.length < 7) continue;
    final link = RegExp(r'SQUADRA=(\d+)').firstMatch(tds[0].outerHtml + tds[1].outerHtml);
    final team = _clean(tds[1].text);
    if (link == null || team.isEmpty) continue;
    int n(int i) => int.tryParse(_clean(tds[i].text)) ?? 0;
    rows.add(StandingRow(
      team: team,
      teamId: link.group(1),
      points: n(2),
      played: n(3),
      wins: n(4),
      draws: n(5),
      losses: n(6),
    ));
  }
  return rows;
}

DateTime? _dateTime(String date, String time) {
  final d = RegExp(r'(\d{1,2})/(\d{1,2})/(\d{4})').firstMatch(date);
  if (d == null) return null;
  final t = RegExp(r'(\d{1,2})[.:](\d{2})').firstMatch(time);
  return DateTime(
    int.parse(d.group(3)!),
    int.parse(d.group(2)!),
    int.parse(d.group(1)!),
    t == null ? 0 : int.parse(t.group(1)!),
    t == null ? 0 : int.parse(t.group(2)!),
  );
}

(int, int)? _teamScore(String text) {
  final m = RegExp(r'^(\d+)\s*-\s*(\d+)$').firstMatch(text.trim());
  return m == null ? null : (int.parse(m.group(1)!), int.parse(m.group(2)!));
}

String? _incontro(Element td) => RegExp(r'INCONTRO=(\d+)').firstMatch(td.outerHtml)?.group(1);

/// Parses Calendario.asp?ANNO=...&CAM=...: every match of every team.
/// Each row holds a first-leg match and its return leg (teams swapped);
/// return-leg rounds are numbered after the first-leg ones.
List<Fixture> parseFitetCalendar(String html) {
  final doc = html_parser.parse(html);
  final first = <Fixture>[];
  final back = <Fixture>[];
  int? giornata;
  var rounds = 0;
  for (final tr in doc.querySelectorAll('tr')) {
    final tds = _cells(tr);
    if (tds.length == 1) {
      final m = RegExp(r'(\d+)\s*\^\s*Giornata', caseSensitive: false).firstMatch(_clean(tds.first.text));
      if (m != null) {
        giornata = int.parse(m.group(1)!);
        if (giornata > rounds) rounds = giornata;
      }
      continue;
    }
    // 8 cells: first leg + return leg; 5 cells: single-leg competitions
    // such as the Supercoppa (date, time, score, home, away).
    if (giornata == null || tds.length < 5) continue;
    final t = tds.map((td) => _clean(td.text)).toList();
    if (t[3].isEmpty || t[4].isEmpty) continue;
    final s1 = _teamScore(t[2]);
    first.add(Fixture(
      giornata: giornata,
      date: _dateTime(t[0], t[1]),
      home: t[3],
      away: t[4],
      homeScore: s1?.$1,
      awayScore: s1?.$2,
      matchId: _incontro(tds[2]),
    ));
    if (tds.length < 8) continue;
    final s2 = _teamScore(t[5]);
    back.add(Fixture(
      giornata: giornata,
      date: _dateTime(t[7], t[6]),
      home: t[4],
      away: t[3],
      homeScore: s2?.$1,
      awayScore: s2?.$2,
      matchId: _incontro(tds[5]),
    ));
  }
  return <Fixture>[...first, ...back.map((f) => f.withGiornata(f.giornata + rounds))];
}

/// Parses percentuali.php?CAM=...&SQUADRA=...: athletes of a team who played.
/// Returns FITeT id -> name (doubles pairs are left out).
Map<String, String> parseFitetRoster(String html) {
  final doc = html_parser.parse(html);
  final out = <String, String>{};
  for (final a in doc.querySelectorAll('a')) {
    final m = RegExp(r'dettaglio_percentuali\.php\?.*IDA=(\d+)').firstMatch(a.attributes['href'] ?? '');
    if (m == null) continue;
    final name = _clean(a.text);
    if (name.isEmpty || name.contains(' - ')) continue;
    out[m.group(1)!] = name;
  }
  return out;
}

/// One championship game with set scores, seen from the athlete's side.
class FitetLeagueGame {
  const FitetLeagueGame({required this.giornata, required this.opponent, required this.sets});

  final int giornata;
  final String opponent;
  final List<SetScore> sets;

  int get setsWon => sets.where((s) => s.won).length;
  int get setsLost => sets.length - setsWon;
}

class FitetPlayerGames {
  const FitetPlayerGames({required this.athlete, required this.games, this.team});

  final String athlete;
  final String? team;
  final List<FitetLeagueGame> games;
}

/// Parses dettaglio_percentuali.php?CAM=...&SQUADRA=...&IDA=...: the athlete's
/// championship games with points of every set (A1 B1 ... A5 B5, from
/// Atleta1's side; 0-0 means the set wasn't played).
FitetPlayerGames parseFitetPlayerGames(String html) {
  final doc = html_parser.parse(html);
  String? athlete;
  String? team;
  final games = <FitetLeagueGame>[];
  for (final tr in doc.querySelectorAll('tr')) {
    final tds = _cells(tr);
    if (tds.length == 1) {
      final text = _clean(tds.first.text);
      athlete ??= RegExp(r'Atleta:\s*(.+)$').firstMatch(text)?.group(1)?.trim();
      team ??= RegExp(r'Squadra:\s*(.+?)\s*(?:-\s*)*Atleta:').firstMatch(text)?.group(1)?.trim();
      continue;
    }
    if (tds.length < 13) continue;
    final t = tds.map((td) => _clean(td.text)).toList();
    final g = int.tryParse(t[0]);
    if (g == null || athlete == null) continue;
    if (t[1].contains(' - ') || t[2].contains(' - ')) continue; // doubles
    final me = fitetNameKey(athlete);
    final bool mineFirst;
    if (fitetNameKey(t[1]) == me) {
      mineFirst = true;
    } else if (fitetNameKey(t[2]) == me) {
      mineFirst = false;
    } else if (tds[1].querySelector('b') != null) {
      mineFirst = true;
    } else if (tds[2].querySelector('b') != null) {
      mineFirst = false;
    } else {
      continue;
    }
    final sets = <SetScore>[];
    for (var k = 0; k < 5; k++) {
      final a = int.tryParse(t[3 + 2 * k]) ?? 0;
      final b = int.tryParse(t[4 + 2 * k]) ?? 0;
      if (a == 0 && b == 0) continue;
      sets.add(mineFirst ? SetScore(a, b) : SetScore(b, a));
    }
    if (sets.isEmpty) continue;
    games.add(FitetLeagueGame(giornata: g, opponent: mineFirst ? t[2] : t[1], sets: sets));
  }
  if (athlete == null) {
    throw const FormatException('Athlete name not found: not a FITeT player detail page');
  }
  return FitetPlayerGames(athlete: athlete, team: team, games: games);
}

/// A FITeT team championship to link (from an address with CAM=).
class FitetChampionshipLink {
  const FitetChampionshipLink({required this.cam, this.team, this.year, this.name, this.teamName});

  /// Championship id (CAM=).
  final String cam;

  /// Team id (SQUADRA=), when the link has it.
  final String? team;

  /// Season code (ANNO=), when the link has it.
  final String? year;

  /// Championship name as the matches page writes it, e.g. "C/2 Gir.D".
  final String? name;

  /// The athlete's team in it, e.g. "TT.Torino B".
  final String? teamName;
}

/// Parses the athlete sheet (scheda_unica_i.php, "Campionati squadre" table):
/// the team championships of the current season, with the athlete's team.
List<FitetChampionshipLink> parseFitetAthleteChampionships(String html) {
  final doc = html_parser.parse(html);
  final out = <String, FitetChampionshipLink>{};
  for (final tr in doc.querySelectorAll('tr')) {
    final tds = _cells(tr);
    if (tds.length < 2) continue;
    final a = tds.first.querySelector('a');
    final href = a?.attributes['href'] ?? '';
    if (!href.contains('campionati')) continue;
    final cam = RegExp(r'[?&]CAM=(\d+)', caseSensitive: false).firstMatch(href)?.group(1);
    if (cam == null) continue;
    final name = _clean(a!.text);
    final team = _clean(tds[1].text);
    out[cam] = FitetChampionshipLink(
      cam: cam,
      name: name.isEmpty ? null : name,
      teamName: team.isEmpty ? null : team,
      year: RegExp(r'[?&]ANNO=(\d+)', caseSensitive: false).firstMatch(href)?.group(1),
    );
  }
  return out.values.toList();
}

/// Name and season of a championship, from testa_campionati.php?CAM=...
class FitetChampionshipHeader {
  const FitetChampionshipHeader({this.title, this.shortName, this.year});

  /// e.g. "CAMPIONATO MASCHILE - SERIE C/2 Gir.D".
  final String? title;

  /// e.g. "C/2 Gir.D", as the athlete matches page writes it.
  final String? shortName;
  final String? year;
}

FitetChampionshipHeader parseFitetChampionshipHeader(String html) {
  final doc = html_parser.parse(html);
  String? title;
  for (final e in doc.querySelectorAll('strong, b, p, td, title')) {
    final t = _clean(e.text);
    if (t.isNotEmpty && t.length < 120 && RegExp(r'CAMPIONATO|SERIE', caseSensitive: false).hasMatch(t)) {
      title = t;
      break;
    }
  }
  String? short;
  if (title != null) {
    short = RegExp(r'SERIE\s+(.+)$', caseSensitive: false).firstMatch(title)?.group(1)?.trim();
    if (short == null) {
      final parts = title.split(' - ');
      short = parts.last.trim();
    }
  }
  final year = RegExp(r'Calendario\.asp\?[^"\x27>]*ANNO=(\d+)', caseSensitive: false).firstMatch(html)?.group(1) ??
      RegExp(r'[?&]ANNO=(\d+)').firstMatch(html)?.group(1);
  return FitetChampionshipHeader(title: title, shortName: short, year: year);
}

/// Parses statistiche_atleti.php?CAM=...: athlete name -> team name.
Map<String, String> parseFitetAthleteStats(String html) {
  final doc = html_parser.parse(html);
  final out = <String, String>{};
  for (final tr in doc.querySelectorAll('tr')) {
    final tds = _cells(tr);
    if (tds.length < 5) continue;
    final name = _clean(tds[1].text);
    final team = _clean(tds[2].text);
    if (name.isEmpty || team.isEmpty || int.tryParse(_clean(tds[3].text)) == null) continue;
    out[name] = team;
  }
  return out;
}

/// "C/2 Gir.D", "SERIE C/2 Gir. D" -> "c/2gird".
String championshipKey(String s) =>
    s.toLowerCase().replaceFirst(RegExp(r'^\s*serie\s+'), '').replaceAll(RegExp(r'[^a-z0-9/]'), '');

// -----------------------------------------------------------------------------
// Downloads
// -----------------------------------------------------------------------------

/// The portal answered with an error status.
class FitetHttpException implements Exception {
  const FitetHttpException(this.message, this.uri);

  final String message;
  final Uri uri;

  @override
  String toString() => '$message (${uri.path})';
}

/// Downloads pages from the FITeT portal, one at a time (replaceable in tests).
class FitetClient {
  static const String host = 'portale.fitet.org';

  /// Path of the athlete search, found on first use.
  String? _searchPath;

  /// Cookies the portal sets (e.g. the PHP session), sent back like a browser.
  final Map<String, String> _cookies = <String, String>{};

  /// Sends the requests (direct on Android/iOS, through a proxy on the web).
  final FitetHttp _http = FitetHttp();

  /// Longest time one request may take, from connecting to the last byte.
  static const Duration requestTimeout = Duration(seconds: 20);

  Future<String> get(String path, Map<String, String> query, {Map<String, String> headers = const <String, String>{}}) =>
      _send('GET', Uri.https(host, path, query), headers: headers);

  /// Form POST (application/x-www-form-urlencoded, with Content-Length).
  Future<String> post(String path, Map<String, String> form) =>
      _send('POST', Uri.https(host, path), form: form);

  Future<String> _send(String method, Uri uri,
      {Map<String, String> headers = const <String, String>{}, Map<String, String>? form}) async {
    final watch = Stopwatch()..start();
    final all = <String, String>{...headers};
    if (_cookies.isNotEmpty) {
      all['Cookie'] = _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
    }
    List<int>? body;
    if (form != null) {
      body = utf8.encode(Uri(queryParameters: form).query);
      all['Content-Type'] = 'application/x-www-form-urlencoded; charset=utf-8';
    }
    try {
      final response = await _http.send(method, uri, headers: all, body: body, timeout: requestTimeout);
      for (final c in response.setCookies) {
        final pair = c.split(';').first;
        final eq = pair.indexOf('=');
        if (eq > 0) _cookies[pair.substring(0, eq).trim()] = pair.substring(eq + 1).trim();
      }
      if (response.statusCode != 200) {
        throw FitetHttpException('FITeT answered ${response.statusCode}', uri);
      }
      return decodeFitet(response.bytes);
    } finally {
      debugPrint('FITeT $method ${uri.path} ${watch.elapsedMilliseconds} ms');
    }
  }

  /// Pages are windows-1252, some are UTF-8 (with or without BOM).
  static String decodeFitet(List<int> bytes) {
    if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
      return utf8.decode(bytes.sublist(3), allowMalformed: true);
    }
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return latin1.decode(bytes, allowInvalid: true);
    }
  }

  Future<String> fetchMatchesPage(String athleteId) =>
      get('/risultati/incontri_atleta_acc.php', <String, String>{'ATLETA': athleteId});

  Future<String> fetchStandingsPage(String cam) =>
      get('/risultati/campionati/classifica_squadre.php', <String, String>{'CAM': cam});

  Future<String> fetchCalendarPage(String cam, String year) =>
      get('/risultati/campionati/Calendario.asp', <String, String>{'ANNO': year, 'CAM': cam});

  Future<String> fetchRosterPage(String cam, String team) =>
      get('/risultati/campionati/percentuali.php', <String, String>{'CAM': cam, 'SQUADRA': team});

  Future<String> fetchPlayerGamesPage(String cam, String team, String athleteId) => get(
      '/risultati/campionati/dettaglio_percentuali.php',
      <String, String>{'CAM': cam, 'IDA': athleteId, 'SQUADRA': team});

  /// Athlete sheet with this season's team championships and tournaments.
  /// The portal loads it in the background from its search page; without
  /// those browser headers it answers an almost empty page (checked: a plain
  /// GET and a POST come back empty, GET with these headers is complete).
  Future<String> fetchAthleteSheet(String athleteId) async {
    final html = await get(
      '/scheda_unica_i.php',
      <String, String>{'ATLETA': athleteId},
      headers: const <String, String>{
        'X-Requested-With': 'XMLHttpRequest',
        'Referer': 'https://$host/risultati/scheda_atleti.php',
        'Accept': 'text/html, */*; q=0.01',
      },
    );
    if (!html.contains('agonistica') && !html.contains('Campionati squadre')) {
      debugPrint('FITeT athlete sheet for $athleteId came back empty');
    }
    return html;
  }

  Future<String> fetchChampionshipHeader(String cam) =>
      get('/risultati/campionati/testa_campionati.php', <String, String>{'CAM': cam, 'CONC': '0'});

  Future<String> fetchAthleteStatsPage(String cam) =>
      get('/risultati/campionati/statistiche_atleti.php', <String, String>{'CAM': cam});

  /// Name search, as used by the athlete search page (answers JSON).
  Future<String> searchAthletes(String term) async {
    final paths = _searchPath != null
        ? <String>[_searchPath!]
        : const <String>['/ajax.php', '/risultati/ajax.php'];
    Object error = const FormatException('FITeT search not available');
    for (final path in paths) {
      try {
        final body = await get(path, <String, String>{'term': term},
            headers: const <String, String>{'X-Requested-With': 'XMLHttpRequest'});
        final t = body.trimLeft();
        if (t.startsWith('[') || t == 'null' || t.isEmpty) {
          _searchPath = path;
          return body;
        }
        error = const FormatException('FITeT search answered with a web page');
      } catch (e) {
        error = e;
      }
    }
    throw error;
  }
}
