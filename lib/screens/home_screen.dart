import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'navigation.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onOpenTab});

  /// Switches the bottom-bar tab (1 = Players).
  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final now = DateTime.now();
    final week = state.matches
        .where((m) => !m.date.isAfter(now) && now.difference(m.date).inDays < 7)
        .toList();
    final wins = week.where((m) => m.won).length;
    final rate = week.isEmpty ? 0 : (wins * 100 / week.length).round();
    final next = state.nextEvent;
    final nextMatch = state.nextTeamMatch;
    final recent = state.matches.where((m) => !m.date.isAfter(now)).take(3).toList();

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.s1,
        onRefresh: () => state.syncFitet(force: true),
        child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: <Widget>[
          Row(
            children: <Widget>[
              const Emblem(size: 40),
              const SizedBox(width: 8),
              Text.rich(
                TextSpan(
                  children: <TextSpan>[
                    TextSpan(
                      text: 'TT ',
                      style: AppText.display(size: 23, color: AppColors.accentText),
                    ),
                    TextSpan(text: 'Piciulin', style: AppText.display(size: 23)),
                  ],
                ),
              ),
              const Spacer(),
              CircleIconButton(
                icon: Icons.search_rounded,
                tooltip: 'Find a player',
                onPressed: () => onOpenTab(1),
              ),
              const SizedBox(width: 8),
              CircleIconButton(
                icon: Icons.notifications_none_rounded,
                tooltip: 'Notifications',
                badge: true,
                onPressed: () => showSoon(context, 'Notifications'),
              ),
            ],
          ),
          if (!state.persistent) ...<Widget>[
            const SizedBox(height: 14),
            const EmptyNote(
                'Saving isn’t working on this phone, so matches will be lost when the app closes. '
                'Please report this so it can be fixed.'),
          ],
          const SizedBox(height: 20),
          ScreenTitle(greeting(now), subtitle: longDate(now)),
          const SizedBox(height: 10),
          const FitetStatusLine(),
          const SizedBox(height: 14),
          Panel(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            child: IntrinsicHeight(
              child: Row(
                children: <Widget>[
                  _Summary(value: '${week.length}', label: 'matches this week'),
                  const VerticalDivider(color: AppColors.line, width: 1, thickness: 1),
                  _Summary(value: '$wins', label: 'wins', color: AppColors.accentText),
                  const VerticalDivider(color: AppColors.line, width: 1, thickness: 1),
                  _Summary(value: '$rate%', label: 'win rate'),
                ],
              ),
            ),
          ),
          if (nextMatch != null) ...<Widget>[
            const SizedBox(height: 14),
            _NextMatchCard(competition: nextMatch.competition, fixture: nextMatch.fixture),
          ],
          if (next != null) ...<Widget>[
            const SizedBox(height: 14),
            _NextEventCard(competition: next),
          ],
          const SizedBox(height: 16),
          SectionHeader('Recent results',
              action: 'See all', onAction: () => openResults(context)),
          const SizedBox(height: 4),
          if (recent.isEmpty)
            Panel(
              onTap: () => openAddMatch(context),
              child: Row(
                children: <Widget>[
                  const IconBadge(Icons.add_rounded),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No results yet. Tap here or the + button to add your first match.',
                      style: AppText.body(size: 14, color: AppColors.muted, height: 1.4),
                    ),
                  ),
                ],
              ),
            )
          else
            Panel(
              padding: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  for (var i = 0; i < recent.length; i++)
                    MatchTile(
                      match: recent[i],
                      showDivider: i > 0,
                      onTap: () => openPlayer(context, recent[i].playerId),
                      onLongPress: () => confirmDeleteMatch(context, recent[i]),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          SectionHeader('Your players',
              action: 'Manage', onAction: () => onOpenTab(1)),
          const SizedBox(height: 4),
          SizedBox(
            height: 86,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: state.players.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final p = state.players[i];
                final playedThisWeek = week.any((m) => m.playerId == p.id);
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => openPlayer(context, p.id),
                  child: SizedBox(
                    width: 64,
                    child: Column(
                      children: <Widget>[
                        const SizedBox(height: 2),
                        Avatar(
                          initials: p.initials,
                          size: 52,
                          background: AppColors.s1,
                          foreground: AppColors.text,
                          ring: playedThisWeek ? AppColors.accent : AppColors.line,
                        ),
                        const SizedBox(height: 6),
                        Text(p.shortName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body(size: 12, weight: FontWeight.w600)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.value, required this.label, this.color = AppColors.text});

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Text(value, style: AppText.body(size: 24, weight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: AppText.body(size: 12, color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _NextEventCard extends StatelessWidget {
  const _NextEventCard({required this.competition});

  final Competition competition;

  @override
  Widget build(BuildContext context) {
    final entered = competition.entrants.length;
    return Panel(
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
      onTap: () => openCompetition(context, competition),
      child: Row(
        children: <Widget>[
          DateTile(date: competition.date, highlight: true),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Next tournament · ${relativeDay(competition.date)}',
                    style: AppText.body(
                        size: 12, weight: FontWeight.w600, color: AppColors.accentText)),
                const SizedBox(height: 2),
                Text(competition.name,
                    style: AppText.body(size: 17, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '${competition.location} · $entered of your players entered',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(size: 13, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
    );
  }
}

/// Next championship match of your players' team (from the FITeT calendar).
class _NextMatchCard extends StatelessWidget {
  const _NextMatchCard({required this.competition, required this.fixture});

  final Competition competition;
  final Fixture fixture;

  @override
  Widget build(BuildContext context) {
    final d = fixture.date!;
    final home = competition.isMine(fixture.home);
    final opponent = home ? fixture.away : fixture.home;
    final details = <String>[
      competition.shortName,
      'Giornata ${fixture.giornata}',
      if (d.hour != 0 || d.minute != 0) clock(d),
      home ? 'Home' : 'Away',
    ].join(' · ');
    return Panel(
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
      onTap: () => openCompetition(context, competition),
      child: Row(
        children: <Widget>[
          DateTile(date: d, highlight: true),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Next match · ${relativeDay(d)}',
                    style: AppText.body(
                        size: 12, weight: FontWeight.w600, color: AppColors.accentText)),
                const SizedBox(height: 2),
                Text('vs $opponent',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(size: 17, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  details,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(size: 13, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
    );
  }
}
