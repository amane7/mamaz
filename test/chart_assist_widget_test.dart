// 会話からカルテの下書き（試作）— 画面の操作テスト。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mama_care/charting/chart_assist.dart';
import 'package:mama_care/charting/conversation.dart';
import 'package:mama_care/charting/insight_store.dart';
import 'package:mama_care/charting/ui/chart_assist_screen.dart';
import 'package:mama_care/learning/learning_models.dart';
import 'package:mama_care/learning/ui/learning_room_screen.dart';
import 'package:mama_care/ops/ops_state.dart';

void main() {
  late LearningKb kb;
  setUpAll(() {
    kb = LearningKb.parse(File('assets/learning/kb.json').readAsStringSync());
  });

  Future<InsightStore> open(
    WidgetTester tester, {
    bool staff = true,
    Size size = const Size(430, 7000),
    InsightStore? store,
    Widget? home,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    final ops = OpsState();
    if (staff) {
      ops.requestStaffAccess(
        requested: StaffRoleKind.midwife,
        code: 'MW-2026-01',
      );
    }
    final insights = store ?? InsightStore();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: ops),
          ChangeNotifierProvider.value(value: insights),
        ],
        child: MaterialApp(home: home ?? ChartAssistScreen(kb: kb)),
      ),
    );
    if (staff) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }
    return insights;
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text).first);
    await tester.pumpAndSettle();
  }

  testWidgets('ご家族の権限では中身を出さない', (tester) async {
    await open(tester, staff: false);
    expect(find.text('専門職向けの画面です'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('架空の会話例'), findsNothing);
  });

  testWidgets('はじめの画面で、試作の範囲（音声未接続・言語モデル不使用・保存なし）を示す', (tester) async {
    await open(tester);
    expect(find.textContaining('音声の録音と文字起こしは、まだつないでいません'), findsOneWidget);
    expect(find.textContaining('言語モデルも使っていません'), findsOneWidget);
    expect(find.textContaining('保存したときだけ入ります'), findsOneWidget);
    expect(find.textContaining('予約の記録には書き込みません'), findsOneWidget);
    for (final c in kSampleConversations) {
      expect(find.text(c.title), findsOneWidget);
    }
    await tapText(tester, '下書きを作る');
    expect(find.text('会話を1行以上書いてください。'), findsOneWidget);
  });

  testWidgets('会話例から、確かめたい点と下書きが出る。確認した内容だけが「確かめたこと」に入る', (tester) async {
    await open(tester);
    await tapText(tester, kSampleConversations[0].title);

    expect(find.text('確かめたい点　5件'), findsOneWidget);
    expect(find.text('今日ここで何ができたら「来てよかった」と思えそうですか。'), findsOneWidget);
    expect(find.text('教材 L01 · 監修前'), findsOneWidget);
    expect(find.text('手掛かりにした発言　2、3'), findsOneWidget);

    // 下書き：発言そのまま・話者つき。最初はすべて未確認。
    expect(find.text('「今日は少し眠りたいです。」（ご本人・発言2）'), findsOneWidget);
    expect(find.text('ご家族から聞いたこと'), findsOneWidget);
    expect(find.text('未確認のまま'), findsOneWidget);
    expect(find.text('助産師が確かめたこと'), findsNothing);

    await tapText(tester, '理由・出典を見て、扱いを決める');
    await tapText(tester, '確認済みとして下書きに入れる');
    expect(find.textContaining('確認できている内容を書いてください'), findsOneWidget);
    expect(find.text('助産師が確かめたこと'), findsNothing);

    await tester.enterText(find.byType(TextField).first, '眠ってから授乳を見てほしい');
    await tapText(tester, '確認済みとして下書きに入れる');
    expect(find.text('助産師が確かめたこと'), findsOneWidget);
    expect(find.text('本人の希望：眠ってから授乳を見てほしい'), findsOneWidget);

    await tapText(tester, '扱いを選び直す');
    expect(find.text('助産師が確かめたこと'), findsNothing);
    await tapText(tester, '次回、ご本人に確かめる');
    expect(find.text('次回、ご本人に確かめること'), findsOneWidget);
  });

  testWidgets('気づきを残すと学習室の「現場の気づき」に出る。会話の文面は渡らない。取り消せる', (tester) async {
    final store = await open(tester);
    await tapText(tester, kSampleConversations[0].title);
    await tapText(tester, '理由・出典を見て、扱いを決める');
    await tapText(tester, 'この問いについて、気づきを残す');
    await tapText(tester, '気づきを残す');
    expect(find.text('気づきを書いてから残してください。'), findsOneWidget);
    expect(store.notes, isEmpty);

    // 入力欄は上から「確認できていること」「気づき」の順
    await tester.enterText(find.byType(TextField).at(1), '同席者がいる時は、先に本人だけに聞く');
    await tapText(tester, 'いつも確かめる');
    await tapText(tester, '気づきを残す');

    final note = store.notes.single;
    expect(note.text, '同席者がいる時は、先に本人だけに聞く');
    expect(note.kind, GapKind.ownWish);
    expect(note.stance, InsightStance.always);
    for (final u in kSampleConversations[0].lines) {
      expect(note.text, isNot(contains(u.text)));
    }

    await open(
      tester,
      store: store,
      home: LearningRoomScreen(kb: kb),
    );
    await tapText(tester, '現場の気づき');
    expect(find.text('同席者がいる時は、先に本人だけに聞く'), findsOneWidget);
    expect(find.text('問いの種類　本人の希望'), findsOneWidget);
    expect(find.textContaining('監修前の覚え書き'), findsOneWidget);
    await tapText(tester, '取り消す');
    expect(store.notes, isEmpty);
    expect(find.textContaining('まだ気づきはありません'), findsOneWidget);
  });

  testWidgets('差し迫った言葉を含む会話では、問いも下書きも出さず人につなぐ', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), '母：赤ちゃんが息をしていないんです');
    await tapText(tester, '下書きを作る');
    expect(find.textContaining('施設の緊急手順・救急要請につないでください'), findsOneWidget);
    expect(find.text('下書き'), findsNothing);
    expect(find.textContaining('確かめたい点'), findsNothing);
  });

  testWidgets('幅390pxでも横にはみ出さない', (tester) async {
    await open(tester, size: const Size(390, 844));
    expect(tester.takeException(), isNull);
    await tapText(tester, kSampleConversations[1].title);
    expect(tester.takeException(), isNull);
    await tapText(tester, '理由・出典を見て、扱いを決める');
    expect(tester.takeException(), isNull);
  });
}
