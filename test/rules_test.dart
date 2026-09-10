// ============================================================================
// rules層（Pure Function）単体テスト — §28
//
// Booking Engine の判定根拠を、State も UI も起動せずに検証する。
// ここが緑である限り、UI をどう作り替えても業務ルールは壊れない。
// ============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:mama_care/ops/ops_models.dart';
import 'package:mama_care/ops/rules/availability_rules.dart';
import 'package:mama_care/ops/rules/eligibility_rules.dart';
import 'package:mama_care/ops/rules/matching_rules.dart';
import 'package:mama_care/ops/rules/resource_rules.dart';

StaffAvailability av(
  int startMin,
  int endMin,
  AvailKind kind, {
  String staffId = 'st_x',
}) => StaffAvailability(
  id: 'a_${startMin}_${endMin}_${kind.name}',
  staffId: staffId,
  date: dayOf(DateTime.now()),
  startMin: startMin,
  endMin: endMin,
  kind: kind,
  updatedAt: DateTime.now(),
);

ServiceDef svc({
  ServiceKind kind = ServiceKind.dayStay,
  int durationMin = 120,
  int travelMin = 0,
  int bufferMin = 15,
  Set<ResourceKind> requiredResourceKinds = const {},
  Set<String> requiredSkills = const {},
  int maxChildAgeDays = 365,
  int minChildAgeDays = 0,
}) => ServiceDef(
  id: 'svc_t',
  name: 'テスト',
  kind: kind,
  durationMin: durationMin,
  requiredSkills: requiredSkills,
  minChildAgeDays: minChildAgeDays,
  maxChildAgeDays: maxChildAgeDays,
  travelMin: travelMin,
  bufferMin: bufferMin,
  priceYen: 0,
  cancelPolicyId: 'cp_standard',
  effectiveFrom: DateTime(2025, 1, 1),
  requiredResourceKinds: requiredResourceKinds,
);

