import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

/// The TT Piciulin monogram: a sharp, italic "TT P" with a white and an
/// orange-red T, an angular P holding a ball, and a tapered stripe below.
class Emblem extends StatelessWidget {
  const Emblem({super.key, this.size = 34});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _EmblemPainter(),
      ),
    );
  }
}

class _EmblemPainter extends CustomPainter {
  static const Color _white = Color(0xFFFFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 48);

    // Sharp tapered stripe under the letters.
    canvas.drawPath(
      Path()
        ..moveTo(3, 43.6)
        ..lineTo(45.5, 38.6)
        ..lineTo(44.6, 41.2)
        ..lineTo(4.6, 45)
        ..close(),
      Paint()..color = AppColors.accent,
    );

    // Italic letters.
    canvas.save();
    canvas.translate(4, 0);
    canvas.skew(math.tan(-12 * math.pi / 180), 0);

    final white = Paint()..color = _white;
    final accent = Paint()..color = AppColors.accent;

    // First T (white): bar with an angled cut, then the stem.
    canvas.drawPath(
      Path()
        ..moveTo(3, 10)
        ..lineTo(18, 10)
        ..lineTo(16.4, 15)
        ..lineTo(3, 15)
        ..close(),
      white,
    );
    canvas.drawRect(const Rect.fromLTWH(7.5, 10, 5, 26), white);

    // Second T (orange-red), stepped down.
    canvas.drawPath(
      Path()
        ..moveTo(12.5, 16.5)
        ..lineTo(27, 16.5)
        ..lineTo(25.4, 21.5)
        ..lineTo(12.5, 21.5)
        ..close(),
      accent,
    );
    canvas.drawRect(const Rect.fromLTWH(16.5, 16.5, 5, 19.5), accent);

    // P: angular bowl with cut corners and an open counter.
    final p = Path()
      ..fillType = PathFillType.evenOdd
      ..moveTo(29.5, 10)
      ..lineTo(40.6, 10)
      ..lineTo(43.8, 13.2)
      ..lineTo(43.8, 22)
      ..lineTo(40.6, 25.2)
      ..lineTo(34.5, 25.2)
      ..lineTo(34.5, 36)
      ..lineTo(29.5, 36)
      ..close()
      ..moveTo(34.5, 14.6)
      ..lineTo(38.4, 14.6)
      ..lineTo(39.3, 15.5)
      ..lineTo(39.3, 19.7)
      ..lineTo(38.4, 20.6)
      ..lineTo(34.5, 20.6)
      ..close();
    canvas.drawPath(p, white);

    // The ball inside the P.
    canvas.drawCircle(const Offset(36.9, 17.6), 1.75, accent);

    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_EmblemPainter old) => false;
}

/// Rounded card with a soft border. Tappable when [onTap] is set.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.color = AppColors.s1,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: shape,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: color,
              borderRadius: shape,
              border: Border.all(color: AppColors.line),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// Round 44×44 icon button with a border, as in the mockup headers.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.color = AppColors.text,
    this.badge = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color color;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.s1,
        shape: const CircleBorder(side: BorderSide(color: AppColors.line)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed ?? () {},
          child: SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Icon(icon, size: 20, color: color),
                if (badge)
                  Positioned(
                    top: 10,
                    right: 11,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.s1, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Header for pushed screens: back button, centered title, optional action.
class DetailHeader extends StatelessWidget {
  const DetailHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: <Widget>[
          CircleIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: AppText.body(size: 15, weight: FontWeight.w700),
            ),
          ),
          trailing ?? const SizedBox(width: 44),
        ],
      ),
    );
  }
}

/// Big screen title with an optional muted line under it.
class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.title, {super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (subtitle != null) ...<Widget>[
          Text(subtitle!,
              style: AppText.body(size: 14, color: AppColors.muted)),
          const SizedBox(height: 4),
        ],
        Text(title, style: AppText.display(size: 30)),
      ],
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.initials,
    this.size = 40,
    this.background = AppColors.accentSoft,
    this.foreground = AppColors.accentText,
    this.ring,
  });

  final String initials;
  final double size;
  final Color background;
  final Color foreground;
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: ring == null ? null : Border.all(color: ring!, width: 2),
      ),
      child: Text(
        initials,
        style: AppText.body(
            size: size * 0.34, weight: FontWeight.w700, color: foreground),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(
    this.label, {
    super.key,
    this.background = AppColors.s2,
    this.foreground = AppColors.muted,
    this.fontSize = 11,
  });

  final String label;
  final Color background;
  final Color foreground;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: AppText.body(
            size: fontSize, weight: FontWeight.w700, color: foreground),
      ),
    );
  }
}

class ResultPill extends StatelessWidget {
  const ResultPill({super.key, required this.won});

