import 'package:flutter/material.dart';

import '../models/models.dart';
import 'add_match_screen.dart';
import 'add_player_screen.dart';
import 'championship_screen.dart';
import 'player_screen.dart';
import 'results_screen.dart';
import 'tournament_screen.dart';

void openPlayer(BuildContext context, String playerId) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => PlayerScreen(playerId: playerId),
  ));
}

void openCompetition(BuildContext context, Competition competition) {
  final Widget? screen = switch (competition.type) {
    CompetitionType.league => ChampionshipScreen(competitionId: competition.id),
    CompetitionType.tournament => TournamentScreen(competitionId: competition.id),
    CompetitionType.friendly => null,
  };
  if (screen == null) return;
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
}

void openResults(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => const ResultsScreen(),
  ));
}

void openAddMatch(BuildContext context, {String? playerId}) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => AddMatchScreen(initialPlayerId: playerId),
  ));
}

void openAddPlayer(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => const AddPlayerScreen(),
  ));
}
