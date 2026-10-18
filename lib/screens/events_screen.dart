import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'navigation.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final now = DateTime.now();
    final upcoming = state.competitions
        .where((c) => c.isTournament && c.date.isAfter(now))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final leagues = state.competitions.where((c) => c.isLeague).toList();
    final past = state.competitions
        .where((c) => c.isTournament && !c.date.isAfter(now))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: <Widget>[
          const ScreenTitle('Events', subtitle: 'Championships and tournaments'),
          if (upcoming.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            const SectionHeader('Coming up'),
            const SizedBox(height: 4),
            _Group(children: <Widget>[
              for (var i = 0; i < upcoming.length; i++)
                ListRow(
                  leading: DateTile(date: upcoming[i].date, size: 44, highlight: true),
                  title: upcoming[i].name,
                  subtitle: _join(<String>[upcoming[i].location, relativeDay(upcoming[i].date)]),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                  showDivider: i > 0,
                  onTap: () => openCompetition(context, upcoming[i]),
                ),
            ]),
          ],
          const SizedBox(height: 16),
          const SectionHeader('Championships'),
          const SizedBox(height: 4),
          if (leagues.isEmpty)
            const EmptyNote(
                'No championships yet. When you add a match, choose Competition › New competition to create one.')
          else
          _Group(children: <Widget>[
            for (var i = 0; i < leagues.length; i++)
              ListRow(
                leading: const IconBadge(Icons.format_list_numbered_rounded),
                title: leagues[i].name,
                subtitle: _leagueSubtitle(leagues[i]),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                showDivider: i > 0,
                onTap: () => openCompetition(context, leagues[i]),
              ),
          ]),
          const SizedBox(height: 16),
          const SectionHeader('Past tournaments'),
          const SizedBox(height: 4),
          if (past.isEmpty)
            const EmptyNote(
                'No tournaments yet. When you add a match, choose Competition › New competition, e.g. "WTT Champions Frankfurt".')
          else
          _Group(children: <Widget>[
            for (var i = 0; i < past.length; i++)
              ListRow(
                leading: DateTile(date: past[i].date, size: 44),
                title: past[i].name,
                subtitle: _join(<String>[past[i].location, _bestResult(state, past[i])]),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                showDivider: i > 0,
                onTap: () => openCompetition(context, past[i]),
              ),
          ]),
        ],
      ),
    );
  }

  static String _join(List<String> parts) =>
      parts.where((p) => p.trim().isNotEmpty).join(' · ');

  static String _leagueSubtitle(Competition c) {
    final parts = <String>[
      if (c.subtitle != null) c.subtitle!,
      if (c.roundsPlayed != null && c.roundsTotal != null)
        'Round ${c.roundsPlayed} of ${c.roundsTotal}',
    ];
    return parts.join(' · ');
  }

  static String _bestResult(AppState state, Competition c) {
    final players = state.playersIn(c.id);
    if (players.isEmpty) return 'No results yet';
    players.sort((a, b) =>
        state.placementRank(b.id, c.id).compareTo(state.placementRank(a.id, c.id)));
    final best = players.first;
    return '${best.shortName}: ${state.placement(best.id, c.id) ?? 'played'}';
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Panel(padding: EdgeInsets.zero, child: Column(children: children));
  }
}
