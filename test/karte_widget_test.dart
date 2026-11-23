// 乳房ケアカルテ — 画面の操作テスト。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mama_care/charting/conversation.dart';
import 'package:mama_care/charting/insight_store.dart';
import 'package:mama_care/charting/ui/chart_assist_screen.dart';
import 'package:mama_care/karte/karte_models.dart';
import 'package:mama_care/karte/karte_store.dart';
import 'package:mama_care/karte/ui/karte_screens.dart';
import 'package:mama_care/learning/learning_models.dart';
import 'package:mama_care/ops/ops_state.dart';

void main() {
  late LearningKb kb;
  setUpAll(() {
    kb = LearningKb.parse(File('assets/learning/kb.json').readAsStringSync());
  });

  Future<KarteStore> open(
    WidgetTester tester, {
    bool staff = true,
    Size size = const Size(430, 9000),
    KarteStore? store,
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
    final kartes = store ?? KarteStore(MemoryKarteStorage());
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: ops),
          ChangeNotifierProvider(create: (_) => InsightStore()),
          ChangeNotifierProvider.value(value: kartes),
        ],
        child: MaterialApp(home: home ?? const KarteListScreen()),
      ),
    );
    if (staff) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }
    return kartes;
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text).first);
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String key, String text) async {
    await tester.enterText(find.byKey(ValueKey(key)), text);
    await tester.pumpAndSettle();
  }

  Future<void> createKarte(WidgetTester tester, String label) async {
    await type(tester, 'karte_new_mother', '試験 花子');
    await type(tester, 'karte_new_child', 'たろう');
    await tapText(tester, label);
  }

  testWidgets('ご家族の権限では中身を出さない', (tester) async {
    await open(tester, staff: false);
    expect(find.text('専門職向けの画面です'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('一覧で、下書きの扱い・保存先・無い機能を示す。氏名なしでは作れない', (tester) async {
    final store = await open(tester);
    expect(find.textContaining('記録はすべて下書きの扱い'), findsOneWidget);
    expect(find.textContaining('確定・署名・印刷の機能はまだありません'), findsOneWidget);
    expect(find.textContaining('暗号化・ほかの端末との共有'), findsOneWidget);
    // テストでは端末の保存先を使っていないので、その旨が出る
    expect(find.textContaining('アプリを閉じると記録が消えます'), findsOneWidget);

    await tapText(tester, 'カルテを作る');
    expect(find.text('氏名を書いてください。'), findsOneWidget);
    expect(store.kartes, isEmpty);
  });

  testWidgets('カルテを作り、紙と同じ欄に書いて、下書きとして保存できる', (tester) async {
    final store = await open(tester);
    await createKarte(tester, 'カルテを作る');
    expect(find.text('氏名：試験 花子'), findsOneWidget);
    expect(find.text('お子様名前：たろう'), findsOneWidget);
    expect(find.text('まだ記録はありません。'), findsOneWidget);

    await tapText(tester, '記録を書く');
    // 紙の様式の見出しと選択肢
    for (final t in [
      'S）', 'O）', 'P）', '【乳房診断】', '【児の発達】', '【家族などのサポート状況】',
      '乳房の形', '乳頭・乳輪の状態', '疼痛', '授乳姿勢', //
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    for (final t in [
      '宝塚', '西宮', '名古屋', '浦和', '訪問', '産後ケア', 'Ⅰ型', 'Ⅱa型', 'Ⅱb型', 'Ⅲ型',
      'ニップル使用', '手動', '電動', '白斑', '亀裂', '発赤', '乳輪', '乳頭', '乳房',
      'カード', 'PayPay', '現金', '初診料 1,000円', '1回 5,500円', 'チケット 14,850円',
      'レンタルタオル 350円', 'ケアタオル 250円', 'その他', '卒乳', '断乳', '硬', '普通', '軟', //
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    // No. は自動で 1。直せる。
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('kf_no')))
          .controller!
          .text,
      '1',
    );

    await type(tester, 'kf_s', '夜に左が張る');
    await type(tester, 'kf_weightG', '4200');
    await type(tester, 'kf_breastPerDay', '8');
    await tapKey(tester, 'kp_place_西宮');
    await tapKey(tester, 'kp_place_産後ケア');
    await tapKey(tester, 'kp_breastShape_Ⅱa型');
    await tapKey(tester, 'kp_breastShape_Ⅲ型'); // 一つだけ選ぶ欄：選び直しになる
    await tapKey(tester, 'kp_nippleState_白斑');
    await tapKey(tester, 'kp_nippleState_亀裂');
    await tapKey(tester, 'kp_fees_first');
    await tapKey(tester, 'kp_fees_single');
    expect(find.textContaining('合計　6,500円'), findsOneWidget);

    // 乳房図：右の円の中心を押すと印が付き、もう一度押すと消える
    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey('breast_R'))),
    );
    await tester.pumpAndSettle();
    expect(find.text('右　中心付近'), findsOneWidget);
    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey('breast_R'))),
    );
    await tester.pumpAndSettle();
    expect(find.text('右　中心付近'), findsNothing);
    final c = tester.getCenter(find.byKey(const ValueKey('breast_L')));
    await tester.tapAt(c + const Offset(0, -40));
    await tester.pumpAndSettle();
    expect(find.textContaining('左　12時の方向'), findsOneWidget);

    expect(store.kartes.single.visits, isEmpty); // 保存を押すまでは入らない
    await tapText(tester, '下書きとして保存');

    final v = store.kartes.single.visits.single;
    expect(v.t(KF.s), '夜に左が張る');
    expect(v.t(KF.weightG), '4200');
    expect(v.t(KF.breastPerDay), '8');
    expect(v.t(KF.no), '1');
    expect(v.p(KP.place), ['西宮', '産後ケア']);
    expect(v.p(KP.breastShape), ['Ⅲ型']);
    expect(v.p(KP.nippleState), ['白斑', '亀裂']);
    expect(v.feeTotal, 6500);
    expect(v.marks.single.side, 'L');
    expect(v.source, isEmpty);

    // 1冊の画面に戻り、記録が「下書き」として並ぶ
    expect(find.text('記録　1件'), findsOneWidget);
    expect(find.text('S）夜に左が張る'), findsOneWidget);
    expect(find.text('下書き'), findsWidgets);

    // 開いてなおす → 同じ記録が置き換わる
    await tapText(tester, 'S）夜に左が張る');
    expect(find.text('記録をなおす'), findsOneWidget);
    await type(tester, 'kf_p', '3日後に再診');
    await tapText(tester, '下書きとして保存');
    expect(store.kartes.single.visits.single.t(KF.p), '3日後に再診');
    expect(store.kartes.single.visits.single.t(KF.s), '夜に左が張る');
  });

  testWidgets('暦に無い日付では保存しない', (tester) async {
    final store = await open(tester);
    await createKarte(tester, 'カルテを作る');
    await tapText(tester, '記録を書く');
    await type(tester, 'kd_month', '2');
    await type(tester, 'kd_day', '30');
    await tapText(tester, '下書きとして保存');
    expect(find.textContaining('日付を確かめてください'), findsOneWidget);
    expect(store.kartes.single.visits, isEmpty);
  });

  testWidgets('書きかけで戻ろうとすると確かめる。保存せずに閉じれば入らない', (tester) async {
    final store = await open(tester);
    await createKarte(tester, 'カルテを作る');
    await tapText(tester, '記録を書く');
    await type(tester, 'kf_s', '書きかけ');
    await tester.tap(find.byTooltip('前の画面にもどる'));
    await tester.pumpAndSettle();
    expect(find.text('保存せずに閉じますか？'), findsOneWidget);
    await tapText(tester, 'もどる');
    expect(find.text('記録を書く'), findsOneWidget);

    await tester.tap(find.byTooltip('前の画面にもどる'));
    await tester.pumpAndSettle();
    await tapText(tester, '保存せずに閉じる');
    expect(find.text('まだ記録はありません。'), findsOneWidget);
    expect(store.kartes.single.visits, isEmpty);
  });

  testWidgets('記録とカルテを、確かめたうえで削除できる', (tester) async {
    final store = await open(tester);
    await createKarte(tester, 'カルテを作る');
    await tapText(tester, '記録を書く');
    await type(tester, 'kf_s', '消す記録');
    await tapText(tester, '下書きとして保存');
    await tapText(tester, 'S）消す記録');
    await tapText(tester, 'この記録を削除');
    expect(find.text('この記録を削除しますか？'), findsOneWidget);
    await tapText(tester, '削除する');
    expect(store.kartes.single.visits, isEmpty);

    await tapText(tester, 'このカルテを削除');
    expect(find.textContaining('元に戻せません'), findsOneWidget);
    await tapText(tester, '削除する');
    expect(store.kartes, isEmpty);
    expect(find.text('カルテ　0件'), findsOneWidget);
  });

  testWidgets('会話の下書きを、選んだカルテの下書きに持ち込める。保存するまでは入らない', (tester) async {
    final store = await open(tester, home: ChartAssistScreen(kb: kb));
    final sample = kSampleConversations[1];
    await tapText(tester, sample.title);
    expect(find.textContaining('実在の方のカルテには入れないでください'), findsOneWidget);
    await tapText(tester, 'カルテを選んで、下書きに入れる');

    expect(find.text('どのカルテの下書きに入れますか'), findsOneWidget);
    expect(find.textContaining('持ち込むのは架空の会話例です'), findsOneWidget);
    await createKarte(tester, 'カルテを作って、下書きを入れる');

    // 記録の画面：S）に発言がそのまま入り、未確認の点が付いている
    expect(find.text('会話の下書きから持ち込んだ記録です'), findsOneWidget);
    expect(find.text('まだ確かめていない点'), findsOneWidget);
    final s = tester
        .widget<TextField>(find.byKey(const ValueKey('kf_s')))
        .controller!
        .text;
    for (final u in sample.lines) {
      if (u.speaker != Speaker.midwife && u.text.length > 4) {
        expect(s, contains(u.text));
      }
    }
    // 数値の欄は埋めていない（会話に「2800グラム」とあっても、体重の欄は空）
    expect(sample.lines.any((u) => u.text.contains('2800')), isTrue);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('kf_weightG')))
          .controller!
          .text,
      isEmpty,
    );
    expect(store.kartes.single.visits, isEmpty);

    await tapText(tester, '下書きとして保存');
    final v = store.kartes.single.visits.single;
    expect(v.source, '架空の会話例「${sample.title}」');
    expect(v.openPoints, isNotEmpty);
    expect(v.t(KF.s), s.trim());
    expect(find.text('まだ確かめていない点 ${v.openPoints.length}件'), findsOneWidget);
    expect(find.textContaining('会話の下書きから：架空の会話例'), findsOneWidget);

    // 「確かめた」を押して保存すると、その点が外れる
    final before = v.openPoints.length;
    await tapText(tester, 'まだ確かめていない点 $before件');
    await tapText(tester, '確かめた');
    await tapText(tester, '下書きとして保存');
    expect(store.kartes.single.visits.single.openPoints.length, before - 1);
  });

  testWidgets('幅390pxでも横にはみ出さない（一覧・1冊・記録）', (tester) async {
    await open(tester, size: const Size(390, 9000));
    expect(tester.takeException(), isNull);
    await createKarte(tester, 'カルテを作る');
    expect(tester.takeException(), isNull);
    await tapText(tester, '記録を書く');
    expect(tester.takeException(), isNull);
    await tapKey(tester, 'kp_fees_ticket');
    await type(tester, 'kf_s', 'あ' * 300);
    await tapText(tester, '下書きとして保存');
    expect(tester.takeException(), isNull);
  });
}
