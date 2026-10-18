import 'package:flutter_test/flutter_test.dart';

import 'package:table_tennis_app/data/app_state.dart';
import 'package:table_tennis_app/data/fitet.dart';
import 'package:table_tennis_app/data/store.dart';
import 'package:table_tennis_app/models/models.dart';

import 'fake_fitet.dart';

const String _headerA2 = '<p class="stile"><strong>CAMPIONATO FEMMINILE - SERIE A/2 Gir.B</strong></p>'
    '<a href="Calendario.asp?CAM=999&ANNO=41">Calendario incontri</a>';

/// Isabella's sheet: the C/2 with Andrea, and an A/2.
const String _sheetIsabella = '<html><body><table><tbody>'
    '<tr><td><h6><a href="risultati/campionati/campionati.php?CAM=204&CONC=0">C/2 Gir.D</a></h6></td>'
    '<td><h6>TT.Torino B</h6></td><td><h6>100%</h6></td></tr>'
    '<tr><td><h6><a href="risultati/campionati/campionati.php?CAM=999&CONC=0">A/2 Gir.B</a></h6></td>'
    '<td><h6>TT.Torino B</h6></td><td><h6>75%</h6></td></tr>'
    '</tbody></table></body></html>';

Future<AppState> _state([Store? store]) async {
  final state = await AppState.load(store ?? MemoryStore());
  state.fitetPause = Duration.zero;
  return state;
}

void main() {
  test('parses championship headers and athlete statistics', () {
    final header = parseFitetChampionshipHeader(FakeFitet.page('header_204.html'));
    expect(header.title, 'CAMPIONATO MASCHILE - SERIE C/2 Gir.D');
    expect(header.shortName, 'C/2 Gir.D');
    expect(header.year, '41');
    expect(championshipKey('C/2 Gir.D'), championshipKey('SERIE C/2 Gir. D'));

    final stats = parseFitetAthleteStats(FakeFitet.page('athlete_stats.html'));
    expect(stats['JAR ISABELLA MARIA'], 'TT.Torino B');
    expect(stats['CALABRESE ANDREA'], 'TT.Valenza Rolandi Auto');
  });

  test('parses the championships on the athlete sheet', () {
    final links = parseFitetAthleteChampionships(FakeFitet.page('athlete_sheet_792524.html'));
    expect(links.length, 1);
    expect(links.first.cam, '204');
    expect(links.first.name, 'C/2 Gir.D');
    expect(links.first.teamName, 'TT.Torino B');
  });

  test('finds the other championships of a player on their athlete sheet', () async {
    final state = await _state();
    final client = FakeFitet()
      ..sheets['762651'] = _sheetIsabella
      ..headers['999'] = _headerA2;
    state.fitetClient = client;
    await state.syncFitet();

    final a2 = state.competitions.singleWhere((c) => c.fitetCam == '999');
    expect(a2.name, 'A/2 Gir.B');
    expect(a2.fitetKey, 'fitet:A/2 Gir.B');
    expect(a2.type, CompetitionType.league);
    expect(a2.fitetTeam, '38782'); // TT.Torino B, found in the standings by name
    expect(a2.myTeam, 'TT.Torino B');
    expect(a2.fixtures.length, 56);
    expect(client.count('stats:999'), 0); // the sheet already says the team
    // The C/2 is already known: not created again.
    expect(state.competitions.where((c) => c.fitetCam == '204').length, 1);
    expect(client.count('header:204'), 0);

    // Sheets are checked at most once a day.
    await state.syncFitet();
    expect(client.count('sheet:762651'), 1);
  });

  test('a championship is linked with its FITeT address, team found automatically', () async {
    final state = await _state();
    state.fitetClient = FakeFitet()..headers['999'] = _headerA2;
    final c = state.addCompetition(
      name: 'A/2 Gir.B',
      type: CompetitionType.league,
      date: DateTime(2026, 10, 1),
    );
    state.addMatch(
      playerId: 'jar_isabella',
      opponent: 'Andrea Calabrese',
      competitionId: c.id,
      date: DateTime(2026, 10, 11),
      sets: const <SetScore>[SetScore(11, 5), SetScore(11, 7), SetScore(11, 9)],
    );
    expect(await state.linkChampionship(c.id, 'hello'), isNotNull);

    final error = await state.linkChampionship(
        c.id, 'https://portale.fitet.org/risultati/campionati/classifica_squadre.php?CAM=999');
    expect(error, isNull);
    final linked = state.competition(c.id);
    expect(linked.fitetCam, '999');
    expect(linked.fitetYear, '41');
    // Isabella's team, from the championship's athlete statistics.
    expect(linked.fitetTeam, '38782');
    expect(linked.myTeam, 'TT.Torino B');
    expect(linked.standings.length, 8);
    expect(linked.fixtures.length, 56);
    expect(linked.roster.length, 3);
  });
}
