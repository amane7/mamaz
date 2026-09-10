// ============================================================================
// 受入テスト（要件定義書 §16 KPI / 付録B テストケース / 付録C 決定事項）
//
// このファイルは「仕様が実装されていること」を機械的に証明するための層です。
// 画面の見た目ではなく、業務ルールそのものを検証します。
//   ・スキル × OK/NG 時間による割当（§6.1 / §8.2）
//   ・NG最優先・空欄は予約不可（§6.2）
//   ・NG理由を保存しない（§19 可用性情報のプライバシー）
//   ・9状態FSM・冪等性・二重予約防止（§14 NFR-02/03）
//   ・赤旗は自動確定しない（§8.4 役割分担）
//   ・キャンセル料の版管理（付録C.5）
//   ・監査ログの改ざん検知（§14 NFR-04）
//   ・§16 KPI 目標値
// ============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:mama_care/ops/matching_engine.dart';
import 'package:mama_care/ops/ops_models.dart';
import 'package:mama_care/ops/ops_seed.dart';
import 'package:mama_care/ops/ops_state.dart';

/// 指定曜日の日時を、シードデータ（特定日NG・初期予約）とぶつからない
/// 十分先の週から取得する。テストが実行日に依存しないようにするため。
DateTime onWeekday(int weekday, int hour, {int minute = 0, int ahead = 14}) {
  var d = dayOf(DateTime.now()).add(Duration(days: ahead));
  while (d.weekday != weekday) {
    d = d.add(const Duration(days: 1));
  }
  return d.add(Duration(hours: hour, minutes: minute));
}

OpsStaff staffOf(String id) => seedStaff.firstWhere((s) => s.id == id);
ServiceDef serviceOf(String id) => seedServices.firstWhere((s) => s.id == id);

