import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'navigation.dart';

class ChampionshipScreen extends StatefulWidget {
  const ChampionshipScreen({super.key, required this.competitionId});

  final String competitionId;

  @override
  State<ChampionshipScreen> createState() => _ChampionshipScreenState();
}

class _ChampionshipScreenState extends State<ChampionshipScreen> {
  int _tab = 0; // 0 standings, 1 fixtures, 2 players
  bool _allTeams = false;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final c = state.competition(widget.competitionId);
    final info = <String>[
      if (c.subtitle != null) c.subtitle!,
      if (c.roundsPlayed != null && c.roundsTotal != null)
        'Round ${c.roundsPlayed} of ${c.roundsTotal}',
    ].join(' · ');
    final canSync = c.fitetCam != null;

    final List<Widget> body = switch (_tab) {
      0 => <Widget>[
          if (c.standings.isEmpty)
            EmptyNote(canSync
                ? 'Standings will appear after the next FITeT update. Tap the update button above.'
                : 'No standings for this championship yet.')
          else
            _StandingsTable(competition: c),
          const SizedBox(height: 16),
          const SectionHeader('Your players here'),
          const SizedBox(height: 4),
          _PlayerRecords(competitionId: c.id),
        ],
      1 => <Widget>[
          if (c.fixtures.isEmpty)
            EmptyNote(canSync
                ? 'Fixtures will appear after the next FITeT update.'
                : 'No fixtures for this championship.')
          else ...<Widget>[
            if (c.myTeam != null) ...<Widget>[
              SegmentedTabs(
                labels: <String>[c.myTeam!, 'All teams'],
                index: _allTeams ? 1 : 0,
                onChanged: (i) => setState(() => _allTeams = i == 1),
              ),
              const SizedBox(height: 12),
            ],
            _FixtureList(competition: c, onlyMine: c.myTeam != null && !_allTeams),
          ],
        ],
      _ => <Widget>[
          _PlayerRecords(competitionId: c.id),
          const SizedBox(height: 16),
          const SectionHeader('Your players’ matches'),
          const SizedBox(height: 4),
          _OurMatches(competitionId: c.id),
        ],
    };

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: AppColors.s1,
          onRefresh: () => state.syncFitet(force: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: <Widget>[
              DetailHeader(
                title: 'Championship',
                trailing: CircleIconButton(
                  icon: Icons.sync_rounded,
                  tooltip: 'Update results',
                  color: state.fitetSyncing ? AppColors.muted : AppColors.text,
                  onPressed: state.fitetSyncing ? null : () => state.syncFitet(force: true),
                ),
              ),
              const SizedBox(height: 16),
              if (info.isNotEmpty) ...<Widget>[
                Text(info,
                    style: AppText.body(
                        size: 13, weight: FontWeight.w600, color: AppColors.muted)),
                const SizedBox(height: 4),
              ],
              Text(c.name, style: AppText.display(size: 28)),
              if (canSync) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  state.fitetSyncing
                      ? 'Updating from FITeT…'
                      : c.fitetUpdated == null
                          ? 'Not updated from FITeT yet'
                          : 'FITeT · updated ${shortDate(c.fitetUpdated!)} at ${clock(c.fitetUpdated!)}',
                  style: AppText.body(size: 12, color: AppColors.muted),
                ),
              ],
              if (!canSync) ...<Widget>[
                const SizedBox(height: 12),
                Panel(
                  padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                  onTap: state.fitetSyncing ? null : () => _link(context, c),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.link_rounded, size: 20, color: AppColors.accentText),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('Link to FITeT for standings and fixtures',
                            style: AppText.body(size: 14, weight: FontWeight.w600)),
                      ),
                      Text('Link',
                          style: AppText.body(
                              size: 14, weight: FontWeight.w700, color: AppColors.accentText)),
                      const SizedBox(width: 6),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              SegmentedTabs(
                labels: const <String>['Standings', 'Fixtures', 'Players'],
                index: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
              const SizedBox(height: 14),
              ...body,
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks for a FITeT championship address (or CAM number) and links it.
Future<void> _link(BuildContext context, Competition c) async {
  final state = AppScope.of(context);
  final controller = TextEditingController();
  final input = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.s1,
      title: Text('Link to FITeT', style: AppText.display(size: 20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Open the championship on portale.fitet.org (e.g. its standings) and '
            'paste the address here. It contains CAM= followed by a number.',
            style: AppText.body(size: 13, color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            style: AppText.body(size: 15),
            decoration: InputDecoration(
              hintText: '…classifica_squadre.php?CAM=204',
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
          child: Text('Link',
              style: AppText.body(size: 14, weight: FontWeight.w700, color: AppColors.accentText)),
        ),
      ],
    ),
  );
  if (input == null || input.trim().isEmpty || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final error = await state.linkChampionship(c.id, input);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(error ?? 'Linked to FITeT')));
}

class _StandingsTable extends StatelessWidget {
  const _StandingsTable({required this.competition});

