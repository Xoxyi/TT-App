import 'package:flutter_test/flutter_test.dart';

import 'package:table_tennis_app/data/app_state.dart';
import 'package:table_tennis_app/data/fitet.dart';
import 'package:table_tennis_app/data/store.dart';

import 'fake_fitet.dart';

void main() {
  test('reads card number, position and ranking list from the athlete sheet', () {
    final r = parseFitetSheetRanking(FakeFitet.page('athlete_sheet_792524.html'));
    expect(r.card, '995253');
    expect(r.position, 1542);
    expect(r.points, isNull);
    expect(r.rankId, '247');
    expect(r.date, DateTime(2026, 9, 27));
  });

  test('reads position, category and points from the ranking card', () {
    final r = parseFitetRankingCard(FakeFitet.page('ranking_card.html'));
    expect(r.position, 43);
    expect(r.category, '3');
    expect(r.points, closeTo(8692.23, 0.001));
    expect(r.date, DateTime(2026, 9, 27));
    // The card's own birth date is never read.
    expect(r.toJson().keys, isNot(contains('birth')));
  });

  test('foreign athletes: points but no position', () {
    const sheet = "<h3>Attivita' agonistica 2026/27 dell'atleta Jar Alin Catalin (969073)</h3>"
        '<li class="list-group-item"><span class="badge"><img class=immagine src=images/bandiere/RO.png></span>'
        '<a href="risultati/new_rank/dettaglioatleta.php?ATLETA=762636&ZU=0&AVVERSARIO=0&ID_CLASS=248">'
        'classifica al 25/10/2026</a></li>';
    final s = parseFitetSheetRanking(sheet);
    expect(s.card, '969073');
    expect(s.position, isNull);
    expect(s.rankId, '248');
    expect(s.date, DateTime(2026, 10, 25));
    const card = '<p class="classifica" style="margin-top: 0"></p><p class="style5">Atleta Straniero</p>'
        '<p class=style_scheda2 style=line-height:20px>Straniero&nbsp;&nbsp&nbsp;&nbsp;punti 5.832,63</p>'
        'SCHEDA DETTAGLIO ATLETA AL 25/10/2026';
    final c = s.withCard(parseFitetRankingCard(card));
    expect(c.isForeign, isTrue);
    expect(c.position, isNull);
    expect(c.points, closeTo(5832.63, 0.001));
    expect(c.card, '969073');
  });

  test('the update stores the ranking and opens the card once per ranking list', () async {
    final store = MemoryStore();
    final state = await AppState.load(store);
    state.fitetPause = Duration.zero;
    final client = FakeFitet();
    state.fitetClient = client;
    await state.syncFitet();

    final r = state.rankingOf('zito_andrea')!;
    expect(r.card, '995253');
    expect(r.position, 43); // from the saved card
    expect(r.category, '3');
    expect(client.count('card:792524'), 1);

    // Saved, and not downloaded again while the ranking list is the same.
    await Future<void>.delayed(Duration.zero);
    final reloaded = await AppState.load(store);
    reloaded.fitetPause = Duration.zero;
    reloaded.fitetClient = client;
    expect(reloaded.rankingOf('zito_andrea')!.position, 43);
    await reloaded.syncFitet(force: true);
    expect(client.count('card:792524'), 1);
    expect(reloaded.rankingOf('zito_andrea')!.card, '995253');

    reloaded.removePlayer('zito_andrea');
    expect(reloaded.rankingOf('zito_andrea'), isNull);
  });
}
