import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../models/models.dart';
import '../utils/format.dart';
import 'built_in_results.dart';
import 'fitet.dart';
import 'store.dart';

/// The players you follow (all right-handed attackers).
const List<Player> kPlayers = <Player>[
  Player(id: 'jar_isabella', firstName: 'Isabella Maria', lastName: 'Jar', style: 'Attacker', fitetId: '762651'),
  Player(id: 'zito_andrea', firstName: 'Andrea', lastName: 'Zito', nickname: 'Xoxyi', style: 'Attacker', fitetId: '792524'),
  Player(id: 'piciulin_gabriele', firstName: 'Gabriele', lastName: 'Piciulin', style: 'Attacker'),
  Player(id: 'jar_alin', firstName: 'Alin Catalin', lastName: 'Jar', nickname: 'Ma Long', style: 'Attacker', fitetId: '762636'),
];

/// Competition used for matches that aren't part of an event.
final Competition kFriendly = Competition(
  id: 'friendly',
  name: 'Other match',
  shortName: 'Other',
  type: CompetitionType.friendly,
  location: '',
  date: DateTime(2000),
);

/// Holds players, competitions and matches, computes statistics, and saves
/// everything on the device whenever something changes.
class AppState extends ChangeNotifier {
  AppState._(this._store, this.persistent);

  /// False when the phone's storage couldn't be opened: nothing is saved.
  final bool persistent;

  static const String _matchesKey = 'matches_v1';
  static const String _competitionsKey = 'competitions_v1';
  static const String _deletedKey = 'deleted_v1';
  static const String _fitetIdsKey = 'fitet_ids_v1';
  static const String _fitetSyncKey = 'fitet_sync_v1';
  static const String _fitetLookupKey = 'fitet_lookup_v1';
  static const String _leagueGamesKey = 'league_games_v1';
  static const String _playersKey = 'players_v1';
  static const String _fitetSheetsKey = 'fitet_sheets_v1';

  /// Automatic FITeT updates happen at most this often per player.
  static const Duration fitetMinInterval = Duration(hours: 1);

  /// Players without a FITeT id are searched by name at most this often.
  static const Duration fitetLookupInterval = Duration(days: 1);

  final Store _store;
  final List<Player> players = List<Player>.of(kPlayers);
  final List<Competition> competitions = <Competition>[kFriendly];
  final List<Match> _matches = <Match>[]; // newest first

  /// Ids of built-in matches the user deleted, so they don't come back.
  final Set<String> _deleted = <String>{};

  /// FITeT athlete ids set in the app (override the built-in ones).
  final Map<String, String> _fitetIds = <String, String>{};

  /// Last successful FITeT update per player.
  final Map<String, DateTime> _fitetSync = <String, DateTime>{};

  /// Last automatic search of a FITeT id per player.
  final Map<String, DateTime> _fitetLookup = <String, DateTime>{};

  /// Last check of each player's FITeT athlete sheet for championships.
  final Map<String, DateTime> _fitetSheets = <String, DateTime>{};

  /// Set scores of championship games (FITeT player detail pages).
  final List<LeagueGame> _leagueGames = <LeagueGame>[];

  /// Downloads FITeT pages (replaceable in tests).
  FitetClient fitetClient = FitetClient();

  /// Pause between two FITeT requests, to stay gentle with the portal.
  Duration fitetPause = const Duration(milliseconds: 800);

  /// True while a FITeT update is running.
  bool fitetSyncing = false;

  /// Message of the last FITeT update error, if any.
  String? fitetError;

  /// What the running FITeT update is doing, e.g. "Andrea’s matches".
  String? fitetStatus;

  /// A FITeT update stops starting new requests after this long.
  static const Duration fitetMaxDuration = Duration(minutes: 3);

  void _step(String status) {
    fitetStatus = status;
    notifyListeners();
  }

