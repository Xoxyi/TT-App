/// Data model: players you follow, competitions (championships and
/// tournaments) and the matches your players played in them.
library;

enum CompetitionType { league, tournament, friendly }

class Player {
  const Player({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.nickname,
    this.hand = 'Right-handed',
    this.style,
    this.country,
    this.worldRank,
    this.age,
    this.wttId,
    this.fitetId,
  });

  final String id;

  /// Given name(s), e.g. "Isabella Maria".
  final String firstName;
  final String lastName;

  /// Optional nickname, e.g. "Ma Long".
  final String? nickname;
  final String hand;

  /// Playing style, e.g. "Attacker".
  final String? style;
  final String? country;
  final int? worldRank;
  final int? age;

  /// Player id on worldtabletennis.com, if any.
  final String? wttId;

  /// Athlete id on portale.fitet.org (the ATLETA= number), if known.
  final String? fitetId;

  String get name => '$firstName $lastName';

  /// Short label for tight spots: the nickname, or the first given name.
  String get shortName => nickname ?? firstName.split(' ').first;

  String get initials {
    final a = firstName.trim();
    final b = lastName.trim();
    return '${a.isEmpty ? '' : a[0]}${b.isEmpty ? '' : b[0]}'.toUpperCase();
  }

  Player copyWith({String? firstName, String? lastName, String? nickname, String? fitetId}) => Player(
        id: id,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        nickname: nickname ?? this.nickname,
        hand: hand,
        style: style,
        country: country,
        worldRank: worldRank,
        age: age,
        wttId: wttId,
        fitetId: fitetId ?? this.fitetId,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'firstName': firstName,
        'lastName': lastName,
        'nickname': nickname,
        'hand': hand,
        'style': style,
        'fitetId': fitetId,
      };

  factory Player.fromJson(Map<String, dynamic> j) => Player(
        id: j['id'] as String,
        firstName: j['firstName'] as String,
        lastName: j['lastName'] as String,
        nickname: j['nickname'] as String?,
        hand: (j['hand'] as String?) ?? 'Right-handed',
        style: j['style'] as String?,
        fitetId: j['fitetId'] as String?,
      );
}

/// One row of a championship table, as published by FITeT.
class StandingRow {
  const StandingRow({
    required this.team,
    required this.points,
    required this.played,
    required this.wins,
    required this.losses,
    this.draws = 0,
    this.teamId,
  });

  final String team;

  /// FITeT team id (the SQUADRA= number), if known.
  final String? teamId;
  final int points;
  final int played;
  final int wins;
  final int draws;
  final int losses;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'team': team,
        'teamId': teamId,
        'points': points,
        'played': played,
        'wins': wins,
        'draws': draws,
        'losses': losses,
      };

  factory StandingRow.fromJson(Map<String, dynamic> j) => StandingRow(
        team: j['team'] as String,
        teamId: j['teamId'] as String?,
        points: (j['points'] as num?)?.toInt() ?? 0,
        played: (j['played'] as num?)?.toInt() ?? 0,
        wins: (j['wins'] as num?)?.toInt() ?? 0,
        draws: (j['draws'] as num?)?.toInt() ?? 0,
        losses: (j['losses'] as num?)?.toInt() ?? 0,
      );
}

/// A team-against-team match of a championship ("incontro").
class Fixture {
  const Fixture({
    required this.giornata,
    required this.home,
    required this.away,
    this.date,
    this.homeScore,
    this.awayScore,
    this.matchId,
  });

  /// Round number; return-leg rounds continue the count (8, 9, ...).
  final int giornata;
  final String home;
  final String away;

  /// Day and start time, when published.
  final DateTime? date;

  /// Individual games won by each team (e.g. 6–1); null until played.
  final int? homeScore;
  final int? awayScore;

  /// FITeT match id (the INCONTRO= number).
  final String? matchId;

  bool get played => homeScore != null && awayScore != null;

  Fixture withGiornata(int g) => Fixture(
        giornata: g,
        home: home,
        away: away,
        date: date,
        homeScore: homeScore,
        awayScore: awayScore,
        matchId: matchId,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'g': giornata,
        'home': home,
        'away': away,
        'date': date?.toIso8601String(),
        'hs': homeScore,
        'as': awayScore,
        'id': matchId,
      };

  factory Fixture.fromJson(Map<String, dynamic> j) => Fixture(
        giornata: (j['g'] as num).toInt(),
        home: j['home'] as String,
        away: j['away'] as String,
        date: j['date'] == null ? null : DateTime.parse(j['date'] as String),
        homeScore: (j['hs'] as num?)?.toInt(),
        awayScore: (j['as'] as num?)?.toInt(),
        matchId: j['id'] as String?,
      );
}