  final Competition competition;

  static const double _num = 28;

  @override
  Widget build(BuildContext context) {
    final rows = competition.standings;
    final showDraws = rows.any((r) => r.draws > 0);
    final header = AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.muted);
    Widget cell(String text, TextStyle style) =>
        SizedBox(width: _num, child: Text(text, textAlign: TextAlign.right, style: style));

    return Panel(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: Row(
              children: <Widget>[
                SizedBox(width: 34, child: Text('#', style: header)),
                Expanded(child: Text('Team', style: header)),
                cell('P', header),
                cell('W', header),
                if (showDraws) cell('D', header),
                cell('L', header),
                SizedBox(width: 38, child: Text('Pts', textAlign: TextAlign.right, style: header)),
              ],
            ),
          ),
          for (var i = 0; i < rows.length; i++)
            Builder(builder: (context) {
              final r = rows[i];
              final mine = competition.isMyRow(r);
              return Container(
                decoration: BoxDecoration(
                  color: mine ? AppColors.accentSoft : null,
                  border: const Border(top: BorderSide(color: AppColors.line)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: 34,
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 4,
                            height: 16,
                            decoration: BoxDecoration(
                              color: i < 2 ? AppColors.accent : Colors.transparent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('${i + 1}',
                              style: AppText.body(size: 14, weight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Text(
                        r.team,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body(
                          size: 14,
                          weight: mine ? FontWeight.w800 : FontWeight.w600,
                          color: mine ? AppColors.accentText : AppColors.text,
                        ),
                      ),
                    ),
                    cell('${r.played}', AppText.body(size: 14, color: AppColors.muted)),
                    cell('${r.wins}', AppText.body(size: 14)),
                    if (showDraws) cell('${r.draws}', AppText.body(size: 14)),
                    cell('${r.losses}', AppText.body(size: 14)),
                    SizedBox(
                      width: 38,
                      child: Text(
                        '${r.points}',
                        textAlign: TextAlign.right,
                        style: AppText.body(
                          size: 14,
                          weight: FontWeight.w800,
                          color: mine ? AppColors.accentText : AppColors.text,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: <Widget>[
                Container(
                  width: 4,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Text('Top 2', style: header),
                const SizedBox(width: 16),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: AppColors.accent),
                  ),
                ),
                const SizedBox(width: 6),
                Text('Your players’ team', style: header),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// All fixtures by round, like a scoreboard: home team above, away below.
class _FixtureList extends StatelessWidget {
  const _FixtureList({required this.competition, required this.onlyMine});

  final Competition competition;
  final bool onlyMine;

  @override
  Widget build(BuildContext context) {
    final c = competition;
    final byRound = <int, List<Fixture>>{};
    for (final f in c.fixtures) {
      if (onlyMine && !c.isMine(f.home) && !c.isMine(f.away)) continue;
      byRound.putIfAbsent(f.giornata, () => <Fixture>[]).add(f);
    }
    final rounds = byRound.keys.toList()..sort();
    if (rounds.isEmpty) return const EmptyNote('No fixtures to show.');
    final firstLeg = c.fixtures.fold<int>(0, (m, f) => f.giornata > m ? f.giornata : m) ~/ 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final g in rounds) ...<Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
            child: Row(
              children: <Widget>[
                Text('Giornata $g',
                    style: AppText.body(size: 14, weight: FontWeight.w800)),
                if (firstLeg > 0 && g > firstLeg)
                  Text('  · return leg',
                      style: AppText.body(size: 12, color: AppColors.muted)),
                const Spacer(),
                if (byRound[g]!.first.date != null)
                  Text(dayDate(byRound[g]!.first.date!),
                      style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.muted)),
              ],
            ),
          ),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                for (var i = 0; i < byRound[g]!.length; i++)
                  _FixtureRow(competition: c, fixture: byRound[g]![i], showDivider: i > 0),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _FixtureRow extends StatelessWidget {
  const _FixtureRow({required this.competition, required this.fixture, required this.showDivider});

  final Competition competition;
  final Fixture fixture;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final f = fixture;
    final d = f.date;
    Widget team(String name, int? score, int? other) {
      final mine = competition.isMine(name);
      final won = score != null && other != null && score > other;
      return Row(
        children: <Widget>[
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(
                size: 14,
                weight: mine || won ? FontWeight.w800 : FontWeight.w500,
                color: mine ? AppColors.accentText : (f.played && !won ? AppColors.muted : AppColors.text),
              ),
            ),
          ),
          SizedBox(
            width: 26,
            child: Text(
              score == null ? '–' : '$score',
              textAlign: TextAlign.right,
              style: AppText.body(
                size: 15,
                weight: won ? FontWeight.w800 : FontWeight.w600,
                color: score == null ? AppColors.muted : (won ? AppColors.text : AppColors.muted),
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: showDivider ? const Border(top: BorderSide(color: AppColors.line)) : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(d == null ? '–' : shortDate(d),
                    style: AppText.body(size: 12, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(d == null || (d.hour == 0 && d.minute == 0) ? '' : clock(d),
                    style: AppText.body(size: 12, color: AppColors.muted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              children: <Widget>[
                team(f.home, f.homeScore, f.awayScore),
                const SizedBox(height: 4),
                team(f.away, f.awayScore, f.homeScore),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerRecords extends StatelessWidget {
  const _PlayerRecords({required this.competitionId});

  final String competitionId;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final players = state.playersIn(competitionId);
    if (players.isEmpty) {
      return const EmptyNote('None of your players has played here yet.');
    }
    return Panel(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          for (var i = 0; i < players.length; i++)
            Builder(builder: (context) {
              final p = players[i];
              final st = state.statsIn(competitionId, p.id);
              return InkWell(
                onTap: () => openPlayer(context, p.id),
                child: Container(
                  decoration: BoxDecoration(
                    border: i > 0
                        ? const Border(top: BorderSide(color: AppColors.line))
                        : null,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  child: Row(
                    children: <Widget>[
                      Avatar(initials: p.initials, size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(p.name,
                                      style: AppText.body(size: 15, weight: FontWeight.w700)),
                                ),
                                Text('${st.wins}–${st.losses}',
                                    style: AppText.body(size: 14, weight: FontWeight.w700)),
                                Text(' · ${st.winPct}%',
                                    style: AppText.body(size: 14, color: AppColors.muted)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ProgressBar(value: st.winRate),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// Matches of the players you follow in this championship.
class _OurMatches extends StatelessWidget {
  const _OurMatches({required this.competitionId});

  final String competitionId;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final matches = state.matchesIn(competitionId);
    if (matches.isEmpty) {
      return const EmptyNote('No matches recorded for this championship yet.');
    }
    return Panel(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          for (var i = 0; i < matches.length; i++)
            MatchTile(
              match: matches[i],
              showDivider: i > 0,
              onTap: () => openPlayer(context, matches[i].playerId),
              onLongPress: () => confirmDeleteMatch(context, matches[i]),
            ),
        ],
      ),
    );
  }
}
