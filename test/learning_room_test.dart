// 助産の学習室（教育試作 0.2）— データ・検索・演習・任意接続のテスト。
//
// 検索と並べ替えの期待値は test/fixtures/learning_parity.json。
// これは配布キット（MAMOA_助産の学習室.html）の JavaScript をそのまま Node で実行して
// 得た値で、Dart への移植が同じ結果を返すことを確かめる。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mama_care/learning/card_selector.dart';
import 'package:mama_care/learning/learning_models.dart';
import 'package:mama_care/learning/learning_search.dart';
import 'package:mama_care/learning/learning_state.dart';

String _raw() => File('assets/learning/kb.json').readAsStringSync();
Map<String, dynamic> _json() => jsonDecode(_raw()) as Map<String, dynamic>;

/// 呼び出しを記録する接続口。
class _FakeSelector implements CardSelector {
  final Future<SelectionResult> Function(List<String> allowed) answer;
  final calls = <Map<String, Object>>[];
  _FakeSelector(this.answer);

  @override
  Future<SelectionResult> select({
    required String caseId,
    required int focusIndex,
    required List<String> allowed,
  }) {
    calls.add({'caseId': caseId, 'focusIndex': focusIndex});
    return answer(allowed);
  }
}

void main() {
  late LearningKb kb;
  late LearningIndex index;
  late Map<String, dynamic> parity;

  setUpAll(() {
    kb = LearningKb.parse(_raw());
    index = LearningIndex(kb);
    parity =
        jsonDecode(
              File('test/fixtures/learning_parity.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
  });

  group('教材データ', () {
    test('出典73・能力37・国内14領域・教材24・ケース8が読める', () {
      expect(kb.version, '0.2-education-20261123');
      expect(kb.sources.length, 73);
      expect(kb.competencies.length, 37);
      expect(kb.notes.length, 14);
      expect(kb.cards.length, 24);
      expect(kb.cases.length, 8);
    });

    test('出典の内訳は B37・K2・A33・M1', () {
      int n(String p) => kb.sources.keys.where((k) => k.startsWith(p)).length;
      expect([n('B'), n('K'), n('A'), n('M')], [37, 2, 33, 1]);
    });

    test('能力マップは5領域37項目で、全項目に教材がある', () {
      expect(kb.groups, ['横断的な専門実践', '性と生殖の健康・権利', '妊娠期', '分娩・出生時', '産後・新生児期']);
      expect(
        [for (final g in kb.groups) kb.competenciesIn(g).length],
        [16, 6, 7, 3, 5],
      );
      for (final c in kb.competencies) {
        expect(kb.cardsFor(c.code), isNotEmpty, reason: c.code);
      }
    });

    test('各ケースは候補3枚・観点3つ・別課題・振り返りの観点を持つ', () {
      for (final c in kb.cases.values) {
        expect(c.cards.length, 3, reason: c.id);
        expect(c.focus.length, 3, reason: c.id);
        expect(c.transfer, isNotEmpty, reason: c.id);
        expect(c.rubric, isNotEmpty, reason: c.id);
      }
    });

    test('教材はすべて監修前の作例として収録されている', () {
      expect({for (final d in kb.cards.values) d.status}, {'監修前の架空演習用作例'});
    });

    test('参照が壊れたデータは受け付けない', () {
      void broken(void Function(Map<String, dynamic> db) edit, String part) {
        final db = _json();
        edit(db);
        expect(
          () => LearningKb.fromJson(db),
          throwsA(
            isA<LearningDataError>().having(
              (e) => e.message,
              'message',
              contains(part),
            ),
          ),
        );
      }

      broken((d) => d['cards']['L01']['refs'] = ['Z99'], '教材 L01');
      broken((d) => d['cards']['L01']['refs'] = <String>[], '教材 L01');
      broken((d) => d['cards']['L01']['codes'] = ['9.z'], '教材 L01');
      broken((d) => d['cards']['L01']['id'] = 'L02', '教材 L01');
      broken((d) => d['cases']['C02']['cards'] = ['L02', 'L02', 'L06'], 'C02');
      broken((d) => d['cases']['C02']['cards'] = ['L02', 'L99'], 'C02');
      broken((d) => d['cases']['C02']['focusReference'] = ['L02'], 'C02');
      broken(
        (d) => d['cases']['C02']['focusReference'] = ['L02', 'L05', 'L01'],
        'C02',
      );
      broken((d) => (d['cases'] as Map).remove('C08'), 'C08');
      broken((d) => d['competencies'][0]['refs'] = ['Z99'], 'competencies');
      broken((d) => d['extended'][0]['refs'] = ['Z99'], 'extended');
      broken((d) => d['sources']['B01']['url'] = 'javascript:alert(1)', 'http');
      broken((d) => d['cards'] = <String, dynamic>{}, '空');
      broken((d) => d['cards']['L01']['title'] = 3, 'title');
      expect(() => LearningKb.parse('{'), throwsA(isA<LearningDataError>()));
      expect(() => LearningKb.parse('[]'), throwsA(isA<LearningDataError>()));
    });
  });

  group('端末内の検索（キットの JavaScript と同じ結果）', () {
    test('文字2-gram の分け方が一致する', () {
      for (final s in parity['search'] as List) {
        final got = grams(s['q'] as String);
        final want = [
          for (final e in s['grams'] as List) MapEntry(e[0] as String, e[1]),
        ];
        expect(got.keys.toList(), [
          for (final e in want) e.key,
        ], reason: s['q']);
        expect(got.values.toList(), [
          for (final e in want) e.value,
        ], reason: s['q']);
      }
    });

    test('類似度が一致する（教材24枚・基礎ノート14件）', () {
      var compared = 0;
      for (final s in parity['search'] as List) {
        final q = s['q'] as String;
        final x = grams(q);
        (s['cardScores'] as Map<String, dynamic>).forEach((id, want) {
          expect(
            index.cardScore(x, id),
            closeTo((want as num).toDouble(), 1e-12),
            reason: '$q / $id',
          );
          compared++;
        });
        final nx = grams(q.trim());
        final wantNotes = s['noteScores'] as Map<String, dynamic>;
        for (var i = 0; i < kb.notes.length; i++) {
          expect(
            index.noteScore(nx, i),
            closeTo((wantNotes[kb.notes[i].label] as num).toDouble(), 1e-12),
            reason: '$q / ${kb.notes[i].label}',
          );
          compared++;
        }
      }
      expect(compared, greaterThan(1000));
    });

    test('教材カードと基礎ノートの候補が一致する', () {
      for (final s in parity['search'] as List) {
        final q = s['q'] as String;
        expect(index.rankCards(q), s['ranked'], reason: 'cards: $q');
        expect(
          [for (final n in index.matchNotes(q)) n.label],
          s['notes'],
          reason: 'notes: $q',
        );
      }
    });

    test('検証記録にある操作：双子の記録・プロラクチンと射乳・L21', () {
      expect(index.rankCards('双子の体重の記録をどう確かめる？').first, 'L02');
      expect(index.rankCards('L21'), ['L21']);
      expect(kb.cards['L21']!.title, '避妊の目的と相談の範囲');
      expect(kb.cardsFor('2.c').map((d) => d.id), contains('L21'));
      expect([
        for (final n in index.matchNotes('プロラクチンと射乳')) n.label,
      ], contains('授乳・乳房'));
    });

    test('候補は教材3件・基礎ノート2件まで。収録のない語は候補なし', () {
      for (final s in parity['search'] as List) {
        final q = s['q'] as String;
        expect(index.rankCards(q).length, lessThanOrEqualTo(3));
        expect(index.matchNotes(q).length, lessThanOrEqualTo(2));
      }
      expect(index.rankCards('xyz'), isEmpty);
      expect(index.matchNotes('xyz'), isEmpty);
      expect(index.rankCards('L99'), isEmpty);
    });

    test('ケース演習の並び順が一致する（8ケース×3観点×4通りの初答）', () {
      final rows = parity['order'] as List;
      expect(rows.length, 96);
      for (final r in rows) {
        final c = kb.cases[r['caseId']]!;
        final ids = index.personalOrder(
          c,
          focusIndex: c.focus.indexOf(r['focus'] as String),
          first: r['first'] as String,
          why: r['why'] as String,
        );
        expect(ids, r['ids'], reason: '${c.id} ${r['focus']} ${r['first']}');
        expect(ids.toSet(), c.cards.toSet());
      }
    });

    test('文献台帳の絞り込みが一致する（出典名・用語・ID）', () {
      for (final f in parity['sourceFilter'] as List) {
        expect(
          [for (final s in index.filterSources(f['q'] as String)) s.id],
          f['ids'],
          reason: 'q=${f['q']}',
        );
      }
      expect(index.filterSources('').length, 73);
      expect([for (final s in index.filterSources('B04')) s.id], ['B04']);
      expect([for (final s in index.filterSources('K01')) s.id], ['K01']);
    });

    test('実際の相談・緊急・薬量・診断の語句では検索しない', () {
      for (final g in parity['guard'] as List) {
        final q = g['q'] as String;
        if (g['hit'] as bool) {
          expect(LearningIndex.asksAboutRealCare(q), isTrue, reason: q);
        }
      }
      // キットで止まらなかった語のうち、全角・大文字の表記ゆれだけは止める。
      final widened = [
        for (final g in parity['guard'] as List)
          if (!(g['hit'] as bool) &&
              LearningIndex.asksAboutRealCare(g['q'] as String))
            g['q'],
      ];
      expect(widened, ['何ｍｇ', '何MG']);
      expect(LearningIndex.asksAboutRealCare('双子の記録'), isFalse);
    });
  });

  group('ケース演習', () {
    LearningState fresh({CardSelector? selector}) =>
        LearningState(kb: kb, selector: selector);

    test('問いと理由の両方がないと参考例へ進めない', () async {
      final s = fresh();
      expect(await s.submitFirst(), '問いと理由をそれぞれ入力してください。');
      s.session.first = '今日はどうしたいですか';
      s.session.why = '   ';
      expect(await s.submitFirst(), isNotNull);
      expect(s.session.step, ExerciseStep.firstAnswer);
      s.session.why = '本人の希望を先に聞きたい';
      expect(await s.submitFirst(), isNull);
      expect(s.session.step, ExerciseStep.compare);
      expect(s.session.method, LearningState.methodOnDevice);
      expect(s.session.rank.toSet(), {'L01', 'L03', 'L07'});
    });

    test('選んだ観点で並びが変わる', () async {
      Future<String> top(int focus) async {
        final s = fresh();
        s.session
          ..first = 'a'
          ..why = 'b';
        s.setFocus(focus);
        await s.submitFirst();
        return s.session.rank.first;
      }

      expect(await top(0), 'L01');
      expect(await top(1), 'L03');
      expect(await top(2), 'L07');
    });

    test('全候補を保留のまま別課題へ進み、振り返りまで行ける', () async {
      final s = fresh()..openCase('C02');
      s.session
        ..first = 'どちらのお子さんの記録ですか'
        ..why = '児と時点が分からないため';
      await s.submitFirst();
      expect(s.submitRewrite(), '次の一言と理由を入力してください。');
      s.session.rewrite = '誰がいつ測ったかを確かめます';
      expect(s.submitRewrite(), isNull);
      expect(s.session.step, ExerciseStep.transfer);
      expect(s.submitTransfer(), 'この事例での回答を入力してください。');
      s.session.transfer = '日付と記入者を尋ねます';
      expect(s.submitTransfer(), isNull);
      expect(s.session.step, ExerciseStep.review);
      expect(s.session.revisited, isFalse);
      expect(
        s.handlingSummary(),
        s.session.rank.map((id) => '${kb.cards[id]!.title}（保留）').join('、'),
      );
    });

    test('採用・見送りは振り返りに残る', () async {
      final s = fresh();
      s.session
        ..first = 'a'
        ..why = 'b';
      await s.submitFirst();
      s.choose('L01', CardChoice.adopt);
      s.choose('L03', CardChoice.skip);
      s.choose('L24', CardChoice.adopt); // 候補にない教材は無視
      expect(s.session.chosen.keys, ['L01', 'L03']);
      expect(s.handlingSummary(), contains('本人にとっての今日の目標（採用）'));
      expect(s.handlingSummary(), contains('授乳の希望と暮らしを一緒に聴く（見送り）'));
      expect(s.handlingSummary(), contains('家族同席と話しやすい環境（保留）'));
    });

    test('別課題の間は他のケース・他のタブを開けない', () async {
      final s = fresh();
      s.session
        ..first = 'a'
        ..why = 'b';
      await s.submitFirst();
      expect(s.locked, isFalse);
      s.session.rewrite = 'c';
      s.submitRewrite();
      expect(s.locked, isTrue);

      s.openCase('C02');
      expect(s.caseId, 'C01');
      for (var i = 1; i < LearningState.tabs.length; i++) {
        s.openTab(i);
        expect(s.tab, LearningState.exerciseTab);
        expect(s.canOpenTab(i), isFalse);
      }
      s.openCardInSearch('L21');
      expect(s.tab, LearningState.exerciseTab);
      expect(s.searchQuery, '');
      expect(
        [for (final c in kb.cases.keys) s.canOpenCase(c)],
        [true, false, false, false, false, false, false, false],
      );
    });

    test('中断すると比較に戻り、再開後は再練習として扱う', () async {
      final s = fresh();
      s.session
        ..first = 'a'
        ..why = 'b';
      await s.submitFirst();
      s.session.rewrite = 'c';
      s.submitRewrite();
      s.session.transfer = '書きかけ';
      s.suspendTransfer();
      expect(s.session.step, ExerciseStep.compare);
      expect(s.session.transfer, '');
      expect(s.session.revisited, isTrue);
      expect(s.locked, isFalse);
      s.openTab(LearningState.searchTab);
      expect(s.tab, LearningState.searchTab);
      s.openTab(LearningState.exerciseTab);
      // 初答・理由・比べたあとの一言は残る
      expect(
        [s.session.first, s.session.why, s.session.rewrite],
        ['a', 'b', 'c'],
      );
      s.submitRewrite();
      s.session.transfer = 'd';
      s.submitTransfer();
      expect(s.session.step, ExerciseStep.review);
      expect(s.session.revisited, isTrue);
    });

    test('「このケースを最初から」で入力が消える。他のケースは残る', () async {
      final s = fresh();
      s.session
        ..first = 'a'
        ..why = 'b';
      s.openCase('C03');
      s.session.first = 'c3';
      s.openCase('C01');
      expect(s.hasInput, isTrue);
      s.restartCase();
      expect(s.session.first, '');
      expect(s.session.step, ExerciseStep.firstAnswer);
      expect(s.sessionOf('C03').first, 'c3');
    });

    test('能力マップから教材を開くと、知識検索にIDが入る', () {
      final s = fresh()..openTab(2);
      s.openCardInSearch('L21');
      expect(s.tab, LearningState.searchTab);
      expect(s.searchQuery, 'L21');
      expect(s.index.rankCards(s.searchQuery), ['L21']);
    });
  });

  group('緊急連携ケース（C08）', () {
    test('提示順は固定で、初答や観点に左右されない', () async {
      for (var focus = 0; focus < 3; focus++) {
        final s = LearningState(kb: kb)..openCase('C08');
        s.session
          ..first = '引継ぎ 申し送り 担当 期限'
          ..why = '出生直後 新生児 蘇生 実技';
        s.setFocus(focus);
        await s.submitFirst();
        expect(s.session.rank, ['L10', 'L06', 'L18']);
        expect(s.session.method, LearningState.methodEmergency);
      }
    });

    test('施設内モデルに接続していても、モデルを呼び出さない', () async {
      final sel = _FakeSelector(
        (a) async => SelectionResult.verified([a.last], 'mamoa-local'),
      );
      final s = LearningState(kb: kb, selector: sel)..openCase('C08');
      s.session
        ..first = 'a'
        ..why = 'b';
      await s.submitFirst();
      expect(sel.calls, isEmpty);
      expect(s.session.rank, ['L10', 'L06', 'L18']);
      expect(s.session.method, LearningState.methodEmergency);
    });
  });

  group('施設内モデルの任意接続', () {
    Future<LearningState> run(CardSelector sel, {String caseId = 'C01'}) async {
      final s = LearningState(kb: kb, selector: sel)..openCase(caseId);
      s.session
        ..first = '学習者が書いた初答の文章'
        ..why = '学習者が書いた理由の文章';
      s.setFocus(1);
      await s.submitFirst();
      return s;
    }

    test('渡すのはケース番号と観点の番号だけ', () async {
      final sel = _FakeSelector(
        (a) async => SelectionResult.verified([a[1], a[0]], 'mamoa-local'),
      );
      final s = await run(sel);
      expect(sel.calls, [
        {'caseId': 'C01', 'focusIndex': 1},
      ]);
      expect(s.session.rank, ['L03', 'L01']);
      expect(s.session.method, '施設内モデルによる選択 · mamoa-local');
      expect(s.modeLabel, '教育用試作 · 端末内のモデル選択を使用');
    });

    test('モデルが候補なしと返したら保留', () async {
      final s = await run(
        _FakeSelector((a) async => const SelectionResult.verified([], 'm')),
      );
      expect(s.session.rank, isEmpty);
      expect(s.session.method, LearningState.methodModelHeld);
      expect(s.session.step, ExerciseStep.compare);
      expect(s.handlingSummary(), '全保留');
    });

    test('検証できない応答・範囲外・重複・例外はすべて保留', () async {
      final bad = <Future<SelectionResult> Function(List<String>)>[
        (a) async => const SelectionResult.held(),
        (a) async => const SelectionResult.verified(['L24'], 'm'),
        (a) async => SelectionResult.verified([a[0], a[0]], 'm'),
        (a) async => SelectionResult.verified([...a, 'L24'], 'm'),
        (a) async => SelectionResult.verified([a[0]], ''),
        (a) async => throw const SocketException('refused'),
        (a) => Future.error(StateError('x')),
      ];
      for (final answer in bad) {
        final s = await run(_FakeSelector(answer));
        expect(s.session.rank, isEmpty);
        expect(s.session.method, LearningState.methodUnverified);
        // 保留のままでも自分の言葉で先へ進める
        s.session.rewrite = '次の一言';
        expect(s.submitRewrite(), isNull);
      }
    });

    test('応答の検査：許可ID・重複・不正な形式・モデル名', () {
      const allowed = ['L01', 'L03', 'L07'];
      SelectionResult check(Object? body) =>
          LocalSelectionApi.checkResponse(body, allowed);

      final ok = check({
        'ids': ['L07', 'L01'],
        'model': 'mamoa-local',
      });
      expect(ok.verified, isTrue);
      expect(ok.ids, ['L07', 'L01']);
      expect(ok.model, 'mamoa-local');
      expect(check({'ids': <String>[], 'model': 'm'}).verified, isTrue);

      final rejected = <Object?>[
        null,
        'L01',
        ['L01'],
        {'model': 'm'},
        {
          'ids': ['L01'],
        },
        {'ids': 'L01', 'model': 'm'},
        {
          'ids': ['L02'],
          'model': 'm',
        },
        {
          'ids': ['L01', 'L01'],
          'model': 'm',
        },
        {
          'ids': ['L01', 'L03', 'L07', 'L01'],
          'model': 'm',
        },
        {
          'ids': [1],
          'model': 'm',
        },
        {
          'ids': ['l01'],
          'model': 'm',
        },
        {
          'ids': ['L01'],
          'model': '',
        },
        {
          'ids': ['L01'],
          'model': 7,
        },
        {
          'ids': ['L01'],
          'model': 'a\nb',
        },
        {
          'ids': ['L01'],
          'model': 'x' * 121,
        },
      ];
      for (final body in rejected) {
        final r = check(body);
        expect(r.verified, isFalse, reason: '$body');
        expect(r.ids, isEmpty);
      }
    });

    test('教材選択APIへの送信内容：同じ端末・2項目のみ・自由記述なし', () async {
      final seen = <http.Request>[];
      final api = LocalSelectionApi(
        port: 8765,
        client: MockClient((req) async {
          seen.add(req);
          if (req.url.path == '/mode') {
            return http.Response('{"mode":"local_model"}', 200);
          }
          return http.Response(
            jsonEncode({
              'ids': ['L03'],
              'model': 'mamoa-local',
            }),
            200,
          );
        }),
      );
      final s = LearningState(kb: kb);
      expect(await s.connect(api), isTrue);
      expect(s.modelConnected, isTrue);
      s.session
        ..first = '学習者が書いた初答の文章'
        ..why = '学習者が書いた理由の文章';
      s.setFocus(2);
      await s.submitFirst();

      expect(s.session.rank, ['L03']);
      final rank = seen.singleWhere((r) => r.url.path == '/rank');
      expect(rank.method, 'POST');
      expect(rank.url.toString(), 'http://127.0.0.1:8765/rank');
      expect(jsonDecode(rank.body), {'case_id': 'C01', 'focus': 2});
      for (final r in seen) {
        expect(r.url.host, '127.0.0.1');
        expect(r.body, isNot(contains('学習者')));
        expect(r.url.toString(), isNot(contains('学習者')));
      }
      // 送信はキットの接続口の上限（250バイト）に収まる
      expect(rank.bodyBytes.length, lessThanOrEqualTo(250));

      s.disconnect();
      expect(s.modelConnected, isFalse);
      expect(s.modeLabel, '教育用試作 · 端末内で動作');
    });

    test('接続口の異常（拒否・不正なJSON・過大な応答・通信失敗）は保留', () async {
      final responders = <Future<http.Response> Function(http.Request)>[
        (r) async => http.Response('{}', 403),
        (r) async => http.Response('{}', 409),
        (r) async => http.Response('not json', 200),
        (r) async => http.Response('{"ids":["L24"],"model":"m"}', 200),
        (r) async =>
            http.Response('{"ids":["L01"],"model":"${'x' * 5000}"}', 200),
        (r) async => throw const SocketException('refused'),
      ];
      for (final respond in responders) {
        final api = LocalSelectionApi(port: 8765, client: MockClient(respond));
        final r = await api.select(
          caseId: 'C01',
          focusIndex: 0,
          allowed: const ['L01', 'L03', 'L07'],
        );
        expect(r.verified, isFalse);
        expect(r.ids, isEmpty);
      }
    });

    test('モデルを使う設定でない接続口には接続しない', () async {
      for (final body in ['{"mode":"fixed"}', '{}', 'x', '[]']) {
        final s = LearningState(kb: kb);
        final api = LocalSelectionApi(
          port: 8765,
          client: MockClient((r) async => http.Response(body, 200)),
        );
        expect(await s.connect(api), isFalse);
        expect(s.modelConnected, isFalse);
      }
      final s = LearningState(kb: kb);
      final down = LocalSelectionApi(
        port: 8765,
        client: MockClient((r) async => throw const SocketException('x')),
      );
      expect(await s.connect(down), isFalse);
      expect(LocalSelectionApi.validPort(0), isFalse);
      expect(LocalSelectionApi.validPort(65536), isFalse);
      expect(LocalSelectionApi.validPort(8765), isTrue);
    });
  });
}
