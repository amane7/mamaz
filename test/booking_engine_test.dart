// ============================================================================
// §29 必須テストケース Case 1〜10
//
// このファイルは要求仕様 §29 が名指しした 10 ケースを、番号どおりに
// 1テスト＝1ケースで検証します。rules_test.dart が Pure Function 単位の
// 検証（部品が正しいこと）を担うのに対し、こちらは
//
//     OpsState（アプリケーションサービス）→ MatchingEngine → rules
//
// の経路を通した End-to-End の検証です。つまり「部品が正しい」ことではなく
// 「業務として正しく振る舞う」ことを証明します。
//
// AvailableSlot = ServiceRule ∩ FacilityAvailability ∩ ResourceAvailability
//                 ∩ RequiredSkill ∩ MidwifeOK
//                 − MidwifeNG − ExistingBookings − TravelTime − BufferTime
//
// 対応表（§29）
//   Case 1  条件を満たす家族が、空いている枠を予約できる
//   Case 2  必要スキルを持つ助産師がいない時間は予約できない
//   Case 3  助産師がNGにした時間は、OKと重なっていても予約できない
//   Case 4  施設・設備（部屋）が満室なら、助産師が空いていても予約できない
//   Case 5  訪問は移動時間・バッファを侵す隣接予約を許さない
//   Case 6  1日の上限を超える割当はできない
//   Case 7  同一枠の二重予約は発生しない（仮おさえ・冪等）
//   Case 8  日時変更は施設・助産師・設備・スキル・可用性を再評価する
//   Case 9  キャンセル料は予約時点の規定版どおりに算定される
//   Case 10 管理者は「必要条件 vs 候補」を比較できる（不足が特定できる）
//
// §30 セキュリティ：実在の個人情報・認証情報は一切使いません。
// ============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:mama_care/ops/matching_engine.dart';
import 'package:mama_care/ops/ops_models.dart';
import 'package:mama_care/ops/ops_seed.dart';
import 'package:mama_care/ops/ops_state.dart';
import 'package:mama_care/ops/rules/matching_rules.dart';

// ---------------------------------------------------------------------------
// テスト補助（ops_acceptance_test.dart と同じ流儀に揃える）
// ---------------------------------------------------------------------------

/// 指定曜日の日時を、シードデータ（特定日NG・初期予約）とぶつからない
/// 十分先の週から取得する。テストが実行日に依存しないようにするため。
DateTime onWeekday(int weekday, int hour, {int minute = 0, int ahead = 21}) {
  var d = dayOf(DateTime.now()).add(Duration(days: ahead));
  while (d.weekday != weekday) {
    d = d.add(const Duration(days: 1));
  }
  return d.add(Duration(hours: hour, minutes: minute));
}

OpsStaff staffOf(String id) => seedStaff.firstWhere((s) => s.id == id);
ServiceDef serviceOf(String id) => seedServices.firstWhere((s) => s.id == id);

/// 既存予約を1件つくる（割当条件をあえて無視して置く＝盤面づくり用）。
OpsBooking place(
  OpsState ops, {
  required String serviceId,
  required DateTime at,
  required String staffId,
  String? facilityId,
  BookingState state = BookingState.confirmed,
  String? id,
}) {
  final svc = serviceOf(serviceId);
  final b = OpsBooking(
    id: id ?? 'bk_case_${ops.bookings.length}',
    code: 'CASE-${ops.bookings.length.toString().padLeft(4, '0')}',
    customerId: ops.customer.id,
    childId: ops.customer.children.first.id,
    serviceId: serviceId,
    at: at,
    durationMin: svc.durationMin,
    kind: svc.kind,
    facilityId: facilityId,
    staffId: staffId,
    state: state,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    feeYen: svc.priceYen,
  );
  ops.bookings.add(b);
  return b;
}

/// その予約に部屋（Resource）を実際に確保させる。
/// Case 4（満室）の盤面づくりに使う。
void occupy(OpsState ops, OpsBooking b) {
  final ok = ops.allocateResource(b);
  expect(ok, isTrue, reason: '盤面づくりの段階では確保できるはず');
}

ConsentSnapshot consentNow(OpsState ops) {
  final t = ops.terms.first;
  return ConsentSnapshot(
    termsId: t.id,
    title: t.title,
    version: t.version,
    revisedAt: t.revisedAt,
    agreedAt: DateTime.now(),
    agreedText: t.keyPoints.join('／'),
  );
}

/// 赤旗なし・自由記述なしの、まっさらな問診回答。
Map<String, dynamic> cleanIntake() => <String, dynamic>{
  'bath': true,
  'meal': false,
  'allergy': '',
  'parking': 'あり',
  'freeText': '',
  'wantHuman': false,
};

