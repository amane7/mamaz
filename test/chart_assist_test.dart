// 会話からカルテの下書き（試作）— 会話の読み取り・確かめたい点・下書き・気づきのテスト。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:mama_care/charting/chart_assist.dart';
import 'package:mama_care/charting/chart_assist_state.dart';
import 'package:mama_care/charting/conversation.dart';
import 'package:mama_care/charting/insight_store.dart';
import 'package:mama_care/learning/learning_models.dart';

List<GapKind> kinds(String raw) => [
  for (final q in analyzeConversation(parseConversation(raw)).questions) q.kind,
];

void main() {
  late LearningKb kb;
  setUpAll(() {
    kb = LearningKb.parse(File('assets/learning/kb.json').readAsStringSync());
  });

  group('会話の読み取り', () {
    test('話者つきの行を読む。全角・半角のコロン、空行、話者のない行', () {
      final c = parseConversation(
        '母：今日は少し眠りたいです。\n家族:授乳の練習をしてほしいんです。\n\nメモだけの行\n助産師：わかりました。',
      );
      expect(c.sample, isFalse);
      expect(
        [for (final u in c.lines) u.speaker],
        [Speaker.mother, Speaker.family, Speaker.unknown, Speaker.midwife],
      );
      expect(c.lines.first.text, '今日は少し眠りたいです。');
      expect(c.lines[2].text, 'メモだけの行');
    });

    test('話者のない行は、話者を推測せず「話者不明」のまま下書きに置く', () {
      final r = analyzeConversation(parseConversation('今日は眠りたいです。'));
      expect(r.draft.single.speaker, Speaker.unknown);
      expect(r.draft.single.section, ChartSection.unknownSpeaker);
      // ご本人の希望としては数えない
      expect([for (final q in r.questions) q.kind], contains(GapKind.ownWish));
    });

    test('行数と1行の長さに上限がある', () {
      final many = List.generate(80, (i) => '母：発言$i').join('\n');
      expect(parseConversation(many).lines.length, kMaxConversationLines);
      final long = parseConversation('母：${'あ' * 500}');
      expect(long.lines.single.text.length, kMaxUtteranceLength);
    });

    test('架空の会話例は3件', () {
      expect(kSampleConversations.length, 3);
      expect(kSampleConversations.every((c) => c.sample), isTrue);
    });
  });

  group('確かめたい点', () {
    test('例1：休みたい本人と、授乳の練習を望む家族', () {
      final r = analyzeConversation(kSampleConversations[0]);
      expect(
        [for (final q in r.questions) q.kind],
        [
          GapKind.ownWish,
          GapKind.feedingWish,
          GapKind.hearsay,
          GapKind.companion,
          GapKind.shortReply,
        ],
      );
      expect(r.questions.first.lines, [1, 2]);
      expect(r.questions.last.lines, [4]);
    });

    test('例2：双子の記録', () {
      final r = analyzeConversation(kSampleConversations[1]);
      expect(
        [for (final q in r.questions) q.kind],
        [
          GapKind.childIdentity,
          GapKind.feedingWish,
          GapKind.hearsay,
          GapKind.handoff,
          GapKind.ownWish,
        ],
      );
      expect(r.questions.first.lines, [1, 2]);
      // 手掛かりの発言がないものは最後
      expect(r.questions.last.lines, isEmpty);
    });

    test('例3：薬の質問と、短い返事', () {
      final r = analyzeConversation(kSampleConversations[2]);
      expect(
        [for (final q in r.questions) q.kind],
        [GapKind.shortReply, GapKind.medication],
      );
    });

    test('問いは、学習室に登録済みの教材から引く', () {
      expect(
        {for (final k in GapKind.values) k: k.cardId},
        {
          GapKind.ownWish: 'L01',
          GapKind.childIdentity: 'L02',
          GapKind.feedingWish: 'L03',
          GapKind.shortReply: 'L04',
          GapKind.hearsay: 'L05',
          GapKind.handoff: 'L06',
          GapKind.companion: 'L07',
          GapKind.medication: 'L17',
        },
      );
      for (final k in GapKind.values) {
        expect(kb.cards.containsKey(k.cardId), isTrue, reason: k.name);
      }
    });

    test('同じ種類の問いは1件にまとめる。発言番号は会話の範囲内', () {
      for (final c in kSampleConversations) {
        final r = analyzeConversation(c);
        final ks = [for (final q in r.questions) q.kind];
        expect(ks.toSet().length, ks.length);
        for (final q in r.questions) {
          expect(q.lines.every((i) => i >= 0 && i < c.lines.length), isTrue);
        }
      }
    });

    test('希望と授乳の意向が話されていれば、候補は挙がらない', () {
      expect(kinds('母：今日は眠りたいです。\n母：授乳は続けたいです。'), isEmpty);
    });

    test('「眠たい」「みたい」は希望として数えない', () {
      expect(kinds('母：眠たいです。'), [GapKind.ownWish]);
      expect(kinds('母：風邪みたいです。'), [GapKind.ownWish]);
    });

    test('どちらの子かが言葉にあれば、児の識別は挙げない。本人自身の話も挙げない', () {
      expect(
        kinds(
          '母：双子です。\n母：上の子はよく飲みました。\n母：下の子は体重が増えました。\n'
          '母：今日は休みたいです。授乳は続けたいです。\n母：私は夜寝ていなくて。',
        ),
        isEmpty,
      );
      expect(kinds('母：双子です。今日は休みたいです。授乳は続けたいです。\n母：昨日はよく飲みました。'), [
        GapKind.childIdentity,
      ]);
    });

    test('担当や期限が言葉にあれば、引継ぎは挙げない', () {
      const wish = '母：今日は休みたいです。授乳は続けたいです。\n';
      expect(kinds('$wish助産師：相談先へ連携しておきますね。'), [GapKind.handoff]);
      expect(kinds('$wish助産師：来週までに担当者が相談先へ連携します。'), isEmpty);
    });

    test('理由は「見つけられなかった」までしか言わない（無いと断定しない）', () {
      for (final c in kSampleConversations) {
        for (final q in analyzeConversation(c).questions) {
          expect(q.reason, isNot(contains('ありません')), reason: q.reason);
        }
      }
    });
  });

  group('下書き', () {
    test('発言を言い換えずに載せる。助産師の発言は載せない', () {
      for (final c in kSampleConversations) {
        final r = analyzeConversation(c);
        expect(r.draft, isNotEmpty);
        for (final e in r.draft) {
          expect(e.text, c.lines[e.line].text);
          expect(e.speaker, c.lines[e.line].speaker);
          expect(e.speaker, isNot(Speaker.midwife));
        }
        final spoken = c.lines.where((u) => u.speaker != Speaker.midwife);
        expect(r.draft.length, lessThanOrEqualTo(spoken.length));
        expect({for (final e in r.draft) e.line}.length, r.draft.length);
      }
    });

    test('ご家族の発言は、内容に関わらず「ご家族から聞いたこと」に置く', () {
      final r = analyzeConversation(kSampleConversations[0]);
      for (final e in r.draft.where((e) => e.speaker == Speaker.family)) {
        expect(e.section, ChartSection.fromFamily);
      }
      expect(
        r.draft.where((e) => e.section == ChartSection.wish).single.text,
        '今日は少し眠りたいです。',
      );
    });

    test('ご本人自身の体重の話を、お子さんの欄に入れない', () {
      final r = analyzeConversation(
        parseConversation('母：私の体重が戻らなくて。\n母：赤ちゃんの体重が気になります。'),
      );
      expect(
        [for (final e in r.draft) e.section],
        [ChartSection.words, ChartSection.baby],
      );
    });
  });

  group('人につなぐ', () {
    test('差し迫った危険・薬の量・診断の言葉があれば、問いも下書きも出さない', () {
      for (final raw in [
        '母：赤ちゃんが息をしていないんです',
        '母：この薬は何錠飲めばいいですか',
        '母：今日は眠りたいです。\n家族：出血が止まらないみたいで',
        '助産師：診断してもらいましたか',
      ]) {
        final r = analyzeConversation(parseConversation(raw));
        expect(r.stopped, isTrue, reason: raw);
        expect(r.draft, isEmpty);
        expect(r.questions, isEmpty);
      }
      expect(analyzeConversation(kSampleConversations[2]).stopped, isFalse);
    });
  });

  group('問いの扱い', () {
    ChartAssistState opened() =>
        ChartAssistState()..open(kSampleConversations[0]);

    test('空の会話は開けない', () {
      final s = ChartAssistState();
      expect(s.open(parseConversation('  \n ')), isNotNull);
      expect(s.isOpen, isFalse);
    });

    test('最初はすべて未確認。確認済みにするには、確かめた内容が要る', () {
      final s = opened();
      expect(s.unresolved.length, 5);
      expect(s.resolve(GapKind.ownWish, Resolution.confirmed), isNotNull);
      expect(
        s.resolve(GapKind.ownWish, Resolution.confirmed, answer: ' '),
        isNotNull,
      );
      expect(s.unresolved.length, 5);
      expect(
        s.resolve(
          GapKind.ownWish,
          Resolution.confirmed,
          answer: ' 眠ってから授乳を見てほしい ',
        ),
        isNull,
      );
      expect(s.answerOf(GapKind.ownWish), '眠ってから授乳を見てほしい');
      expect([for (final q in s.confirmed) q.kind], [GapKind.ownWish]);
      expect(s.unresolved.length, 4);
    });

    test('次回に確かめる・今回は確かめない・選び直す', () {
      final s = opened();
      expect(s.resolve(GapKind.feedingWish, Resolution.askNext), isNull);
      expect(s.resolve(GapKind.companion, Resolution.notNeeded), isNull);
      expect([for (final q in s.nextChecks) q.kind], [GapKind.feedingWish]);
      expect(s.resolutionOf(GapKind.companion), Resolution.notNeeded);
      expect(s.unresolved.length, 3);
      s.reopen(GapKind.feedingWish);
      expect(s.nextChecks, isEmpty);
      expect(s.unresolved.length, 4);
    });

    test('確認済みから別の扱いに変えると、書いた内容は残さない', () {
      final s = opened();
      s.resolve(GapKind.ownWish, Resolution.confirmed, answer: 'a');
      s.resolve(GapKind.ownWish, Resolution.askNext);
      expect(s.answerOf(GapKind.ownWish), '');
      expect(s.confirmed, isEmpty);
    });

    test('挙がっていない種類の問いは扱えない。閉じると消える', () {
      final s = opened();
      expect(s.resolve(GapKind.medication, Resolution.askNext), isNull);
      expect(s.resolutionOf(GapKind.medication), isNull);
      s.resolve(GapKind.ownWish, Resolution.confirmed, answer: 'a');
      s.close();
      expect(s.isOpen, isFalse);
      expect(s.questions, isEmpty);
      s.open(kSampleConversations[0]);
      expect(s.answerOf(GapKind.ownWish), '');
      expect(s.unresolved.length, 5);
    });
  });

  group('気づき', () {
    test('空・長すぎる文章は残さない', () {
      final store = InsightStore();
      expect(store.add(stance: InsightStance.depends, text: '  '), isNotNull);
      expect(
        store.add(
          stance: InsightStance.depends,
          text: 'あ' * (InsightStore.maxLength + 1),
        ),
        isNotNull,
      );
      expect(store.notes, isEmpty);
    });

    test('残した順の新しいものが先。取り消せる', () {
      final store = InsightStore();
      var notified = 0;
      store.addListener(() => notified++);
      expect(
        store.add(
          stance: InsightStance.depends,
          kind: GapKind.shortReply,
          text: ' 一つ目 ',
        ),
        isNull,
      );
      expect(store.add(stance: InsightStance.missing, text: '二つ目'), isNull);
      expect([for (final n in store.notes) n.text], ['二つ目', '一つ目']);
      expect(store.notes.last.kind, GapKind.shortReply);
      expect(store.notes.first.kind, isNull);
      store.remove(store.notes.last.id);
      expect([for (final n in store.notes) n.text], ['二つ目']);
      store.remove(999);
      expect(notified, 3);
    });
  });
}
