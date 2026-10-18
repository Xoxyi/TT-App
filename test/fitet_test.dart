import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:table_tennis_app/data/app_state.dart';
import 'package:table_tennis_app/data/fitet.dart';
import 'package:table_tennis_app/data/store.dart';

import 'fake_fitet.dart';

Future<AppState> _state([Store? store]) async {
  final state = await AppState.load(store ?? MemoryStore());
  state.fitetPause = Duration.zero;
  return state;
}

void main() {
  final html = File('test/fitet_sample.html').readAsStringSync();

  test('parses the FITeT matches page', () {
    final sheet = parseFitetMatches(html);
    expect(sheet.athlete, 'ZITO ANDREA');
    expect(sheet.season, '2026/27');
    expect(sheet.matches.length, 18);
    expect(sheet.matches.where((m) => m.won).length, 13);
    expect(sheet.warnings, isEmpty);

    final first = sheet.matches.first;
    expect(first.competition, 'Torneo Open Enjoy');
    expect(first.date, DateTime(2026, 8, 29));
    expect(first.location, 'Moncalieri (TO)');
    expect(first.roundCode, 'GQ');
    expect(first.opponent, 'VETRI LUCA');
    expect(first.setsWon, 3);
    expect(first.setsLost, 0);

    final team = sheet.matches.where((m) => m.section == 'team').toList();
    expect(team.length, 4);
    expect(team.first.competition, 'C/2 Gir.D');
    expect(team.last.giornata, 2);
  });

  test('imports FITeT matches without duplicating round 1', () async {
    final state = await _state();
    final before = state.matchesFor('zito_andrea').length; // 3 built-in (incl. doubles)
    state.fitetClient = FakeFitet();
    await state.syncFitet();

    final mine = state.matchesFor('zito_andrea');
    // 18 FITeT matches, minus Maspes and Pop already present with set scores.
    expect(mine.length, before + 16);
    expect(mine.where((m) => m.isFitet).length, 16);

    // Championship matches land in the built-in Serie C2 · Girone D,
    // with set scores and the real date from the calendar.
    final league = state.matchesIn('ttorino_b_2026_27', playerId: 'zito_andrea');
    final boero = league.singleWhere((m) => m.opponent == 'Boero Alessandro');
    expect(boero.setsText, '12-10   11-5   11-7');
    expect(boero.date, DateTime(2026, 10, 17, 15));
    expect(boero.dateApprox, isFalse);
    final salerno = league.singleWhere((m) => m.opponent == 'Salerno Marco');
    expect(salerno.sets.map((s) => s.toString()).toList(),
        <String>['12-10', '11-8', '3-11', '4-11', '11-6']);
    expect(salerno.score, '3–2');

    // Tournaments were created, with placements.
    final regional = state.competitions
        .firstWhere((c) => c.name == 'Torneo Regionale Ordinario di Categoria Torino');
    expect(state.placement('zito_andrea', regional.id), 'Semifinal');
  });

  test('a second update replaces, not duplicates, and respects the interval', () async {
    final state = await _state();
    final client = FakeFitet();
    state.fitetClient = client;
    await state.syncFitet();
    final count = state.matches.length;
    expect(client.count('matches:792524'), 1);

    await state.syncFitet(); // within the interval: no request
    expect(client.count('matches:792524'), 1);
    expect(client.count('standings'), 1);

    await state.syncFitet(force: true);
    expect(client.count('matches:792524'), 2);
    expect(client.count('standings'), 2);
    expect(state.matches.length, count);
  });
}
