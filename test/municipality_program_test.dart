// 要件再定義（2026-09）：自治体制度マスタ・料金計算・利用申請フローのテスト
//
// 守りたいこと
//  1. 料金・対象条件はコードに直接書かず、有効期間付きルール（マスタ）から出る
//  2. MAMOA の料金表示は「概算」。確定は人（スタッフ）が行う
//  3. 未申請／申請中は予約確定できない。行政調整型は MAMOA で確定しない
//  4. ボタン文言は自治体・申請状態で変わる
//  5. 状態遷移：確定→問診済み→実施済み→請求済み／対象外／自費切替／引継ぎ
import 'package:flutter_test/flutter_test.dart';
import 'package:mama_care/ops/ops_models.dart';
import 'package:mama_care/ops/ops_seed.dart';
import 'package:mama_care/ops/ops_state.dart';
import 'package:mama_care/ops/rules/eligibility_rules.dart';
import 'package:mama_care/ops/rules/fee_rules.dart';

MunicipalityProgram _prog(String id) =>
    seedMunicipalities.firstWhere((m) => m.id == id);

ServiceDef _svc(String id) => seedServices.firstWhere((s) => s.id == id);

/// [asOf] は日齢を数える基準日。判定日を固定するテストでは同じ日を渡す
/// （実行日によって日齢がずれないようにするため）。
OpsChild _child({int ageDays = 30, int plurality = 1, DateTime? asOf}) =>
    OpsChild(
      id: 'c',
      name: 'テスト',
      kana: 'テスト',
      birth: (asOf ?? DateTime.now()).subtract(Duration(days: ageDays)),
      multiple: plurality > 1,
      pluralityValue: plurality,
    );

DateTime _onWeekday(int weekday, int hour, {int ahead = 21}) {
  var d = DateTime.now().add(Duration(days: ahead));
  while (d.weekday != weekday) {
    d = d.add(const Duration(days: 1));
  }
  return DateTime(d.year, d.month, d.day, hour);
}