/// Same team name regardless of case and spacing ("T.T. CRDC  TORINO A").
String teamKey(String s) => s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

class Competition {
  const Competition({
    required this.id,
    required this.name,
    required this.shortName,
    required this.type,
    required this.location,
    required this.date,
    this.subtitle,
    this.roundsPlayed,
    this.roundsTotal,
    this.standings = const <StandingRow>[],
    this.fixtures = const <Fixture>[],
    this.roster = const <String, String>{},
    this.playersCount,
    this.imported = false,
    this.entrants = const <String>[],
    this.fitetKey,
    this.fitetCam,
    this.fitetTeam,
    this.fitetYear,
    this.myTeam,
    this.fitetUpdated,
  });

  final String id;
  final String name;
  final String shortName;
  final CompetitionType type;
  final String location;

  /// Tournament day, or season start for championships.
  final DateTime date;
  final String? subtitle;
  final int? roundsPlayed;
  final int? roundsTotal;
  final List<StandingRow> standings;

  /// All the championship's matches, every team (from the FITeT calendar).
  final List<Fixture> fixtures;

  /// Athletes of [myTeam] who played: FITeT id -> name as FITeT writes it.
  final Map<String, String> roster;
  final int? playersCount;
  final bool imported;

  /// Player ids entered in an upcoming tournament.
  final List<String> entrants;

  /// Identifies the matching FITeT competition, e.g. "fitet:C/2 Gir.D".
  final String? fitetKey;

  /// FITeT championship id (CAM=), team id of your players (SQUADRA=)
  /// and season code (ANNO=, 41 = 2026/27).
  final String? fitetCam;
  final String? fitetTeam;
  final String? fitetYear;

  /// Name of your players' team, as written in the standings.
  final String? myTeam;

  /// Last time standings and fixtures were downloaded.
  final DateTime? fitetUpdated;

  bool get isLeague => type == CompetitionType.league;
  bool get isTournament => type == CompetitionType.tournament;

  /// True for your players' team.
  bool isMine(String team) => myTeam != null && teamKey(team) == teamKey(myTeam!);

  bool isMyRow(StandingRow row) =>
      (fitetTeam != null && row.teamId == fitetTeam) || isMine(row.team);

  /// Your team's match in round [giornata], if known.
  Fixture? myFixture(int? giornata) {
    if (giornata == null) return null;
    for (final f in fixtures) {
      if (f.giornata == giornata && (isMine(f.home) || isMine(f.away))) return f;
    }
    return null;
  }

  Competition copyWith({
    String? subtitle,
    String? fitetCam,
    String? fitetTeam,
    String? fitetYear,
    List<StandingRow>? standings,
    List<Fixture>? fixtures,
    Map<String, String>? roster,
    int? roundsPlayed,
    int? roundsTotal,
    String? myTeam,
    DateTime? fitetUpdated,
  }) =>
      Competition(
        id: id,
        name: name,
        shortName: shortName,
        type: type,
        location: location,
        date: date,
        subtitle: subtitle ?? this.subtitle,
        roundsPlayed: roundsPlayed ?? this.roundsPlayed,
        roundsTotal: roundsTotal ?? this.roundsTotal,
        standings: standings ?? this.standings,
        fixtures: fixtures ?? this.fixtures,
        roster: roster ?? this.roster,
        playersCount: playersCount,
        imported: imported,
        entrants: entrants,
        fitetKey: fitetKey,
        fitetCam: fitetCam ?? this.fitetCam,
        fitetTeam: fitetTeam ?? this.fitetTeam,
        fitetYear: fitetYear ?? this.fitetYear,
        myTeam: myTeam ?? this.myTeam,
        fitetUpdated: fitetUpdated ?? this.fitetUpdated,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'shortName': shortName,
        'type': type.name,
        'location': location,
        'date': date.toIso8601String(),
        'subtitle': subtitle,
        'entrants': entrants,
        'fitetKey': fitetKey,
        'imported': imported,
        'roundsPlayed': roundsPlayed,
        'roundsTotal': roundsTotal,
        'fitetCam': fitetCam,
        'fitetTeam': fitetTeam,
        'fitetYear': fitetYear,
        'myTeam': myTeam,
        'fitetUpdated': fitetUpdated?.toIso8601String(),
        'standings': standings.map((r) => r.toJson()).toList(),
        'fixtures': fixtures.map((f) => f.toJson()).toList(),
        'roster': roster,
      };

