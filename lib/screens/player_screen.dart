import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'navigation.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.playerId});

  final String playerId;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  int _period = 0; // 0 = 6 months, 1 = this season, 2 = all time

  DateTime? _since(DateTime now) => switch (_period) {
        0 => now.subtract(const Duration(days: 182)),
        1 => seasonStart(now),
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = state.player(widget.playerId);
    final now = DateTime.now();
    final st = state.stats(p.id, since: _since(now));
    final months = state.monthly(p.id);
    final comps = state.competitionsFor(p.id);
    final latest = state.matchesFor(p.id).take(8).toList();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: <Widget>[
            DetailHeader(
              title: 'Player',
              trailing: state.isAddedPlayer(p.id)
                  ? CircleIconButton(
                      icon: Icons.person_remove_alt_1_rounded,
                      tooltip: 'Stop following',
                      onPressed: () => _confirmRemove(context, p),
                    )
                  : const CircleIconButton(
                      icon: Icons.star_rounded,
                      tooltip: 'Following',
                      color: AppColors.accent,
                    ),
            ),
            const SizedBox(height: 16),
            _ProfileCard(player: p),
            const SizedBox(height: 10),
            _FitetLink(player: p),
            const SizedBox(height: 14),
            SegmentedTabs(
              labels: const <String>['6 months', 'This season', 'All time'],
              index: _period,
              onChanged: (i) => setState(() => _period = i),
            ),
            const SizedBox(height: 14),
            Panel(
              child: Row(
                children: <Widget>[
                  WinRing(rate: st.winRate),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      children: <Widget>[
                        _CountRow(label: 'Wins', value: st.wins, color: AppColors.accent),
                        const SizedBox(height: 10),
                        _CountRow(label: 'Losses', value: st.losses, color: AppColors.lossBar),
                        const SizedBox(height: 10),
                        const Divider(height: 1, color: AppColors.line),
                        const SizedBox(height: 10),
                        Row(
                          children: <Widget>[
                            Text('Last ${st.lastResults.length}',
                                style: AppText.body(
                                    size: 13, weight: FontWeight.w600, color: AppColors.muted)),
                            const Spacer(),
                            FormDots(results: st.lastResults),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: _StatTile(
                    label: 'Sets',
                    value: '${st.setsWon}–${st.setsLost}',
                    note: '${(st.setRate * 100).toStringAsFixed(1)}% won',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(
                    label: 'Points',
                    value: '${st.pointsWon}–${st.pointsLost}',
                    note: st.withSetScores < st.played
                        ? '${st.pointDiff >= 0 ? '+' : ''}${st.pointDiff} · ${st.withSetScores} of ${st.played} matches'
                        : '${st.pointDiff >= 0 ? '+' : ''}${st.pointDiff} difference',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Panel(
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text('Matches by month',
                            style: AppText.display(size: 17, weight: FontWeight.w600)),
                      ),
                      const LegendDot(color: AppColors.accent, label: 'Won'),
                      const SizedBox(width: 12),
                      const LegendDot(color: AppColors.lossBar, label: 'Lost'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  MonthChart(data: months),
                ],
              ),
            ),
            if (comps.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              const SectionHeader('Championships & tournaments'),
              const SizedBox(height: 4),
              Panel(
                padding: EdgeInsets.zero,
                child: Column(
                  children: <Widget>[
                    for (var i = 0; i < comps.length; i++)
                      _CompetitionRow(
                        playerId: p.id,
                        competition: comps[i],
                        showDivider: i > 0,
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            SectionHeader('Latest matches',
                action: 'Add', onAction: () => openAddMatch(context, playerId: p.id)),
            const SizedBox(height: 4),
            if (latest.isEmpty)
              EmptyNote('No matches for ${p.shortName} yet. Tap Add to enter the first one.')
            else ...<Widget>[
              Panel(
                padding: EdgeInsets.zero,
                child: Column(
                  children: <Widget>[
                    for (var i = 0; i < latest.length; i++)
                      MatchTile(
                        match: latest[i],
                        showPlayer: false,
                        showDivider: i > 0,
                        onLongPress: () => confirmDeleteMatch(context, latest[i]),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text('Press and hold a match to delete it.',
                  textAlign: TextAlign.center,
                  style: AppText.body(size: 12, color: AppColors.muted)),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> _confirmRemove(BuildContext context, Player p) async {
  final state = AppScope.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.s1,
      title: Text('Stop following ${p.shortName}?', style: AppText.display(size: 20)),
      content: Text('${p.name} and all their matches will be removed from the app.',
          style: AppText.body(size: 14, color: AppColors.muted, height: 1.4)),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Cancel', style: AppText.body(size: 14, weight: FontWeight.w600)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('Remove',
              style: AppText.body(
                  size: 14, weight: FontWeight.w700, color: const Color(0xFFFF8A80))),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  Navigator.of(context).pop();
  state.removePlayer(p.id);
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    final subtitle = <String>[
      if (player.country != null) player.country!,
      if (player.age != null) '${player.age} years',
      '${player.hand} ${(player.style ?? 'player').toLowerCase()}',
    ].join(' · ');
    return Panel(
      radius: 22,
      padding: EdgeInsets.zero,
      child: Stack(
        children: <Widget>[
          const Positioned(
            right: -30,
            top: -22,
            child: Opacity(
              opacity: 0.09,
              child: Emblem(size: 150),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: <Widget>[
                Avatar(initials: player.initials, size: 62),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(player.name, style: AppText.display(size: 25)),
                      const SizedBox(height: 6),
                      Text(subtitle, style: AppText.body(size: 14, color: AppColors.muted)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: <Widget>[
                          if (player.nickname != null)
                            Pill('“${player.nickname}”',
                                fontSize: 12,
                                background: AppColors.accentSoft,
                                foreground: AppColors.accentText),
                          if (player.worldRank != null)
                            Pill('World #${player.worldRank}',
                                fontSize: 12,
                                background: AppColors.accentSoft,
                                foreground: AppColors.accentText),
                          if (player.style != null) Pill(player.style!, fontSize: 12),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows the player's FITeT athlete id and lets you set or change it.
class _FitetLink extends StatelessWidget {
  const _FitetLink({required this.player});

  final Player player;

  Future<void> _edit(BuildContext context) async {
    final state = AppScope.of(context);
    final controller = TextEditingController(text: state.fitetIdOf(player.id) ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.s1,
        title: Text('FITeT athlete ID', style: AppText.display(size: 20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Open ${player.shortName}’s card on portale.fitet.org: the ID is the '
              'number after ATLETA= in the address (e.g. 792524). Leave empty to unlink.',
              style: AppText.body(size: 13, color: AppColors.muted, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              style: AppText.body(size: 16),
              decoration: InputDecoration(
                hintText: 'ATLETA number',
                filled: true,
                fillColor: AppColors.bg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: AppText.body(size: 14, weight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text('Save',
                style: AppText.body(size: 14, weight: FontWeight.w700, color: AppColors.accentText)),
          ),
        ],
      ),
    );
    if (result == null) return;
    await state.setFitetId(player.id, result.replaceAll(RegExp(r'[^0-9]'), ''));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final id = state.fitetIdOf(player.id);
    final fitetCount = state.matchesFor(player.id).where((m) => m.isFitet).length;
    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      onTap: () => _edit(context),
      child: Row(
        children: <Widget>[
          const Icon(Icons.link_rounded, size: 20, color: AppColors.accentText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              id == null
                  ? (state.fitetLookupFailed(player.id)
                      ? 'Not found on FITeT automatically · link it'
                      : 'Link FITeT profile to import matches')
                  : 'FITeT ID $id · $fitetCount matches imported',
              style: AppText.body(size: 14, weight: FontWeight.w600),
            ),
          ),
          Text(id == null ? 'Link' : 'Edit',
              style: AppText.body(size: 14, weight: FontWeight.w700, color: AppColors.accentText)),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

class _CountRow extends StatelessWidget {
  const _CountRow({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: AppText.body(size: 14, weight: FontWeight.w600)),
        const Spacer(),
        Text('$value', style: AppText.body(size: 18, weight: FontWeight.w800)),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.note});

  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label,
              style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.muted)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: AppText.body(size: 22, weight: FontWeight.w800)),
          ),
          const SizedBox(height: 2),
          Text(note,
              style: AppText.body(
                  size: 12, weight: FontWeight.w700, color: AppColors.accentText)),
        ],
      ),
    );
  }
}

class _CompetitionRow extends StatelessWidget {
  const _CompetitionRow({
    required this.playerId,
    required this.competition,
    required this.showDivider,
  });

  final String playerId;
  final Competition competition;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final Widget trailing;
    final String subtitle;
    if (competition.isTournament) {
      final place = state.placement(playerId, competition.id);
      trailing = place == null ? const SizedBox.shrink() : PlacementPill(place);
      subtitle = 'Tournament · ${shortDate(competition.date)}';
    } else {
      final st = state.statsIn(competition.id, playerId);
      trailing = Text('${st.wins}–${st.losses}',
          style: AppText.body(size: 14, weight: FontWeight.w700));
      subtitle = competition.subtitle ?? 'Championship';
    }
    return ListRow(
      leading: IconBadge(competition.isTournament
          ? Icons.emoji_events_outlined
          : Icons.format_list_numbered_rounded),
      title: competition.name,
      subtitle: subtitle,
      trailing: trailing,
      showDivider: showDivider,
      onTap: () => openCompetition(context, competition),
    );
  }
}