  /// Loads saved data (or starts empty the first time).
  static Future<AppState> load(Store store, {bool persistent = true}) async {
    final state = AppState._(store, persistent);
    try {
      final added = await store.read(_playersKey);
      if (added != null) {
        for (final j in jsonDecode(added) as List<dynamic>) {
          final p = Player.fromJson(j as Map<String, dynamic>);
          if (!state.players.any((x) => x.id == p.id)) state.players.add(p);
        }
      }
      final comps = await store.read(_competitionsKey);
      if (comps != null) {
        for (final j in jsonDecode(comps) as List<dynamic>) {
          final c = Competition.fromJson(j as Map<String, dynamic>);
          if (c.id != kFriendly.id) state.competitions.add(c);
        }
      }
      final matches = await store.read(_matchesKey);
      if (matches != null) {
        for (final j in jsonDecode(matches) as List<dynamic>) {
          final m = Match.fromJson(j as Map<String, dynamic>);
          // Skip matches of players who are no longer in the list.
          if (state.players.any((p) => p.id == m.playerId)) state._matches.add(m);
        }
        state._sort();
      }
      final deleted = await store.read(_deletedKey);
      if (deleted != null) {
        state._deleted.addAll((jsonDecode(deleted) as List<dynamic>).cast<String>());
      }
      final ids = await store.read(_fitetIdsKey);
      if (ids != null) {
        (jsonDecode(ids) as Map<String, dynamic>)
            .forEach((k, v) => state._fitetIds[k] = v as String);
      }
      final sync = await store.read(_fitetSyncKey);
      if (sync != null) {
        (jsonDecode(sync) as Map<String, dynamic>)
            .forEach((k, v) => state._fitetSync[k] = DateTime.parse(v as String));
      }
      final lookup = await store.read(_fitetLookupKey);
      if (lookup != null) {
        (jsonDecode(lookup) as Map<String, dynamic>)
            .forEach((k, v) => state._fitetLookup[k] = DateTime.parse(v as String));
      }
      final sheets = await store.read(_fitetSheetsKey);
      if (sheets != null) {
        (jsonDecode(sheets) as Map<String, dynamic>)
            .forEach((k, v) => state._fitetSheets[k] = DateTime.parse(v as String));
      }
      final games = await store.read(_leagueGamesKey);
      if (games != null) {
        for (final j in jsonDecode(games) as List<dynamic>) {
          state._leagueGames.add(LeagueGame.fromJson(j as Map<String, dynamic>));
        }
      }
    } catch (e) {
      debugPrint('Could not read saved data: $e');
    }
    if (state._addBuiltIn()) await state._save();
    return state;
  }

  /// Adds built-in results that aren't in the app yet. Returns true if any.
  bool _addBuiltIn() {
    var changed = false;
    for (final c in builtInCompetitions) {
      final i = competitions.indexWhere((x) => x.id == c.id);
      if (i < 0) {
        competitions.add(c);
        changed = true;
      } else {
        // Keep built-in competitions up to date, but keep what FITeT sent.
        final stored = competitions[i];
        final merged = c.copyWith(
          standings: stored.standings,
          fixtures: stored.fixtures,
          roster: stored.roster,
          roundsPlayed: stored.roundsPlayed,
          roundsTotal: stored.roundsTotal,
          myTeam: stored.myTeam,
          fitetUpdated: stored.fitetUpdated,
        );
        if (jsonEncode(merged.toJson()) != jsonEncode(stored.toJson())) {
          competitions[i] = merged;
          changed = true;
        }
      }
    }
    for (final m in builtInMatches) {
      if (_deleted.contains(m.id) || _matches.any((x) => x.id == m.id)) continue;
      if (!players.any((p) => p.id == m.playerId)) continue;
      _matches.add(m);
      changed = true;
    }
    if (changed) _sort();
    return changed;
  }

  Future<void> _save() async {
    try {
      await _store.write(
        _competitionsKey,
        jsonEncode(competitions
            .where((c) => c.id != kFriendly.id)
            .map((c) => c.toJson())
            .toList()),
      );
      await _store.write(
          _matchesKey, jsonEncode(_matches.map((m) => m.toJson()).toList()));
      await _store.write(_deletedKey, jsonEncode(_deleted.toList()));
      await _store.write(_fitetIdsKey, jsonEncode(_fitetIds));
      await _store.write(_fitetSyncKey,
          jsonEncode(_fitetSync.map((k, v) => MapEntry(k, v.toIso8601String()))));
      await _store.write(_fitetLookupKey,
          jsonEncode(_fitetLookup.map((k, v) => MapEntry(k, v.toIso8601String()))));
      await _store.write(_fitetSheetsKey,
          jsonEncode(_fitetSheets.map((k, v) => MapEntry(k, v.toIso8601String()))));
      await _store.write(
          _leagueGamesKey, jsonEncode(_leagueGames.map((g) => g.toJson()).toList()));
      await _store.write(
          _playersKey,
          jsonEncode(players
              .where((p) => !kPlayers.any((k) => k.id == p.id))
              .map((p) => p.toJson())
              .toList()));
    } catch (e) {
      debugPrint('Could not save data: $e');
    }
  }

  List<Match> get matches => List<Match>.unmodifiable(_matches);

  /// The player with this id (a placeholder if they were just removed).
  Player player(String id) => players.firstWhere(
        (p) => p.id == id,
        orElse: () => Player(id: id, firstName: 'Removed', lastName: 'player'),
      );

  Competition competition(String id) => competitions.firstWhere(
        (c) => c.id == id,
        orElse: () => kFriendly,
      );

  List<Match> matchesFor(String playerId, {DateTime? since}) => _matches
      .where((m) =>
          m.playerId == playerId && (since == null || !m.date.isBefore(since)))
      .toList();

