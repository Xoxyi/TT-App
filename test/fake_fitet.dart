import 'dart:io';

import 'package:table_tennis_app/data/fitet.dart';

/// Answers with saved FITeT pages instead of contacting the portal.
class FakeFitet extends FitetClient {
  FakeFitet({this.searchAnswer = '[]'});

  /// What the athlete search answers (JSON).
  String searchAnswer;

  /// Athlete sheets by athlete id (792524 is the saved one).
  final Map<String, String> sheets = <String, String>{};

  /// Championship header pages by CAM (204 is the saved C/2 one).
  final Map<String, String> headers = <String, String>{};

  /// Number of requests per page kind, e.g. 'matches:792524', 'standings'.
  final Map<String, int> calls = <String, int>{};

  static const Map<String, String> names = <String, String>{
    '792524': 'ZITO ANDREA',
    '762651': 'JAR ISABELLA MARIA',
    '762636': 'JAR ALIN CATALIN',
    '999001': 'PICIULIN GABRIELE',
    '999009': 'ROSSI GABRIELE',
  };

  static String page(String name) => File('test/fitet/$name').readAsStringSync();

  static String emptyMatches(String athlete) =>
      "<html><body><p>Scheda incontri dell'atleta: <b>$athlete</b></p></body></html>";

  static String emptyGames(String athlete) =>
      '<html><body><table><tr><td colspan="15">Squadra: TT.Torino B - - - - Atleta: $athlete</td></tr></table></body></html>';

  int count(String key) => calls[key] ?? 0;

  void _hit(String key) => calls[key] = count(key) + 1;

  @override
  Future<String> fetchMatchesPage(String athleteId) async {
    _hit('matches:$athleteId');
    if (athleteId == '792524') return File('test/fitet_sample.html').readAsStringSync();
    return emptyMatches(names[athleteId] ?? 'SCONOSCIUTO ATLETA');
  }

  @override
  Future<String> fetchStandingsPage(String cam) async {
    _hit('standings');
    return page('standings.html');
  }

  @override
  Future<String> fetchCalendarPage(String cam, String year) async {
    _hit('calendar');
    return page('calendar.html');
  }

  @override
  Future<String> fetchRosterPage(String cam, String team) async {
    _hit('roster');
    return page('roster.html');
  }

  @override
  Future<String> fetchPlayerGamesPage(String cam, String team, String athleteId) async {
    _hit('games:$athleteId');
    if (athleteId == '792524') return page('player_games_792524.html');
    return emptyGames(names[athleteId] ?? 'SCONOSCIUTO ATLETA');
  }

  @override
  Future<String> searchAthletes(String term) async {
    _hit('search');
    return searchAnswer;
  }

  @override
  Future<String> fetchChampionshipHeader(String cam) async {
    _hit('header:$cam');
    return headers[cam] ?? (cam == '204' ? page('header_204.html') : '<html></html>');
  }

  @override
  Future<String> fetchAthleteStatsPage(String cam) async {
    _hit('stats:$cam');
    return page('athlete_stats.html');
  }

  @override
  Future<String> fetchAthleteSheet(String athleteId) async {
    _hit('sheet:$athleteId');
    return sheets[athleteId] ??
        (athleteId == '792524' ? page('athlete_sheet_792524.html') : '<html></html>');
  }
}