void main() {
  // =========================================================================
  // Case 1｜条件を満たす家族が、空いている枠をそのまま予約できる
  //   ServiceRule ∩ Facility ∩ Resource ∩ Skill ∩ MidwifeOK がすべて成立し、
  //   例外が1件も立たなければ、人の手を介さず確定まで進む（§13 標準ケース）。
  // =========================================================================
  group('Case 1｜条件を満たす家族が空いている枠を予約できる', () {
    // 実行した「時刻」でテスト結果が変わってはいけない。
    //
    // 予約数制限（§12）は「これから来るご予約」の件数を数えるので、
    // 初期データの予約が上限と同数だと、午前に走らせると上限に達し
    // 午後に走らせると達しない、という揺れが出る。
    // それは初期データの不備であって、Case 1 の期待値を緩める理由にはならない。
    // 実害は本番でも同じ（ご家族が標準ケースなのに要確認に落ちる）ため、
    // ここで初期データ側の余裕を門番として固定する。
    test('前提：初期データのご家族は予約数制限に達していない（時刻に依存しない）', () {
      final ops = OpsState();
      final program = ops.municipalityById(ops.customer.municipalityId);
      final future = ops.bookings
          .where(
            (b) =>
                b.customerId == ops.customer.id &&
                b.state.isActive &&
                b.at.isAfter(DateTime.now()),
          )
          .length;
      expect(
        program.maxConcurrentBookings == 0 ||
            future < program.maxConcurrentBookings,
        isTrue,
        reason:
            '初期データの有効な先の予約が$future件、上限が${program.maxConcurrentBookings}件。'
            '上限と同数だと、実行時刻によって標準ケースが要確認に落ちてしまう',
      );
    });

    // 自動確定の対象は §4 により母乳外来（INSTANT）である。
    // 産後ケア（訪問・通所・宿泊）は現場の指摘（§2）を受けて
    // REQUEST_APPROVAL に変わったため、こちらは BM-02 で検証する。
    test('自動確定まで到達し、担当が決まり、例外が立たない', () {
      final ops = OpsState();
      // 火曜10:00 = 佐藤・田中とも OK（9:00-17:00 / 10:00-16:00）
      final at = onWeekday(DateTime.tuesday, 10);
      final svc = serviceOf('svc_breast');
      expect(svc.bookingMode, BookingMode.instant, reason: '§4 母乳外来は即時確定');

      final slot = ops.engine.buildSlot(
        service: svc,
        at: at,
        facilityId: 'fac_sakura',
        areaCode: ops.customer.address.areaCode,
        customerId: ops.customer.id,
      );
      expect(slot.bookable, isTrue, reason: '条件を満たす枠は家族に見える');

      final held = ops.holdSlot(
        service: svc,
        child: ops.customer.children.first,
        at: at,
        facilityId: 'fac_sakura',
        intake: cleanIntake(),
        needs: const ['授乳を相談したい'],
        idempotencyKey: 'case1-key',
      );
      expect(held, isNotNull);
      expect(held!.state, BookingState.slotHeld);
      expect(held.staffId, isNotNull, reason: '担当候補が決まっている');
      expect(held.hasOpenException, isFalse, reason: 'Case 1 は例外ゼロ');

      final ok = ops.confirmBooking(held, consent: consentNow(ops));
      expect(ok, isTrue);
      expect(held.state, BookingState.confirmed, reason: '§13 標準は自動確定');
      expect(held.consent, isNotNull, reason: '§20 同意版が凍結保存される');
    });

    test('確定後も6条件の事後検証を通る（KPI 不適合0件の門番）', () {
      final ops = OpsState();
      final at = onWeekday(DateTime.tuesday, 10);
      final svc = serviceOf('svc_breast');
      final held = ops.holdSlot(
        service: svc,
        child: ops.customer.children.first,
        at: at,
        facilityId: 'fac_sakura',
        intake: cleanIntake(),
        needs: const [],
        idempotencyKey: 'case1-verify',
      );
      ops.confirmBooking(held!, consent: consentNow(ops));
      expect(held.state, BookingState.confirmed);

      expect(
        ops.engine.verifyAssignment(
          s: ops.staffById(held.staffId)!,
          service: svc,
          at: held.at,
          facilityId: held.facilityId,
          areaCode: ops.customer.address.areaCode,
          excludeBookingId: held.id,
        ),
        isTrue,
      );
      expect(ops.misAssignments, 0);
      expect(ops.doubleBookings, 0);
    });
  });

  // =========================================================================
  // Case BM｜予約方式（bookingMode）が最終動作を決める
  //
  //   スタッフからの最重要フィードバック（§2）:
  //   「産後ケアは月齢・多胎・訪問場所・自治体条件・施設受入状況・スタッフ配置を
  //     確認して調整する必要があり、全員が即時確定する運用は難しい」
  //
  //   これに対する答えが bookingMode。ルールエンジンは残したまま、
  //   その結果を «自動確定» ではなく «スタッフ判断の材料» として使う（§7）。
  //   ここが今回の改修の中心なので、方式ごとの出口をすべて固定する。
  // =========================================================================
  group('Case BM｜Booking Mode', () {
    test('BM-01 母乳外来（INSTANT）は条件を満たせば即時確定する', () {
      final ops = OpsState();
      final at = onWeekday(DateTime.tuesday, 10);
      final held = ops.holdSlot(
        service: serviceOf('svc_breast'),
        child: ops.customer.children.first,
        at: at,
        facilityId: 'fac_sakura',
        intake: cleanIntake(),
        needs: const [],
        idempotencyKey: 'bm01',
      );
      expect(held, isNotNull);
      expect(ops.confirmBooking(held!, consent: consentNow(ops)), isTrue);
      expect(held.state, BookingState.confirmed);
      expect(held.autoAssigned, isTrue, reason: '人の介在なしで成立した');
      expect(held.feeState, FeeState.confirmed);
    });

    test('BM-02 通所ケア（REQUEST_APPROVAL）は条件を満たしても確定せず予約希望になる', () {
      final ops = OpsState();
      final at = onWeekday(DateTime.tuesday, 10);
      final svc = serviceOf('svc_day4');
      expect(svc.bookingMode, BookingMode.requestApproval);

      final held = ops.holdSlot(
        service: svc,
        child: ops.customer.children.first,
        at: at,
        facilityId: 'fac_sakura',
        intake: cleanIntake(),
        needs: const ['休みたい'],
        idempotencyKey: 'bm02',
      );
      expect(held, isNotNull);
      expect(held!.hasOpenException, isFalse, reason: '条件そのものは満たしている');

      final accepted = ops.confirmBooking(held, consent: consentNow(ops));
      expect(accepted, isTrue, reason: '申込の受付そのものは成功する');
      expect(
        held.state,
        BookingState.requested,
        reason: '§45 条件OKでも REQUEST_APPROVAL は確定しない',
      );
      expect(
        held.feeState,
        isNot(FeeState.confirmed),
        reason: '確定していないのに料金を確定表示してはいけない',
      );
      expect(held.autoAssigned, isFalse);

      // §46 管理者の確認待ちキューに載る
      expect(ops.pendingRequests.any((b) => b.id == held.id), isTrue);
      expect(
        ops.tasksFor(TaskOwner.siteAdmin).any((t) => t.bookingId == held.id),
        isTrue,
        reason: '確認タスクが立つ（放置されない）',
      );

      // スタッフ確認後に確定できる
      ops.switchRole(OpsRole.admin);
      expect(ops.approveRequest(held), isTrue);
      expect(held.state, BookingState.confirmed);
      expect(held.autoAssigned, isFalse, reason: 'KPI で自動完結率と区別できること');
      expect(held.manualTouches, greaterThan(0));
    });

    test('BM-02b 予約希望のまま放置しても、確定扱いにはならない', () {
      final ops = OpsState();
      final held = ops.holdSlot(
        service: serviceOf('svc_day4'),
        child: ops.customer.children.first,
        at: onWeekday(DateTime.tuesday, 10),
        facilityId: 'fac_sakura',
        intake: cleanIntake(),
        needs: const [],
        idempotencyKey: 'bm02b',
      )!;
      ops.confirmBooking(held, consent: consentNow(ops));
      // 予約希望は枠を占有しない＝他のご家族の候補を潰さない
      expect(held.state.isActive, isFalse);
      expect(
        ops.familyBookings.any(
          (b) => b.id == held.id && b.state == BookingState.confirmed,
        ),
        isFalse,
      );
    });

    test('BM-03 条件が不明なら方式に関係なく確認待ちになる', () {
      final ops = OpsState();
      final held = ops.holdSlot(
        service: serviceOf('svc_day4'),
        child: ops.customer.children.first,
        at: onWeekday(DateTime.tuesday, 10),
        facilityId: 'fac_sakura',
        // 赤旗（発熱）＝機械では判断できない
        intake: {...cleanIntake(), 'fever': true},
        needs: const [],
        idempotencyKey: 'bm03',
      );
      expect(held, isNotNull);
      ops.confirmBooking(held!, consent: consentNow(ops));
      expect(held.state, BookingState.needsReview);

      // 未解決の確認事項があるあいだは、確定させない
      ops.switchRole(OpsRole.admin);
      expect(
        ops.approveRequest(held),
        isFalse,
        reason: '§0 要確認を残したまま確定してはいけない',
      );
      expect(held.state, BookingState.needsReview);
    });

    test('BM-03b 即時確定サービスでも、要確認があれば自動確定しない', () {
      final ops = OpsState();
      final held = ops.holdSlot(
        service: serviceOf('svc_breast'),
        child: ops.customer.children.first,
        at: onWeekday(DateTime.tuesday, 10),
        facilityId: 'fac_sakura',
        intake: {...cleanIntake(), 'fever': true},
        needs: const [],
        idempotencyKey: 'bm03b',
      )!;
      ops.confirmBooking(held, consent: consentNow(ops));
      expect(held.state, BookingState.needsReview);
    });

    test('BM-04 ADMIN_ONLY はご家族の操作では成立しない（画面制御に頼らない）', () {
      final ops = OpsState();
      final svc = serviceOf(
        'svc_day4',
      ).copyWith(bookingMode: BookingMode.adminOnly);
      final held = ops.holdSlot(
        service: svc,
        child: ops.customer.children.first,
        at: onWeekday(DateTime.tuesday, 10),
        facilityId: 'fac_sakura',
        intake: cleanIntake(),
        needs: const [],
        idempotencyKey: 'bm04',
      );
      expect(held, isNull, reason: '§42 ドメイン層で断る。ボタンを隠すだけでは不十分');

      // スタッフ代理登録なら通る
      final byStaff = ops.holdSlot(
        service: svc,
        child: ops.customer.children.first,
        at: onWeekday(DateTime.tuesday, 10),
        facilityId: 'fac_sakura',
        intake: cleanIntake(),
        needs: const [],
        idempotencyKey: 'bm04-staff',
        byStaff: true,
      );
      expect(byStaff, isNotNull);
    });

    test('予約方式は固定実装ではなくデータであり、後から変更できる（§3/§4）', () {
      final ops = OpsState();
      final before = ops.serviceById('svc_day4');
      expect(before.bookingMode, BookingMode.requestApproval);

      // 管理者が「通所ケアは即時確定でよい」と判断した将来を想定
      ops.updateService('svc_day4', bookingMode: BookingMode.instant);
      expect(ops.serviceById('svc_day4').bookingMode, BookingMode.instant);

      final held = ops.holdSlot(
        service: ops.serviceById('svc_day4'),
        child: ops.customer.children.first,
        at: onWeekday(DateTime.tuesday, 10),
        facilityId: 'fac_sakura',
        intake: cleanIntake(),
        needs: const [],
        idempotencyKey: 'bm-switch',
      )!;
      ops.confirmBooking(held, consent: consentNow(ops));
      expect(
        held.state,
        BookingState.confirmed,
        reason: 'コード修正なしで即時確定へ切り替えられる（§0）',
      );
    });

    test('申込時の方式は凍結され、後の設定変更で過去の予約が書き換わらない', () {
      final ops = OpsState();
      final held = ops.holdSlot(
        service: ops.serviceById('svc_day4'),
        child: ops.customer.children.first,
        at: onWeekday(DateTime.tuesday, 10),
        facilityId: 'fac_sakura',
        intake: cleanIntake(),
        needs: const [],
        idempotencyKey: 'bm-freeze',
      )!;
      expect(held.bookingMode, BookingMode.requestApproval);

      ops.updateService('svc_day4', bookingMode: BookingMode.instant);
      expect(
        held.bookingMode,
        BookingMode.requestApproval,
        reason: '過去の予約希望が「即時確定だったはず」に見えてはいけない',
      );
    });

    test('§12 開始時刻の刻みは所要時間と分離されている', () {
      final breast = serviceOf('svc_breast');
      expect(breast.durationMin, 60);
      expect(breast.startInterval, 30, reason: '60分ケアでも30分刻みで開始できる');
      for (final s in seedServices) {
        expect(
          s.startInterval,
          lessThanOrEqualTo(s.durationMin),
          reason: '${s.name} の開始刻みが所要時間より粗い',
        );
      }
    });

    test('予約希望に添えないときは、理由を残して丁寧に断れる（§46）', () {
      final ops = OpsState();
      final held = ops.holdSlot(
        service: serviceOf('svc_day4'),
        child: ops.customer.children.first,
        at: onWeekday(DateTime.tuesday, 10),
        facilityId: 'fac_sakura',
        intake: cleanIntake(),
        needs: const [],
        idempotencyKey: 'bm-decline',
      )!;
      ops.confirmBooking(held, consent: consentNow(ops));
      ops.switchRole(OpsRole.admin);
      expect(ops.declineRequest(held, reason: '同日に多胎のご家族の受入が入っているため'), isTrue);
      expect(held.state, BookingState.cancelled);
      expect(
        ops.notifications.any((n) => n.bookingId == held.id),
        isTrue,
        reason: 'ご家族に必ず連絡が飛ぶ',
      );
      expect(
        ops.auditLog.any(
          (e) => e.target == held.code && e.action.contains('添えず'),
        ),
        isTrue,
      );
    });

    test('仮予約はご家族に「確定」と伝わらない（§47）', () {
      final ops = OpsState();
      final held = ops.holdSlot(
        service: serviceOf('svc_day4'),
        child: ops.customer.children.first,
        at: onWeekday(DateTime.tuesday, 10),
        facilityId: 'fac_sakura',
        intake: cleanIntake(),
        needs: const [],
        idempotencyKey: 'bm-prov',
      )!;
      ops.confirmBooking(held, consent: consentNow(ops));
      ops.switchRole(OpsRole.admin);
      expect(ops.setProvisional(held), isTrue);
      expect(held.state, BookingState.provisional);
      expect(held.state.familyLabel, contains('仮'));
      expect(held.state.familyHint, contains('確定'));
      expect(held.state.familyLabel, isNot(BookingState.confirmed.familyLabel));
      // 仮予約からも確定できる
      expect(ops.approveRequest(held), isTrue);
      expect(held.state, BookingState.confirmed);
    });

    test('家族向け文言に「予約する」を使わない方式がある（§5）', () {
      expect(BookingMode.instant.familyCta, contains('予約する'));
      expect(
        BookingMode.requestApproval.familyCta,
        isNot(contains('予約する')),
        reason: '確定したと誤解させる言葉を使ってはいけない',
      );
      expect(
        BookingMode.requestApproval.familyAfterSubmit,
        allOf(contains('予約希望'), contains('確認')),
      );
      expect(BookingMode.instant.familyCanConfirm, isTrue);
      expect(BookingMode.requestApproval.familyCanConfirm, isFalse);
      expect(BookingMode.adminOnly.familyCanConfirm, isFalse);
    });

    test('未知の方式コードは安全側（人が見る）に倒れる', () {
      expect(BookingModeX.fromCode('INSTANT'), BookingMode.instant);
      expect(
        BookingModeX.fromCode('SOMETHING_NEW'),
        BookingMode.requestApproval,
        reason: '解釈できない設定で勝手に自動確定してはいけない',
      );
    });
  });

  // =========================================================================
  // Case 2｜必要スキルを持つ助産師がいなければ予約できない
  //   RequiredSkill は §11 のマスタ由来。固定実装ではない。
  // =========================================================================
  group('Case 2｜必要スキルが無ければ予約できない', () {
    test('母乳ケア未保有の助産師は母乳外来に割当されない', () {
      final ops = OpsState();
      final at = onWeekday(DateTime.tuesday, 10);
      // 木村：母乳ケアを持たない
      final rejects = ops.engine.verifyAssignmentReasons(
        s: staffOf('st_kimura'),
        service: serviceOf('svc_breast'),
        at: at,
        facilityId: 'fac_midori',
        areaCode: 'area_midori',
      );
      expect(
        rejects,
        anyOf(
          contains(RejectReason.skillMismatch),
          contains(RejectReason.serviceMismatch),
        ),
        reason: '必要スキル／対応サービスの不一致で除外される',
      );
    });

    test('不足しているスキル名を列挙できる（§23 管理者が理由を特定できる）', () {
      final missing = missingSkills(
        requiredSkills: serviceOf('svc_breast').requiredSkills,
        staffSkills: staffOf('st_kimura').skills,
      );
      expect(missing, contains('母乳ケア'));
    });

    test('スキル保有者だけが候補に残る', () {
      final ops = OpsState();
      final at = onWeekday(DateTime.tuesday, 10);
      final slot = ops.engine.buildSlot(
        service: serviceOf('svc_breast'),
        at: at,
        facilityId: 'fac_sakura',
        areaCode: 'area_sakura',
        customerId: ops.customer.id,
      );
      for (final e in slot.eligible) {
        expect(
          e.staff.skills.containsAll(serviceOf('svc_breast').requiredSkills),
          isTrue,
          reason: '候補は全員が必要スキルを満たしていること',
        );
      }
    });

    test('スキル要件は固定実装ではなくマスタから来ている（§11）', () {
      final ops = OpsState();
      expect(ops.skills, isNotEmpty, reason: 'Skill はマスタとして存在する');
      for (final need in serviceOf('svc_breast').requiredSkills) {
        expect(
          ops.skills.any((s) => s.name == need),
          isTrue,
          reason: 'サービスが要求するスキルはマスタに定義されている：$need',
        );
      }
    });
  });

  // =========================================================================
  // Case 3｜助産師がNGにした時間は、OKと重なっていても予約できない
  //   §8 NG は OK に対して絶対優先。§9 理由は保存も表示もしない。
  // =========================================================================
  group('Case 3｜NGはOKに絶対優先する', () {
    test('水曜午後（OK 9-17 と NG 13-17 が重なる）は割当されない', () {
      final ops = OpsState();
      final wedPm = onWeekday(DateTime.wednesday, 14);
      final rejects = ops.engine.verifyAssignmentReasons(
        s: staffOf('st_sato'),
        service: serviceOf('svc_visit2'),
        at: wedPm,
        areaCode: 'area_sakura',
      );
      expect(rejects, contains(RejectReason.overlapNg));
    });

    test('同じ助産師の水曜午前（NGの外）は割当できる', () {
      final ops = OpsState();
      final wedAm = onWeekday(DateTime.wednesday, 10);
      final rejects = ops.engine.verifyAssignmentReasons(
        s: staffOf('st_sato'),
        service: serviceOf('svc_visit2'),
        at: wedAm,
        areaCode: 'area_sakura',
      );
      expect(rejects, isNot(contains(RejectReason.overlapNg)));
    });

    test('NGを取り消せば、同じ時間に割当できるようになる（§10 修正可能）', () {
      final ops = OpsState();
      final wedPm = onWeekday(DateTime.wednesday, 14);

      // その日を「特定日の登録だけを正」にして、OKだけを残す
      ops.replaceDay(
        staffId: 'st_sato',
        date: dayOf(wedPm),
        ranges: [
          StaffAvailability(
            id: 'av_case3_ok',
            staffId: 'st_sato',
            date: dayOf(wedPm),
            startMin: 540,
            endMin: 1020,
            kind: AvailKind.ok,
            updatedAt: DateTime.now(),
          ),
        ],
      );

      final rejects = ops.engine.verifyAssignmentReasons(
        s: staffOf('st_sato'),
        service: serviceOf('svc_visit2'),
        at: wedPm,
        areaCode: 'area_sakura',
      );
      expect(rejects, isNot(contains(RejectReason.overlapNg)));
      expect(rejects, isNot(contains(RejectReason.outsideOk)));
    });

    test('NG理由は保存されず、家族にも開示されない（§9）', () {
      final ops = OpsState();
      final wedPm = onWeekday(DateTime.wednesday, 14);
      final ngRecords = ops
          .effectiveAvailability('st_sato', dayOf(wedPm))
          .where((a) => a.kind == AvailKind.ng);
      expect(ngRecords, isNotEmpty);
      // 構造的に理由フィールドを持たない
      expect(
        ngRecords.first.toString().contains('reason'),
        isFalse,
        reason: 'StaffAvailability は理由を持たない構造である',
      );
      expect(
        RejectReason.overlapNg.familyVisible,
        isFalse,
        reason: 'NG起因の除外理由は家族に見せない',
      );
    });
  });

  // =========================================================================
  // Case 4｜施設・設備が満室なら、助産師が空いていても予約できない
  //   §15 人と設備は別資源。ResourceAvailability を独立に交差させる。
  // =========================================================================
  group('Case 4｜部屋が満室なら助産師が空いていても不可', () {
    test('個室2室すべて埋まった通所4時間は bookable にならない', () {
      final ops = OpsState();
      final at = onWeekday(DateTime.tuesday, 10);
      final svc = serviceOf('svc_day4'); // requiredResourceKinds: {room}

      // 先に確認：満室にする前は予約できる
      final before = ops.engine.buildSlot(
        service: svc,
        at: at,
        facilityId: 'fac_sakura',
        areaCode: 'area_sakura',
        customerId: ops.customer.id,
      );
      expect(before.bookable, isTrue, reason: '満室にする前は成立する');

      // さくら院の個室は2室。同じ時間に2件を確保して満室にする
      occupy(
        ops,
        place(
          ops,
          serviceId: 'svc_day4',
          at: at,
          staffId: 'st_sato',
          facilityId: 'fac_sakura',
          id: 'bk_room_1',
        ),
      );
      occupy(
        ops,
        place(
          ops,
          serviceId: 'svc_day4',
          at: at,
          staffId: 'st_ono',
          facilityId: 'fac_sakura',
          id: 'bk_room_2',
        ),
      );

      final after = ops.engine.buildSlot(
        service: svc,
        at: at,
        facilityId: 'fac_sakura',
        areaCode: 'area_sakura',
        customerId: ops.customer.id,
      );
      expect(after.resourceFull, isTrue, reason: '部屋の空きが無い');
      expect(after.bookable, isFalse, reason: '助産師の空きだけでは成立しない');
    });

    test('「部屋の空きなし」は家族に伝えてよい理由である（§9 との切り分け）', () {
      expect(RejectReason.resourceUnavailable.familyVisible, isTrue);
      expect(RejectReason.resourceUnavailable.label, '部屋・設備の空きなし');
    });

    test('満室では確定できず、確認待ちへ退避する（安全側）', () {
      final ops = OpsState();
      final at = onWeekday(DateTime.tuesday, 10);

      final b = place(
        ops,
        serviceId: 'svc_day4',
        at: at,
        staffId: 'st_sato',
        facilityId: 'fac_sakura',
        state: BookingState.slotHeld,
        id: 'bk_target',
      );
      b.holdExpiresAt = DateTime.now().add(const Duration(minutes: 20));

      // 2室を他の予約で占有
      occupy(
        ops,
        place(
          ops,
          serviceId: 'svc_day4',
          at: at,
          staffId: 'st_ono',
          facilityId: 'fac_sakura',
          id: 'bk_room_a',
        ),
      );
      occupy(
        ops,
        place(
          ops,
          serviceId: 'svc_day4',
          at: at,
          staffId: 'st_tanaka',
          facilityId: 'fac_sakura',
          id: 'bk_room_b',
        ),
      );

      final ok = ops.confirmBooking(b, consent: consentNow(ops));
      expect(ok, isFalse, reason: '部屋が無いのに確定してはいけない');
      expect(b.state, BookingState.needsReview);
    });

    test('リソース未登録の施設は従来動作（後方互換）', () {
      final ops = OpsState();
      final at = onWeekday(DateTime.tuesday, 10);
      // ひなた（リソース未登録）相当：resources を空にしたエンジンで確認
      final engine = MatchingEngine(
        staff: ops.staff,
        availability: ops.availability,
        blocks: ops.blocks,
        bookings: ops.bookings,
        facilities: ops.facilities,
        // resources を渡さない＝この層では判定しない
      );
      expect(
        engine.hasResource(
          service: serviceOf('svc_day4'),
          at: at,
          facilityId: 'fac_sakura',
        ),
        isTrue,
      );
    });
  });

  // =========================================================================
  // Case 5｜訪問は移動時間・バッファを侵す隣接予約を許さない
  //   §14 前予約 → 移動 → ケア → 移動 → 次予約
  // =========================================================================
  group('Case 5｜移動時間・バッファを侵す割当はできない', () {
    test('直後に隣接する訪問は、移動＋バッファ不足で割当されない', () {
      final ops = OpsState();
      final at = onWeekday(DateTime.tuesday, 10);
      // 田中に10:00-12:00の訪問（移動30分・バッファ20分）
      place(ops, serviceId: 'svc_visit2', at: at, staffId: 'st_tanaka');
      // 12:00 ちょうどに次の訪問は入らない
      final rejects = ops.engine.verifyAssignmentReasons(
        s: staffOf('st_tanaka'),
        service: serviceOf('svc_visit2'),
        at: at.add(const Duration(hours: 2)),
        areaCode: 'area_sakura',
      );
      expect(
        rejects,
        anyOf(
          contains(RejectReason.bufferViolation),
          contains(RejectReason.overlapBooking),
        ),
      );
    });

    test('占有時間は 移動 → ケア → 移動 → バッファ の順に層になる（§14）', () {
      final o = occupancyOf(
        service: serviceOf('svc_visit2'), // 120分・移動30・バッファ15
        startMin: 600,
        bufferMin: 20, // 助産師側のバッファが優先される想定
      );
      expect(o.careStart, 600);
      expect(o.careEnd, 720);
      expect(o.travelStart, 570, reason: 'ケア前に移動30分');
      expect(o.travelEnd, 750, reason: 'ケア後に移動30分');
      expect(o.blockEnd, 770, reason: '移動のさらに外側にバッファ20分が乗る');
    });

    test('十分に離れた時間なら割当できる（バッファは「常に不可」ではない）', () {
      final ops = OpsState();
      final at = onWeekday(DateTime.tuesday, 10);
      place(ops, serviceId: 'svc_visit2', at: at, staffId: 'st_tanaka');
      final rejects = ops.engine.verifyAssignmentReasons(
        s: staffOf('st_tanaka'),
        service: serviceOf('svc_visit2'),
        at: at.add(const Duration(hours: 4)), // 14:00
        areaCode: 'area_sakura',
      );
      expect(rejects, isNot(contains(RejectReason.bufferViolation)));
      expect(rejects, isNot(contains(RejectReason.overlapBooking)));
    });

    test('通所・宿泊には移動時間が付かない（訪問固有のルール）', () {
      final o = occupancyOf(
        service: serviceOf('svc_day4'),
        startMin: 600,
        bufferMin: 20,
      );
      expect(o.travelStart, o.careStart, reason: '通所は移動なし');
      expect(o.travelEnd, o.careEnd);
    });
  });

  // =========================================================================
  // Case 6｜1日の上限を超える割当はできない
  //   §12 ⑤ 1日総稼働・連続対応の上限。助産師を守るためのルール。
  // =========================================================================
  group('Case 6｜1日上限・連続対応上限を超えられない', () {
    test('田中（上限360分）に240分＋180分は入らない', () {
      final ops = OpsState();
      final tue = onWeekday(DateTime.tuesday, 10);
      place(
        ops,
        serviceId: 'svc_day4', // 240分
        at: tue,
        staffId: 'st_tanaka',
        facilityId: 'fac_sakura',
      );
      final rejects = ops.engine.verifyAssignmentReasons(
        s: staffOf('st_tanaka'),
        service: serviceOf('svc_visit3'), // 180分
        at: tue.add(const Duration(hours: 5)),
        areaCode: 'area_sakura',
      );
      expect(
        rejects,
        anyOf(
          contains(RejectReason.dailyCapExceeded),
          contains(RejectReason.consecutiveExceeded),
          contains(RejectReason.outsideOk),
        ),
        reason: '合計420分は上限360分を超える',
      );
    });

    test('上限判定は固定値ではなく助産師マスタの値を使う', () {
      expect(staffOf('st_tanaka').dailyMaxMin, 360);
      expect(staffOf('st_ono').dailyMaxMin, 480);
      expect(
        dailyCapExceeded(loadMin: 240, addMin: 180, dailyMaxMin: 360),
        isTrue,
      );
      expect(
        dailyCapExceeded(loadMin: 240, addMin: 180, dailyMaxMin: 480),
        isFalse,
        reason: '同じ負荷でも上限の大きい助産師なら入る',
      );
    });

    test('連続対応上限も件数で守られる', () {
      expect(
        consecutiveExceeded(count: 2, consecutiveMax: 2),
        isTrue,
        reason: '既に上限件数に達していれば追加できない',
      );
      expect(consecutiveExceeded(count: 1, consecutiveMax: 2), isFalse);
    });
  });

  // =========================================================================
  // Case 7｜同一枠の二重予約は発生しない
  //   §18 Slot Hold・冪等キー・自動解放。
  // =========================================================================
  group('Case 7｜二重予約は構造的に発生しない', () {
    test('同じ冪等キーの再送は、同じ予約を返す（新規作成しない）', () {
      final ops = OpsState();
      final at = onWeekday(DateTime.tuesday, 10);
      final svc = serviceOf('svc_visit2');
      final before = ops.bookings.length;

      final a = ops.holdSlot(
        service: svc,
        child: ops.customer.children.first,
        at: at,
        intake: cleanIntake(),
        needs: const [],
        idempotencyKey: 'case7-same',
      );
      final b = ops.holdSlot(
        service: svc,
        child: ops.customer.children.first,
        at: at,
        intake: cleanIntake(),
        needs: const [],
        idempotencyKey: 'case7-same',
      );
      expect(a, isNotNull);
      expect(identical(a, b), isTrue, reason: '同一予約が返る');
      expect(ops.bookings.length, before + 1, reason: '1件しか増えない');
    });

    test('別キーで同じ枠を連続申込しても、同じ助産師に二重で入らない', () {
      final ops = OpsState();
      final at = onWeekday(DateTime.tuesday, 10);
      final svc = serviceOf('svc_visit2');

      for (var i = 0; i < 4; i++) {
        ops.holdSlot(
          service: svc,
          child: ops.customer.children.first,
          at: at,
          intake: cleanIntake(),
          needs: const [],
          idempotencyKey: 'case7-$i',
        );
      }
      expect(ops.doubleBookings, 0, reason: '§18 二重予約は 0 件');
    });

    test('仮おさえは期限を持ち、期限切れなら確定できない（自動解放）', () {
      final ops = OpsState();
      final at = onWeekday(DateTime.tuesday, 10);
      final held = ops.holdSlot(
        service: serviceOf('svc_visit2'),
        child: ops.customer.children.first,
        at: at,
        intake: cleanIntake(),
        needs: const [],
        idempotencyKey: 'case7-expire',
      );
      expect(held, isNotNull);
      expect(held!.holdExpiresAt, isNotNull, reason: '§18 期限を持つ');

      held.holdExpiresAt = DateTime.now().subtract(const Duration(minutes: 1));
      expect(held.holdExpired, isTrue);
      expect(
        ops.confirmBooking(held, consent: consentNow(ops)),
        isFalse,
        reason: '期限切れの枠は確定できない',
      );
      expect(held.state, BookingState.draft, reason: '枠は解放される');
    });
  });

  // =========================================================================
  // Case 8｜日時変更は全条件を再評価する
  //   §19 施設・助産師・設備・スキル・可用性・ルールを再判定する。
  // =========================================================================
  group('Case 8｜変更時に全条件を再評価する', () {
    test('条件を満たす日時への変更は成功し、担当が再決定される', () {
      final ops = OpsState();
      final at = onWeekday(DateTime.tuesday, 10);
      final held = ops.holdSlot(
        service: serviceOf('svc_visit2'),
        child: ops.customer.children.first,
        at: at,
        intake: cleanIntake(),
        needs: const [],
        idempotencyKey: 'case8-ok',
      );
      ops.confirmBooking(held!, consent: consentNow(ops));

      final newAt = onWeekday(DateTime.thursday, 11, ahead: 21);
      final changed = ops.requestChange(held, newAt);
      expect(changed, isTrue);
      expect(held.at, newAt);
      expect(held.staffId, isNotNull, reason: '変更後の担当が決まっている');
      expect(
        held.stateLog.any((l) => l.contains('変更確定')),
        isTrue,
        reason: '変更履歴が残る',
      );
    });

    test('NG時間への変更は拒否される（可用性の再評価が効いている）', () {
      final ops = OpsState();
      final at = onWeekday(DateTime.tuesday, 10);
      final held = ops.holdSlot(
        service: serviceOf('svc_visit2'),
        child: ops.customer.children.first,
        at: at,
        intake: cleanIntake(),
        needs: const [],
        idempotencyKey: 'case8-ng',
      );
      ops.confirmBooking(held!, consent: consentNow(ops));
      final original = held.at;

      // 全助産師のその日を終日NGにしてから変更を試みる
      final target = onWeekday(DateTime.thursday, 11, ahead: 21);
      for (final s in ops.staff) {
        ops.setAllDayNg(staffId: s.id, date: dayOf(target));
      }

      final changed = ops.requestChange(held, target);
      expect(changed, isFalse, reason: '割当できない日時へは変更しない');
      expect(held.at, original, reason: '失敗時は元の日時を保持する');
    });

    test('部屋が満室の日時への変更は拒否され、元のリソース確保が戻る（§15）', () {
      final ops = OpsState();
      final at = onWeekday(DateTime.tuesday, 10);
      final b = place(
        ops,
        serviceId: 'svc_day4',
        at: at,
        staffId: 'st_sato',
        facilityId: 'fac_sakura',
        id: 'bk_change_src',
      );
      occupy(ops, b);
      final keptBefore = ops.resourceAllocations
          .where((a) => a.bookingId == b.id)
          .length;
      expect(keptBefore, 1);

      // 変更先の時間を満室にする
      final target = onWeekday(DateTime.wednesday, 10, ahead: 21);
      occupy(
        ops,
        place(
          ops,
          serviceId: 'svc_day4',
          at: target,
          staffId: 'st_ono',
          facilityId: 'fac_sakura',
          id: 'bk_full_1',
        ),
      );
      occupy(
        ops,
        place(
          ops,
          serviceId: 'svc_day4',
          at: target,
          staffId: 'st_tanaka',
          facilityId: 'fac_sakura',
          id: 'bk_full_2',
        ),
      );

      final changed = ops.requestChange(b, target);
      expect(changed, isFalse, reason: '部屋が無い日時へは変更しない');
      expect(b.at, at, reason: '元の日時を保持する');
      expect(
        ops.resourceAllocations.where((a) => a.bookingId == b.id).length,
        keptBefore,
        reason: '失敗時は元のリソース確保が復元される',
      );
    });

    test('変更期限を過ぎた変更希望は自動処理せず、有人確認へ回る（§20）', () {
      final ops = OpsState();
      // 変更期限 55時間 → 24時間後の予約は期限外
      final soon = DateTime.now().add(const Duration(hours: 24));
      final b = place(
        ops,
        serviceId: 'svc_visit2',
        at: soon,
        staffId: 'st_sato',
        id: 'bk_late_change',
      );
      b.cancelPolicyId = 'cp_standard';
      b.cancelPolicyVersion = 4;

      expect(ops.canChange(b), isFalse);
      final changed = ops.requestChange(b, soon.add(const Duration(hours: 2)));
      expect(changed, isFalse);
      expect(b.state, BookingState.needsReview);
      expect(
        ops.tasks.any((t) => t.bookingId == b.id && !t.done),
        isTrue,
        reason: '§13 管理者キューにタスクが立つ',
      );
    });
  });

  // =========================================================================
  // Case 9｜キャンセル料は予約時点の規定版どおりに算定される
  //   §20 規定はマスタから。固定実装しない。版番号を予約に凍結する。
  // =========================================================================
  group('Case 9｜キャンセル料は版管理された規定どおり', () {
    test('通常規定は ¥0 / ¥5,000 / ¥10,000 の3段階（固定実装しない）', () {
      final ops = OpsState();
      final p = ops.policyById('cp_standard');
      expect(p.tiers.map((t) => t.feeYen).toList(), [0, 5000, 10000]);
      expect(p.version, isNonZero, reason: '版番号を持つ');
      expect(p.effectiveFrom, isNotNull, reason: '適用開始日を持つ');
    });

    test('期限内は無料、前日は5,000円、当日は10,000円', () {
      final ops = OpsState();
      final p = ops.policyById('cp_standard');
      final now = DateTime.now();
      expect(
        p.feeFor(bookingAt: now.add(const Duration(hours: 80)), requestAt: now),
        0,
      );
      expect(
        p.feeFor(bookingAt: now.add(const Duration(hours: 40)), requestAt: now),
        5000,
      );
      expect(
        p.feeFor(bookingAt: now.add(const Duration(hours: 5)), requestAt: now),
        10000,
      );
    });

    test('予約は確定時の規定版を凍結保存し、以後の改定に影響されない', () {
      final ops = OpsState();
      final at = onWeekday(DateTime.tuesday, 10);
      final held = ops.holdSlot(
        service: serviceOf('svc_visit2'),
        child: ops.customer.children.first,
        at: at,
        intake: cleanIntake(),
        needs: const [],
        idempotencyKey: 'case9-freeze',
      );
      ops.confirmBooking(held!, consent: consentNow(ops));
      expect(held.cancelPolicyId, 'cp_standard');
      expect(held.cancelPolicyVersion, ops.policyById('cp_standard').version);
    });

    test('サービスごとに異なる規定が適用される（通所2時間は3,400/6,800）', () {
      final ops = OpsState();
      expect(serviceOf('svc_day2').cancelPolicyId, 'cp_day2h');
      expect(ops.policyById('cp_day2h').tiers.map((t) => t.feeYen).toList(), [
        0,
        3400,
        6800,
      ]);
    });

    test('期限内キャンセルは無料で自動確定、期限後は有人確認へ（§13）', () {
      final ops = OpsState();
      final far = DateTime.now().add(const Duration(hours: 100));
      final free = place(
        ops,
        serviceId: 'svc_visit2',
        at: far,
        staffId: 'st_sato',
        id: 'bk_cancel_free',
      );
      free.cancelPolicyId = 'cp_standard';
      expect(ops.cancelEstimate(free), 0);
      ops.requestCancel(free, 'ご都合により');
      expect(free.state, BookingState.cancelled);

      final soon = DateTime.now().add(const Duration(hours: 5));
      final paid = place(
        ops,
        serviceId: 'svc_visit2',
        at: soon,
        staffId: 'st_sato',
        id: 'bk_cancel_paid',
      );
      paid.cancelPolicyId = 'cp_standard';
      expect(ops.cancelEstimate(paid), 10000);
      ops.requestCancel(paid, 'ご都合により');
      expect(
        paid.state,
        isNot(BookingState.cancelled),
        reason: '有料キャンセルは自動確定しない',
      );
    });
  });

  // =========================================================================
  // Case 10｜管理者は「必要条件 vs 候補」を比較できる
  //   §23 Matching Control Tower。なぜ成立しないかを特定できること。
  // =========================================================================
  group('Case 10｜必要条件 vs 候補の比較ができる', () {
    test('候補0の枠でも、除外理由の内訳を件数つきで取得できる', () {
      final ops = OpsState();
      // 全助産師のその日を終日NGにする＝候補0の盤面
      final target = onWeekday(DateTime.wednesday, 14, ahead: 21);
      for (final s in ops.staff) {
        ops.setAllDayNg(staffId: s.id, date: dayOf(target));
      }
      final slot = ops.engine.buildSlot(
        service: serviceOf('svc_visit2'),
        at: target,
        areaCode: 'area_sakura',
        customerId: ops.customer.id,
      );
      expect(slot.bookable, isFalse);
      expect(slot.evaluations.length, ops.staff.length, reason: '全員を評価している');
      final hist = slot.rejectHistogram;
      expect(hist, isNotEmpty, reason: '§23 除外理由の内訳が出る');
      expect(
        hist.values.reduce((a, b) => a + b),
        greaterThan(0),
        reason: '理由に件数が付く',
      );
    });

    test('助産師ごとに「満たした／満たさない」を個別に確認できる', () {
      final ops = OpsState();
      final at = onWeekday(DateTime.tuesday, 10);
      final slot = ops.engine.buildSlot(
        service: serviceOf('svc_breast'),
        at: at,
        facilityId: 'fac_sakura',
        areaCode: 'area_sakura',
        customerId: ops.customer.id,
      );
      for (final e in slot.evaluations) {
        // eligible なら理由は空、eligible でないなら必ず理由がある
        expect(
          e.eligible ? e.rejects.isEmpty : e.rejects.isNotEmpty,
          isTrue,
          reason: '${e.staff.name} の判定に理由の欠落がない',
        );
      }
      expect(slot.eligible.length + 0, lessThanOrEqualTo(ops.staff.length));
    });

    test('空いている部屋・設備を一覧できる（必要条件との突き合わせ用）', () {
      final ops = OpsState();
      final at = onWeekday(DateTime.tuesday, 10);
      final free = ops.engine.availableResources(
        service: serviceOf('svc_day4'),
        at: at,
        facilityId: 'fac_sakura',
      );
      expect(free, isNotEmpty, reason: '空きリソースを列挙できる');
      expect(
        free.every((r) => r.facilityId == 'fac_sakura' && r.active),
        isTrue,
      );
    });

    test('不足している設備の種別を特定できる（§23 の核心）', () {
      final ops = OpsState();
      final at = onWeekday(DateTime.tuesday, 10);
      final svc = serviceOf('svc_day4'); // room が必要

      expect(
        ops.engine.missingResourceKinds(
          service: svc,
          at: at,
          facilityId: 'fac_sakura',
        ),
        isEmpty,
        reason: '満室でなければ不足はない',
      );

      // 個室2室を占有して満室にする
      occupy(
        ops,
        place(
          ops,
          serviceId: 'svc_day4',
          at: at,
          staffId: 'st_sato',
          facilityId: 'fac_sakura',
          id: 'bk_c10_1',
        ),
      );
      occupy(
        ops,
        place(
          ops,
          serviceId: 'svc_day4',
          at: at,
          staffId: 'st_ono',
          facilityId: 'fac_sakura',
          id: 'bk_c10_2',
        ),
      );

      expect(
        ops.engine.missingResourceKinds(
          service: svc,
          at: at,
          facilityId: 'fac_sakura',
        ),
        contains(ResourceKind.room),
        reason: '「個室が足りない」と名指しできる',
      );
    });

    test('不足スキルを名指しできる（人side の必要条件 vs 候補）', () {
      expect(
        missingSkills(
          requiredSkills: serviceOf('svc_stay').requiredSkills,
          staffSkills: staffOf('st_kimura').skills,
        ),
        contains('宿泊対応'),
      );
      expect(
        missingSkills(
          requiredSkills: serviceOf('svc_stay').requiredSkills,
          staffSkills: staffOf('st_sato').skills,
        ),
        isEmpty,
        reason: '満たしている助産師は不足ゼロ',
      );
    });

    test('例外は管理者／助産師のキューに振り分けられる（§13）', () {
      final ops = OpsState();
      final at = onWeekday(DateTime.tuesday, 10);
      final held = ops.holdSlot(
        service: serviceOf('svc_visit2'),
        child: ops.customer.children.first,
        at: at,
        intake: {...cleanIntake(), 'fever': true}, // 赤旗
        needs: const [],
        idempotencyKey: 'case10-queue',
      );
      expect(held, isNotNull);
      ops.confirmBooking(held!, consent: consentNow(ops));
      expect(held.state, BookingState.needsReview, reason: '§1 赤旗は自動確定しない');
      expect(
        ops.tasks.any(
          (t) => t.bookingId == held.id && t.owner == TaskOwner.midwife,
        ),
        isTrue,
        reason: '専門職判断は助産師キューへ',
      );
      expect(ops.exceptionQueue.any((b) => b.id == held.id), isTrue);
    });
  });
}
