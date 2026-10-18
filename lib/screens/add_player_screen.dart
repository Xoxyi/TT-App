import 'dart:async';

import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/fitet.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'navigation.dart';

/// Search an athlete on FITeT by name and follow them.
class AddPlayerScreen extends StatefulWidget {
  const AddPlayerScreen({super.key});

  @override
  State<AddPlayerScreen> createState() => _AddPlayerScreenState();
}

class _AddPlayerScreenState extends State<AddPlayerScreen> {
  final TextEditingController _query = TextEditingController();
  Timer? _debounce;
  List<FitetAthleteHit> _hits = const <FitetAthleteHit>[];
  bool _searching = false;
  String? _error;
  String _searched = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () => _search(text));
  }

  Future<void> _search(String text) async {
    final term = text.trim();
    if (term.length < 3) {
      setState(() {
        _hits = const <FitetAthleteHit>[];
        _error = null;
        _searched = '';
      });
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final hits = await AppScope.of(context).searchFitet(term);
      if (!mounted || _query.text.trim() != term) return;
      setState(() {
        _hits = hits;
        _searched = term;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Search isn’t working right now. Check the connection and try again.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _add({FitetAthleteHit? hit}) async {
    final state = AppScope.of(context);
    final split = hit == null ? null : splitFitetName(hit.name);
    final first = TextEditingController(text: split?.firstName ?? '');
    final last = TextEditingController(text: split?.lastName ?? '');
    final nick = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.s1,
        title: Text(hit == null ? 'New player' : 'Follow player', style: AppText.display(size: 20)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (hit != null) ...<Widget>[
                Text('FITeT ID ${hit.id}. Matches are imported automatically.',
                    style: AppText.body(size: 13, color: AppColors.muted, height: 1.4)),
                const SizedBox(height: 12),
              ],
              _Field(controller: first, label: 'First name'),
              const SizedBox(height: 10),
              _Field(controller: last, label: 'Last name'),
              const SizedBox(height: 10),
              _Field(controller: nick, label: 'Nickname (optional)'),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: AppText.body(size: 14, weight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () {
              if (first.text.trim().isEmpty && last.text.trim().isEmpty) return;
              Navigator.of(context).pop(true);
            },
            child: Text('Follow',
                style: AppText.body(size: 14, weight: FontWeight.w700, color: AppColors.accentText)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final p = state.addPlayer(
      firstName: first.text,
      lastName: last.text,
      nickname: nick.text,
      fitetId: hit?.id,
    );
    final navigator = Navigator.of(context);
    navigator.pop();
    openPlayer(navigator.context, p.id);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final followed = <String>{
      for (final p in state.players)
        if (state.fitetIdOf(p.id) != null) state.fitetIdOf(p.id)!,
    };
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: <Widget>[
            const DetailHeader(title: 'Add player'),
            const SizedBox(height: 16),
            Text('Find on FITeT', style: AppText.display(size: 28)),
            const SizedBox(height: 4),
            Text('Type a last name, or last name and first name.',
                style: AppText.body(size: 14, color: AppColors.muted)),
            const SizedBox(height: 14),
            TextField(
              controller: _query,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              onSubmitted: _search,
              style: AppText.body(size: 16),
              decoration: InputDecoration(
                hintText: 'e.g. Piciulin Gabriele',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.muted),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                        ),
                      )
                    : null,
                filled: true,
                fillColor: AppColors.s1,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.line),
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (_error != null)
              EmptyNote(_error!)
            else if (_searched.isNotEmpty && _hits.isEmpty && !_searching)
              EmptyNote('No athlete found for “$_searched”.')
            else if (_hits.isNotEmpty)
              Panel(
                padding: EdgeInsets.zero,
                child: Column(
                  children: <Widget>[
                    for (var i = 0; i < _hits.length; i++)
                      Builder(builder: (context) {
                        final h = _hits[i];
                        final split = splitFitetName(h.name);
                        final already = followed.contains(h.id);
                        return ListRow(
                          leading: Avatar(
                            initials: '${split.firstName.isEmpty ? '' : split.firstName[0]}'
                                    '${split.lastName.isEmpty ? '' : split.lastName[0]}'
                                .toUpperCase(),
                            size: 36,
                          ),
                          title: '${split.firstName} ${split.lastName}'.trim(),
                          subtitle: h.birthDate == null ? 'FITeT ${h.id}' : 'Born ${h.birthDate}',
                          trailing: already
                              ? const Pill('Following', fontSize: 12)
                              : const Icon(Icons.add_circle_outline_rounded, color: AppColors.accentText),
                          showDivider: i > 0,
                          onTap: already ? null : () => _add(hit: h),
                        );
                      }),
                  ],
                ),
              ),
            const SizedBox(height: 18),
            Center(
              child: TextButton(
                onPressed: () => _add(),
                child: Text('Add a player without FITeT',
                    style: AppText.body(size: 14, weight: FontWeight.w600, color: AppColors.accentText)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textCapitalization: TextCapitalization.words,
      style: AppText.body(size: 16),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.bg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