  final bool won;

  @override
  Widget build(BuildContext context) {
    return won
        ? const Pill('Won',
            background: AppColors.accentSoft, foreground: AppColors.accentText)
        : const Pill('Lost');
  }
}

/// Placement pill for tournaments; good results get the orange highlight.
class PlacementPill extends StatelessWidget {
  const PlacementPill(this.placement, {super.key});

  final String placement;

  @override
  Widget build(BuildContext context) {
    const highlight = <String>{'Winner', 'Final', 'Semifinal'};
    final top = highlight.contains(placement);
    return Pill(
      placement,
      fontSize: 12,
      background: top ? AppColors.accentSoft : AppColors.s2,
      foreground: top ? AppColors.accentText : AppColors.muted,
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.action,
    this.onAction,
    this.trailingText,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;
  final String? trailingText;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(title,
                style: AppText.display(size: 19, weight: FontWeight.w600)),
          ),
          if (trailingText != null)
            Text(trailingText!,
                style: AppText.body(
                    size: 13, weight: FontWeight.w600, color: AppColors.muted)),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accentText,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(44, 40),
              ),
              child: Text(action!,
                  style: AppText.body(
                      size: 14,
                      weight: FontWeight.w600,
                      color: AppColors.accentText)),
            ),
        ],
      ),
    );
  }
}

/// Pill-shaped segmented control ("6 months | This season | All time").
class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.s2,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: <Widget>[
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == index,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == index ? AppColors.s1 : Colors.transparent,
                      borderRadius: BorderRadius.circular(19),
                    ),
                    child: Text(
                      labels[i],
                      style: AppText.body(
                        size: 13,
                        weight: i == index ? FontWeight.w700 : FontWeight.w600,
                        color: i == index ? AppColors.text : AppColors.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value, this.height = 6});

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: AppColors.s2,
        color: AppColors.accent,
      ),
    );
  }
}

/// Calendar-style date tile ("OCT / 18").
class DateTile extends StatelessWidget {
  const DateTile({super.key, required this.date, this.size = 54, this.highlight = false});

  final DateTime date;
  final double size;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final fg = highlight ? AppColors.accentText : AppColors.text;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: highlight ? AppColors.accentSoft : AppColors.s1,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: highlight ? null : Border.all(color: AppColors.line),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            monthShort(date.month).toUpperCase(),
            style: AppText.body(
              size: 11,
              weight: FontWeight.w700,
              color: highlight ? AppColors.accentText : AppColors.muted,
            ),
          ),
          Text('${date.day}', style: AppText.display(size: size * 0.41, color: fg)),
        ],
      ),
    );
  }
}

/// Donut chart showing a win rate.
class WinRing extends StatelessWidget {
  const WinRing({super.key, required this.rate, this.size = 96});

  final double rate;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Win rate ${(rate * 100).round()} percent',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(rate),
          child: Center(
            child: ExcludeSemantics(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text('${(rate * 100).round()}%',
                      style: AppText.body(
                          size: 22, weight: FontWeight.w800, height: 1)),
                  Text('win rate',
                      style: AppText.body(
                          size: 11,
                          weight: FontWeight.w600,
                          color: AppColors.muted)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.rate);

  final double rate;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final track = Paint()
      ..color = AppColors.s2
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);
    if (rate > 0) {
      final arc = Paint()
        ..color = AppColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * rate.clamp(0.0, 1.0), false, arc);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.rate != rate;
}

/// Row of small dots for recent form (filled = win, outlined = loss).
class FormDots extends StatelessWidget {
  const FormDots({super.key, required this.results, this.size = 9});

  final List<bool> results;
  final double size;

  @override
  Widget build(BuildContext context) {
    final wins = results.where((r) => r).length;
    return Semantics(
      label: 'Last ${results.length}: $wins wins, ${results.length - wins} losses',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final won in results)
            Container(
              width: size,
              height: size,
              margin: const EdgeInsets.only(left: 3),
              decoration: BoxDecoration(
                color: won ? AppColors.accent : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                    color: won ? AppColors.accent : AppColors.lossBar, width: 1.5),
              ),
            ),
        ],
      ),
    );
  }
}

/// Paired bars per month: wins (blue) and losses (grey).
class MonthChart extends StatelessWidget {
  const MonthChart({super.key, required this.data});

  final List<MonthBar> data;