  factory Competition.fromJson(Map<String, dynamic> j) => Competition(
        id: j['id'] as String,
        name: j['name'] as String,
        shortName: (j['shortName'] as String?) ?? (j['name'] as String),
        type: CompetitionType.values.firstWhere(
          (t) => t.name == j['type'],
          orElse: () => CompetitionType.tournament,
        ),
        location: (j['location'] as String?) ?? '',
        date: DateTime.parse(j['date'] as String),
        subtitle: j['subtitle'] as String?,
        entrants: ((j['entrants'] as List<dynamic>?) ?? const <dynamic>[])
            .map((e) => e as String)
            .toList(),
        fitetKey: j['fitetKey'] as String?,
        imported: (j['imported'] as bool?) ?? false,
        roundsPlayed: (j['roundsPlayed'] as num?)?.toInt(),
        roundsTotal: (j['roundsTotal'] as num?)?.toInt(),
        fitetCam: j['fitetCam'] as String?,
        fitetTeam: j['fitetTeam'] as String?,
        fitetYear: j['fitetYear'] as String?,
        myTeam: j['myTeam'] as String?,
        fitetUpdated:
            j['fitetUpdated'] == null ? null : DateTime.parse(j['fitetUpdated'] as String),
        standings: ((j['standings'] as List<dynamic>?) ?? const <dynamic>[])
            .map((e) => StandingRow.fromJson(e as Map<String, dynamic>))
            .toList(),
        fixtures: ((j['fixtures'] as List<dynamic>?) ?? const <dynamic>[])
            .map((e) => Fixture.fromJson(e as Map<String, dynamic>))
            .toList(),
        roster: ((j['roster'] as Map<String, dynamic>?) ?? const <String, dynamic>{})
            .map((k, v) => MapEntry(k, v as String)),
      );
}

/// Set-by-set scores of a championship game, from the FITeT player detail page.
class LeagueGame {
  const LeagueGame({
    required this.competitionId,
    required this.playerId,
    required this.giornata,
    required this.opponent,
    required this.sets,
  });

  final String competitionId;
  final String playerId;
  final int giornata;
  final String opponent;

  /// From the followed player's side.
  final List<SetScore> sets;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'c': competitionId,
        'p': playerId,
        'g': giornata,
        'o': opponent,
        's': sets.map((s) => <int>[s.mine, s.theirs]).toList(),
      };

  factory LeagueGame.fromJson(Map<String, dynamic> j) => LeagueGame(
        competitionId: j['c'] as String,
        playerId: j['p'] as String,
        giornata: (j['g'] as num).toInt(),
        opponent: j['o'] as String,
        sets: (j['s'] as List<dynamic>).map((s) {
          final pair = s as List<dynamic>;
          return SetScore((pair[0] as num).toInt(), (pair[1] as num).toInt());
        }).toList(),
      );
}

class SetScore {
  const SetScore(this.mine, this.theirs);

  /// Points of the followed player.
  final int mine;

  /// Points of the opponent.
  final int theirs;

  bool get won => mine > theirs;

  @override
  String toString() => '$mine-$theirs';
}

/// Tournament rounds, earliest first.
const List<String> kRounds = <String>[
  'GR', 'R128', 'R64', 'R32', 'R16', 'QF', 'SF', 'F',
];

const Map<String, String> kRoundNames = <String, String>{
  'GR': 'Group stage',
  'R128': 'Round of 128',
  'R64': 'Round of 64',
  'R32': 'Round of 32',
  'R16': 'Round of 16',
  'QF': 'Quarterfinal',
  'SF': 'Semifinal',
  'F': 'Final',
};

class Match {
  const Match({
    required this.id,
    required this.playerId,
    required this.opponent,
    required this.competitionId,
    required this.date,
    required this.sets,
    this.round,
    this.partner,
    this.source,
    this.scoreMine,
    this.scoreTheirs,
    this.event,
    this.giornata,
    this.dateApprox = false,
  });

  final String id;
  final String playerId;
  final String opponent;
  final String competitionId;
  final DateTime date;
  final List<SetScore> sets;

  /// Tournament round (see [kRounds]); null for league or friendly matches.
  final String? round;

  /// Doubles partner's name; null for singles.
  final String? partner;

  bool get isDoubles => partner != null;

  /// Where the match came from: null (entered/built in) or 'fitet'.
  final String? source;

