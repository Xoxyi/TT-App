import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'navigation.dart';

class PlayersScreen extends StatelessWidget {
  const PlayersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final since = DateTime.now().subtract(const Duration(days: 182));
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: ScreenTitle('Players', subtitle: '${state.players.length} players you follow'),
              ),
              CircleIconButton(
                icon: Icons.person_add_alt_1_rounded,
                tooltip: 'Add a player',
                color: AppColors.accentText,
                onPressed: () => openAddPlayer(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          for (final p in state.players) ...<Widget>[
            Builder(builder: (context) {
              final st = state.stats(p.id, since: since);
              return Panel(
                onTap: () => openPlayer(context, p.id),
                child: Row(
                  children: <Widget>[
                    Avatar(initials: p.initials, size: 48),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(p.name,
                                    style: AppText.body(size: 16, weight: FontWeight.w700)),
                              ),
                              Text('${st.winPct}%',
                                  style: AppText.body(size: 16, weight: FontWeight.w800)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                    <String>[
                                      if (p.nickname != null) '“${p.nickname}”',
                                      if (p.worldRank != null) 'World #${p.worldRank}',
                                      if (p.country != null) p.country!,
                                      if (p.style != null) p.style!,
                                    ].join(' · '),
                                    style: AppText.body(size: 13, color: AppColors.muted)),
                              ),
                              Text('${st.wins}–${st.losses}',
                                  style: AppText.body(size: 13, color: AppColors.muted)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ProgressBar(value: st.winRate),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 4),
          Panel(
            onTap: () => openAddPlayer(context),
            child: Row(
              children: <Widget>[
                const IconBadge(Icons.person_search_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Follow another player: search by name on FITeT',
                      style: AppText.body(size: 14, weight: FontWeight.w600)),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text('Win rate over the last 6 months.',
              textAlign: TextAlign.center,
              style: AppText.body(size: 12, color: AppColors.muted)),
        ],
      ),
    );
  }
}
