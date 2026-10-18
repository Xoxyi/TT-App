import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../widgets/common.dart';
import 'navigation.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final matches = state.matches;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: <Widget>[
            const DetailHeader(title: 'All results'),
            const SizedBox(height: 16),
            Panel(
              padding: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  for (var i = 0; i < matches.length; i++)
                    MatchTile(
                      match: matches[i],
                      showDivider: i > 0,
                      onTap: () => openPlayer(context, matches[i].playerId),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
