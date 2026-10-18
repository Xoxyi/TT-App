import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'navigation.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final since = DateTime.now().subtract(const Duration(days: 182));
    final rows = <({Player player, PlayerStats stats})>[
      for (final p in state.players) (player: p, stats: state.stats(p.id, since: since)),
    ]..sort((a, b) => b.stats.winRate.compareTo(a.stats.winRate));

    final total = rows.fold<int>(0, (s, r) => s + r.stats.played);
    final wins = rows.fold<int>(0, (s, r) => s + r.stats.wins);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: <Widget>[
          const ScreenTitle('Stats', subtitle: 'Last 6 months'),
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              Expanded(child: _Big(label: 'Matches', value: '$total')),
              const SizedBox(width: 10),
              Expanded(child: _Big(label: 'Wins', value: '$wins', color: AppColors.accentText)),
              const SizedBox(width: 10),
              Expanded(
                child: _Big(
                  label: 'Win rate',
                  value: total == 0 ? '0%' : '${(wins * 100 / total).round()}%',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const SectionHeader('Leaderboard'),
          const SizedBox(height: 4),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                for (var i = 0; i < rows.length; i++)
                  InkWell(
                    onTap: () => openPlayer(context, rows[i].player.id),
                    child: Container(
                      decoration: BoxDecoration(
                        border: i > 0
                            ? const Border(top: BorderSide(color: AppColors.line))
                            : null,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: <Widget>[
                          SizedBox(
                            width: 24,
                            child: Text('${i + 1}',
                                style: AppText.body(
                                  size: 15,
                                  weight: FontWeight.w800,
                                  color: i == 0 ? AppColors.accentText : AppColors.muted,
                                )),
                          ),
                          Avatar(initials: rows[i].player.initials, size: 36),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(rows[i].player.name,
                                          style: AppText.body(
                                              size: 15, weight: FontWeight.w700)),
                                    ),
                                    Text('${rows[i].stats.winPct}%',
                                        style: AppText.body(
                                            size: 15, weight: FontWeight.w800)),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${rows[i].stats.wins}–${rows[i].stats.losses} · sets ${rows[i].stats.setsWon}–${rows[i].stats.setsLost}',
                                  style: AppText.body(size: 12, color: AppColors.muted),
                                ),
                                const SizedBox(height: 8),
                                ProgressBar(value: rows[i].stats.winRate),
                              ],
                            ),
                          ),
                        ],
                      ),
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

class _Big extends StatelessWidget {
  const _Big({required this.label, required this.value, this.color = AppColors.text});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label,
              style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.muted)),
          const SizedBox(height: 2),
          Text(value, style: AppText.body(size: 22, weight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}
