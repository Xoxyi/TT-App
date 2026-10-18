import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'events_screen.dart';
import 'home_screen.dart';
import 'navigation.dart';
import 'players_screen.dart';
import 'stats_screen.dart';

/// Main screen with the bottom bar: Home, Players, (+), Events, Stats.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  void _select(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: <Widget>[
          HomeScreen(onOpenTab: _select),
          const PlayersScreen(),
          const EventsScreen(),
          const StatsScreen(),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        index: _tab,
        onSelect: _select,
        onAdd: () => openAddMatch(context),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.index,
    required this.onSelect,
    required this.onAdd,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.s1,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                selected: index == 0,
                onTap: () => onSelect(0),
              ),
              _NavItem(
                icon: Icons.people_alt_rounded,
                label: 'Players',
                selected: index == 1,
                onTap: () => onSelect(1),
              ),
              Tooltip(
                message: 'Add match',
                child: Material(
                  color: AppColors.accent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onAdd,
                    child: const SizedBox(
                      width: 52,
                      height: 52,
                      child: Icon(Icons.add_rounded,
                          size: 28, color: AppColors.onAccent),
                    ),
                  ),
                ),
              ),
              _NavItem(
                icon: Icons.calendar_month_rounded,
                label: 'Events',
                selected: index == 2,
                onTap: () => onSelect(2),
              ),
              _NavItem(
                icon: Icons.bar_chart_rounded,
                label: 'Stats',
                selected: index == 3,
                onTap: () => onSelect(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accentText : AppColors.muted;
    return Semantics(
      button: true,
      selected: selected,
      child: InkResponse(
        onTap: onTap,
        radius: 32,
        child: SizedBox(
          width: 64,
          height: 56,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 23, color: color),
              const SizedBox(height: 3),
              Text(
                label,
                style: AppText.body(
                  size: 11,
                  weight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
