import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_state.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

class AddMatchScreen extends StatefulWidget {
  const AddMatchScreen({super.key, this.initialPlayerId});

  final String? initialPlayerId;

  @override
  State<AddMatchScreen> createState() => _AddMatchScreenState();
}

class _AddMatchScreenState extends State<AddMatchScreen> {
  static const int _maxSets = 5;

  int _tab = 0; // 0 manual, 1 import
  String? _playerId;
  String? _competitionId;
  String? _round;
  DateTime _date = DateTime.now();
  final TextEditingController _opponent = TextEditingController();
  final TextEditingController _link = TextEditingController();
  final TextEditingController _newCompetitionName = TextEditingController();
  static const String _newCompetitionKey = '__new__';
  final List<TextEditingController> _mine =
      List<TextEditingController>.generate(_maxSets, (_) => TextEditingController());
  final List<TextEditingController> _theirs =
      List<TextEditingController>.generate(_maxSets, (_) => TextEditingController());

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_playerId == null) {
      final state = AppScope.of(context);
      final p = widget.initialPlayerId != null
          ? state.player(widget.initialPlayerId!)
          : state.players.first;
      _playerId = p.id;
      // Start from the competition used most recently.
      _competitionId =
          state.matches.isEmpty ? kFriendly.id : state.matches.first.competitionId;
    }
  }

  @override
  void dispose() {
    _opponent.dispose();
    _link.dispose();
    _newCompetitionName.dispose();
    for (final c in <TextEditingController>[..._mine, ..._theirs]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Completed sets (both scores filled in and different).
  List<SetScore> get _sets {
    final sets = <SetScore>[];
    for (var i = 0; i < _maxSets; i++) {
      final a = int.tryParse(_mine[i].text);
      final b = int.tryParse(_theirs[i].text);
      if (a != null && b != null && a != b) sets.add(SetScore(a, b));
    }
    return sets;
  }

  /// A valid best-of-five: someone reached 3 sets, and no sets after that.
  bool get _validScore {
    var won = 0;
    var lost = 0;
    for (final s in _sets) {
      if (won == 3 || lost == 3) return false;
      if (s.won) {
        won++;
      } else {
        lost++;
      }
    }
    return won == 3 || lost == 3;
  }

  bool get _canSave => _validScore && _opponent.text.trim().isNotEmpty;

  Future<void> _pick<T>({
    required String title,
    required List<(T, String)> options,
    required ValueChanged<T> onPicked,
  }) async {
    final picked = await showModalBottomSheet<T>(
      context: context,
      backgroundColor: AppColors.s1,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 12),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(title, style: AppText.display(size: 19, weight: FontWeight.w600)),
            ),
            for (final o in options)
              ListTile(
                title: Text(o.$2, style: AppText.body(size: 16, weight: FontWeight.w600)),
                onTap: () => Navigator.of(context).pop(o.$1),
              ),
          ],
        ),
      ),
    );
    if (picked != null) onPicked(picked);
  }

  /// Dialog to create a tournament or championship, then select it.
  Future<void> _createCompetition() async {
    _newCompetitionName.clear();
    var type = CompetitionType.tournament;
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          backgroundColor: AppColors.s1,
          title: Text('New competition', style: AppText.display(size: 20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: _newCompetitionName,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                style: AppText.body(size: 16),
                decoration: _decoration('e.g. WTT Champions Frankfurt'),
              ),
              const SizedBox(height: 12),
              SegmentedTabs(
                labels: const <String>['Tournament', 'Championship'],
                index: type == CompetitionType.tournament ? 0 : 1,
                onChanged: (i) => setDialog(() => type =
                    i == 0 ? CompetitionType.tournament : CompetitionType.league),
              ),
              const SizedBox(height: 10),
              Text('Date: ${fullDate(_date)} (same as the match)',
                  style: AppText.body(size: 12, color: AppColors.muted)),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel', style: AppText.body(size: 14, weight: FontWeight.w600)),
            ),
            TextButton(
              onPressed: () {
                if (_newCompetitionName.text.trim().isNotEmpty) {
                  Navigator.of(context).pop(true);
                }
              },
              child: Text('Create',
                  style: AppText.body(
                      size: 14, weight: FontWeight.w700, color: AppColors.accentText)),
            ),
          ],
        ),
      ),
    );
    final name = _newCompetitionName.text.trim();
    if (created != true || name.isEmpty || !mounted) return;
    final c = AppScope.of(context).addCompetition(name: name, type: type, date: _date);
    setState(() {
      _competitionId = c.id;
      _round = null;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (!mounted || picked == null) return;
    setState(() => _date = picked);
  }

  void _save() {
    final state = AppScope.of(context);
    final comp = state.competition(_competitionId!);
    state.addMatch(
      playerId: _playerId!,
      opponent: _opponent.text.trim(),
      competitionId: comp.id,
      date: DateTime(_date.year, _date.month, _date.day, 20),
      sets: _sets,
      round: comp.isTournament ? _round : null,
    );
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(const SnackBar(content: Text('Match saved')));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final player = state.player(_playerId!);
    final comp = state.competition(_competitionId!);
    final sets = _sets;
    final won = sets.where((s) => s.won).length;
    final lost = sets.length - won;
    final opponentName = _opponent.text.trim().isEmpty ? 'Opponent' : _opponent.text.trim();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: <Widget>[
            SizedBox(
              height: 48,
              child: Row(
                children: <Widget>[
                  CircleIconButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: Text('New match',
                        textAlign: TextAlign.center, style: AppText.display(size: 20)),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SegmentedTabs(
              labels: const <String>['Enter manually', 'Import from link'],
              index: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
            const SizedBox(height: 16),
            if (_tab == 1)
              ..._importTab()
            else ...<Widget>[
              const _Label('Player'),
              _PickerField(
                value: player.name,
                bold: true,
                onTap: () => _pick<String>(
                  title: 'Player',
                  options: <(String, String)>[for (final p in state.players)
                      (p.id, p.nickname == null ? p.name : '${p.name} (${p.nickname})')],
                  onPicked: (id) => setState(() => _playerId = id),
                ),
              ),
              const SizedBox(height: 12),
              const _Label('Opponent'),
              TextField(
                controller: _opponent,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
                style: AppText.body(size: 16),
                decoration: _decoration('Opponent name'),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const _Label('Competition'),
                        _PickerField(
                          value: comp.shortName,
                          onTap: () => _pick<String>(
                            title: 'Competition',
                            options: <(String, String)>[
                              (_newCompetitionKey, '+ New competition'),
                              for (final c in state.competitions.reversed) (c.id, c.name),
                            ],
                            onPicked: (id) {
                              if (id == _newCompetitionKey) {
                                _createCompetition();
                              } else {
                                setState(() {
                                  _competitionId = id;
                                  _round = null;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const _Label('Date'),
                        _PickerField(
                          value: fullDate(_date),
                          icon: Icons.calendar_today_rounded,
                          onTap: _pickDate,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (comp.isTournament) ...<Widget>[
                const SizedBox(height: 12),
                const _Label('Round'),
                _PickerField(
                  value: _round == null ? 'Choose round' : kRoundNames[_round]!,
                  onTap: () => _pick<String>(
                    title: 'Round',
                    options: <(String, String)>[
                      for (final r in kRounds) (r, kRoundNames[r]!),
                    ],
                    onPicked: (r) => setState(() => _round = r),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Panel(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        SizedBox(width: 52, child: _small('Set')),
                        Expanded(child: Center(child: _small(player.lastName))),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Center(
                            child: _small(opponentName, maxLines: 1),
                          ),
                        ),
                      ],
                    ),
                    for (var i = 0; i < _maxSets; i++) ...<Widget>[
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          SizedBox(
                            width: 52,
                            child: Text('Set ${i + 1}',
                                style: AppText.body(
                                    size: 14, weight: FontWeight.w700, color: AppColors.muted)),
                          ),
                          Expanded(child: _setField(i, mine: true)),
                          const SizedBox(width: 10),
                          Expanded(child: _setField(i, mine: false)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _validScore ? AppColors.accentSoft : AppColors.s2,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        _validScore
                            ? (won > lost ? '${player.shortName} wins' : '${player.shortName} loses')
                            : 'Enter the set scores (best of 5)',
                        style: AppText.body(
                          size: 14,
                          weight: FontWeight.w600,
                          color: _validScore ? AppColors.accentText : AppColors.muted,
                        ),
                      ),
                    ),
                    Text('$won–$lost',
                        style: AppText.body(
                          size: 22,
                          weight: FontWeight.w800,
                          color: _validScore ? AppColors.accentText : AppColors.muted,
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: _canSave ? _save : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.onAccent,
                    disabledBackgroundColor: AppColors.s2,
                    disabledForegroundColor: AppColors.muted,
                    shape: const StadiumBorder(),
                  ),
                  child: Text('Save match',
                      style: AppText.body(
                        size: 16,
                        weight: FontWeight.w700,
                        color: _canSave ? AppColors.onAccent : AppColors.muted,
                      )),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _importTab() {
    return <Widget>[
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Row(
              children: <Widget>[
                IconBadge(Icons.link_rounded),
                SizedBox(width: 12),
                Expanded(child: _ImportTitle()),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Automatic import needs permission from the data owner. World Table Tennis '
              'does not allow apps to read its site automatically, so for now enter '
              'results with "Enter manually". Import will be added once official access is granted.',
              style: AppText.body(size: 14, color: AppColors.muted, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _link,
              keyboardType: TextInputType.url,
              style: AppText.body(size: 15),
              decoration: _decoration('https://…'),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () => showSoon(context, 'Importing from a link'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.onAccent,
                  shape: const StadiumBorder(),
                ),
                child: Text('Import results',
                    style: AppText.body(
                        size: 15, weight: FontWeight.w700, color: AppColors.onAccent)),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _setField(int i, {required bool mine}) {
    final a = int.tryParse(_mine[i].text);
    final b = int.tryParse(_theirs[i].text);
    final winner = a != null && b != null && a != b && (mine ? a > b : b > a);
    return SizedBox(
      height: 44,
      child: TextField(
        controller: mine ? _mine[i] : _theirs[i],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(2),
        ],
        onChanged: (_) => setState(() {}),
        style: AppText.body(
          size: 17,
          weight: FontWeight.w800,
          color: winner ? AppColors.accentText : AppColors.text,
        ),
        decoration: InputDecoration(
          hintText: '–',
          hintStyle: AppText.body(size: 17, color: AppColors.muted),
          filled: true,
          fillColor: winner ? AppColors.accentSoft : AppColors.bg,
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: winner ? AppColors.accent : AppColors.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _small(String text, {int? maxLines}) => Text(
        text,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
        style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.muted),
      );

  InputDecoration _decoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: AppText.body(size: 16, color: AppColors.muted),
        filled: true,
        fillColor: AppColors.s1,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      );
}

class _ImportTitle extends StatelessWidget {
  const _ImportTitle();

  @override
  Widget build(BuildContext context) {
    return Text('Import results',
        style: AppText.body(size: 16, weight: FontWeight.w700));
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.muted)),
    );
  }
}

/// Looks like a text field; opens a picker when tapped.
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.value,
    required this.onTap,
    this.icon = Icons.expand_more_rounded,
    this.bold = false,
  });

  final String value;
  final VoidCallback onTap;
  final IconData icon;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Panel(
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      onTap: onTap,
      child: SizedBox(
        height: 48,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(
                    size: bold ? 16 : 15, weight: bold ? FontWeight.w700 : FontWeight.w500),
              ),
            ),
            Icon(icon, size: 18, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