void main() {
  // -------------------------------------------------------------------------
  group('§8 OK − NG｜NGは常にOKに勝つ', () {
    test('subtractRanges：NGがOKの中央を切ると2区間に割れる', () {
      final r = subtractRanges(
        [const TimeRange(540, 1020)], // 09:00-17:00
        [const TimeRange(720, 780)], // 12:00-13:00
      );
      expect(r.length, 2);
      expect(r[0], const TimeRange(540, 720));
      expect(r[1], const TimeRange(780, 1020));
    });

    test('subtractRanges：NGがOKを完全に覆うと働ける時間は消える', () {
      final r = subtractRanges(
        [const TimeRange(540, 1020)],
        [const TimeRange(480, 1080)],
      );
      expect(r, isEmpty, reason: 'NGが全面を覆えば残ってはいけない');
    });

    test('subtractRanges：端が接するだけなら削られない', () {
      final r = subtractRanges(
        [const TimeRange(540, 720)],
        [const TimeRange(720, 780)], // 直後に接する
      );
      expect(r, [const TimeRange(540, 720)]);
    });

    test('workableRanges：登録順に関係なくNGが優先される', () {
      final a = [
        av(720, 780, AvailKind.ng), // NGを先に登録
        av(540, 1020, AvailKind.ok),
      ];
      final b = [
        av(540, 1020, AvailKind.ok), // OKを先に登録
        av(720, 780, AvailKind.ng),
      ];
      expect(workableRanges(a), workableRanges(b));
      expect(workableRanges(a).length, 2);
    });

    test('mergeRanges：連続・重複するOKは1本にまとまる', () {
      final r = mergeRanges([
        const TimeRange(540, 660),
        const TimeRange(660, 720), // 連続
        const TimeRange(700, 780), // 重複
      ]);
      expect(r, [const TimeRange(540, 780)]);
    });

    test('overlapsNg / containedInOk が一致した解釈をする', () {
      final a = [av(540, 1020, AvailKind.ok), av(720, 780, AvailKind.ng)];
      expect(containedInOk(a, const TimeRange(600, 660)), isTrue);
      expect(overlapsNg(a, const TimeRange(600, 660)), isFalse);
      expect(overlapsNg(a, const TimeRange(700, 730)), isTrue);
    });

    test('OK未登録は「空欄」＝予約不可として扱う', () {
      expect(hasOkRegistered([av(720, 780, AvailKind.ng)]), isFalse);
      expect(hasOkRegistered([av(540, 1020, AvailKind.ok)]), isTrue);
    });
  });

  // -------------------------------------------------------------------------
  group('§14 訪問の占有｜移動＋バッファが正しく層になる', () {
    test('訪問は前後に移動時間を持ち、さらにバッファが乗る', () {
      final o = occupancyOf(
        service: svc(kind: ServiceKind.visit, durationMin: 180, travelMin: 30),
        startMin: 600, // 10:00
        bufferMin: 15,
      );
      expect(o.careStart, 600);
      expect(o.careEnd, 780); // 13:00
      expect(o.travelStart, 570, reason: '前の移動30分');
      expect(o.travelEnd, 810, reason: '後の移動30分');
      expect(o.blockStart, 570);
      expect(o.blockEnd, 825, reason: '移動の外側にさらにバッファ15分');
    });

    test('通所・宿泊には移動時間が付かない', () {
      final o = occupancyOf(
        service: svc(
          kind: ServiceKind.dayStay,
          durationMin: 120,
          travelMin: 30,
        ),
        startMin: 600,
        bufferMin: 15,
      );
      expect(o.travelStart, o.careStart, reason: '訪問以外に移動は乗らない');
      expect(o.travelEnd, o.careEnd);
      expect(o.blockEnd, 735);
    });

    test('移動込みの時間がOKに収まらなければ割当不可', () {
      final avail = [av(600, 780, AvailKind.ok)]; // 10:00-13:00
      final o = occupancyOf(
        service: svc(kind: ServiceKind.visit, durationMin: 120, travelMin: 30),
        startMin: 600,
        bufferMin: 15,
      );
      expect(withinOk(avail, o), isFalse, reason: '09:30発の移動がOK開始前なので入れない');
    });
  });

  // -------------------------------------------------------------------------
  group('§12 スキル・条件判定', () {
    test('必要スキルを1つでも欠けば不可、欠けたものを列挙できる', () {
      expect(
        skillSatisfied(
          requiredSkills: {'midwife', 'breast'},
          staffSkills: {'midwife'},
        ),
        isFalse,
      );
      expect(
        missingSkills(
          requiredSkills: {'midwife', 'breast'},
          staffSkills: {'midwife'},
        ),
        ['breast'],
      );
    });

    test('必要スキルが空なら誰でも満たす', () {
      expect(
        skillSatisfied(requiredSkills: const {}, staffSkills: const {}),
        isTrue,
      );
    });
  });

  // -------------------------------------------------------------------------
  group('§15 リソース｜助産師が空いていても部屋が無ければ不可', () {
    final room1 = const OpsResource(
      id: 'r1',
      facilityId: 'f1',
      name: '個室A',
      kind: ResourceKind.room,
      serviceKinds: {ServiceKind.dayStay, ServiceKind.stay},
      overnightCapable: true,
    );
    final room2 = const OpsResource(
      id: 'r2',
      facilityId: 'f1',
      name: '個室B',
      kind: ResourceKind.room,
      serviceKinds: {ServiceKind.dayStay, ServiceKind.stay},
      overnightCapable: true,
    );
    final bath = const OpsResource(
      id: 'b1',
      facilityId: 'f1',
      name: '沐浴',
      kind: ResourceKind.bath,
      serviceKinds: {ServiceKind.dayStay},
    );

    final from = DateTime(2026, 4, 1, 10);
    final to = DateTime(2026, 4, 1, 12);

    BookingResource alloc(String id, String resourceId, String bookingId) =>
        BookingResource(
          id: id,
          bookingId: bookingId,
          resourceId: resourceId,
          from: from,
          to: to,
        );

    test('リソース未登録の施設は、この層では判定しない（従来動作）', () {
      expect(
        resourceAvailable(
          resources: const [],
          allocations: const [],
          facilityId: 'f1',
          kind: ServiceKind.dayStay,
          from: from,
          to: to,
        ),
        isTrue,
      );
    });

    test('個室2室が両方埋まれば不可、1室でも空けば可', () {
      final all = [room1, room2];
      expect(
        resourceAvailable(
          resources: all,
          allocations: [alloc('x1', 'r1', 'bk1')],
          facilityId: 'f1',
          kind: ServiceKind.dayStay,
          from: from,
          to: to,
        ),
        isTrue,
        reason: '個室Bが空いている',
      );
      expect(
        resourceAvailable(
          resources: all,
          allocations: [alloc('x1', 'r1', 'bk1'), alloc('x2', 'r2', 'bk2')],
          facilityId: 'f1',
          kind: ServiceKind.dayStay,
          from: from,
          to: to,
        ),
        isFalse,
        reason: '両室満室なら「部屋の空きなし」',
      );
    });

    test('時間が重ならなければ同じ部屋を使える', () {
      expect(
        resourceFree(
          resource: room1,
          allocations: [alloc('x1', 'r1', 'bk1')],
          from: DateTime(2026, 4, 1, 12),
          to: DateTime(2026, 4, 1, 14),
        ),
        isTrue,
      );
    });

    test('自分自身の予約は重複相手として数えない（変更時）', () {
      expect(
        resourceFree(
          resource: room1,
          allocations: [alloc('x1', 'r1', 'bk1')],
          from: from,
          to: to,
          excludeBookingId: 'bk1',
        ),
        isTrue,
      );
    });

    test('プランが必要とする設備種別は、種別ごとに空きが必要', () {
      final all = [room1, bath];
      // 沐浴設備だけ埋まっている → 沐浴必須プランは不可
      expect(
        resourceAvailable(
          resources: all,
          allocations: [alloc('x1', 'b1', 'bk1')],
          facilityId: 'f1',
          kind: ServiceKind.dayStay,
          from: from,
          to: to,
          requiredKinds: {ResourceKind.room, ResourceKind.bath},
        ),
        isFalse,
      );
      // 部屋だけ必須なら通る
      expect(
        resourceAvailable(
          resources: all,
          allocations: [alloc('x1', 'b1', 'bk1')],
          facilityId: 'f1',
          kind: ServiceKind.dayStay,
          from: from,
          to: to,
          requiredKinds: {ResourceKind.room},
        ),
        isTrue,
      );
    });

    test('その設備を持たない施設では、必須指定でも従来動作にする', () {
      expect(
        resourceAvailable(
          resources: [room1],
          allocations: const [],
          facilityId: 'f1',
          kind: ServiceKind.dayStay,
          from: from,
          to: to,
          requiredKinds: {ResourceKind.bath}, // f1に沐浴設備は無い
        ),
        isTrue,
      );
    });

    test('定員つきリソースは定員まで同時利用できる', () {
      const seat = OpsResource(
        id: 's1',
        facilityId: 'f1',
        name: '座席',
        kind: ResourceKind.seat,
        capacity: 2,
        serviceKinds: {ServiceKind.breastClinic},
      );
      expect(
        resourceFree(
          resource: seat,
          allocations: [alloc('x1', 's1', 'bk1')],
          from: from,
          to: to,
        ),
        isTrue,
        reason: '定員2のうち1枠使用中',
      );
      expect(
        resourceFree(
          resource: seat,
          allocations: [alloc('x1', 's1', 'bk1'), alloc('x2', 's1', 'bk2')],
          from: from,
          to: to,
        ),
        isFalse,
        reason: '定員に達したら不可',
      );
    });
  });

  // -------------------------------------------------------------------------
  group('§12 ①〜⑤ 利用条件', () {
    final program = MunicipalityProgram(
      id: 'mun_t',
      name: 'テスト市',
      version: 1,
      effectiveFrom: DateTime(2025, 1, 1),
      maxUseCount: 7,
      maxChildAgeDays: 120,
      maxConcurrentBookings: 3,
    );

    OpsChild childAged(int days) => OpsChild(
      id: 'ch_t',
      name: 'テスト',
      kana: 'てすと',
      birth: dayOf(DateTime.now()).subtract(Duration(days: days)),
      birthOrder: 1,
    );

    EligibilityContext ctx({
      int ageDays = 30,
      bool hasProgramNumber = true,
      int usedCount = 0,
      int futureBookingCount = 0,
      Municipality? municipality,
      ServiceDef? service,
    }) => EligibilityContext(
      service: service ?? svc(),
      child: childAged(ageDays),
      at: DateTime.now(),
      program: program,
      municipality: municipality,
      hasProgramNumber: hasProgramNumber,
      usedCount: usedCount,
      futureBookingCount: futureBookingCount,
    );

    test('条件を満たせば例外は立たない（自動処理可）', () {
      expect(evaluateEligibility(ctx()), isEmpty);
    });

    test('①事業番号が未提出なら要確認', () {
      final c = ctx(hasProgramNumber: false);
      expect(programNumberMissing(c), isTrue);
      expect(evaluateEligibility(c), contains(ReasonCode.eligibilityUnknown));
      expect(eligibilityMessage(c), contains('利用券番号'));
    });

    test('②利用回数の上限に達したら要確認・のこりは負にならない', () {
      final c = ctx(usedCount: 7);
      expect(useCountExceeded(c), isTrue);
      expect(remainingUses(ctx(usedCount: 9)), 0);
      expect(remainingUses(ctx(usedCount: 2)), 5);
    });

    test('③自治体の月齢上限を超えたら要確認', () {
      expect(childAgeOutOfRange(ctx(ageDays: 200)), isTrue);
      expect(childAgeOutOfRange(ctx(ageDays: 100)), isFalse);
    });

    test('③サービスの下限月齢を下回る場合も対象外', () {
      final c = ctx(ageDays: 5, service: svc(minChildAgeDays: 14));
      expect(childAgeOutOfRange(c), isTrue);
    });

    test('④自治体がこの事業を実施していなければ対象外', () {
      const notOffering = Municipality(
        id: 'city_x',
        name: 'よその市',
        prefecture: 'よそ県',
        programIds: ['mun_other'],
      );
      final c = ctx(municipality: notOffering);
      expect(municipalityOffersProgram(c), isFalse);
      expect(eligibilityMessage(c), contains('実施していません'));
    });

    test('④自治体マスタ未登録なら従来どおり通す', () {
      expect(municipalityOffersProgram(ctx()), isTrue);
    });

    test('⑤先のご予約が上限件数に達したら予約数制限で要確認', () {
      final c = ctx(futureBookingCount: 3);
      expect(concurrentBookingLimitReached(c), isTrue);
      expect(evaluateEligibility(c), contains(ReasonCode.futureBookingLimit));
      expect(eligibilityMessage(c), contains('3件'));
    });

    test('⑤上限未満ならリピーターでも止めない（§21・§33）', () {
      expect(
        concurrentBookingLimitReached(ctx(futureBookingCount: 2)),
        isFalse,
      );
      expect(evaluateEligibility(ctx(futureBookingCount: 2)), isEmpty);
    });

    test('⑤上限 0 は「制限なし」として扱う', () {
      final noLimit = MunicipalityProgram(
        id: 'mun_free',
        name: '制限なし市',
        version: 1,
        effectiveFrom: DateTime(2025, 1, 1),
        maxConcurrentBookings: 0,
      );
      final c = EligibilityContext(
        service: svc(),
        child: childAged(30),
        at: DateTime.now(),
        program: noLimit,
        futureBookingCount: 99,
      );
      expect(concurrentBookingLimitReached(c), isFalse);
    });

    test('複数の理由が重なっても ReasonCode は重複しない', () {
      final c = ctx(hasProgramNumber: false, usedCount: 9, ageDays: 300);
      final r = evaluateEligibility(c);
      expect(r.where((e) => e == ReasonCode.eligibilityUnknown).length, 1);
    });
  });

  // -------------------------------------------------------------------------
  group('§12 ⑨〜⑮ 既存予約との衝突・上限', () {
    OpsBooking bk(int startMin, int durationMin) => OpsBooking(
      id: 'bk_$startMin',
      code: 'C$startMin',
      customerId: 'cu',
      childId: 'ch',
      serviceId: 'svc_t',
      at: dayOf(DateTime.now()).add(Duration(minutes: startMin)),
      durationMin: durationMin,
      kind: ServiceKind.dayStay,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    test('本体が重なれば hardOverlap', () {
      final o = occupancyOf(service: svc(), startMin: 600, bufferMin: 15);
      final c = evaluateBookings(
        sameDayBookings: [bk(660, 120)],
        o: o,
        bufferMin: 15,
      );
      expect(c.hardOverlap, isTrue);
    });

    test('本体は重ならないがバッファに食い込めば bufferOverlap', () {
      final o = occupancyOf(service: svc(), startMin: 600, bufferMin: 15);
      // 10:00-12:00 のケア。12:05開始は本体非重複だがバッファ内。
      final c = evaluateBookings(
        sameDayBookings: [bk(725, 60)],
        o: o,
        bufferMin: 15,
      );
      expect(c.hardOverlap, isFalse);
      expect(c.bufferOverlap, isTrue);
    });

    test('十分離れていればどちらも立たず、負荷だけ積まれる', () {
      final o = occupancyOf(service: svc(), startMin: 600, bufferMin: 15);
      final c = evaluateBookings(
        sameDayBookings: [bk(900, 60)],
        o: o,
        bufferMin: 15,
      );
      expect(c.hardOverlap, isFalse);
      expect(c.bufferOverlap, isFalse);
      expect(c.loadMin, 60);
      expect(c.count, 1);
    });

    test('1日上限・連続件数の上限を超える割当は不可', () {
      expect(
        dailyCapExceeded(loadMin: 300, addMin: 180, dailyMaxMin: 420),
        isTrue,
      );
      expect(
        dailyCapExceeded(loadMin: 120, addMin: 120, dailyMaxMin: 420),
        isFalse,
      );
      expect(consecutiveExceeded(count: 3, consecutiveMax: 3), isTrue);
      expect(consecutiveExceeded(count: 2, consecutiveMax: 3), isFalse);
    });

    test('スコアは 負荷が軽い・移動が少ない・継続担当 を高く評価する', () {
      final light = assignmentScore(
        loadMin: 0,
        dailyMaxMin: 420,
        travelPenaltyMin: 0,
        continuity: true,
      );
      final heavy = assignmentScore(
        loadMin: 400,
        dailyMaxMin: 420,
        travelPenaltyMin: 30,
        continuity: false,
      );
      expect(light, greaterThan(heavy));
    });

    test('継続担当（前回と同じ助産師）は加点される', () {
      final withC = assignmentScore(
        loadMin: 120,
        dailyMaxMin: 420,
        travelPenaltyMin: 0,
        continuity: true,
      );
      final without = assignmentScore(
        loadMin: 120,
        dailyMaxMin: 420,
        travelPenaltyMin: 0,
        continuity: false,
      );
      expect(withC - without, closeTo(25, 0.001));
    });
  });
}