  /// Match score when set-by-set scores aren't known (FITeT imports).
  final int? scoreMine;
  final int? scoreTheirs;

  /// FITeT event, e.g. "Singolo M/F 4^ categoria".
  final String? event;

  /// League round number ("giornata"), when known.
  final int? giornata;

  /// True when [date] is only an estimate (FITeT team rounds have no date).
  final bool dateApprox;

  bool get isFitet => source == 'fitet';

  Match copyWith({List<SetScore>? sets, DateTime? date, bool? dateApprox}) => Match(
        id: id,
        playerId: playerId,
        opponent: opponent,
        competitionId: competitionId,
        date: date ?? this.date,
        sets: sets ?? this.sets,
        round: round,
        partner: partner,
        source: source,
        scoreMine: scoreMine,
        scoreTheirs: scoreTheirs,
        event: event,
        giornata: giornata,
        dateApprox: dateApprox ?? this.dateApprox,
      );
  bool get hasSetDetail => sets.isNotEmpty;

  int get setsWon =>
      sets.isEmpty && scoreMine != null ? scoreMine! : sets.where((s) => s.won).length;
  int get setsLost =>
      sets.isEmpty && scoreTheirs != null ? scoreTheirs! : sets.length - sets.where((s) => s.won).length;
  bool get won => setsWon > setsLost;
  int get pointsWon => sets.fold(0, (sum, s) => sum + s.mine);
  int get pointsLost => sets.fold(0, (sum, s) => sum + s.theirs);
  String get score => '$setsWon–$setsLost';
  String get setsText => sets.map((s) => s.toString()).join('   ');

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'playerId': playerId,
        'opponent': opponent,
        'competitionId': competitionId,
        'date': date.toIso8601String(),
        'sets': sets.map((s) => <int>[s.mine, s.theirs]).toList(),
        'round': round,
        'partner': partner,
        'source': source,
        'scoreMine': scoreMine,
        'scoreTheirs': scoreTheirs,
        'event': event,
        'giornata': giornata,
        'dateApprox': dateApprox,
      };

  factory Match.fromJson(Map<String, dynamic> j) => Match(
        id: j['id'] as String,
        playerId: j['playerId'] as String,
        opponent: j['opponent'] as String,
        competitionId: j['competitionId'] as String,
        date: DateTime.parse(j['date'] as String),
        sets: (j['sets'] as List<dynamic>).map((s) {
          final pair = s as List<dynamic>;
          return SetScore((pair[0] as num).toInt(), (pair[1] as num).toInt());
        }).toList(),
        round: j['round'] as String?,
        partner: j['partner'] as String?,
        source: j['source'] as String?,
        scoreMine: (j['scoreMine'] as num?)?.toInt(),
        scoreTheirs: (j['scoreTheirs'] as num?)?.toInt(),
        event: j['event'] as String?,
        giornata: (j['giornata'] as num?)?.toInt(),
        dateApprox: (j['dateApprox'] as bool?) ?? false,
      );
}

class PlayerStats {
  PlayerStats.from(List<Match> matches)
      : played = matches.length,
        wins = matches.where((m) => m.won).length,
        setsWon = matches.fold(0, (sum, m) => sum + m.setsWon),
        setsLost = matches.fold(0, (sum, m) => sum + m.setsLost),
        pointsWon = matches.fold(0, (sum, m) => sum + m.pointsWon),
        pointsLost = matches.fold(0, (sum, m) => sum + m.pointsLost),
        withSetScores = matches.where((m) => m.hasSetDetail).length,
        lastResults = _lastTen(matches);

  final int played;
  final int wins;
  final int setsWon;
  final int setsLost;
  final int pointsWon;
  final int pointsLost;

  /// Matches with set-by-set scores (points are counted only from these).
  final int withSetScores;

  /// Up to 10 most recent results, oldest first (true = win).
  final List<bool> lastResults;

  int get losses => played - wins;
  double get winRate => played == 0 ? 0 : wins / played;
  int get winPct => (winRate * 100).round();
  double get setRate =>
      setsWon + setsLost == 0 ? 0 : setsWon / (setsWon + setsLost);
  int get pointDiff => pointsWon - pointsLost;

  static List<bool> _lastTen(List<Match> matches) {
    final sorted = List<Match>.of(matches)
      ..sort((a, b) => b.date.compareTo(a.date));
    return sorted.take(10).map((m) => m.won).toList().reversed.toList();
  }
}

class MonthBar {
  const MonthBar(this.label, this.wins, this.losses);

  final String label;
  final int wins;
  final int losses;
}
