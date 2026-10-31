import 'package:flutter_test/flutter_test.dart';

import 'package:table_tennis_app/data/app_state.dart';
import 'package:table_tennis_app/data/fitet.dart';
import 'package:table_tennis_app/data/store.dart';
import 'package:table_tennis_app/models/models.dart';

import 'fake_fitet.dart';

const String _searchZito =
    '[{"id":"792524","label":"<span class=\\"hl_results\\">ZITO</span> <span class=\\"hl_results\\">ANDREA</span> (01/01/2000)","value":"ZITO ANDREA"}]';

Future<AppState> _state([Store? store]) async {
  final state = await AppState.load(store ?? MemoryStore());
  state.fitetPause = Duration.zero;
  return state;
}

void main() {
  test('parses the championship standings', () {
    final rows = parseFitetStandings(FakeFitet.page('standings.html'));
    expect(rows.length, 8);
    final first = rows.first;
    expect(first.team, 'TT.Torino B');
    expect(first.teamId, '38782');
    expect(first.points, 6);
    expect(first.played, 2);
    expect(first.wins, 2);
    expect(first.losses, 0);
    final crdc = rows.singleWhere((r) => r.team == 'T.T. CRDC TORINO A');
    expect(crdc.points, 2);
    expect(crdc.wins, 1);
  });

  test('parses the calendar, first and return legs', () {
    final fixtures = parseFitetCalendar(FakeFitet.page('calendar.html'));
    expect(fixtures.length, 56);
    final first = fixtures.first;
    expect(first.giornata, 1);
    expect(first.date, DateTime(2026, 10, 10, 16));
    expect(first.home, 'TT.Cus B');
    expect(first.away, 'TT.Alessandria');
    expect(first.homeScore, 2);
    expect(first.awayScore, 5);
    expect(first.matchId, '376353');

    final back = fixtures.singleWhere((f) => f.matchId == '376381');
    expect(back.giornata, 8);
    expect(back.home, 'TT.Alessandria');
    expect(back.away, 'TT.Cus B');
    expect(back.date, DateTime(2027, 1, 16, 15, 30));
    expect(back.played, isFalse);

    final ours = fixtures.singleWhere((f) => f.giornata == 2 && f.away == 'TT.Torino B');
    expect(ours.home, 'TT SAN DAMIANO ITALFRESE');
    expect(ours.homeScore, 2);
    expect(ours.awayScore, 5);
    expect(fixtures.map((f) => f.giornata).reduce((a, b) => a > b ? a : b), 14);
  });

  test('parses a single-leg calendar (Supercoppa)', () {
    final fixtures = parseFitetCalendar(FakeFitet.page('calendar_single_leg.html'));
    expect(fixtures, isNotEmpty);
    final first = fixtures.first;
    expect(first.giornata, 1);
    expect(first.date, DateTime(2026, 9, 25, 17, 30));
    expect(first.home, 'POLISPORTIVA BAGNOLESE ASD');
    expect(first.away, 'TOP SPIN MESSINA AMTIVO');
    expect(first.homeScore, 0);
    expect(first.awayScore, 2);
    expect(first.matchId, '374981');
  });

  test('parses the team roster and a player’s set scores', () {
    final roster = parseFitetRoster(FakeFitet.page('roster.html'));
    expect(roster, <String, String>{
      '762651': 'JAR ISABELLA MARIA',
      '792524': 'ZITO ANDREA',
      '762636': 'JAR ALIN CATALIN',
    });

    final page = parseFitetPlayerGames(FakeFitet.page('player_games_792524.html'));
    expect(page.athlete, 'ZITO ANDREA');
    expect(page.team, 'TT.Torino B');
    expect(page.games.length, 4);
    final maspes = page.games.first;
    expect(maspes.giornata, 1);
    expect(maspes.opponent, 'MASPES ANDREA');
    expect(maspes.sets.map((s) => s.toString()).join(' '), '6-11 11-9 11-8 12-10');
    // FITeT lists Boero first: the scores are turned to Zito's side.
    final boero = page.games[2];
    expect(boero.opponent, 'BOERO ALESSANDRO');
    expect(boero.sets.map((s) => s.toString()).join(' '), '12-10 11-5 11-7');
    expect(boero.setsWon, 3);
    expect(boero.setsLost, 0);
  });

  test('parses the athlete search and splits names', () {
    final hits = parseFitetSearch(_searchZito);
    expect(hits.length, 1);
    expect(hits.first.id, '792524');
    expect(hits.first.name, 'ZITO ANDREA');
    expect(hits.first.birthDate, '01/01/2000');
    expect(parseFitetSearch('[]'), isEmpty);

    final a = splitFitetName('JAR ISABELLA MARIA');
    expect(a.lastName, 'Jar');
    expect(a.firstName, 'Isabella Maria');
    final b = splitFitetName('DE LUCA MARCO');
    expect(b.lastName, 'De Luca');
    expect(b.firstName, 'Marco');
  });

  test('update downloads standings and fixtures and finds missing ids', () async {
    final state = await _state();
    final client = FakeFitet(
      searchAnswer: '[{"id":"999001","label":"PICIULIN GABRIELE (01/01/2000)","value":"PICIULIN GABRIELE"},'
          '{"id":"999002","label":"PICIULIN MARCO (01/01/1990)","value":"PICIULIN MARCO"}]',
    );
    state.fitetClient = client;
    await state.syncFitet();

    final c = state.competition('ttorino_b_2026_27');
    expect(c.standings.length, 8);
    expect(c.isMyRow(c.standings.first), isTrue);
    expect(c.myTeam, 'TT.Torino B');
    expect(c.fixtures.length, 56);
    expect(c.roundsTotal, 14);
    expect(c.roundsPlayed, 2);
    expect(c.roster.length, 3);

    // Gabriele had no id: found by name (Marco is someone else) and imported.
    expect(state.fitetIdOf('piciulin_gabriele'), '999001');
    expect(client.count('matches:999001'), 1);
    // Isabella and Alin have built-in ids and their set scores are requested.
    expect(client.count('games:762651'), 1);
    expect(client.count('games:762636'), 1);
    expect(state.fitetError, isNull);

    final next = state.nextTeamMatch;
    if (next != null) {
      expect(next.fixture.played, isFalse);
      expect(next.competition.isMine(next.fixture.home) || next.competition.isMine(next.fixture.away),
          isTrue);
    }
  });

  test('namesakes are not linked automatically', () async {
    final state = await _state();
    state.fitetClient = FakeFitet(
      searchAnswer: '[{"id":"999001","label":"PICIULIN GABRIELE (01/01/2000)","value":"PICIULIN GABRIELE"},'
          '{"id":"999003","label":"PICIULIN GABRIELE (05/05/1970)","value":"PICIULIN GABRIELE"}]',
    );
    await state.syncFitet();
    expect(state.fitetIdOf('piciulin_gabriele'), isNull);
    expect(state.fitetLookupFailed('piciulin_gabriele'), isTrue);
  });

  test('standings, fixtures and added players are saved', () async {
    final store = MemoryStore();
    final state = await _state(store);
    state.fitetClient = FakeFitet();
    await state.syncFitet();
    final p = state.addPlayer(firstName: 'Gabriele', lastName: 'Rossi', nickname: 'Gabri', fitetId: '999009');
    await Future<void>.delayed(const Duration(milliseconds: 50)); // let the update finish

    final reloaded = await _state(store);
    final c = reloaded.competition('ttorino_b_2026_27');
    expect(c.standings.length, 8);
    expect(c.fixtures.length, 56);
    expect(c.fitetCam, '204');
    expect(reloaded.player(p.id).nickname, 'Gabri');
    expect(reloaded.players.any((x) => x.id == p.id), isTrue);
    final boero = reloaded
        .matchesIn('ttorino_b_2026_27', playerId: 'zito_andrea')
        .singleWhere((m) => m.opponent == 'Boero Alessandro');
    expect(boero.hasSetDetail, isTrue);

    reloaded.removePlayer(p.id);
    expect(reloaded.players.any((x) => x.id == p.id), isFalse);
    // Built-in players can be removed too, and stay removed after a restart.
    reloaded.removePlayer('zito_andrea');
    expect(reloaded.players.any((x) => x.id == 'zito_andrea'), isFalse);
    expect(reloaded.matchesFor('zito_andrea'), isEmpty);
    await Future<void>.delayed(Duration.zero); // let the save finish
    final again = await _state(store);
    expect(again.players.any((x) => x.id == 'zito_andrea'), isFalse);
    expect(again.matchesFor('zito_andrea'), isEmpty);

    // Following them again (found by FITeT id) brings back the built-in player.
    again.fitetClient = FakeFitet();
    final back = again.addPlayer(firstName: 'Andrea', lastName: 'Zito', fitetId: '792524');
    expect(back.id, 'zito_andrea');
    expect(again.players.any((x) => x.id == 'zito_andrea'), isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });

  test('a FITeT id can be linked once but not changed', () async {
    final state = await _state(MemoryStore());
    state.fitetClient = FakeFitet();
    await state.setFitetId('zito_andrea', '111111');
    expect(state.fitetIdOf('zito_andrea'), '792524');
    final p = state.addPlayer(firstName: 'No', lastName: 'Id');
    await state.setFitetId(p.id, '999009');
    expect(state.fitetIdOf(p.id), '999009');
    await state.setFitetId(p.id, '123');
    expect(state.fitetIdOf(p.id), '999009');
  });

  test('a championship is downloaded again only when there can be new results', () {
    final now = DateTime(2026, 10, 31, 12);
    Competition league({DateTime? updated, List<Fixture> fixtures = const <Fixture>[]}) => Competition(
          id: 'c',
          name: 'C2',
          shortName: 'C2',
          type: CompetitionType.league,
          location: '',
          date: DateTime(2026, 9, 1),
          fitetUpdated: updated,
          fixtures: fixtures,
          standings: const <StandingRow>[
            StandingRow(team: 'A', points: 3, played: 1, wins: 1, losses: 0),
          ],
        );
    const played = Fixture(giornata: 1, home: 'A', away: 'B', homeScore: 5, awayScore: 2);
    final done = <Fixture>[
      Fixture(giornata: 1, home: 'A', away: 'B', date: DateTime(2026, 10, 10, 16), homeScore: 5, awayScore: 2),
      Fixture(giornata: 2, home: 'B', away: 'A', date: DateTime(2026, 11, 7, 16)),
    ];
    // Never downloaded, or no fixtures yet.
    expect(AppState.leagueHasNews(league(), now), isTrue);
    expect(AppState.leagueHasNews(league(updated: now, fixtures: const <Fixture>[played]), now), isFalse);
    // All past matches have results, the next one is in the future: nothing new.
    expect(AppState.leagueHasNews(league(updated: DateTime(2026, 10, 30), fixtures: done), now), isFalse);
    // A match was played and its result isn't in the app yet.
    final waiting = <Fixture>[
      done.first,
      Fixture(giornata: 2, home: 'B', away: 'A', date: DateTime(2026, 10, 31, 10)),
    ];
    expect(AppState.leagueHasNews(league(updated: DateTime(2026, 10, 30), fixtures: waiting), now), isTrue);
    // A result that never came (e.g. postponed) stops counting after three weeks.
    final old = <Fixture>[Fixture(giornata: 2, home: 'B', away: 'A', date: DateTime(2026, 10, 1))];
    expect(AppState.leagueHasNews(league(updated: DateTime(2026, 10, 30), fixtures: old), now), isFalse);
    // Once a week anyway, for date changes.
    expect(AppState.leagueHasNews(league(updated: DateTime(2026, 10, 20), fixtures: done), now), isTrue);
  });
}