void main() {
  // ---------------------------------------------------------------------------
  group('自治体制度マスタ｜5自治体が有効期間・出典・調整主体を持つ', () {
    test('5自治体が登録され、必須のメタ情報を持つ', () {
      expect(seedMunicipalities.length, 5);
      for (final m in seedMunicipalities) {
        expect(m.sourceUrl, isNotEmpty, reason: '${m.name} 公式URL');
        expect(m.lastVerifiedAt, isNotNull, reason: '${m.name} 最終確認日');
        expect(m.verifiedBy, isNotEmpty, reason: '${m.name} 確認担当');
        expect(m.applicationContact, isNotEmpty, reason: '${m.name} 申請先');
        expect(m.feeRules, isNotEmpty, reason: '${m.name} 料金ルール');
        expect(m.effectiveTo, isNotNull, reason: '${m.name} 適用終了日');
      }
    });

    test('予約・日程調整の主体が自治体ごとに異なる', () {
      expect(_prog('mun_nagoya').scheduling, SchedulingAuthority.provider);
      expect(_prog('mun_seto').scheduling, SchedulingAuthority.municipality);
      expect(_prog('mun_komaki').scheduling, SchedulingAuthority.municipality);
      expect(_prog('mun_nagakute').scheduling, SchedulingAuthority.shared);
    });

    test('MVP：予約機能は名古屋市のみ。他は制度案内', () {
      expect(_prog('mun_nagoya').bookingEnabled, isTrue);
      for (final id in [
        'mun_owariasahi',
        'mun_nagakute',
        'mun_seto',
        'mun_komaki',
      ]) {
        expect(_prog(id).bookingEnabled, isFalse, reason: id);
      }
    });

    test('有効期間の判定（年度をまたぐ旧版は無効）', () {
      final m = _prog('mun_nagoya');
      expect(m.isEffectiveAt(DateTime(2026, 6, 1)), isTrue);
      expect(m.isEffectiveAt(DateTime(2025, 9, 30)), isFalse);
      expect(m.isEffectiveAt(DateTime(2027, 4, 1)), isFalse);
    });

    test('尾張旭市：双子・三つ子の対象月齢は単胎より短い', () {
      final e = _prog(
        'mun_owariasahi',
      ).eligibilityFor(ProgramServiceType.dayCare)!;
      expect(e.maxAgeDaysFor(1), 364);
      expect(e.maxAgeDaysFor(2), 213);
      expect(e.maxAgeDaysFor(3), 213);
    });

    test('未確認のキャンセル規定は「未確認」と表示し、金額を断定しない', () {
      expect(_prog('mun_owariasahi').cancelRule.verified, isFalse);
      expect(_prog('mun_owariasahi').cancelRule.label, contains('未確認'));
      expect(_prog('mun_nagakute').cancelRule.label, contains('1650'));
    });
  });

  // ---------------------------------------------------------------------------
  group('料金計算（§4）｜概算はマスタから出る。確定しない', () {
    FeeEstimate est(
      String mun,
      String svc, {
      TaxClass tax = TaxClass.taxable,
      int useIndex = 1,
      bool coupon = false,
      int plurality = 1,
      FundingType funding = FundingType.municipal,
    }) => estimateFee(
      FeeContext(
        program: _prog(mun),
        service: _svc(svc),
        child: _child(plurality: plurality),
        at: DateTime(2026, 10, 1),
        useIndex: useIndex,
        taxClass: tax,
        couponUsed: coupon,
        funding: funding,
      ),
    );

    test('名古屋市：通所2,360円／訪問1,560円／非課税0円', () {
      expect(est('mun_nagoya', 'svc_day4').yen, 2360);
      expect(est('mun_nagoya', 'svc_visit3').yen, 1560);
      expect(est('mun_nagoya', 'svc_day4', tax: TaxClass.exempt).yen, 0);
    });

    test('尾張旭市：1〜5日目と6日目以降で段階が変わる', () {
      expect(est('mun_owariasahi', 'svc_day4', useIndex: 5).yen, 1250);
      expect(est('mun_owariasahi', 'svc_day4', useIndex: 6).yen, 3750);
      expect(est('mun_owariasahi', 'svc_visit3', useIndex: 1).yen, 500);
      expect(est('mun_owariasahi', 'svc_visit3', useIndex: 7).yen, 3000);
    });

    test('長久手市：クーポン有無で料金が変わる', () {
      expect(est('mun_nagakute', 'svc_day4', coupon: true).yen, 1000);
      expect(est('mun_nagakute', 'svc_day4', coupon: false).yen, 3500);
    });

    test('瀬戸市：回数段階＋双子別料金、訪問は2回まで無料', () {
      expect(est('mun_seto', 'svc_day4', useIndex: 3).yen, 1500);
      expect(est('mun_seto', 'svc_day4', useIndex: 6).yen, 4000);
      expect(est('mun_seto', 'svc_day4', useIndex: 2, plurality: 2).yen, 1800);
      expect(est('mun_seto', 'svc_day4', useIndex: 7, plurality: 2).yen, 4300);
      expect(est('mun_seto', 'svc_visit3', useIndex: 2).yen, 0);
    });

    test('ルールに一致しない条件は概算を出さず、要確認（M-03）へ', () {
      // 瀬戸市の訪問3回目は料金表に無い → 断定しない
      final f = est('mun_seto', 'svc_visit3', useIndex: 3);
      expect(f.determined, isFalse);
      expect(f.reason, ReasonCode.feeUndetermined);
    });

    test('母乳外来は自治体事業の類型外＝自費（定価）', () {
      final f = est('mun_nagoya', 'svc_breast');
      expect(f.isSelfPay, isTrue);
      expect(f.yen, _svc('svc_breast').priceYen);
    });

    test('自費指定なら自治体ルールを使わず定価', () {
      final f = est('mun_nagoya', 'svc_day4', funding: FundingType.selfPay);
      expect(f.isSelfPay, isTrue);
      expect(f.yen, _svc('svc_day4').priceYen);
    });

    test('自治体側キャンセル料：長久手市は前日17時以降1,650円', () {
      final bookingAt = DateTime(2026, 10, 10, 10);
      expect(
        municipalCancelFee(
          program: _prog('mun_nagakute'),
          bookingAt: bookingAt,
          cancelAt: DateTime(2026, 10, 9, 16, 59),
        ),
        0,
      );
      expect(
        municipalCancelFee(
          program: _prog('mun_nagakute'),
          bookingAt: bookingAt,
          cancelAt: DateTime(2026, 10, 9, 17, 0),
        ),
        1650,
      );
      // 未確認の自治体は null（断定しない）
      expect(
        municipalCancelFee(
          program: _prog('mun_owariasahi'),
          bookingAt: bookingAt,
          cancelAt: DateTime(2026, 10, 9, 20),
        ),
        isNull,
      );
    });
  });

  // ---------------------------------------------------------------------------
  group('利用条件｜申請状態・利用券・施設受入が判定に効く', () {
    EligibilityContext ctx({
      ApplicationStatus application = ApplicationStatus.approved,
      bool voucherVerified = true,
      FundingType funding = FundingType.municipal,
      int ageDays = 30,
      int plurality = 1,
      String mun = 'mun_nagoya',
      OpsFacility? facility,
    }) => EligibilityContext(
      service: _svc('svc_day4'),
      child: _child(
        ageDays: ageDays,
        plurality: plurality,
        asOf: DateTime(2026, 10, 1),
      ),
      at: DateTime(2026, 10, 1),
      program: _prog(mun),
      application: application,
      voucherVerified: voucherVerified,
      funding: funding,
      facility: facility,
    );

    test('未申請・申請中は M-01 で止まる（承認済みだけが通る）', () {
      expect(
        evaluateEligibility(ctx(application: ApplicationStatus.notApplied)),
        contains(ReasonCode.applicationMissing),
      );
      expect(
        evaluateEligibility(ctx(application: ApplicationStatus.applied)),
        contains(ReasonCode.applicationMissing),
      );
      expect(
        evaluateEligibility(ctx()),
        isNot(contains(ReasonCode.applicationMissing)),
      );
    });

    test('利用券未確認は M-02', () {
      expect(
        evaluateEligibility(ctx(voucherVerified: false)),
        contains(ReasonCode.voucherUnverified),
      );
    });

    test('自費なら自治体条件は見ない', () {
      final r = evaluateEligibility(
        ctx(
          application: ApplicationStatus.notApplied,
          voucherVerified: false,
          funding: FundingType.selfPay,
        ),
      );
      expect(r, isNot(contains(ReasonCode.applicationMissing)));
      expect(r, isNot(contains(ReasonCode.voucherUnverified)));
    });

    test('尾張旭市：双子は7か月を超えると対象外、単胎は対象', () {
      expect(
        evaluateEligibility(
          ctx(mun: 'mun_owariasahi', ageDays: 240, plurality: 2),
        ),
        contains(ReasonCode.eligibilityUnknown),
      );
      expect(
        clearlyNotEligible(
          ctx(mun: 'mun_owariasahi', ageDays: 240, plurality: 2),
        ),
        isTrue,
      );
      expect(
        evaluateEligibility(
          ctx(mun: 'mun_owariasahi', ageDays: 240, plurality: 1),
        ),
        isNot(contains(ReasonCode.eligibilityUnknown)),
      );
    });

    test('施設の受入条件（多胎不可・月齢上限）で M-06', () {
      const f = OpsFacility(
        id: 'f',
        name: 'f',
        area: 'a',
        rooms: 1,
        concurrentCapacity: 1,
        acceptsMultiples: false,
        maxChildAgeDays: 120,
      );
      expect(
        evaluateEligibility(ctx(facility: f, plurality: 2)),
        contains(ReasonCode.facilityAcceptance),
      );
      expect(
        evaluateEligibility(ctx(facility: f, ageDays: 200)),
        contains(ReasonCode.facilityAcceptance),
      );
    });

    test('多胎児は助産師（専門職）の確認へ回る', () {
      final r = evaluateEligibility(ctx(plurality: 2));
      expect(r, contains(ReasonCode.multipleBirth));
      expect(ReasonCode.multipleBirth.toMidwife, isTrue);
    });

    test('申請中の説明文は「決定通知が届いてから」と伝える', () {
      expect(
        eligibilityMessage(ctx(application: ApplicationStatus.applied)),
        contains('決定通知'),
      );
    });
  });

  // ---------------------------------------------------------------------------
  group('ボタン文言｜自治体・申請状態で変わる', () {
    test('未申請 → 自治体へ利用申請する', () {
      expect(
        familyCtaFor(
          application: ApplicationStatus.notApplied,
          scheduling: SchedulingAuthority.provider,
          instant: false,
          selfPay: false,
          requiresApproval: true,
        ),
        '自治体へ利用申請する',
      );
    });
    test('行政調整型 → 利用希望を送る', () {
      expect(
        familyCtaFor(
          application: ApplicationStatus.approved,
          scheduling: SchedulingAuthority.municipality,
          instant: false,
          selfPay: false,
          requiresApproval: true,
        ),
        '利用希望を送る',
      );
    });
    test('事業所調整型 → 仮予約を申し込む', () {
      expect(
        familyCtaFor(
          application: ApplicationStatus.approved,
          scheduling: SchedulingAuthority.provider,
          instant: false,
          selfPay: false,
          requiresApproval: true,
        ),
        '仮予約を申し込む',
      );
    });
    test('自費・即時確定 → この日時で予約する', () {
      expect(
        familyCtaFor(
          application: ApplicationStatus.notApplied,
          scheduling: SchedulingAuthority.municipality,
          instant: true,
          selfPay: true,
          requiresApproval: true,
        ),
        'この日時で予約する',
      );
    });
  });

  // ---------------------------------------------------------------------------
  group('フロー｜MAMOA は一次受付。確定は人が行う', () {
    late OpsState ops;
    setUp(() => ops = OpsState());

    ConsentSnapshot consent(OpsState o) {
      final t = o.terms.first;
      return ConsentSnapshot(
        termsId: t.id,
        title: t.title,
        version: t.version,
        revisedAt: t.revisedAt,
        agreedAt: DateTime.now(),
        agreedText: '',
      );
    }

    OpsBooking? hold(
      OpsState o,
      String svcId, {
      String? facilityId,
      String key = 'k',
    }) => o.holdSlot(
      service: o.serviceById(svcId),
      child: o.customer.children.first,
      at: _onWeekday(DateTime.tuesday, 10),
      facilityId: facilityId,
      intake: {'bath': false, 'meal': false, 'allergy': ''},
      needs: const ['休みたい'],
      idempotencyKey: key,
    );

    test('初期データのご家族は名古屋市・承認済み・利用券確認済み', () {
      expect(ops.customer.municipalityId, 'mun_nagoya');
      expect(ops.customer.application.status, ApplicationStatus.approved);
      expect(ops.voucherVerifiedForCustomer, isTrue);
    });

    test('予約に自治体マスタの版・概算根拠・費用区分が凍結される', () {
      final b = hold(ops, 'svc_day4', facilityId: 'fac_sakura')!;
      expect(b.municipalityProgramId, 'mun_nagoya');
      expect(b.municipalityProgramVersion, _prog('mun_nagoya').version);
      expect(b.funding, FundingType.municipal);
      expect(b.feeYen, 2360, reason: '名古屋市 通所の概算');
      expect(b.feeState, FeeState.estimate, reason: '概算。確定ではない');
      expect(b.feeBasis, contains('名古屋市'));
    });

    test('未申請のご家族は確認待ち（M-01）になり、確定しない', () {
      ops.switchMunicipality('mun_nagoya'); // 申請状態が未申請に戻る
      expect(ops.customer.application.status, ApplicationStatus.notApplied);
      final b = hold(ops, 'svc_day4', facilityId: 'fac_sakura')!;
      expect(
        b.exceptions.map((e) => e.code),
        contains(ReasonCode.applicationMissing),
      );
      ops.confirmBooking(b, consent: consent(ops));
      expect(b.state, BookingState.needsReview);
      // 申請→利用券登録→スタッフ確認 で通るようになる
      ops.markApplied();
      expect(ops.customer.application.status, ApplicationStatus.applied);
      ops.registerVoucher('NG-9999');
      expect(ops.customer.application.status, ApplicationStatus.approved);
      expect(ops.voucherVerifiedForCustomer, isFalse, reason: 'スタッフ確認前');
      ops.switchRole(OpsRole.admin);
      ops.verifyVoucher();
      expect(ops.voucherVerifiedForCustomer, isTrue);
    });

    test('行政調整型（瀬戸市）の利用希望は 行政調整中 になり、MAMOA では確定しない', () {
      ops.switchMunicipality('mun_seto');
      ops.registerVoucher('ST-0001');
      ops.switchRole(OpsRole.admin);
      ops.verifyVoucher();
      ops.switchRole(OpsRole.family);
      final b = hold(ops, 'svc_day4', facilityId: 'fac_sakura')!;
      expect(
        b.hasOpenException,
        isFalse,
        reason: b.exceptions.map((e) => e.code.code).join(','),
      );
      ops.confirmBooking(b, consent: consent(ops));
      expect(b.state, BookingState.municipalCoordination);
      expect(b.state.isActive, isFalse);
      expect(b.state.familyHint, contains('確定はまだ'));
    });

    test('事業所調整型（名古屋市）の利用希望は 利用希望受付 → 仮予約 → ご家族が確定', () {
      final b = hold(ops, 'svc_day4', facilityId: 'fac_sakura')!;
      ops.confirmBooking(b, consent: consent(ops));
      expect(b.state, BookingState.requested);
      ops.switchRole(OpsRole.admin);
      expect(ops.setProvisional(b), isTrue);
      expect(b.state, BookingState.provisional);
      ops.switchRole(OpsRole.family);
      expect(
        ops.actionRequired.map((e) => e.id),
        contains(b.id),
        reason: '家族の「確定する」導線',
      );
      expect(ops.familyConfirmProvisional(b), isTrue);
      expect(b.state, BookingState.confirmed);
      expect(b.feeState, FeeState.confirmed);
    });

    test('利用券未確認のままスタッフが確定しようとしても断られる', () {
      ops.switchMunicipality('mun_nagoya');
      ops.registerVoucher('NG-0002'); // 承認済みだが未確認
      final b = hold(ops, 'svc_day4', facilityId: 'fac_sakura')!;
      ops.confirmBooking(b, consent: consent(ops));
      ops.switchRole(OpsRole.admin);
      // 例外（M-02）を解消しても、利用券確認そのものが済んでいないと確定不可
      expect(ops.approveRequest(b), isFalse);
      ops.verifyVoucher();
      for (final ex in b.openExceptions) {
        ex.resolved = true;
      }
      expect(ops.approveRequest(b), isTrue);
      expect(b.voucherVerified, isTrue);
    });

    test('確定 → 問診済み → 利用中 → 実施済み → 請求済み（利用回数が増える）', () {
      final b = hold(ops, 'svc_breast', facilityId: 'fac_sakura')!; // INSTANT
      ops.confirmBooking(b, consent: consent(ops));
      expect(b.state, BookingState.confirmed);
      ops.switchRole(OpsRole.midwife);
      expect(ops.markIntakeDone(b), isTrue);
      expect(b.state, BookingState.intakeDone);
      ops.startService(b);
      expect(b.state, BookingState.inService);
      ops.completeService(b, '');
      expect(b.state, BookingState.completed);
      ops.switchRole(OpsRole.admin);
      final before = ops.customer.usedCount;
      expect(ops.markBilled(b), isTrue);
      expect(b.state, BookingState.billed);
      // 母乳外来は自費なので回数は増えない
      expect(ops.customer.usedCount, before);
    });

    test('制度利用の実施済みを請求済みにすると利用回数が1増える', () {
      final b = hold(ops, 'svc_day4', facilityId: 'fac_sakura')!;
      ops.confirmBooking(b, consent: consent(ops));
      ops.switchRole(OpsRole.admin);
      ops.approveRequest(b);
      ops.startService(b);
      ops.completeService(b, '');
      final before = ops.customer.usedCount;
      ops.markBilled(b);
      expect(ops.customer.usedCount, before + 1);
    });

    test('対象外 → 自費切替 で料金が定価に置き換わり、履歴に理由が残る', () {
      final b = hold(ops, 'svc_day4', facilityId: 'fac_sakura')!;
      ops.confirmBooking(b, consent: consent(ops));
      ops.switchRole(OpsRole.admin);
      expect(ops.markBookingNotEligible(b, reason: '利用券が期限切れ'), isTrue);
      expect(b.state, BookingState.notEligible);
      expect(ops.switchToSelfPay(b, reason: 'ご家族の希望'), isTrue);
      expect(b.funding, FundingType.selfPay);
      expect(b.feeYen, ops.serviceById('svc_day4').priceYen);
      expect(b.state, BookingState.requested, reason: '自費として再度スタッフ確認へ');
      expect(b.stateLog.any((l) => l.contains('自費へ切替')), isTrue);
    });

    test('医療機関案内への引継ぎは枠を解放し、要配慮として監査に残る', () {
      final b = hold(ops, 'svc_day4', facilityId: 'fac_sakura')!;
      ops.confirmBooking(b, consent: consent(ops));
      ops.switchRole(OpsRole.midwife);
      expect(
        ops.handOff(
          b,
          kind: HandoffKind.medicalReferral,
          note: '乳腺炎の疑い。受診をご案内',
        ),
        isTrue,
      );
      expect(b.state, BookingState.handedOff);
      expect(b.handoff, HandoffKind.medicalReferral);
      expect(ops.auditLog.last.sensitiveAccess, isTrue);
    });

    test('自治体マスタの改定は版を上げ、確認だけなら版を上げない', () {
      ops.switchRole(OpsRole.admin);
      final v0 = _progFrom(ops, 'mun_nagoya').version;
      ops.verifyProgram('mun_nagoya', by: 'テスト');
      expect(_progFrom(ops, 'mun_nagoya').version, v0, reason: '確認は改定ではない');
      expect(_progFrom(ops, 'mun_nagoya').verifiedBy, 'テスト');
      ops.updateProgram(
        'mun_nagoya',
        feeRules: const [
          FeeRule(service: ProgramServiceType.dayCare, yen: 9999),
        ],
      );
      expect(_progFrom(ops, 'mun_nagoya').version, v0 + 1);
      // 改定が概算に効く（固定実装していない）
      final f = ops.estimateFeeFor(
        service: ops.serviceById('svc_day4'),
        child: ops.customer.children.first,
        at: _onWeekday(DateTime.tuesday, 10),
      );
      expect(f.yen, 9999);
    });

    test('要確認事項はデータとして持ち、解決すると監査に残る', () {
      expect(ops.unresolvedIssues.length, greaterThanOrEqualTo(10));
      expect(ops.issuesFor('mun_nagoya'), isNotEmpty);
      ops.switchRole(OpsRole.admin);
      final id = ops.issuesFor('mun_nagoya').first.id;
      expect(ops.resolveOpenIssue(id, resolution: '市に確認：前日まで'), isTrue);
      expect(ops.issuesFor('mun_nagoya').any((i) => i.id == id), isFalse);
      expect(ops.resolveOpenIssue(id, resolution: '二重解決'), isFalse);
    });
  });
}

MunicipalityProgram _progFrom(OpsState o, String id) =>
    o.municipalities.firstWhere((m) => m.id == id);
