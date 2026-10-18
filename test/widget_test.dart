import 'package:flutter_test/flutter_test.dart';

import 'package:table_tennis_app/data/app_state.dart';
import 'package:table_tennis_app/data/store.dart';
import 'package:table_tennis_app/models/models.dart';

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

  test('a deleted built-in match does not come back', () async {
    final store = MemoryStore();
    final state = await AppState.load(store);
    state.deleteMatch('r1_2026_10_10_g6');
    await Future<void>.delayed(Duration.zero);
    final reloaded = await AppState.load(store);
    expect(reloaded.matches.length, 7);
    expect(reloaded.matches.any((m) => m.id == 'r1_2026_10_10_g6'), isFalse);
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

  test('deleting a match updates the stats', () async {
    final state = await AppState.load(MemoryStore());
    state.addMatch(
      playerId: 'jar_isabella',
      opponent: 'X',
      competitionId: 'friendly',
      date: DateTime.now(),
      sets: const <SetScore>[SetScore(5, 11), SetScore(5, 11), SetScore(5, 11)],
    );
    expect(state.stats('jar_isabella').losses, 1);
    final added = state.matches.firstWhere((m) => m.opponent == 'X');
    state.deleteMatch(added.id);
    expect(state.stats('jar_isabella').losses, 0);
  });
}