  List<Match> matchesIn(String competitionId, {String? playerId}) => _matches
      .where((m) =>
          m.competitionId == competitionId &&
          (playerId == null || m.playerId == playerId))
      .toList();

  /// Singles statistics (doubles are listed but not counted).
  PlayerStats stats(String playerId, {DateTime? since}) => PlayerStats.from(
      matchesFor(playerId, since: since).where((m) => !m.isDoubles).toList());

  PlayerStats statsIn(String competitionId, String playerId) => PlayerStats.from(
      matchesIn(competitionId, playerId: playerId).where((m) => !m.isDoubles).toList());

  /// Wins and losses per month for the last [months] months.
  List<MonthBar> monthly(String playerId, {int months = 6}) {
    final now = DateTime.now();
    final bars = <MonthBar>[];
    for (var i = months - 1; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final ms = _matches.where((m) =>
          m.playerId == playerId &&
          !m.isDoubles &&
          m.date.year == month.year &&
          m.date.month == month.month);
      final wins = ms.where((m) => m.won).length;
      bars.add(MonthBar(monthShort(month.month), wins, ms.length - wins));
    }
    return bars;
  }

  /// Players (of the ones you follow) who played in a competition.
  List<Player> playersIn(String competitionId) {
    final ids = _matches
        .where((m) => m.competitionId == competitionId)
        .map((m) => m.playerId)
        .toSet();
    return players.where((p) => ids.contains(p.id)).toList();
  }