  @override
  Widget build(BuildContext context) {
    final maxValue = data.fold<int>(
        1, (m, b) => math.max(m, math.max(b.wins, b.losses)));
    Widget bar(int value, Color color) => Container(
          width: 11,
          height: math.max(4.0, 76.0 * value / maxValue),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        for (final b in data)
          Semantics(
            label: '${b.label}: ${b.wins} won, ${b.losses} lost',
            child: Column(
              children: <Widget>[
                SizedBox(
                  height: 80,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      bar(b.wins, AppColors.accent),
                      const SizedBox(width: 3),
                      bar(b.losses, AppColors.lossBar),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(b.label,
                    style: AppText.body(
                        size: 11,
                        weight: FontWeight.w600,
                        color: AppColors.muted)),
              ],
            ),
          ),
      ],
    );
  }
}

class LegendDot extends StatelessWidget {
  const LegendDot({super.key, required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: AppText.body(
                size: 12, weight: FontWeight.w600, color: AppColors.muted)),
      ],
    );
  }
}

/// One match result row. Shows the player (Home) or the date (Player page).
class MatchTile extends StatelessWidget {
  const MatchTile({
    super.key,
    required this.match,
    this.showPlayer = true,
    this.showDivider = false,
    this.onTap,
    this.onLongPress,
  });

  final Match match;
  final bool showPlayer;
  final bool showDivider;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final player = state.player(match.playerId);
    final comp = state.competition(match.competitionId);
    final title = showPlayer ? player.name : 'vs ${match.opponent}';
    final doubles = match.isDoubles ? 'Doubles with ${match.partner} · ' : '';
    final when = match.dateApprox && match.giornata != null
        ? 'Giornata ${match.giornata}'
        : shortDate(match.date);
    final subtitle = showPlayer
        ? '${doubles}vs ${match.opponent} · ${comp.shortName}'
        : '$doubles${comp.shortName} · $when';
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(top: BorderSide(color: AppColors.line))
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: <Widget>[
            if (showPlayer) ...<Widget>[
              Avatar(initials: player.initials),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(size: 15, weight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(size: 13, color: AppColors.muted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(match.score,
                    style: AppText.body(size: 17, weight: FontWeight.w800)),
                const SizedBox(height: 3),
                ResultPill(won: match.won),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Generic list row used for events and competitions.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.showDivider = false,
    this.onTap,
    this.highlighted = false,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool showDivider;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: highlighted ? AppColors.s2 : null,
          border: showDivider
              ? const Border(top: BorderSide(color: AppColors.line))
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: <Widget>[
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(size: 15, weight: FontWeight.w700)),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body(size: 13, color: AppColors.muted)),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...<Widget>[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Round icon used as the leading element of competition rows.
class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, this.color = AppColors.accentText});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(color: AppColors.s2, shape: BoxShape.circle),
      child: Icon(icon, size: 20, color: color),
    );
  }
}

class EmptyNote extends StatelessWidget {
  const EmptyNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Text(text,
          style: AppText.body(size: 14, color: AppColors.muted, height: 1.4)),
    );
  }
}

/// Asks for confirmation, then deletes a match.
Future<void> confirmDeleteMatch(BuildContext context, Match match) async {
  final state = AppScope.of(context);
  final player = state.player(match.playerId);
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.s1,
      title: Text('Delete match?', style: AppText.display(size: 20)),
      content: Text(
        '${player.name} vs ${match.opponent}, ${match.score} on ${shortDate(match.date)}.',
        style: AppText.body(size: 14, color: AppColors.muted, height: 1.4),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Cancel', style: AppText.body(size: 14, weight: FontWeight.w600)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('Delete',
              style: AppText.body(
                  size: 14, weight: FontWeight.w700, color: const Color(0xFFFF8A80))),
        ),
      ],
    ),
  );
  if (ok == true) state.deleteMatch(match.id);
}

/// "FITeT · updated 5 min ago" line with a refresh button (or progress/error).
class FitetStatusLine extends StatelessWidget {
  const FitetStatusLine({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (state.fitetLinkedCount == 0) return const SizedBox.shrink();
    final last = state.lastFitetSync;
    final String text;
    Color color = AppColors.muted;
    if (state.fitetSyncing) {
      text = state.fitetStatus == null
          ? 'Updating from FITeT…'
          : 'Updating from FITeT · ${state.fitetStatus}…';
    } else if (state.fitetError != null) {
      text = '${state.fitetError} · tap to retry';
      color = AppColors.accentText;
    } else if (last == null) {
      text = 'FITeT results not loaded yet';
    } else {
      text = 'FITeT · updated ${_ago(last)}';
    }
    return Semantics(
      button: !state.fitetSyncing,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: state.fitetSyncing ? null : () => state.syncFitet(force: true),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: <Widget>[
              if (state.fitetSyncing)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                )
              else
                Icon(Icons.sync_rounded, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(text,
                    style: AppText.body(size: 13, weight: FontWeight.w600, color: color)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return shortDate(t);
  }
}

void showSoon(BuildContext context, String what) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$what is coming soon')));
}
