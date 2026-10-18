import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'navigation.dart';

class TournamentScreen extends StatefulWidget {
  const TournamentScreen({super.key, required this.competitionId});

  final String competitionId;

  @override
  State<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends State<TournamentScreen> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final c = state.competition(widget.competitionId);
    final upcoming = c.date.isAfter(DateTime.now());
    final details = <String>[
      if (c.location.isNotEmpty) c.location,
      'Singles',
      if (c.playersCount != null) '${c.playersCount} players',
    ].join(' · ');

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: <Widget>[
            DetailHeader(
              title: 'Tournament',
              trailing: CircleIconButton(
                icon: Icons.ios_share_rounded,
                tooltip: 'Share',
                onPressed: () => showSoon(context, 'Sharing'),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                DateTile(date: c.date, size: 62, highlight: upcoming),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(c.name, style: AppText.display(size: 28)),
                      const SizedBox(height: 3),
                      Text(details, style: AppText.body(size: 14, color: AppColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
            if (c.imported) ...<Widget>[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.s2,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.sync_rounded, size: 16, color: AppColors.accentText),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Results imported automatically',
                          style: AppText.body(
                              size: 13, weight: FontWeight.w600, color: AppColors.muted)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (upcoming) ..._upcoming(context, state, c) else ..._results(context, state, c),
          ],
        ),
      ),
    );
  }

  List<Widget> _upcoming(BuildContext context, AppState state, Competition c) {
    return <Widget>[
      SectionHeader('Your players entered', trailingText: 'Starts ${relativeDay(c.date)}'),
      const SizedBox(height: 4),
      if (c.entrants.isEmpty)
        const EmptyNote('None of your players has entered yet.')
      else
        Panel(
          padding: EdgeInsets.zero,
          child: Column(
            children: <Widget>[
              for (var i = 0; i < c.entrants.length; i++)
                Builder(builder: (context) {
                  final p = state.player(c.entrants[i]);
                  return ListRow(
                    leading: Avatar(initials: p.initials, size: 36),
                    title: p.name,
                    subtitle: p.nickname ?? p.style,
                    trailing: const Pill('Entered', fontSize: 12),
                    showDivider: i > 0,
                    onTap: () => openPlayer(context, p.id),
                  );
                }),
            ],
          ),
        ),
      const SizedBox(height: 14),
      Text('Results will appear here after the tournament. You can also add them yourself with the + button.',
          style: AppText.body(size: 13, color: AppColors.muted, height: 1.4)),
    ];
  }

  List<Widget> _results(BuildContext context, AppState state, Competition c) {
    final players = state.playersIn(c.id)
      ..sort((a, b) =>
          state.placementRank(b.id, c.id).compareTo(state.placementRank(a.id, c.id)));
    if (players.isEmpty) {
      return const <Widget>[EmptyNote('No results for your players in this tournament.')];
    }
    final selected = players.firstWhere(
      (p) => p.id == _selectedId,
      orElse: () => players.first,
    );
    final run = state.matchesIn(c.id, playerId: selected.id)
      ..sort((a, b) => _roundIndex(a).compareTo(_roundIndex(b)));
    final setsWon = run.fold<int>(0, (s, m) => s + m.setsWon);
    final setsLost = run.fold<int>(0, (s, m) => s + m.setsLost);

    return <Widget>[
      const SectionHeader('How your players did'),
      const SizedBox(height: 4),
      Panel(
        padding: EdgeInsets.zero,
        child: Column(
          children: <Widget>[
            for (var i = 0; i < players.length; i++)
              Builder(builder: (context) {
                final p = players[i];
                final st = state.statsIn(c.id, p.id);
                final place = state.placement(p.id, c.id);
                return ListRow(
                  leading: Avatar(initials: p.initials, size: 36),
                  title: p.name,
                  subtitle:
                      '${st.wins} ${st.wins == 1 ? 'win' : 'wins'} · ${st.losses} ${st.losses == 1 ? 'loss' : 'losses'}',
                  trailing: place == null ? null : PlacementPill(place),
                  highlighted: p.id == selected.id && players.length > 1,
                  showDivider: i > 0,
                  onTap: () => setState(() => _selectedId = p.id),
                );
              }),
          ],
        ),
      ),
      const SizedBox(height: 16),
      SectionHeader('${selected.shortName}’s matches', trailingText: 'Sets $setsWon–$setsLost'),
      const SizedBox(height: 4),
      Panel(
        padding: EdgeInsets.zero,
        child: Column(
          children: <Widget>[
            for (var i = 0; i < run.length; i++) _RoundRow(match: run[i], showDivider: i > 0),
          ],
        ),
      ),
    ];
  }

  static int _roundIndex(Match m) => m.round == null ? -1 : kRounds.indexOf(m.round!);
}

class _RoundRow extends StatelessWidget {
  const _RoundRow({required this.match, required this.showDivider});

  final Match match;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: showDivider ? const Border(top: BorderSide(color: AppColors.line)) : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            padding: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.s2,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(match.round ?? '–',
                textAlign: TextAlign.center,
                style: AppText.body(size: 12, weight: FontWeight.w700, color: AppColors.muted)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('vs ${match.opponent}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(size: 15, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(match.hasSetDetail ? match.setsText : (match.event ?? 'Set scores not available'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(size: 12, color: AppColors.muted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(match.score, style: AppText.body(size: 17, weight: FontWeight.w800)),
              const SizedBox(height: 3),
              ResultPill(won: match.won),
            ],
          ),
        ],
      ),
    );
  }
}