  /// Championships and tournaments a player took part in, newest first.
  List<Competition> competitionsFor(String playerId) {
    final ids = _matches
        .where((m) => m.playerId == playerId)
        .map((m) => m.competitionId)
        .toSet();
    final list = competitions
        .where((c) => ids.contains(c.id) && c.type != CompetitionType.friendly)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// How far a player got in a tournament, e.g. "Semifinal" or "Winner".
  String? placement(String playerId, String competitionId) {
    final ms = matchesIn(competitionId, playerId: playerId)
        .where((m) => m.round != null && kRounds.contains(m.round))
        .toList();
    if (ms.isEmpty) return null;
    ms.sort((a, b) =>
        kRounds.indexOf(a.round!).compareTo(kRounds.indexOf(b.round!)));
    final last = ms.last;
    if (last.won && last.round == 'F') return 'Winner';
    if (last.won && !competition(competitionId).date.isBefore(_today())) return 'Still in';
    return kRoundNames[last.round!];
  }

  /// Sort key for placements: higher is better.
  int placementRank(String playerId, String competitionId) {
    final p = placement(playerId, competitionId);
    if (p == null) return -1;
    if (p == 'Winner') return 100;
    if (p == 'Still in') return 50;
    final round = kRoundNames.entries
        .firstWhere((e) => e.value == p, orElse: () => const MapEntry('', ''))
        .key;
    return kRounds.indexOf(round);
  }

  /// The next upcoming tournament, if any.
  Competition? get nextEvent {
    final now = DateTime.now();
    final upcoming = competitions
        .where((c) => c.isTournament && c.date.isAfter(now))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  /// The next championship match of your players' team, if published.
  ({Competition competition, Fixture fixture})? get nextTeamMatch {
    final today = _today();
    ({Competition competition, Fixture fixture})? best;
    for (final c in competitions) {
      if (!c.isLeague || c.myTeam == null) continue;
      for (final f in c.fixtures) {
        final d = f.date;
        if (f.played || d == null || d.isBefore(today)) continue;
        if (!c.isMine(f.home) && !c.isMine(f.away)) continue;
        if (best == null || d.isBefore(best.fixture.date!)) {
          best = (competition: c, fixture: f);
        }
      }
    }
    return best;
  }

  // ---------------------------------------------------------------------------
  // Players
  // ---------------------------------------------------------------------------

  /// True for players added in the app (they can be removed).
  bool isAddedPlayer(String playerId) => !kPlayers.any((p) => p.id == playerId);

  /// Adds a player to follow and, with a FITeT id, starts importing their
  /// matches (await [syncFitet] with onlyPlayerId to wait for it).
  Player addPlayer({
    required String firstName,
    required String lastName,
    String? nickname,
    String? fitetId,
  }) {
    final nick = nickname?.trim();
    final fid = fitetId?.trim();
    final existing = fid == null || fid.isEmpty
        ? null
        : players.where((p) => fitetIdOf(p.id) == fid).firstOrNull;
    if (existing != null) return existing;
    final p = Player(
      id: fid == null || fid.isEmpty ? _newId('p') : 'fitet_$fid',
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      nickname: nick == null || nick.isEmpty ? null : nick,
      fitetId: fid == null || fid.isEmpty ? null : fid,
    );
    players.add(p);
    notifyListeners();
    _save();
    if (p.fitetId != null) unawaited(syncFitet(force: true, onlyPlayerId: p.id));
    return p;
  }

  /// Stops following a player added in the app, removing their matches.
  void removePlayer(String playerId) {
    if (!isAddedPlayer(playerId)) return;
    players.removeWhere((p) => p.id == playerId);
    _matches.removeWhere((m) => m.playerId == playerId);
    _leagueGames.removeWhere((g) => g.playerId == playerId);
    _fitetIds.remove(playerId);
    _fitetSync.remove(playerId);
    _fitetLookup.remove(playerId);
    _fitetSheets.remove(playerId);
    notifyListeners();
    _save();
  }

  /// Searches athletes on FITeT by name (for adding a player).
  Future<List<FitetAthleteHit>> searchFitet(String term) async =>
      parseFitetSearch(await fitetClient.searchAthletes(term.trim()));

  String _newId(String prefix) =>
      '$prefix${DateTime.now().microsecondsSinceEpoch}';

  void addMatch({
    required String playerId,
    required String opponent,
    required String competitionId,
    required DateTime date,
    required List<SetScore> sets,
    String? round,
  }) {
    _matches.add(Match(
      id: _newId('m'),
      playerId: playerId,
      opponent: opponent,
      competitionId: competitionId,
      date: date,
      sets: List<SetScore>.unmodifiable(sets),
      round: round,
    ));
    _sort();
    notifyListeners();
    _save();
  }

  void deleteMatch(String matchId) {
    _matches.removeWhere((m) => m.id == matchId);
    _deleted.add(matchId);
    notifyListeners();
    _save();
  }

  /// Creates a championship or tournament and returns it.
  Competition addCompetition({
    required String name,
    required CompetitionType type,
    required DateTime date,
    String location = '',
  }) {
    final c = Competition(
      id: _newId('c'),
      name: name,
      shortName: name,
      type: type,
      location: location,
      date: date,
      subtitle: type == CompetitionType.league ? 'Championship' : null,
    );
    competitions.add(c);
    notifyListeners();
    _save();
    return c;
  }

  void _sort() => _matches.sort((a, b) => b.date.compareTo(a.date));

  DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  // ---------------------------------------------------------------------------
  // FITeT import
  // ---------------------------------------------------------------------------

  /// The player's FITeT athlete id (set in the app, or built in).
  String? fitetIdOf(String playerId) => _fitetIds[playerId] ?? player(playerId).fitetId;

  /// Sets (or clears, with an empty string) a player's FITeT id, then updates.
  Future<void> setFitetId(String playerId, String id) async {
    final clean = id.trim();
    if (clean.isEmpty) {
      _fitetIds.remove(playerId);
      _matches.removeWhere((m) => m.playerId == playerId && m.isFitet);
      _leagueGames.removeWhere((g) => g.playerId == playerId);
    } else {
      _fitetIds[playerId] = clean;
    }
    _fitetSync.remove(playerId);
    notifyListeners();
    await _save();
    if (clean.isNotEmpty) await syncFitet(force: true, onlyPlayerId: playerId);
  }

  /// Most recent successful FITeT update across players.
  DateTime? get lastFitetSync => _fitetSync.values.isEmpty
      ? null
      : _fitetSync.values.reduce((a, b) => a.isAfter(b) ? a : b);

  /// Number of players with a FITeT id.
  int get fitetLinkedCount => players.where((p) => fitetIdOf(p.id) != null).length;

  /// True if no FITeT id was found automatically for the player.
  bool fitetLookupFailed(String playerId) =>
      fitetIdOf(playerId) == null && _fitetLookup.containsKey(playerId);

  /// Updates everything from FITeT. Runs at startup and on pull-to-refresh:
  ///  1. standings, fixtures and team roster of each championship with ids;
  ///  2. FITeT ids of players without one (team roster, then name search);
  ///  3. each linked player's matches, with set scores of championship games.
  /// Skips what was updated less than [fitetMinInterval] ago unless [force].
  /// One request at a time, with [fitetPause] between them.
  Future<void> syncFitet({bool force = false, String? onlyPlayerId}) async {
    if (fitetSyncing) {
      // A player added or linked during an update gets their own update after it.
      if (onlyPlayerId != null) _queuedSync.add(onlyPlayerId);
      return;
    }
    final now = DateTime.now();
    bool due(DateTime? last, Duration every) =>
        force || last == null || now.difference(last) >= every;
    bool playerDue(Player p) =>
        (onlyPlayerId == null || p.id == onlyPlayerId) &&
        fitetIdOf(p.id) != null &&
        due(_fitetSync[p.id], fitetMinInterval);

    final leagues = onlyPlayerId != null
        ? <Competition>[]
        : competitions
            .where((c) => c.isLeague && c.fitetCam != null && due(c.fitetUpdated, fitetMinInterval))
            .toList();
    final lookups = onlyPlayerId != null
        ? <Player>[]
        : players
            .where((p) => fitetIdOf(p.id) == null && due(_fitetLookup[p.id], fitetLookupInterval))
            .toList();
    bool sheetDue(Player p) =>
        (onlyPlayerId == null || p.id == onlyPlayerId) &&
        fitetIdOf(p.id) != null &&
        due(_fitetSheets[p.id], fitetLookupInterval);
    if (leagues.isEmpty && lookups.isEmpty && !players.any(playerDue) && !players.any(sheetDue)) return;

    fitetSyncing = true;
    fitetError = null;
    fitetStatus = null;
    notifyListeners();
    final errors = <String>[];
    var requests = 0;
    final started = DateTime.now();
    Future<String> fetch(Future<String> Function() request) async {
      if (DateTime.now().difference(started) > fitetMaxDuration) {
        throw TimeoutException('FITeT update took too long');
      }
      if (requests++ > 0 && fitetPause > Duration.zero) await Future<void>.delayed(fitetPause);
      return request();
    }

    try {
    // 1. Championships.
    for (final c in leagues) {
      _step('Standings · ${c.shortName}');
      try {
        await _syncLeague(c, fetch);
      } catch (e) {
        debugPrint('FITeT update failed for ${c.name}: $e');
        errors.add(c.shortName);
      }
    }

    // 2. Missing FITeT ids.
    for (final p in lookups) {
      _step('Looking for ${p.shortName} on FITeT');
      _fitetLookup[p.id] = DateTime.now();
      try {
        final id = _idFromRosters(p) ?? await _idFromSearch(p, fetch);
        if (id != null) _fitetIds[p.id] = id;
      } catch (e) {
        debugPrint('FITeT search failed for ${p.name}: $e');
      }
    }

    // 3. Players' matches.
    for (final p in players.where(playerDue).toList()) {
      final id = fitetIdOf(p.id)!;
      _step('${p.shortName}’s matches');
      try {
        for (final c in competitions.toList()) {
          if (!c.isLeague || c.fitetCam == null || c.fitetTeam == null) continue;
          if (!c.roster.containsKey(id)) continue;
          final html = await fetch(() => fitetClient.fetchPlayerGamesPage(c.fitetCam!, c.fitetTeam!, id));
          _applyLeagueGames(p, c, parseFitetPlayerGames(html));
        }
        final html = await fetch(() => fitetClient.fetchMatchesPage(id));
        final sheet = parseFitetMatches(html);
        if (!_sameAthlete(p, sheet.athlete)) {
          throw FormatException('FITeT id $id belongs to ${sheet.athlete}');
        }
        applyFitetSheet(p.id, sheet);
        _fitetSync[p.id] = DateTime.now();
      } catch (e) {
        debugPrint('FITeT update failed for ${p.name}: $e');
        errors.add(p.shortName);
      }
    }

    // 4. Each player's championships (e.g. A/2), from their FITeT athlete sheet.
    for (final p in players.where(sheetDue).toList()) {
      _step('${p.shortName}’s championships');
      _fitetSheets[p.id] = DateTime.now();
      try {
        final html = await fetch(() => fitetClient.fetchAthleteSheet(fitetIdOf(p.id)!));
        for (final link in parseFitetAthleteChampionships(html)) {
          if (competitions.any((c) => c.fitetCam == link.cam)) continue;
          final c = await _discoverLeague(link, fetch, player: p);
          if (c != null) await _completeLeague(c, fetch);
        }
      } catch (e) {
        debugPrint('FITeT athlete sheet failed for ${p.name}: $e');
      }
    }

    } finally {
      fitetSyncing = false;
      fitetStatus = null;
      if (errors.isNotEmpty) fitetError = 'Couldn’t update ${errors.join(', ')}';
      _sort();
      notifyListeners();
    }
    await _save();

    final queued = _queuedSync.toList();
    _queuedSync.clear();
    for (final id in queued) {
      if (players.any((p) => p.id == id)) await syncFitet(force: true, onlyPlayerId: id);
    }
  }

  final Set<String> _queuedSync = <String>{};

  /// Downloads standings, fixtures and roster of a championship.
  Future<void> _syncLeague(Competition c, Future<String> Function(Future<String> Function()) fetch) async {
    final cam = c.fitetCam!;
    final standings = parseFitetStandings(await fetch(() => fitetClient.fetchStandingsPage(cam)));
    final year = c.fitetYear ?? '${seasonStart(c.date).year - 1985}';
    final fixtures = parseFitetCalendar(await fetch(() => fitetClient.fetchCalendarPage(cam, year)));
    var roster = c.roster;
    if (c.fitetTeam != null) {
      roster = parseFitetRoster(await fetch(() => fitetClient.fetchRosterPage(cam, c.fitetTeam!)));
    }
    if (standings.isEmpty && fixtures.isEmpty) {
      throw const FormatException('No standings or fixtures found');
    }
    String? myTeam;
    for (final r in standings) {
      if (c.fitetTeam != null && r.teamId == c.fitetTeam) myTeam = r.team;
    }
    var played = 0;
    var total = 0;
    for (final f in fixtures) {
      if (f.giornata > total) total = f.giornata;
      if (f.played && f.giornata > played) played = f.giornata;
    }
    final i = competitions.indexWhere((x) => x.id == c.id);
    if (i < 0) return;
    competitions[i] = competitions[i].copyWith(
      standings: standings.isEmpty ? null : standings,
      fixtures: fixtures.isEmpty ? null : fixtures,
      roster: roster,
      roundsPlayed: fixtures.isEmpty ? null : played,
      roundsTotal: fixtures.isEmpty ? null : total,
      myTeam: myTeam,
      fitetUpdated: DateTime.now(),
    );
  }

  /// Turns a championship found on FITeT into a competition with ids:
  /// attaches it to the competition the player's matches already landed in
  /// (same name, or same opponents), or creates it. Returns null if the
  /// player doesn't play in it this season.
  Future<Competition?> _discoverLeague(
    FitetChampionshipLink link,
    Future<String> Function(Future<String> Function()) fetch, {
    Player? player,
    Competition? target,
  }) async {
    final header = parseFitetChampionshipHeader(
        await fetch(() => fitetClient.fetchChampionshipHeader(link.cam)));
    final standings = parseFitetStandings(await fetch(() => fitetClient.fetchStandingsPage(link.cam)));
    final short = link.name ?? header.shortName;

    Map<String, String>? stats;
    Future<Map<String, String>> athletes() async =>
        stats ??= parseFitetAthleteStats(await fetch(() => fitetClient.fetchAthleteStatsPage(link.cam)));

    // Your player's team.
    var team = link.team;
    var teamName = link.teamName;
    if (team == null && teamName == null && player != null) {
      final key = fitetNameKey(player.name);
      for (final e in (await athletes()).entries) {
        if (fitetNameKey(e.key) == key) teamName = e.value;
      }
    }
    if (team == null && teamName != null) {
      for (final r in standings) {
        if (teamKey(r.team) == teamKey(teamName)) team = r.teamId;
      }
    }
    for (final r in standings) {
      if (team != null && r.teamId == team) teamName = r.team;
    }

    // The competition it belongs to.
    bool free(Competition c) => c.isLeague && c.fitetCam == null;
    if (target == null && short != null) {
      final key = championshipKey(short);
      target = competitions.where((c) => free(c) && championshipKey(c.name) == key).firstOrNull;
    }
    final candidates = target != null || player == null
        ? <Competition>[]
        : competitions.where((c) => free(c) && matchesIn(c.id, playerId: player.id).isNotEmpty).toList();
    if (candidates.isNotEmpty) {
      final names = (await athletes()).keys.map(fitetNameKey).toSet();
      for (final c in candidates) {
        final opponents = matchesIn(c.id, playerId: player!.id)
            .where((m) => !m.isDoubles)
            .map((m) => fitetNameKey(m.opponent))
            .toList();
        final known = opponents.where(names.contains).length;
        if (opponents.isNotEmpty && known * 2 >= opponents.length) {
          target = c;
          break;
        }
      }
    }
    if (target == null) {
      // A new championship: only for this season and if the player is in it.
      final season = '${seasonStart(DateTime.now()).year - 1985}';
      final year = header.year ?? link.year;
      if (short == null || team == null || (year != null && year != season)) return null;
      final key = 'fitet:$short';
      target = competitions.where((c) => c.fitetKey == key).firstOrNull ??
          Competition(
            id: 'fitet_${_slug(key)}',
            name: short,
            shortName: short,
            type: CompetitionType.league,
            location: '',
            date: seasonStart(DateTime.now()),
            subtitle: 'Team championship',
            imported: true,
            fitetKey: key,
          );
    }

    final updated = target.copyWith(
      fitetCam: link.cam,
      fitetTeam: team,
      fitetYear: header.year ?? link.year,
      myTeam: teamName,
      subtitle: teamName,
      standings: standings.isEmpty ? null : standings,
    );
    final i = competitions.indexWhere((c) => c.id == updated.id);
    if (i < 0) {
      competitions.add(updated);
    } else {
      competitions[i] = updated;
    }
    return updated;
  }

  /// After a championship got its ids: downloads it, then the set scores of
  /// your players in its roster, and fixes their matches' sets and dates.
  Future<void> _completeLeague(Competition c, Future<String> Function(Future<String> Function()) fetch) async {
    await _syncLeague(c, fetch);
    final league = competition(c.id);
    if (league.fitetCam == null || league.fitetTeam == null) return;
    for (final p in players.toList()) {
      final id = fitetIdOf(p.id);
      if (id == null || !league.roster.containsKey(id)) continue;
      try {
        final html = await fetch(() => fitetClient.fetchPlayerGamesPage(league.fitetCam!, league.fitetTeam!, id));
        _applyLeagueGames(p, league, parseFitetPlayerGames(html));
      } catch (e) {
        debugPrint('FITeT set scores failed for ${p.name}: $e');
      }
    }
    _refreshLeagueMatches(league);
  }

  /// Adds set scores and real dates to imported matches of a championship.
  void _refreshLeagueMatches(Competition c) {
    for (var i = 0; i < _matches.length; i++) {
      final m = _matches[i];
      if (!m.isFitet || m.competitionId != c.id) continue;
      final sets = m.sets.isNotEmpty
          ? m.sets
          : _leagueSets(m.playerId, c.id, m.giornata, m.opponent, m.setsWon, m.setsLost);
      final date = c.myFixture(m.giornata)?.date;
      _matches[i] = m.copyWith(
        sets: sets,
        date: date,
        dateApprox: date == null ? m.dateApprox : false,
      );
    }
    _sort();
  }

  /// Links a championship to FITeT by hand: [input] is a FITeT championship
  /// address (anything with CAM=) or the CAM number. Returns an error
  /// message, or null when it worked.
  Future<String?> linkChampionship(String competitionId, String input) async {
    final text = input.trim();
    final cam = RegExp(r'CAMP?=(\d+)', caseSensitive: false).firstMatch(text)?.group(1) ??
        (RegExp(r'^\d+$').hasMatch(text) ? text : null);
    if (cam == null) return 'Paste a FITeT championship address (with CAM=) or its number.';
    if (fitetSyncing) return 'An update is running: try again in a moment.';
    final target = competition(competitionId);
    final player = players
        .where((p) => fitetIdOf(p.id) != null && matchesIn(target.id, playerId: p.id).isNotEmpty)
        .firstOrNull;
    final link = FitetChampionshipLink(
      cam: cam,
      team: RegExp(r'SQUADRA=(\d+)', caseSensitive: false).firstMatch(text)?.group(1),
      year: RegExp(r'ANNO=(\d+)', caseSensitive: false).firstMatch(text)?.group(1),
    );
    fitetSyncing = true;
    notifyListeners();
    var requests = 0;
    Future<String> fetch(Future<String> Function() request) async {
      if (requests++ > 0 && fitetPause > Duration.zero) await Future<void>.delayed(fitetPause);
      return request();
    }

    String? error;
    fitetStatus = 'Linking ${target.shortName}';
    try {
      final c = await _discoverLeague(link, fetch, player: player, target: target);
      if (c == null) {
        error = 'That championship couldn’t be linked.';
      } else {
        await _completeLeague(c, fetch);
      }
    } catch (e) {
      debugPrint('FITeT link failed: $e');
      error = 'FITeT couldn’t be reached, or that isn’t a championship.';
    } finally {
      fitetSyncing = false;
      fitetStatus = null;
      notifyListeners();
    }
    await _save();
    return error;
  }

  /// A player's FITeT id from a team roster, matching the full name.
  String? _idFromRosters(Player p) {
    final key = fitetNameKey(p.name);
    for (final c in competitions) {
      for (final e in c.roster.entries) {
        if (fitetNameKey(e.value) == key) return e.key;
      }
    }
    return null;
  }

  /// A player's FITeT id from the name search, only if exactly one athlete
  /// has the same full name (namesakes are left for the user to choose).
  Future<String?> _idFromSearch(Player p, Future<String> Function(Future<String> Function()) fetch) async {
    final key = fitetNameKey(p.name);
    final hits = parseFitetSearch(await fetch(() => fitetClient.searchAthletes(p.name)));
    final same = hits.where((h) => fitetNameKey(h.name) == key).map((h) => h.id).toSet();
    return same.length == 1 ? same.first : null;
  }

  /// The FITeT page is about this player (every word of the last name appears).
  static bool _sameAthlete(Player p, String athlete) {
    final words = fitetNameKey(athlete).split(' ').toSet();
    return fitetNameKey(p.lastName).split(' ').every(words.contains);
  }

  void _applyLeagueGames(Player p, Competition c, FitetPlayerGames page) {
    if (!_sameAthlete(p, page.athlete)) return;
    _leagueGames.removeWhere((g) => g.playerId == p.id && g.competitionId == c.id);
    for (final g in page.games) {
      _leagueGames.add(LeagueGame(
        competitionId: c.id,
        playerId: p.id,
        giornata: g.giornata,
        opponent: _titleCase(g.opponent),
        sets: List<SetScore>.unmodifiable(g.sets),
      ));
    }
  }

  /// Set scores of a championship game, if they agree with the match score.
  List<SetScore> _leagueSets(String playerId, String competitionId, int? giornata, String opponent, int won, int lost) {
    if (giornata == null) return const <SetScore>[];
    final key = fitetNameKey(opponent);
    for (final g in _leagueGames) {
      if (g.playerId != playerId || g.competitionId != competitionId || g.giornata != giornata) continue;
      if (fitetNameKey(g.opponent) != key) continue;
      final w = g.sets.where((s) => s.won).length;
      if (w == won && g.sets.length - w == lost) return g.sets;
    }
    return const <SetScore>[];
  }

  /// Replaces a player's FITeT matches with the ones in [sheet], skipping
  /// matches already in the app with full set scores and ones the user deleted.
  void applyFitetSheet(String playerId, FitetSheet sheet) {
    _matches.removeWhere((m) => m.playerId == playerId && m.isFitet);
    final seen = <String, int>{};
    for (final row in sheet.matches) {
      final comp = _competitionForFitet(row);
      final opponent = _titleCase(row.opponent);
      final round = row.section == 'tournament' ? _roundFromFitet(row.roundCode) : null;

      final base = 'fitet_${playerId}_${_slug(comp.id)}_${row.roundCode ?? row.giornata ?? ''}_'
          '${_slug(opponent)}_${row.setsWon}${row.setsLost}';
      final n = seen[base] = (seen[base] ?? 0) + 1;
      final id = '${base}_$n';
      if (_deleted.contains(id)) continue;

      // Already in the app (e.g. entered with set scores)? Keep that one.
      final duplicate = _matches.any((m) =>
          m.playerId == playerId &&
          !m.isFitet &&
          !m.isDoubles &&
          m.competitionId == comp.id &&
          _nameKey(m.opponent) == _nameKey(opponent) &&
          m.setsWon == row.setsWon &&
          m.setsLost == row.setsLost);
      if (duplicate) continue;

      DateTime date;
      var approx = false;
      final fixtureDate = row.section == 'tournament' ? null : comp.myFixture(row.giornata)?.date;
      if (row.date != null) {
        date = DateTime(row.date!.year, row.date!.month, row.date!.day, 12);
      } else if (fixtureDate != null) {
        date = fixtureDate;
      } else {
        // Team rounds have no date on FITeT: estimate one week per round.
        approx = true;
        date = comp.date.add(Duration(days: 7 * ((row.giornata ?? 1) - 1), hours: 20));
        final now = DateTime.now();
        if (date.isAfter(now)) date = now;
      }

      _matches.add(Match(
        id: id,
        playerId: playerId,
        opponent: opponent,
        competitionId: comp.id,
        date: date,
        sets: row.section == 'tournament'
            ? const <SetScore>[]
            : _leagueSets(playerId, comp.id, row.giornata, opponent, row.setsWon, row.setsLost),
        round: round,
        source: 'fitet',
        scoreMine: row.setsWon,
        scoreTheirs: row.setsLost,
        event: row.event,
        giornata: row.giornata,
        dateApprox: approx,
      ));
    }
    _sort();
  }

  Competition _competitionForFitet(FitetMatchRow row) {
    final isTournament = row.section == 'tournament';
    final d = row.date;
    final key = isTournament && d != null
        ? 'fitet:${row.competition}|${d.year}-${d.month}-${d.day}'
        : 'fitet:${row.competition}';
    for (final c in competitions) {
      if (c.fitetKey == key) return c;
    }
    final now = DateTime.now();
    final c = Competition(
      id: 'fitet_${_slug(key)}',
      name: row.competition,
      shortName: row.competition,
      type: isTournament ? CompetitionType.tournament : CompetitionType.league,
      location: row.location ?? '',
      date: d ?? seasonStart(now),
      subtitle: isTournament ? null : (row.section == 'playoff' ? 'Play-off/out' : 'Team championship'),
      imported: true,
      fitetKey: key,
    );
    competitions.add(c);
    return c;
  }

  static String? _roundFromFitet(String? code) => switch (code) {
        'GQ' => 'GR',
        'TS' => 'R64',
        'SD' => 'R32',
        'OF' => 'R16',
        'QF' => 'QF',
        'SF' => 'SF',
        'F' => 'F',
        _ => null,
      };

  static String _slug(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');

  static String _nameKey(String s) => fitetNameKey(s);

  static String _titleCase(String s) => s
      .toLowerCase()
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

/// Makes [AppState] available to every screen and rebuilds them on changes.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required super.notifier, required super.child});

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