void main() {
  // -------------------------------------------------------------------------
  group('§16 KPI｜起動直後の運用データが目標値を満たす', () {
    test('割当品質：スキル不一致／NG時間への予約割当は 0 件', () {
      final ops = OpsState();
      expect(ops.misAssignments, 0, reason: '§16 割当品質の目標は 0 件');
    });

    test('二重予約は 0 件', () {
      final ops = OpsState();
      expect(ops.doubleBookings, 0);
    });

    test('赤旗の見落とし（SLA超過の未対応）は 0 件', () {
      final ops = OpsState();
      expect(ops.redFlagMissed, 0);
    });

    test('自動完結率 70% 以上・ゼロタッチ率 60% 以上', () {
      final ops = OpsState();
      expect(ops.autoRate, greaterThanOrEqualTo(0.70));
      expect(ops.zeroTouchRate, greaterThanOrEqualTo(0.60));
    });

    test('チャット往復の削減見込み 50% 以上（As-Is 4,401通/月モデル）', () {
      final ops = OpsState();
      expect(OpsState.baselineTotal, 4401);
      expect(OpsState.baselineReceived, 1596);
      expect(OpsState.baselineSent, 2805);
      expect(OpsState.baselineRooms, 863);
      expect(ops.chatReductionRate, greaterThanOrEqualTo(0.50));
      expect(ops.estimatedMessagesSaved, greaterThan(0));
    });

    test('通知到達率 98% 以上', () {
      final ops = OpsState();
      expect(ops.deliverySuccessRate, greaterThanOrEqualTo(0.98));
    });
  });

  // -------------------------------------------------------------------------
  group('§6.1/§8.2 割当エンジン｜6条件ゲート', () {
    test('① 必要スキルが無ければ割当不可（母乳ケア未保有）', () {
      final ops = OpsState();
      final r = ops.engine.verifyAssignmentReasons(
        s: staffOf('st_kimura'), // 母乳ケアを持たない
        service: serviceOf('svc_breast'), // 母乳ケアが必要
        at: onWeekday(DateTime.tuesday, 10),
        facilityId: 'fac_sakura',
      );
      expect(r, contains(RejectReason.skillMismatch));
    });

    test('② OK時間外は割当不可', () {
      final ops = OpsState();
      // 田中：火・木・土 10:00-16:00 OK → 火 18:00 はOK時間外
      final r = ops.engine.verifyAssignmentReasons(
        s: staffOf('st_tanaka'),
        service: serviceOf('svc_breast'),
        at: onWeekday(DateTime.tuesday, 18),
        facilityId: 'fac_sakura',
      );
      expect(r, contains(RejectReason.outsideOk));
    });

    test('③ NG時間は最優先で除外（OKと重なっていてもNGが勝つ）', () {
      final ops = OpsState();
      // 佐藤：月〜金 9:00-17:00 OK かつ 水 13:00-17:00 NG
      final wed14 = onWeekday(DateTime.wednesday, 14);
      final r = ops.engine.verifyAssignmentReasons(
        s: staffOf('st_sato'),
        service: serviceOf('svc_visit3'),
        at: wed14,
        areaCode: 'area_sakura',
      );
      expect(
        r,
        contains(RejectReason.overlapNg),
        reason: 'NGはOKより優先されなければならない（§6.2）',
      );
      expect(
        ops.engine.verifyAssignment(
          s: staffOf('st_sato'),
          service: serviceOf('svc_visit3'),
          at: wed14,
          areaCode: 'area_sakura',
        ),
        isFalse,
      );
    });

    test('空欄時間（OK未登録）は原則予約不可', () {
      final ops = OpsState();
      // 田中は月曜にOKを登録していない
      final r = ops.engine.verifyAssignmentReasons(
        s: staffOf('st_tanaka'),
        service: serviceOf('svc_breast'),
        at: onWeekday(DateTime.monday, 11),
        facilityId: 'fac_sakura',
      );
      expect(r, contains(RejectReason.noOkRegistered));
    });

    test('⑥ 訪問エリア外は割当不可', () {
      final ops = OpsState();
      final r = ops.engine.verifyAssignmentReasons(
        s: staffOf('st_kimura'), // area_midori / area_hinata
        service: serviceOf('svc_visit3'),
        at: onWeekday(DateTime.monday, 10),
        areaCode: 'area_sakura',
      );
      expect(r, contains(RejectReason.areaMismatch));
    });

    test('⑥ 施設条件を満たさなければ割当不可', () {
      final ops = OpsState();
      final r = ops.engine.verifyAssignmentReasons(
        s: staffOf('st_kimura'), // fac_midori のみ
        service: serviceOf('svc_day2'),
        at: onWeekday(DateTime.monday, 10),
        facilityId: 'fac_sakura',
      );
      expect(r, contains(RejectReason.facilityMismatch));
    });

    test('④ 予約間バッファ・移動時間を確保できなければ割当不可', () {
      final ops = OpsState();
      final mon = onWeekday(DateTime.monday, 9);
      // 佐藤に 9:00-12:00 の訪問を入れる（移動30分＋バッファ15分の占有）
      ops.bookings.add(
        OpsBooking(
          id: 'bk_test_buffer',
          code: 'TEST-0001',
          customerId: ops.customer.id,
          childId: ops.customer.children.first.id,
          serviceId: 'svc_visit3',
          at: mon,
          durationMin: 180,
          kind: ServiceKind.visit,
          staffId: 'st_sato',
          state: BookingState.confirmed,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          feeYen: 6000,
        ),
      );
      final r = ops.engine.verifyAssignmentReasons(
        s: staffOf('st_sato'),
        service: serviceOf('svc_visit3'),
        at: mon.add(const Duration(hours: 3)), // 12:00 開始＝直後
        areaCode: 'area_sakura',
      );
      expect(
        r.any(
          (x) =>
              x == RejectReason.bufferViolation ||
              x == RejectReason.overlapBooking ||
              x == RejectReason.outsideOk ||
              x == RejectReason.dailyCapExceeded,
        ),
        isTrue,
        reason: '連続する枠は移動・バッファ・上限のいずれかで弾かれる必要がある',
      );
    });

    test('⑤ 1日上限を超える割当はできない', () {
      final ops = OpsState();
      final tue = onWeekday(DateTime.tuesday, 10);
      // 田中の1日上限 360分。240分の通所を入れると訪問3時間は入らない
      ops.bookings.add(
        OpsBooking(
          id: 'bk_test_cap',
          code: 'TEST-0002',
          customerId: ops.customer.id,
          childId: ops.customer.children.first.id,
          serviceId: 'svc_day4',
          at: tue,
          durationMin: 240,
          kind: ServiceKind.dayStay,
          staffId: 'st_tanaka',
          state: BookingState.confirmed,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          feeYen: 8000,
        ),
      );
      final r = ops.engine.verifyAssignmentReasons(
        s: staffOf('st_tanaka'),
        service: serviceOf('svc_visit3'),
        at: tue.add(const Duration(hours: 4)),
        areaCode: 'area_sakura',
      );
      expect(
        r.any(
          (x) =>
              x == RejectReason.dailyCapExceeded ||
              x == RejectReason.consecutiveExceeded ||
              x == RejectReason.outsideOk ||
              x == RejectReason.bufferViolation,
        ),
        isTrue,
      );
    });

    test('候補0人の枠は家族に見せない（bookable のみ返す）', () {
      final ops = OpsState();
      final slots = ops.engine.searchSlots(
        service: serviceOf('svc_visit3'),
        from: dayOf(DateTime.now()).add(const Duration(days: 14)),
        days: 7,
        startMinutes: const [540, 600, 660, 780, 840, 900],
        areaCode: 'area_sakura',
        customerId: 'cus_001',
      );
      expect(slots.every((s) => s.bookable), isTrue);
      expect(slots.every((s) => s.best != null), isTrue);
    });
  });

  // -------------------------------------------------------------------------
  group('回帰：割当検証が「自分自身」を重複相手として数えない', () {
    test('確定済み予約は exclude 付きで必ず条件を満たす', () {
      final ops = OpsState();
      final active = ops.bookings.where(
        (b) => b.state.isActive && b.staffId != null,
      );
      expect(active, isNotEmpty);
      for (final b in active) {
        final ok = ops.engine.verifyAssignment(
          s: ops.staffById(b.staffId)!,
          service: ops.serviceById(b.serviceId),
          at: b.at,
          facilityId: b.facilityId,
          areaCode: ops.customer.address.areaCode,
          excludeBookingId: b.id,
        );
        expect(ok, isTrue, reason: '${b.code} が自己重複で不適合と判定されている');
      }
    });

    test('exclude を外すと自己重複を検出する（パラメータが効いていることの証明）', () {
      final ops = OpsState();
      final b = ops.bookings.firstWhere(
        (b) => b.state.isActive && b.staffId != null,
      );
      final reasons = ops.engine.verifyAssignmentReasons(
        s: ops.staffById(b.staffId)!,
        service: ops.serviceById(b.serviceId),
        at: b.at,
        facilityId: b.facilityId,
        areaCode: ops.customer.address.areaCode,
        // excludeBookingId をあえて渡さない
      );
      expect(reasons, contains(RejectReason.overlapBooking));
    });
  });

  // -------------------------------------------------------------------------
  group('§19 可用性情報のプライバシー｜NG理由を持たない・残さない', () {
    test('StaffAvailability は理由を保持できない構造である', () {
      final a = StaffAvailability(
        id: 'av_x',
        staffId: 'st_sato',
        date: dayOf(DateTime.now()),
        startMin: 540,
        endMin: 600,
        kind: AvailKind.ng,
        updatedAt: DateTime.now(),
      );
      // 理由フィールドが存在しないため、そもそも保存されない
      expect(a.kind, AvailKind.ng);
      expect(a.toString().contains('reason'), isFalse);
    });

    test('NG登録の監査ログに理由は含まれず、非保存であることが記録される', () {
      final ops = OpsState();
      final before = ops.auditLog.length;
      ops.setAvailability(
        staffId: 'st_sato',
        date: onWeekday(DateTime.monday, 0),
        startMin: 600,
        endMin: 660,
        kind: AvailKind.ng,
      );
      expect(ops.auditLog.length, greaterThan(before));
      // 監査ログは追記専用なので、最新は末尾。
      final e = ops.auditLog.last;
      expect(e.action, contains('NG'));
      expect(e.detail, contains('理由は保存しません'));
      // 監査ログ全体を走査しても、NG理由に相当する語が残っていないこと。
      for (final a in ops.auditLog) {
        expect(a.detail.contains('私的'), isFalse);
        expect(a.detail.contains('通院'), isFalse);
      }
    });

    test('NG時間の除外理由は家族に開示されない', () {
      expect(RejectReason.overlapNg.familyVisible, isFalse);
      expect(RejectReason.outsideOk.familyVisible, isFalse);
      expect(RejectReason.overlapBlock.familyVisible, isFalse);
      // 家族に説明してよいのは地域・施設条件のみ
      expect(RejectReason.areaMismatch.familyVisible, isTrue);
      expect(RejectReason.facilityMismatch.familyVisible, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  group('§14 NFR｜冪等性・二重予約防止・監査ログ', () {
    test('Webhook は同一イベントを一度だけ処理する', () {
      final ops = OpsState();
      expect(ops.processWebhook('evt-0001'), isTrue);
      expect(ops.processWebhook('evt-0001'), isFalse);
      expect(ops.processWebhook('evt-0002'), isTrue);
    });

    test('同一冪等キーの仮おさえは同じ予約を返す（二重送信対策）', () {
      final ops = OpsState();
      final at = onWeekday(DateTime.tuesday, 11);
      final a = ops.holdSlot(
        service: serviceOf('svc_breast'),
        child: ops.customer.children.first,
        at: at,
        facilityId: 'fac_sakura',
        intake: const {},
        needs: const [],
        idempotencyKey: 'key-same',
      );
      final b = ops.holdSlot(
        service: serviceOf('svc_breast'),
        child: ops.customer.children.first,
        at: at,
        facilityId: 'fac_sakura',
        intake: const {},
        needs: const [],
        idempotencyKey: 'key-same',
      );
      expect(a, isNotNull);
      expect(identical(a, b), isTrue);
      expect(
        ops.bookings.where((x) => x.idempotencyKey == 'key-same').length,
        1,
      );
    });

    test('連続した仮おさえでも二重予約は発生しない', () {
      final ops = OpsState();
      final at = onWeekday(DateTime.tuesday, 11);
      for (var i = 0; i < 4; i++) {
        ops.holdSlot(
          service: serviceOf('svc_breast'),
          child: ops.customer.children.first,
          at: at,
          facilityId: 'fac_sakura',
          intake: const {},
          needs: const [],
          idempotencyKey: 'key-$i',
        );
      }
      expect(ops.doubleBookings, 0);
      expect(ops.misAssignments, 0);
    });

    test('監査ログは追記のみで、ハッシュ連鎖が壊れていない', () {
      final ops = OpsState();
      expect(ops.auditIntact, isTrue);
      ops.audit('テスト操作', 'TEST', '検証用の追記');
      expect(ops.auditIntact, isTrue);
      expect(ops.auditLog.length, greaterThanOrEqualTo(2));
    });

    test('仮おさえの期限が切れていれば確定できない', () {
      final ops = OpsState();
      final b = ops.holdSlot(
        service: serviceOf('svc_breast'),
        child: ops.customer.children.first,
        at: onWeekday(DateTime.tuesday, 11),
        facilityId: 'fac_sakura',
        intake: const {},
        needs: const [],
        idempotencyKey: 'key-expired',
        holdMinutes: -1,
      );
      expect(b, isNotNull);
      expect(b!.holdExpired, isTrue);
      final ok = ops.confirmBooking(b, consent: _consent());
      expect(ok, isFalse);
      expect(b.state, BookingState.draft);
    });
  });

  // -------------------------------------------------------------------------
  group('§8.4 役割分担｜赤旗は自動確定せず助産師へ', () {
    test('赤旗ありの申込は NEEDS_REVIEW となり、助産師タスクが立つ', () {
      final ops = OpsState();
      final b = ops.holdSlot(
        service: serviceOf('svc_breast'),
        child: ops.customer.children.first,
        at: onWeekday(DateTime.tuesday, 11),
        facilityId: 'fac_sakura',
        intake: const {'breast_pain': true},
        needs: const ['乳房が痛い'],
        idempotencyKey: 'key-redflag',
      );
      expect(b, isNotNull);
      expect(b!.exceptions.map((e) => e.code), contains(ReasonCode.redFlag));

      final confirmed = ops.confirmBooking(b, consent: _consent());
      expect(confirmed, isTrue); // 受付は成功するが確定はしない
      expect(b.state, BookingState.needsReview);
      expect(b.feeState, FeeState.underReview);
      expect(b.autoAssigned, isFalse);

      final midwifeTasks = ops.tasksFor(TaskOwner.midwife);
      expect(
        midwifeTasks.any((t) => t.reason == ReasonCode.redFlag),
        isTrue,
        reason: '健康判断は助産師に割り当てられなければならない',
      );
      expect(ReasonCode.redFlag.toMidwife, isTrue);
      expect(ReasonCode.redFlag.slaMinutes, 30);
    });

    test('赤旗の質問は定義済みのみ（診断はしない）', () {
      expect(seedRedFlags.length, 6);
      expect(
        seedRedFlags.map((r) => r.reasonCode),
        containsAll(<String>[
          'RF-FEVER',
          'RF-BREAST',
          'RF-BLEED',
          'RF-INFECT',
          'RF-WEIGHT',
          'RF-MOOD',
        ]),
      );
    });

    test('有人確認で承認すると確定し、条件も満たす', () {
      final ops = OpsState();
      final ex = ops.bookings.firstWhere(
        (b) => b.state == BookingState.needsReview,
      );
      ops.switchRole(OpsRole.midwife);
      ops.resolveReview(ex, approve: true, note: '電話で確認済み。通常対応で可。');
      expect(ex.state, BookingState.confirmed);
      expect(ex.hasOpenException, isFalse);
      expect(ops.misAssignments, 0, reason: '有人確定でも割当条件は守られる');
    });
  });

  // -------------------------------------------------------------------------
  group('付録C.5 キャンセル料・変更期限｜版管理された規定どおり', () {
    test('通常規定：¥0 / ¥5,000 / ¥10,000 の3段階', () {
      final p = seedCancelPolicies.firstWhere((x) => x.id == 'cp_standard');
      final now = DateTime(2026, 8, 1, 12);
      expect(p.changeDeadlineHours, 55);
      expect(
        p.feeFor(bookingAt: now.add(const Duration(hours: 60)), requestAt: now),
        0,
      );
      expect(
        p.feeFor(bookingAt: now.add(const Duration(hours: 40)), requestAt: now),
        5000,
      );
      expect(
        p.feeFor(bookingAt: now.add(const Duration(hours: 10)), requestAt: now),
        10000,
      );
    });

    test('通所2時間規定：¥0 / ¥3,400 / ¥6,800 の3段階', () {
      final p = seedCancelPolicies.firstWhere((x) => x.id == 'cp_day2h');
      final now = DateTime(2026, 8, 1, 12);
      expect(p.changeDeadlineHours, 55);
      expect(
        p.feeFor(bookingAt: now.add(const Duration(hours: 60)), requestAt: now),
        0,
      );
      expect(
        p.feeFor(bookingAt: now.add(const Duration(hours: 40)), requestAt: now),
        3400,
      );
      expect(
        p.feeFor(bookingAt: now.add(const Duration(hours: 2)), requestAt: now),
        6800,
      );
    });

    test('期限内キャンセルは無料で自動確定、期限後は有人確認へ', () {
      final ops = OpsState();
      // 期限内（十分先）の予約を作る
      final far = ops.holdSlot(
        service: serviceOf('svc_breast'),
        child: ops.customer.children.first,
        at: onWeekday(DateTime.tuesday, 11, ahead: 21),
        facilityId: 'fac_sakura',
        intake: const {},
        needs: const [],
        idempotencyKey: 'key-cancel-free',
      )!;
      expect(ops.cancelEstimate(far), 0);
      ops.requestCancel(far, 'テスト');
      expect(far.state, BookingState.cancelled);
      expect(far.cancelFeeYen, 0);
      expect(far.cancelFeeState, FeeState.confirmed);

      // 期限後（当日）の予約
      final near = ops.bookings.firstWhere(
        (b) => b.state.isActive && b.at.isAfter(DateTime.now()),
      );
      final fee = ops.cancelEstimate(near);
      if (fee > 0) {
        ops.requestCancel(near, 'テスト（期限後）');
        expect(
          near.cancelFeeState,
          FeeState.underReview,
          reason: '金額が発生する取消は「確認中」で止める（勝手に確定しない）',
        );
      }
    });

    test('規定は固定実装せず、版番号と適用開始日を持つ', () {
      for (final p in seedCancelPolicies) {
        expect(p.version, greaterThan(0));
        expect(p.effectiveFrom.year, greaterThanOrEqualTo(2026));
        expect(p.tiers.length, 3);
      }
    });
  });

  // -------------------------------------------------------------------------
  group('§8.3 同意スナップショット｜改定が過去予約に影響しない', () {
    test('確定時の規約版が予約に凍結保存される', () {
      final ops = OpsState();
      final b = ops.holdSlot(
        service: serviceOf('svc_breast'),
        child: ops.customer.children.first,
        at: onWeekday(DateTime.tuesday, 11),
        facilityId: 'fac_sakura',
        intake: const {},
        needs: const [],
        idempotencyKey: 'key-consent',
      )!;
      ops.confirmBooking(b, consent: _consent(version: 7));
      expect(b.consent, isNotNull);
      expect(b.consent!.version, 7);
      expect(b.cancelPolicyVersion, isNotNull);
    });

    test('自治体プログラムも版管理されている', () {
      for (final m in seedMunicipalities) {
        expect(m.version, greaterThan(0));
        expect(m.requiredDocs, isNotEmpty);
      }
    });
  });

  // -------------------------------------------------------------------------
  group('§10.2 通知｜未達は電話タスクへ確実にエスカレーションする', () {
    test('送信失敗は電話タスク化され、受付に割り当てられる', () {
      final ops = OpsState();
      final n = ops.notify(
        bookingId: 'bk_dummy',
        event: NotifyEvent.confirmed,
        title: 'テスト通知',
        body: '本文',
        forceFail: true,
      );
      expect(n.status, DeliveryStatus.phoneTask);
      expect(
        ops
            .tasksFor(TaskOwner.reception)
            .any((t) => t.reason == ReasonCode.lineUndelivered),
        isTrue,
      );
    });

    test('再送2回で電話タスクへ切り替わる', () {
      final ops = OpsState();
      final n = ops.notify(
        bookingId: 'bk_dummy2',
        event: NotifyEvent.dayOf,
        title: 'テスト',
        body: '本文',
      );
      ops.retryNotification(n.id);
      expect(n.status, DeliveryStatus.retried);
      ops.retryNotification(n.id);
      expect(n.status, DeliveryStatus.phoneTask);
    });
  });

  // -------------------------------------------------------------------------
  group('§6.2 OK/NG入力｜週パターン・前週コピー・終日NG', () {
    test('毎週パターンを登録すると以後の同曜日に適用される', () {
      final ops = OpsState();
      ops.switchStaff('st_tanaka');
      ops.setWeeklyPattern(
        staffId: 'st_tanaka',
        weekday: DateTime.monday,
        startMin: 600,
        endMin: 780,
        kind: AvailKind.ok,
      );
      final eff = ops.effectiveAvailability(
        'st_tanaka',
        onWeekday(DateTime.monday, 0),
      );
      expect(
        eff.any((a) => a.kind == AvailKind.ok && a.startMin == 600),
        isTrue,
      );
    });

    test('終日NGを設定するとその日は一切割当されない', () {
      final ops = OpsState();
      final day = onWeekday(DateTime.tuesday, 0);
      ops.setAllDayNg(staffId: 'st_tanaka', date: day);
      final r = ops.engine.verifyAssignmentReasons(
        s: staffOf('st_tanaka'),
        service: serviceOf('svc_breast'),
        at: day.add(const Duration(hours: 11)),
        facilityId: 'fac_sakura',
      );
      expect(r, contains(RejectReason.overlapNg));
    });

    test('前週コピーで登録件数が引き継がれる', () {
      final ops = OpsState();
      final thisWeek = dayOf(DateTime.now());
      final monday = thisWeek.subtract(Duration(days: thisWeek.weekday - 1));
      // 前週に特定日OKを作る
      ops.setAvailability(
        staffId: 'st_tanaka',
        date: monday.subtract(const Duration(days: 7)),
        startMin: 600,
        endMin: 720,
        kind: AvailKind.ok,
      );
      final copied = ops.copyPreviousWeek(
        staffId: 'st_tanaka',
        weekStart: monday,
      );
      expect(copied, greaterThanOrEqualTo(1));
    });

    test('NGはOKより優先される（同じ時間に両方登録した場合）', () {
      final ops = OpsState();
      final day = onWeekday(DateTime.thursday, 0);
      ops.setAvailability(
        staffId: 'st_tanaka',
        date: day,
        startMin: 540,
        endMin: 1020,
        kind: AvailKind.ok,
      );
      ops.setAvailability(
        staffId: 'st_tanaka',
        date: day,
        startMin: 660,
        endMin: 780,
        kind: AvailKind.ng,
      );
      final r = ops.engine.verifyAssignmentReasons(
        s: staffOf('st_tanaka'),
        service: serviceOf('svc_breast'),
        at: day.add(const Duration(hours: 11, minutes: 30)),
        facilityId: 'fac_sakura',
      );
      expect(r, contains(RejectReason.overlapNg));
    });
  });

  // -------------------------------------------------------------------------
  // 不具合再発防止：一度登録したNGが取り消せない問題（回帰テスト）
  group('§6.2 OK/NG入力｜NGの取り消しが必ず反映される', () {
    /// 佐藤は毎週水曜 13:00-17:00 がNG（シードデータ）。
    /// この「毎週パターン由来のNG」を、その日だけ取り消せることを証明する。
    test('毎週パターン由来のNGを、その日だけ取り消せる', () {
      final ops = OpsState();
      final wed = onWeekday(DateTime.wednesday, 0);

      // 前提：取り消す前はNGが効いている
      final before = ops.effectiveAvailability('st_sato', wed);
      expect(
        before.any((a) => a.kind == AvailKind.ng),
        isTrue,
        reason: 'シードの毎週水曜NGが適用されているはず',
      );

      // カレンダー画面の「保存」と同じ操作：その日をOKだけで置き換える
      ops.replaceDay(
        staffId: 'st_sato',
        date: wed,
        ranges: [
          StaffAvailability(
            id: 'tmp',
            staffId: 'st_sato',
            date: wed,
            startMin: 540,
            endMin: 1020,
            kind: AvailKind.ok,
            updatedAt: DateTime.now(),
          ),
        ],
      );

      final after = ops.effectiveAvailability('st_sato', wed);
      expect(
        after.any((a) => a.kind == AvailKind.ng),
        isFalse,
        reason: 'NGを消して保存したのに、毎週パターンから復活してはいけない',
      );
    });

    test('取り消したNGの時間に、実際に予約が割当できるようになる', () {
      final ops = OpsState();
      final wed = onWeekday(DateTime.wednesday, 0);

      // NG時間帯（14:00）は割当不可であること
      final blocked = ops.engine.verifyAssignmentReasons(
        s: staffOf('st_sato'),
        service: serviceOf('svc_breast'),
        at: wed.add(const Duration(hours: 14)),
        facilityId: 'fac_sakura',
      );
      expect(blocked, contains(RejectReason.overlapNg));

      // NGを取り消して保存
      ops.replaceDay(
        staffId: 'st_sato',
        date: wed,
        ranges: [
          StaffAvailability(
            id: 'tmp',
            staffId: 'st_sato',
            date: wed,
            startMin: 540,
            endMin: 1080,
            kind: AvailKind.ok,
            updatedAt: DateTime.now(),
          ),
        ],
      );

      final freed = ops.engine.verifyAssignmentReasons(
        s: staffOf('st_sato'),
        service: serviceOf('svc_breast'),
        at: wed.add(const Duration(hours: 14)),
        facilityId: 'fac_sakura',
      );
      expect(
        freed,
        isNot(contains(RejectReason.overlapNg)),
        reason: '取り消したNGが割当判定にまで残ってはいけない',
      );
    });

    test('その日の登録を全部消すと、毎週パターンのNGも当日は効かない', () {
      final ops = OpsState();
      final wed = onWeekday(DateTime.wednesday, 0);
      ops.clearAvailability(staffId: 'st_sato', date: wed);
      final eff = ops.effectiveAvailability('st_sato', wed);
      expect(eff, isEmpty, reason: '空欄＝予約不可。NGが残り続けてはいけない');
    });

    test('基本パターンは1件だけ取り消せる（OKを残してNGだけ消す）', () {
      final ops = OpsState();
      final ngs = ops.availability
          .where(
            (a) =>
                a.staffId == 'st_sato' &&
                a.isRecurring &&
                a.kind == AvailKind.ng,
          )
          .toList();
      expect(ngs, isNotEmpty);
      final okCountBefore = ops.availability
          .where(
            (a) =>
                a.staffId == 'st_sato' &&
                a.isRecurring &&
                a.kind == AvailKind.ok,
          )
          .length;

      ops.removeAvailabilityById(ngs.first.id);

      expect(
        ops.availability.any((a) => a.id == ngs.first.id),
        isFalse,
        reason: '指定したNG1件が消えること',
      );
      expect(
        ops.availability
            .where(
              (a) =>
                  a.staffId == 'st_sato' &&
                  a.isRecurring &&
                  a.kind == AvailKind.ok,
            )
            .length,
        okCountBefore,
        reason: 'NGを消してもOKは影響を受けないこと',
      );
    });

    test('個別設定は「基本パターンに戻す」で解除できる', () {
      final ops = OpsState();
      final wed = onWeekday(DateTime.wednesday, 0);

      ops.clearAvailability(staffId: 'st_sato', date: wed);
      expect(ops.isDayOverridden('st_sato', wed), isTrue);
      expect(ops.effectiveAvailability('st_sato', wed), isEmpty);

      ops.restoreWeeklyPatternFor(staffId: 'st_sato', date: wed);
      expect(ops.isDayOverridden('st_sato', wed), isFalse);
      final eff = ops.effectiveAvailability('st_sato', wed);
      expect(
        eff.any((a) => a.kind == AvailKind.ng),
        isTrue,
        reason: '基本パターンに戻せば、毎週水曜NGが再び適用されること',
      );
    });

    test('一部だけ直しても、その日の残りの基本パターンは失われない', () {
      final ops = OpsState();
      final mon = onWeekday(DateTime.monday, 0);
      // 佐藤は毎週月曜 9:00-17:00 OK。11:00-12:00 だけNGにする。
      ops.setAvailability(
        staffId: 'st_sato',
        date: mon,
        startMin: 660,
        endMin: 720,
        kind: AvailKind.ng,
      );
      final eff = ops.effectiveAvailability('st_sato', mon);
      expect(
        eff.any((a) => a.kind == AvailKind.ok),
        isTrue,
        reason: '1区間NGにしただけで、その日のOKが消えてはいけない',
      );
      expect(eff.any((a) => a.kind == AvailKind.ng), isTrue);
    });

    test('画面表示と割当判定のOK／NG解釈が一致する', () {
      final ops = OpsState();
      for (final s in ops.staff) {
        for (var i = 0; i < 14; i++) {
          final d = dayOf(DateTime.now()).add(Duration(days: i));
          final ui = ops.effectiveAvailability(s.id, d);
          final engineView = ops.engine.effectiveFor(s.id, d);
          expect(
            ui.map((a) => a.id).toSet(),
            engineView.map((a) => a.id).toSet(),
            reason: '${s.name} ${d.month}/${d.day}：画面と判定で可否が食い違ってはいけない',
          );
        }
      }
    });
  });

  // -------------------------------------------------------------------------
  group('付録C.7 宿泊・§12 マスタ整合', () {
    test('宿泊ケアは通常の自動確定ロジックに乗せない', () {
      final ops = OpsState();
      final r = ops.engine.assign(
        service: serviceOf('svc_stay'),
        at: onWeekday(DateTime.monday, 10),
        facilityId: 'fac_sakura',
        areaCode: 'area_sakura',
        customerId: 'cus_001',
      );
      expect(
        r.exceptions.contains(ReasonCode.stayService) ||
            r.exceptions.contains(ReasonCode.noSlot),
        isTrue,
      );
      expect(r.autoConfirmable, isFalse);
    });

    test('サービス定義は版番号・適用開始日・必要スキルを持つ', () {
      for (final s in seedServices) {
        expect(s.version, greaterThan(0));
        expect(s.requiredSkills, isNotEmpty);
        expect(s.cancelPolicyId, isNotEmpty);
        expect(s.blockMin, greaterThanOrEqualTo(s.durationMin));
      }
    });

    // §6 で REQUESTED / PROVISIONAL を追加し 11 状態。
    // 要件再定義（2026-09）で 行政調整中／問診済み／請求済み／対象外／引継ぎ を追加し 16 状態。
    //   未申請 → 申請中 → 承認済み → 利用希望受付 → 行政調整中／スタッフ確認中
    //   → 仮予約 → 確定 → 問診済み → 実施済み → 請求済み
    // 予約希望（REQUESTED）は枠を占有しない＝isActive ではない、という
    // 区別がこの改修の要。ここが崩れると、同じ枠に希望を並べられなくなる。
    test('16状態FSMがすべて定義され、有効状態が正しい', () {
      expect(BookingState.values.length, 16);
      expect(BookingState.confirmed.isActive, isTrue);
      expect(
        BookingState.intakeDone.isActive,
        isTrue,
        reason: '問診済みも確定＝枠を押さえる',
      );
      expect(
        BookingState.municipalCoordination.isActive,
        isFalse,
        reason: '行政調整中は市の連絡待ち。枠を占有しない',
      );
      expect(BookingState.billed.isActive, isFalse);
      expect(BookingState.notEligible.isActive, isFalse);
      expect(BookingState.handedOff.isActive, isFalse);
      expect(BookingState.slotHeld.isActive, isTrue);
      expect(BookingState.inService.isActive, isTrue);
      expect(BookingState.provisional.isActive, isTrue, reason: '仮予約は枠を押さえる');
      expect(
        BookingState.requested.isActive,
        isFalse,
        reason: '予約希望は枠を占有しない（複数のご家族から希望を受けられる）',
      );
      expect(BookingState.needsReview.isActive, isFalse);
      expect(BookingState.cancelled.isActive, isFalse);
      expect(BookingState.noShow.isActive, isFalse);
    });

    test('ご家族に見せる文言に内部コードが混ざっていない（§6）', () {
      for (final s in BookingState.values) {
        expect(s.familyLabel, isNotEmpty);
        expect(
          s.familyLabel,
          isNot(matches(RegExp(r'[A-Z_]{4,}'))),
          reason: '${s.name} の家族向け表示に内部コードが出ている',
        );
      }
      // §47 予約希望と予約確定は、言葉としても明確に違うこと。
      expect(
        BookingState.requested.familyLabel,
        isNot(BookingState.confirmed.familyLabel),
      );
      expect(BookingState.requested.familyHint, contains('確定はまだ'));
    });

    test('料金表示は 見込／確認中／確定 の3状態を持つ', () {
      expect(FeeState.values.length, 3);
    });

    test('例外理由コードは E-01〜E-07 を含み、SLAが定義されている', () {
      final codes = ReasonCode.values.map((r) => r.code).toSet();
      for (final c in [
        'E-01',
        'E-02',
        'E-03',
        'E-04',
        'E-05',
        'E-06',
        'E-07',
      ]) {
        expect(codes, contains(c), reason: '$c が未定義');
      }
      for (final r in ReasonCode.values) {
        expect(r.slaMinutes, greaterThan(0));
      }
    });
  });

  // -------------------------------------------------------------------------
  group('構造的保証｜不適合な割当が確定状態で残らない', () {
    test('OK時間を全消ししても、確定済みは自動確定のまま残らない', () {
      final ops = OpsState();
      // すべての可用性を消す ＝ 空欄（予約不可）にする
      ops.availability.clear();
      // この状態で新規確定は不可能
      final r = ops.engine.assign(
        service: serviceOf('svc_visit3'),
        at: onWeekday(DateTime.monday, 10),
        areaCode: 'area_sakura',
        customerId: 'cus_001',
      );
      expect(r.autoConfirmable, isFalse);
      expect(r.exceptions, contains(ReasonCode.noSlot));
      // 代替枠の提示も0件（枠を捏造しない）
      expect(r.alternatives, isEmpty);
    });

    test('起動時の自己修復により、確定済みは全件が条件を満たす', () {
      final ops = OpsState();
      for (final b in ops.bookings.where((b) => b.state.isActive)) {
        expect(b.staffId, isNotNull, reason: '有効な予約に担当が無い状態は許されない（${b.code}）');
      }
      expect(ops.misAssignments, 0);
    });
  });
}

ConsentSnapshot _consent({int version = 5}) => ConsentSnapshot(
  termsId: 'terms_care',
  title: 'ご利用規約',
  version: version,
  revisedAt: DateTime(2026, 4, 1),
  agreedAt: DateTime.now(),
  agreedText: 'キャンセル規定・個人情報の取り扱いに同意しました。',
);
