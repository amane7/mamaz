// 助産の学習室 — 画面の操作テスト（初答 → 比較 → 別課題 → 振り返り、検索、権限）。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mama_care/charting/insight_store.dart';
import 'package:mama_care/learning/learning_models.dart';
import 'package:mama_care/learning/ui/learning_room_screen.dart';
import 'package:mama_care/ops/ops_state.dart';

void main() {
  late LearningKb kb;
  setUpAll(() {
    kb = LearningKb.parse(File('assets/learning/kb.json').readAsStringSync());
  });

  /// 権限なしの案内はアイコンが動き続けるため、一定時間だけ進める。
  Future<void> settle(WidgetTester tester, {required bool staff}) async {
    if (staff) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }
  }

  Future<OpsState> open(
    WidgetTester tester, {
    bool staff = true,
    Size size = const Size(430, 3200),
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
      expect(ops.role, OpsRole.midwife);
    }
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: ops),
          ChangeNotifierProvider(create: (_) => InsightStore()),
        ],
        child: MaterialApp(home: LearningRoomScreen(kb: kb)),
      ),
    );
    await settle(tester, staff: staff);
    return ops;
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text).first);
    await tester.pumpAndSettle();
  }

  testWidgets('ご家族の権限では学習室の中身を出さない', (tester) async {
    await open(tester, staff: false);
    expect(find.text('専門職向けの画面です'), findsOneWidget);
    expect(find.text('ケース演習'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('権限が外れたら、その場で中身を閉じる', (tester) async {
    final ops = await open(tester);
    expect(find.text('ケース演習'), findsOneWidget);
    ops.returnToFamily();
    await settle(tester, staff: false);
    expect(find.text('専門職向けの画面です'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('初答から振り返りまで（全候補を保留、別課題中は他を開けない、中断と再開）', (tester) async {
    await open(tester);
    expect(find.text('1 / 4　最初の問い'), findsOneWidget);
    expect(find.text('休みに来たのに、授乳の話になった'), findsWidgets);
    expect(find.text('教育用試作 · 端末内で動作'), findsOneWidget);

    // 空のままでは進めない
    await tapText(tester, '自分の問いを残して、参考例を見る');
    expect(find.text('問いと理由をそれぞれ入力してください。'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), '今日はどう過ごしたいですか');
    await tester.enterText(find.byType(TextField).at(1), '本人の希望を先に聞きたい');
    await tapText(tester, '自分の問いを残して、参考例を見る');

    expect(find.text('2 / 4　参考例と比較'), findsOneWidget);
    expect(find.text('端末内検索で初答と観点に近い順 · 監修前の作例'), findsOneWidget);
    expect(find.text('今日ここで何ができたら「来てよかった」と思えそうですか。'), findsOneWidget);
    expect(find.text('この事例では'), findsNWidgets(3));

    // すべて保留のまま、次の一言だけ書いて進む
    await tapText(tester, '参考例を閉じて、別の事例へ');
    expect(find.text('次の一言と理由を入力してください。'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '眠りたい気持ちを先に確かめます');
    await tapText(tester, '参考例を閉じて、別の事例へ');

    expect(find.text('3 / 4　別の事例'), findsOneWidget);
    expect(find.text('別の事例で考える'), findsOneWidget);
    // 参考例は閉じている
    expect(find.text('今日ここで何ができたら「来てよかった」と思えそうですか。'), findsNothing);
    // 他のタブ・他のケースは開けない
    await tester.tap(find.text('知識を探す'));
    await tester.pumpAndSettle();
    expect(find.text('別の事例で考える'), findsOneWidget);
    await tester.tap(find.text('休みに来たのに、授乳の話になった'));
    await tester.pumpAndSettle();
    expect(find.text('すべて架空の事例です。'), findsNothing);

    // 中断すると比較に戻り、書いた一言は残る
    await tapText(tester, '中断して比較に戻る');
    expect(find.text('2 / 4　参考例と比較'), findsOneWidget);
    expect(find.text('眠りたい気持ちを先に確かめます'), findsOneWidget);

    await tapText(tester, '参考例を閉じて、別の事例へ');
    await tester.enterText(find.byType(TextField).first, '夕方に困る場面を具体的に聞きます');
    await tapText(tester, '回答を確定して振り返る');

    expect(find.text('4 / 4　振り返り'), findsOneWidget);
    expect(
      find.text('別課題を一度中断しています。初見時の独力評価には使わず、再練習として振り返ります。'),
      findsOneWidget,
    );
    expect(find.text('本人の選好と家族の要望を区別し、暮らしで困る時を具体化したか。'), findsOneWidget);
    expect(find.textContaining('本人にとっての今日の目標（保留）'), findsOneWidget);

    await tapText(tester, 'このケースを最初から');
    expect(find.text('1 / 4　最初の問い'), findsOneWidget);
    expect(find.text('今日はどう過ごしたいですか'), findsNothing);
  });

  testWidgets('緊急連携ケースは人につなぐ注意を出し、固定順で示す', (tester) async {
    await open(tester);
    await tapText(tester, 'ケースを選ぶ');
    await tapText(tester, 'ケース検討を中断する時');
    expect(find.textContaining('ただちに施設の緊急手順で人へ連絡します'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), '担当者へ連絡します');
    await tester.enterText(find.byType(TextField).at(1), '人につなぐのが先');
    await tapText(tester, '自分の問いを残して、参考例を見る');
    expect(find.text('緊急連携の固定演習 · 監修前の作例'), findsOneWidget);
    final first = tester.getTopLeft(find.text('この場で練習を止め、誰にどんな観察事実を渡しますか。'));
    final second = tester.getTopLeft(find.text('誰が、いつまでに、何を確かめ、誰へ返す予定ですか。'));
    final third = tester.getTopLeft(find.text('誰が観察し、誰に引き継ぎ、実技を誰が確認しますか。'));
    expect(first.dy < second.dy && second.dy < third.dy, isTrue);
  });

  testWidgets('知識を探す：教材と基礎ノート、説明例の開閉、実相談の語句は人につなぐ', (tester) async {
    await open(tester);
    await tapText(tester, '知識を探す');
    expect(find.text('学びたいテーマを入力するか、例を選んでください。'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'プロラクチンと射乳');
    await tapText(tester, '教材を探す');
    expect(find.text('関連する基礎ノート'), findsOneWidget);
    expect(find.text('授乳・乳房'), findsOneWidget);
    final answer = kb.notes.firstWhere((n) => n.label == '基礎科学').selfAnswer;
    expect(find.text(answer), findsNothing);
    await tapText(tester, '自分の説明と比べる');
    expect(find.text(answer), findsOneWidget);
    expect(find.text('説明例を閉じる'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '何錠飲めばいいですか');
    await tapText(tester, '教材を探す');
    expect(find.textContaining('実際の母子については担当の医療者へ'), findsOneWidget);
    expect(find.textContaining('教材カード'), findsNothing);

    await tester.enterText(find.byType(TextField), 'xyz');
    await tapText(tester, '教材を探す');
    expect(find.textContaining('該当する教材を特定できません'), findsOneWidget);
  });

  testWidgets('能力マップから L21 を開く。文献台帳は ID で絞り込める', (tester) async {
    await open(tester);
    await tapText(tester, '能力マップ');
    expect(find.text('横断的な専門実践　16項目'), findsOneWidget);
    expect(find.text('国内実務の学習領域　14領域'), findsOneWidget);
    await tapText(tester, '性と生殖の健康・権利　6項目');
    await tapText(tester, 'L21 避妊の目的と相談の範囲');
    expect(find.text('教材カード · 1件'), findsOneWidget);
    expect(find.text('避妊の目的と相談の範囲'), findsOneWidget);
    expect(find.text('L21 · 監修前の架空演習用作例'), findsOneWidget);

    await tapText(tester, '文献台帳');
    expect(find.text('73件'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'B04');
    await tester.pumpAndSettle();
    expect(find.text('1件'), findsOneWidget);
    expect(find.textContaining('B04　'), findsOneWidget);
  });

  testWidgets('小さい画面でも、ケース一覧は最後までスクロールして選べる', (tester) async {
    await open(tester, size: const Size(390, 600));
    await tapText(tester, 'ケースを選ぶ');
    expect(find.text('すべて架空の事例です。'), findsOneWidget);
    final last = find.text('ケース検討を中断する時');
    await tester.scrollUntilVisible(
      last,
      120,
      scrollable: find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(last);
    await tester.pumpAndSettle();
    expect(find.text('すべて架空の事例です。'), findsNothing);
    expect(find.text('緊急時の連携'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('幅390pxでも横にはみ出さない（4つの画面と接続の説明）', (tester) async {
    await open(tester, size: const Size(390, 844));
    for (final tab in ['知識を探す', '能力マップ', '文献台帳', '現場の気づき', 'ケース演習']) {
      await tapText(tester, tab);
      expect(tester.takeException(), isNull, reason: tab);
    }
    await tester.tap(find.byTooltip('施設内モデルの任意接続'));
    await tester.pumpAndSettle();
    expect(find.textContaining('送るのはケース番号と観点の番号だけです'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
