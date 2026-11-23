// 乳房ケアカルテ — 記録の形・保存・会話の下書きからの持ち込み。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:mama_care/charting/chart_assist_state.dart';
import 'package:mama_care/charting/chart_assist.dart';
import 'package:mama_care/charting/conversation.dart';
import 'package:mama_care/karte/karte_models.dart';
import 'package:mama_care/karte/karte_prefill.dart';
import 'package:mama_care/karte/karte_store.dart';
import 'package:mama_care/learning/learning_models.dart';

class _FailingStorage implements KarteStorage {
  @override
  Map<String, String> readAll() => {};
  @override
  Future<void> write(String id, String json) async => throw StateError('満杯');
  @override
  Future<void> remove(String id) async => throw StateError('満杯');
}

void main() {
  group('様式', () {
    test('紙の様式の選択肢と金額をそのまま持つ', () {
      expect(kKarteChoices[KP.place]!.options, [
        '宝塚', '西宮', '名古屋', '浦和', '訪問', '産後ケア', //
      ]);
      expect(kKarteChoices[KP.breastShape]!.options, [
        'Ⅰ型',
        'Ⅱa型',
        'Ⅱb型',
        'Ⅲ型',
      ]);
      expect(kKarteChoices[KP.nippleState]!.options, ['白斑', '亀裂', '発赤']);
      expect(kKarteChoices[KP.pain]!.options, ['乳輪', '乳頭', '乳房']);
      expect(kKarteChoices[KP.stool]!.options, ['硬', '普通', '軟']);
      expect(kKarteChoices[KP.pumpType]!.options, ['手動', '電動']);
      expect(kKarteChoices[KP.payMethod]!.options, ['カード', 'PayPay', '現金']);
      expect(
        {for (final f in kKarteFees) f.label: f.yen},
        {'初診料': 1000, '1回': 5500, 'チケット': 14850, 'レンタルタオル': 350, 'ケアタオル': 250},
      );
      expect(formatYen(14850), '14,850');
      expect(formatYen(350), '350');
    });

    test('選ぶ欄のキーと、お会計の項目がずれていない', () {
      expect(kKarteChoices[KP.fees]!.options, [
        for (final f in kKarteFees) f.id,
        kFeeOtherId,
      ]);
      expect(KF.all.toSet().length, KF.all.length);
      expect(KF.all.toSet().containsAll(KF.long), isTrue);
    });
  });

  group('記録', () {
    test('空の欄は持たない。様式に無い選択肢は捨てる。一つだけ選ぶ欄は一つにする', () {
      final v = KarteVisit.build(
        id: 'v1',
        date: DateTime(2026, 11, 23, 15, 30),
        text: {KF.s: '  眠れていない  ', KF.p: '   ', 'unknown': 'x'},
        picks: {
          KP.place: ['訪問', '宝塚', '東京'],
          KP.breastShape: ['Ⅲ型', 'Ⅰ型'],
          KP.pain: <String>[],
        },
      );
      expect(v.text, {KF.s: '眠れていない'});
      expect(v.p(KP.place), ['宝塚', '訪問']);
      expect(v.p(KP.breastShape), ['Ⅰ型']);
      expect(v.picks.containsKey(KP.pain), isFalse);
      expect(v.date, DateTime(2026, 11, 23));
      expect(v.dateLabel, '2026年11月23日（月）');
    });

    test('長すぎる入力は欄の上限で切る', () {
      final v = KarteVisit.build(
        id: 'v1',
        date: DateTime(2026, 1, 1),
        text: {KF.s: 'あ' * (kKarteLongMax + 50), KF.staff: 'い' * 100},
      );
      expect(v.t(KF.s).length, kKarteLongMax);
      expect(v.t(KF.staff).length, kKarteShortMax);
    });

    test('合計は印を付けた項目だけ。「その他」は金額が無いので含めない', () {
      final v = KarteVisit.build(
        id: 'v1',
        date: DateTime(2026, 1, 1),
        picks: {
          KP.fees: ['first', 'single', 'careTowel', kFeeOtherId],
        },
        text: {KF.feeOther: '交通費'},
      );
      expect(v.feeTotal, 1000 + 5500 + 250);
      expect(
        KarteVisit.build(id: 'v2', date: DateTime(2026, 1, 1)).feeTotal,
        0,
      );
    });

    test('JSON にして戻しても同じ内容', () {
      final v = KarteVisit.build(
        id: 'v1',
        date: DateTime(2026, 11, 23),
        text: {KF.no: '3', KF.s: 'S の文', KF.weightG: '4200'},
        picks: {
          KP.place: ['西宮', '産後ケア'],
          KP.fees: ['ticket'],
        },
        marks: const [BreastMark('R', 0.5, -0.5), BreastMark('L', 0, 0)],
        source: '画面で書いた会話',
        openPoints: ['児の識別：どちらのお子さんか'],
        updatedAt: DateTime(2026, 11, 23, 10),
      );
      final back = KarteVisit.fromJson(jsonDecode(jsonEncode(v.toJson())))!;
      expect(back.toJson(), v.toJson());
      expect(back.marks.length, 2);
    });

    test('壊れた内容は記録として読まない', () {
      expect(KarteVisit.fromJson(null), isNull);
      expect(KarteVisit.fromJson({'id': '', 'date': '2026-01-01'}), isNull);
      expect(KarteVisit.fromJson({'id': 'a', 'date': 'きのう'}), isNull);
      expect(Karte.fromJson({'id': 'a'}), isNull);
      expect(BreastMark.fromJson({'side': 'X', 'x': 0, 'y': 0}), isNull);
    });
  });

  group('乳房図の印', () {
    test('置いた位置を文字盤の方向で言う（紙と同じ 12・3・6・9）', () {
      expect(const BreastMark('R', 0, -0.8).where, '右　12時の方向・ふち寄り');
      expect(const BreastMark('R', 0.8, 0).where, '右　3時の方向・ふち寄り');
      expect(const BreastMark('L', 0, 0.4).where, '左　6時の方向・中心寄り');
      expect(const BreastMark('L', -0.4, 0).where, '左　9時の方向・中心寄り');
      expect(const BreastMark('L', 0.05, 0.05).where, '左　中心付近');
      expect(const BreastMark('R', 0.5, -0.87).hour, 1);
      expect(const BreastMark('R', -0.5, -0.87).hour, 11);
    });
  });

  group('カルテ', () {
    test('記録は日付の古い順。次の No. は、いちばん大きい番号の次', () {
      final k = Karte(
        id: 'k',
        motherName: '試験 花子',
        childName: '',
        createdAt: DateTime(2026, 1, 1),
        visits: [
          KarteVisit.build(
            id: 'b',
            date: DateTime(2026, 3, 1),
            text: {KF.no: '7'},
          ),
          KarteVisit.build(
            id: 'a',
            date: DateTime(2026, 2, 1),
            text: {KF.no: '1'},
          ),
        ],
      );
      expect([for (final v in k.visits) v.id], ['a', 'b']);
      expect(k.nextNo, '8');
      expect(
        Karte(
          id: 'k',
          motherName: 'x',
          childName: '',
          createdAt: DateTime(2026),
        ).nextNo,
        '1',
      );
    });
  });

  group('保存', () {
    test('作る・記録を保存する・開き直しても残る', () async {
      final storage = MemoryKarteStorage();
      final store = KarteStore(storage);
      final r = await store.create(motherName: ' 試験 花子 ', childName: 'たろう');
      final k = r.karte!;
      expect(k.motherName, '試験 花子');

      final visit = KarteVisit.build(
        id: KarteStore.newId(),
        date: DateTime(2026, 11, 23),
        text: {KF.s: '夜に張る'},
      );
      expect(await store.saveVisit(k.id, visit), isNull);
      expect(store.byId(k.id)!.visits.single.t(KF.s), '夜に張る');

      // 同じ id で保存すると置き換わる（増えない）
      final edited = KarteVisit.build(
        id: visit.id,
        date: DateTime(2026, 11, 23),
        text: {KF.s: '夜に張る。左が強い'},
      );
      expect(await store.saveVisit(k.id, edited), isNull);
      expect(store.byId(k.id)!.visits.single.t(KF.s), '夜に張る。左が強い');

      final reopened = KarteStore(MemoryKarteStorage(storage.data));
      expect(reopened.kartes.single.motherName, '試験 花子');
      expect(reopened.kartes.single.childName, 'たろう');
      expect(reopened.kartes.single.visits.single.t(KF.s), '夜に張る。左が強い');
    });

    test('氏名が空・長すぎるときは作らない', () async {
      final store = KarteStore(MemoryKarteStorage());
      expect((await store.create(motherName: '   ')).error, '氏名を書いてください。');
      expect(
        (await store.create(motherName: 'あ' * (kKarteNameMax + 1))).error,
        contains('字まで'),
      );
      expect(store.kartes, isEmpty);
    });

    test('記録の削除・カルテの削除', () async {
      final storage = MemoryKarteStorage();
      final store = KarteStore(storage);
      final k = (await store.create(motherName: '試験 花子')).karte!;
      final v = KarteVisit.build(id: 'v', date: DateTime(2026, 1, 1));
      await store.saveVisit(k.id, v);
      expect(await store.deleteVisit(k.id, 'v'), isNull);
      expect(store.byId(k.id)!.visits, isEmpty);
      expect(await store.deleteKarte(k.id), isNull);
      expect(store.kartes, isEmpty);
      expect(storage.data, isEmpty);
    });

    test('保存に失敗したら、保存できたことにしない', () async {
      final store = KarteStore(_FailingStorage());
      final r = await store.create(motherName: '試験 花子');
      expect(r.karte, isNull);
      expect(r.error, contains('保存できませんでした'));
      expect(store.kartes, isEmpty);
    });

    test('壊れた内容は読まずに数え、消さない', () {
      final storage = MemoryKarteStorage({
        'bad': '{こわれている',
        'mismatch': jsonEncode(
          Karte(
            id: 'other',
            motherName: 'x',
            childName: '',
            createdAt: DateTime(2026),
          ).toJson(),
        ),
      });
      final store = KarteStore(storage);
      expect(store.kartes, isEmpty);
      expect(store.unreadable, 2);
      expect(storage.data.length, 2);
    });

    test('無いカルテには保存しない', () async {
      final store = KarteStore(MemoryKarteStorage());
      final v = KarteVisit.build(id: 'v', date: DateTime(2026, 1, 1));
      expect(await store.saveVisit('nope', v), 'カルテが見つかりません。');
    });
  });

  group('会話の下書きからの持ち込み', () {
    late LearningKb kb;
    setUpAll(() {
      kb = LearningKb.parse(File('assets/learning/kb.json').readAsStringSync());
    });

    test('発言はそのまま S）へ。確かめた内容も S）へ。次回確かめる問いは P）へ。残りは未確認', () {
      final assist = ChartAssistState()..open(kSampleConversations[0]);
      final kinds = [for (final q in assist.questions) q.kind];
      expect(kinds.length, greaterThanOrEqualTo(3));
      assist.resolve(kinds[0], Resolution.confirmed, answer: '眠ってから授乳を見てほしい');
      assist.resolve(kinds[1], Resolution.askNext);
      assist.resolve(kinds[2], Resolution.notNeeded);

      final pre = prefillFromAssist(assist, kb.cards)!;

      // 下書きに載った発言は、すべて言い換えずに入っている
      for (final e in assist.result!.draft) {
        expect(pre.s, contains('「${e.text}」'));
      }
      // 助産師の発言は下書きに載せていないので、S）にも入らない
      for (final u in kSampleConversations[0].lines) {
        if (u.speaker == Speaker.midwife) {
          expect(pre.s, isNot(contains(u.text)));
        }
      }
      expect(pre.s, contains('${kinds[0].label}：眠ってから授乳を見てほしい'));
      expect(pre.p, contains(kb.cards[kinds[1].cardId]!.question));
      expect(pre.p, isNot(contains(kb.cards[kinds[0].cardId]!.question)));

      expect(pre.openPoints.length, kinds.length - 3);
      for (final k in kinds.skip(3)) {
        expect(pre.openPoints.any((o) => o.startsWith('${k.label}：')), isTrue);
      }
      expect(pre.source, '架空の会話例「${kSampleConversations[0].title}」');
    });

    test('画面で書いた会話は、出どころをそう書く', () {
      final assist = ChartAssistState()
        ..open(parseConversation('母：今日は少し眠りたいです。\n家族：授乳の練習をしてほしいんです。'));
      final pre = prefillFromAssist(assist, kb.cards)!;
      expect(pre.source, '画面で書いた会話');
      expect(pre.s, contains('ご本人「今日は少し眠りたいです。」'));
      expect(pre.s, contains('ご家族「授乳の練習をしてほしいんです。」'));
      expect(pre.p, isEmpty);
    });

    test('人につなぐ会話・開いていない会話からは、持ち込まない', () {
      expect(prefillFromAssist(ChartAssistState(), kb.cards), isNull);
      final assist = ChartAssistState()
        ..open(parseConversation('母：死にたい気持ちになります。'));
      expect(assist.result!.stopped, isTrue);
      expect(prefillFromAssist(assist, kb.cards), isNull);
    });

    test('持ち込みは数値の欄を作らない（S・P・未確認・出どころだけ）', () {
      final assist = ChartAssistState()..open(kSampleConversations[1]);
      final pre = prefillFromAssist(assist, kb.cards)!;
      final v = KarteVisit.build(
        id: 'v',
        date: DateTime(2026, 1, 1),
        text: {KF.s: pre.s, KF.p: pre.p},
        source: pre.source,
        openPoints: pre.openPoints,
      );
      expect(v.text.keys.toSet().difference({KF.s, KF.p}), isEmpty);
      expect(v.t(KF.weightG), isEmpty);
      expect(v.picks, isEmpty);
      expect(GapKind.values.length, 8);
    });
  });
}
