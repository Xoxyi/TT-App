import 'package:flutter_test/flutter_test.dart';

import 'package:table_tennis_app/data/app_state.dart';
import 'package:table_tennis_app/data/store.dart';
import 'package:table_tennis_app/models/models.dart';
import 'package:table_tennis_app/utils/format.dart';

void main() {
  test('match score, winner and points are computed from the sets', () {
    final m = Match(
      id: 't1',
      playerId: 'zito_andrea',
      opponent: 'Test',
      competitionId: 'friendly',
      date: DateTime(2026, 10, 1),
      sets: const <SetScore>[SetScore(11, 6), SetScore(9, 11), SetScore(11, 8), SetScore(12, 10)],
    );
    expect(m.setsWon, 3);
    expect(m.setsLost, 1);
    expect(m.won, isTrue);
    expect(m.score, '3–1');
    expect(m.pointsWon, 43);
    expect(m.pointsLost, 35);
  });

  test('starts with the club players and the round 1 results', () async {
    final state = await AppState.load(MemoryStore());
    expect(state.players.map((p) => p.name).toList(), <String>[
      'Isabella Maria Jar',
      'Andrea Zito',
      'Gabriele Piciulin',
      'Alin Catalin Jar',
    ]);
    expect(state.player('jar_alin').shortName, 'Ma Long');
    expect(state.player('zito_andrea').shortName, 'Xoxyi');
    expect(state.player('jar_isabella').shortName, 'Isabella');
    // 7 games, the doubles counted for both players.
    expect(state.matches.length, 8);
    final alin = state.stats('jar_alin');
    expect(alin.wins, 1);
    expect(alin.losses, 1);
    // Doubles are listed but not in the singles stats.
    expect(state.stats('jar_isabella').played, 2);
    expect(state.matchesFor('jar_isabella').length, 3);
  });

  test('matches and competitions are saved and loaded again', () async {
    final store = MemoryStore();
    final state = await AppState.load(store);
    final cup = state.addCompetition(
      name: 'Test Cup',
      type: CompetitionType.tournament,
      date: DateTime(2026, 10, 1),
    );
    state.addMatch(
      playerId: 'piciulin_gabriele',
      opponent: 'Test Opponent',
      competitionId: cup.id,
      date: DateTime(2026, 10, 1),
      sets: const <SetScore>[SetScore(8, 11), SetScore(11, 5), SetScore(11, 9), SetScore(11, 7)],
      round: 'SF',
    );
    await Future<void>.delayed(Duration.zero); // let the save finish

    final reloaded = await AppState.load(store);
    expect(reloaded.matches.length, 9);
    expect(reloaded.matches.any((m) => m.opponent == 'Test Opponent'), isTrue);
    expect(reloaded.competition(cup.id).name, 'Test Cup');
    // The tournament date is in the past, so the furthest round reached shows.
    expect(reloaded.placement('piciulin_gabriele', cup.id), 'Semifinal');
    expect(reloaded.stats('piciulin_gabriele').wins, 1);
  });

  test('statistics by season, singles only', () async {
    final state = await AppState.load(MemoryStore());
    state.addMatch(
      playerId: 'jar_isabella',
      opponent: 'Last season',
      competitionId: 'friendly',
      date: DateTime(2026, 5, 10),
      sets: const <SetScore>[SetScore(5, 11), SetScore(5, 11), SetScore(5, 11)],
    );
    final current = DateTime(2026, 9, 1);
    final last = DateTime(2025, 9, 1);
    // Round 1 (October 2026): 2 singles won; the doubles isn't counted.
    expect(state.stats('jar_isabella', since: current).played, 2);
    final previous = state.stats('jar_isabella', since: last, until: current);
    expect(previous.played, 1);
    expect(previous.losses, 1);
    expect(state.stats('jar_isabella').played, 3);
    // In September, before any match of the new season, stats open on the last one.
    expect(state.defaultSeasonStart(DateTime(2027, 9, 5)), DateTime(2026, 9, 1));
    expect(state.defaultSeasonStart(DateTime(2026, 10, 20)), DateTime(2026, 9, 1));
  });

  test('season months and labels', () async {
    final state = await AppState.load(MemoryStore());
    final bars = state.monthly('jar_isabella', season: DateTime(2025, 9, 1));
    expect(bars.length, 12);
    expect(bars.first.label, 'Sep');
    expect(bars.last.label, 'Aug');
    expect(state.monthly('jar_isabella').length, 12);
    expect(seasonLabel(DateTime(2026, 9, 1)), '2026/27');
    expect(seasonLabel(DateTime(2099, 9, 1)), '2099/00');
    expect(ordinal(1), '1st');
    expect(ordinal(2), '2nd');
    expect(ordinal(3), '3rd');
    expect(ordinal(11), '11th');
    expect(ordinal(22), '22nd');
  });
}
