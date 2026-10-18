import '../models/models.dart';

/// Results added to the app automatically (each one only once, by id).
/// Deleting one in the app keeps it deleted.

/// Team championship of TT.Torino B, season 2026/27.
final Competition kTeamChampionship = Competition(
  id: 'ttorino_b_2026_27',
  name: 'Serie C2 · Girone D',
  shortName: 'C2 Gir. D',
  type: CompetitionType.league,
  location: 'Torino',
  date: DateTime(2026, 10, 10),
  subtitle: 'TT.Torino B · 2026/27',
  fitetKey: 'fitet:C/2 Gir.D',
  // portale.fitet.org ids: championship, team, season (41 = 2026/27).
  fitetCam: '204',
  fitetTeam: '38782',
  fitetYear: '41',
  myTeam: 'TT.Torino B',
);

List<Competition> get builtInCompetitions => <Competition>[kTeamChampionship];

/// 1ª giornata, 10/10/2026: TT.Torino B 6–1 A.S.D. T.T. Enjoy
/// (Palestra E/23, Via Stefano Tempia 8, Torino). Sets 18–7, points 255–213.
List<Match> get builtInMatches {
  const comp = 'ttorino_b_2026_27';
  DateTime at(int game) => DateTime(2026, 10, 10, 20, game);
  return <Match>[
    Match(
      id: 'r1_2026_10_10_g1',
      playerId: 'jar_isabella',
      opponent: 'Piero Sistino',
      competitionId: comp,
      date: at(1),
      sets: const <SetScore>[SetScore(11, 8), SetScore(11, 7), SetScore(11, 9)],
    ),
    Match(
      id: 'r1_2026_10_10_g2',
      playerId: 'zito_andrea',
      opponent: 'Andrea Maspes',
      competitionId: comp,
      date: at(2),
      sets: const <SetScore>[SetScore(6, 11), SetScore(11, 9), SetScore(11, 8), SetScore(12, 10)],
    ),
    Match(
      id: 'r1_2026_10_10_g3',
      playerId: 'jar_alin',
      opponent: 'Cristian Pop',
      competitionId: comp,
      date: at(3),
      sets: const <SetScore>[SetScore(11, 9), SetScore(11, 5), SetScore(7, 11), SetScore(11, 2)],
    ),
    // Game 4 is the doubles: Jar I. M. / Zito A. vs Sistino P. / Maspes A.
    Match(
      id: 'r1_2026_10_10_g4_jar_isabella',
      playerId: 'jar_isabella',
      partner: 'Andrea Zito',
      opponent: 'Sistino P. / Maspes A.',
      competitionId: comp,
      date: at(4),
      sets: const <SetScore>[SetScore(11, 4), SetScore(11, 7), SetScore(11, 8)],
    ),
    Match(
      id: 'r1_2026_10_10_g4_zito_andrea',
      playerId: 'zito_andrea',
      partner: 'Isabella Maria Jar',
      opponent: 'Sistino P. / Maspes A.',
      competitionId: comp,
      date: at(4),
      sets: const <SetScore>[SetScore(11, 4), SetScore(11, 7), SetScore(11, 8)],
    ),
    Match(
      id: 'r1_2026_10_10_g5',
      playerId: 'jar_isabella',
      opponent: 'Andrea Maspes',
      competitionId: comp,
      date: at(5),
      sets: const <SetScore>[SetScore(11, 7), SetScore(13, 11), SetScore(11, 6)],
    ),
    Match(
      id: 'r1_2026_10_10_g6',
      playerId: 'jar_alin',
      opponent: 'Piero Sistino',
      competitionId: comp,
      date: at(6),
      sets: const <SetScore>[SetScore(8, 11), SetScore(7, 11), SetScore(10, 12)],
    ),
    Match(
      id: 'r1_2026_10_10_g7',
      playerId: 'zito_andrea',
      opponent: 'Cristian Pop',
      competitionId: comp,
      date: at(7),
      sets: const <SetScore>[SetScore(8, 11), SetScore(11, 7), SetScore(7, 11), SetScore(12, 10), SetScore(11, 8)],
    ),
  ];
}
