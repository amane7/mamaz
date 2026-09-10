// ============================================================================
// スキル × OK／NG時間による予約可能枠生成エンジン
// 要件定義書 §6.1 / §8.2 / 付録C.5
//
// 予約割当の成立条件（すべて満たすこと）:
//   ① 必要スキル一致
//   ② 予約時間がOK時間内（前後バッファを含む）
//   ③ NG時間・確定予約・休暇と非重複（NGが最優先）
//   ④ 移動時間・予約間バッファを確保
//   ⑤ 1日上限・連続対応上限を超えない
//   ⑥ 訪問地域・施設条件を満たす
//
// 空欄時間（OKにもNGにも未登録）は原則予約不可。
// 候補0人ならその枠を家族に表示しない（別時間・別スタッフ・待機リストを提示）。
// KPI: スキル不一致／NG時間への予約割当 0件
// ============================================================================

import 'ops_models.dart';
import 'rules/availability_rules.dart';
import 'rules/matching_rules.dart';
import 'rules/resource_rules.dart';

/// 除外理由（監査・管理者向けの説明可能性のため必ず記録する）
enum RejectReason {
  skillMismatch, // ①
  outsideOk, // ②
  overlapNg, // ③ NG時間
  overlapBooking, // ③ 確定予約
  overlapBlock, // ③ 休暇
  bufferViolation, // ④
  dailyCapExceeded, // ⑤ 1日上限
  consecutiveExceeded, // ⑤ 連続対応上限
  areaMismatch, // ⑥ 訪問地域
  facilityMismatch, // ⑥ 施設条件
  serviceMismatch, // ⑥ 対応サービス
  noOkRegistered, // 空欄時間
  resourceUnavailable, // §15 部屋・ベッド・設備の空きなし
}

extension RejectReasonX on RejectReason {
  String get label => switch (this) {
    RejectReason.skillMismatch => '必要スキル不一致',
    RejectReason.outsideOk => 'OK時間外',
    RejectReason.overlapNg => 'NG時間と重複',
    RejectReason.overlapBooking => '確定予約と重複',
    RejectReason.overlapBlock => '休暇・研修と重複',
    RejectReason.bufferViolation => '移動時間・バッファ不足',
    RejectReason.dailyCapExceeded => '1日上限を超過',
    RejectReason.consecutiveExceeded => '連続対応上限を超過',
    RejectReason.areaMismatch => '訪問エリア外',
    RejectReason.facilityMismatch => '施設条件不一致',
    RejectReason.serviceMismatch => '対応サービス外',
    RejectReason.noOkRegistered => 'OK時間が未登録（原則予約不可）',
    RejectReason.resourceUnavailable => '部屋・設備の空きなし',
  };

  /// 家族に見せてよい情報か（NG理由・私的予定は非開示 = §19）
  bool get familyVisible =>
      this == RejectReason.areaMismatch ||
      this == RejectReason.facilityMismatch ||
      this == RejectReason.resourceUnavailable;
}

class StaffEvaluation {
  final OpsStaff staff;
  final bool eligible;
  final List<RejectReason> rejects;
  final double score; // 高いほど優先（負荷平準化・移動効率・連続性）
  final int loadMinToday;
  final int bookingsToday;
  final int travelPenaltyMin;
  final bool continuity; // 同一顧客の継続担当

  const StaffEvaluation({
    required this.staff,
    required this.eligible,
    required this.rejects,
    required this.score,
    required this.loadMinToday,
    required this.bookingsToday,
    required this.travelPenaltyMin,
    required this.continuity,
  });

  String get reasonSummary =>
      rejects.isEmpty ? '割当可' : rejects.map((r) => r.label).join(' / ');
}

class SlotCandidate {
  final DateTime at;
  final ServiceDef service;
  final String? facilityId;
  final List<StaffEvaluation> evaluations;

  /// §15 施設定員・部屋（Resource）に空きが無い枠。
  /// 助産師が空いていても予約は成立しない（人と設備は別資源）。
  final bool resourceFull;

  const SlotCandidate({
    required this.at,
    required this.service,
    this.facilityId,
    required this.evaluations,
    this.resourceFull = false,
  });

  List<StaffEvaluation> get eligible =>
      evaluations.where((e) => e.eligible).toList()
        ..sort((a, b) => b.score.compareTo(a.score));

  bool get bookable => !resourceFull && eligible.isNotEmpty;
  StaffEvaluation? get best => eligible.isEmpty ? null : eligible.first;

  /// 家族に見せない理由をまとめる（管理者・監査用）
  Map<RejectReason, int> get rejectHistogram {
    final m = <RejectReason, int>{};
    for (final e in evaluations) {
      for (final r in e.rejects) {
        m[r] = (m[r] ?? 0) + 1;
      }
    }
    return m;
  }
}

/// 割当結果（自動確定 / 例外 / 枠なし）
class AssignmentResult {
  final SlotCandidate? slot;
  final StaffEvaluation? assigned;
  final List<ReasonCode> exceptions;
  final List<SlotCandidate> alternatives;
  const AssignmentResult({
    this.slot,
    this.assigned,
    this.exceptions = const [],
    this.alternatives = const [],
  });

  bool get autoConfirmable => assigned != null && exceptions.isEmpty;
}

class MatchingEngine {
  final List<OpsStaff> staff;
  final List<StaffAvailability> availability;
  final List<StaffBlock> blocks;
  final List<OpsBooking> bookings;
  final List<OpsFacility> facilities;

  /// §15 設備資源（個室・ベッド・座席・沐浴設備）。
  /// 未登録の施設は従来どおり施設定員だけで判定する（後方互換）。
  final List<OpsResource> resources;

  /// 予約 ⇄ リソースの割当。二重予約防止の排他単位。
  final List<BookingResource> resourceAllocations;

  /// §11 助産師 ⇄ スキルの付与（管理者がマスタ画面で付け外しする）。
  ///
  /// スキルの正は「この付与テーブル」であって OpsStaff.skills ではない。
  /// そうしないと、管理者がスキルを取り消しても判定に効かない
  /// （画面だけ変わって予約が取れてしまう）ことになる。
  final List<MidwifeSkill> midwifeSkills;

  /// 「その日は特定日の登録だけを正とする」日（availDayKey）。
  /// 助産師がカレンダーでその日を編集したら、毎週パターンは適用しない。
  final Set<String> dayOverrides;

  const MatchingEngine({
    required this.staff,
    required this.availability,
    required this.blocks,
    required this.bookings,
    required this.facilities,
    this.resources = const [],
    this.resourceAllocations = const [],
    this.midwifeSkills = const [],
    this.dayOverrides = const {},
  });

  /// その助産師が実際に持っているスキルID（§11）。
  ///
  /// 付与テーブルが1件でもあれば、それを正とする（管理者の取消が効く）。
  /// 付与テーブルが空のとき（古い保存データ・単体テスト）は
  /// OpsStaff.skills を使い、後方互換を保つ。
  Set<String> skillsOf(OpsStaff s) {
    final granted = midwifeSkills
        .where((m) => m.staffId == s.id)
        .map((m) => m.skillId)
        .toSet();
    return midwifeSkills.any((m) => m.staffId == s.id) ? granted : s.skills;
  }

  // -------------------------------------------------------------------------
  // 可否の解釈（すべて rules/ の純関数に委譲する — §28）
  // -------------------------------------------------------------------------

  /// 指定日のスタッフの実効区間（特定日が毎週パターンを上書き）。
  ///
  /// 解決規則（この順序が「取り消せること」の根拠）:
  ///   1. その日が上書き対象（助産師がカレンダーで編集済み）なら、
  ///      特定日の登録だけを正とし、毎週パターンは一切適用しない。
  ///      → 毎週パターン由来のNGも、その日だけ確実に取り消せる。
  ///   2. 上書きが無い日は、毎週パターンを土台にして特定日の登録を重ねる。
  ///      特定日にOKがあれば毎週OKは置換し、毎週NGは安全側で残す。
  /// 判定は rules/availability_rules.dart（純関数）に委譲する（§28）。
  List<StaffAvailability> effectiveFor(String staffId, DateTime day) =>
      resolveDayAvailability(
        all: availability,
        staffId: staffId,
        day: day,
        dayOverrides: dayOverrides,
      );

  List<StaffAvailability> _availFor(String staffId, DateTime day) =>
      effectiveFor(staffId, day);

  /// §8 実際に働ける時間 = OK − NG（管理者・KPI表示の根拠）。
  List<TimeRange> workableFor(String staffId, DateTime day) =>
      workableRanges(effectiveFor(staffId, day));

  /// その助産師のその日の有効予約。
  /// [excludeBookingId] は事後検証（verifyAssignment）で「自分自身」を
  /// 重複相手として数えないために用いる。これを外すと確定済み予約が
  /// すべて自己重複として誤検知され、§16 の「割当品質 0件」が壊れる。
  List<OpsBooking> _bookingsOf(
    String staffId,
    DateTime day, {
    String? excludeBookingId,
  }) => bookings
      .where(
        (b) =>
            b.staffId == staffId &&
            dayOf(b.at) == dayOf(day) &&
            b.state.isActive &&
            b.id != excludeBookingId,
      )
      .toList();

  // -------------------------------------------------------------------------
  // 単一スタッフの評価（6条件ゲート）
  // -------------------------------------------------------------------------

  StaffEvaluation evaluate({
    required OpsStaff s,
    required ServiceDef service,
    required DateTime at,
    String? facilityId,
    String? areaCode,
    String? customerId,
    String? excludeBookingId,
  }) {
    final rejects = <RejectReason>[];
    final day = dayOf(at);

    // ④ 前後の移動・バッファを含む占有区間（rules/matching_rules）
    final occ = occupancyOf(
      service: service,
      startMin: minOfDay(at),
      bufferMin: s.bufferMin,
    );

    // ① 必要スキル一致
    if (!skillSatisfied(
      requiredSkills: service.requiredSkills,
      staffSkills: skillsOf(s),
    )) {
      rejects.add(RejectReason.skillMismatch);
    }

    // ⑥ 対応サービス / 訪問地域 / 施設条件
    if (!serviceSupported(s, service)) {
      rejects.add(RejectReason.serviceMismatch);
    }
    if (!areaSupported(s, service, areaCode)) {
      rejects.add(RejectReason.areaMismatch);
    }
    if (!facilitySupported(s, service, facilityId)) {
      rejects.add(RejectReason.facilityMismatch);
    }

    final avail = _availFor(s.id, day);

    // 空欄時間 = 原則予約不可
    if (!okRegistered(avail)) {
      rejects.add(RejectReason.noOkRegistered);
    } else if (!withinOk(avail, occ)) {
      // ② OK時間内（ケア＋移動が収まること）
      rejects.add(RejectReason.outsideOk);
    }

    // ③ NG時間（最優先で除外）
    if (blockedByNg(avail, occ)) {
      rejects.add(RejectReason.overlapNg);
    }

    // ③ 休暇・研修
    if (blockedByBlocks(blocks: blocks, staffId: s.id, day: day, o: occ)) {
      rejects.add(RejectReason.overlapBlock);
    }

    // ③④ 確定予約との重複／バッファ
    final todays = _bookingsOf(s.id, day, excludeBookingId: excludeBookingId);
    final conflict = evaluateBookings(
      sameDayBookings: todays,
      o: occ,
      bufferMin: s.bufferMin,
    );
    if (conflict.hardOverlap) rejects.add(RejectReason.overlapBooking);
    if (conflict.bufferOverlap) rejects.add(RejectReason.bufferViolation);

    // ⑤ 1日上限・連続対応上限
    if (dailyCapExceeded(
      loadMin: conflict.loadMin,
      addMin: service.durationMin,
      dailyMaxMin: s.dailyMaxMin,
    )) {
      rejects.add(RejectReason.dailyCapExceeded);
    }
    if (consecutiveExceeded(
      count: conflict.count,
      consecutiveMax: s.consecutiveMax,
    )) {
      rejects.add(RejectReason.consecutiveExceeded);
    }

    // 継続性（同一顧客の前回担当）
    final continuity =
        customerId != null &&
        bookings.any(
          (b) =>
              b.customerId == customerId &&
              b.staffId == s.id &&
              (b.state == BookingState.completed ||
                  b.state == BookingState.confirmed),
        );

    // 優先順位スコア: 負荷平準化 > 移動効率 > 継続性
    final score = assignmentScore(
      loadMin: conflict.loadMin,
      dailyMaxMin: s.dailyMaxMin,
      travelPenaltyMin: conflict.travelPenaltyMin,
      continuity: continuity,
    );

    final dedup = <RejectReason>{...rejects}.toList();
    return StaffEvaluation(
      staff: s,
      eligible: dedup.isEmpty,
      rejects: dedup,
      score: score,
      loadMinToday: conflict.loadMin,
      bookingsToday: conflict.count,
      travelPenaltyMin: conflict.travelPenaltyMin,
      continuity: continuity,
    );
  }

  // -------------------------------------------------------------------------
  // 枠生成（家族には bookable な枠だけを見せる）
  // -------------------------------------------------------------------------

  SlotCandidate buildSlot({
    required ServiceDef service,
    required DateTime at,
    String? facilityId,
    String? areaCode,
    String? customerId,
    String? excludeBookingId,
  }) {
    final evals = staff
        .map(
          (s) => evaluate(
            s: s,
            service: service,
            at: at,
            facilityId: facilityId,
            areaCode: areaCode,
            customerId: customerId,
            excludeBookingId: excludeBookingId,
          ),
        )
        .toList();
    return SlotCandidate(
      at: at,
      service: service,
      facilityId: facilityId,
      evaluations: evals,
      resourceFull: !hasResource(
        service: service,
        at: at,
        facilityId: facilityId,
        excludeBookingId: excludeBookingId,
      ),
    );
  }

  /// §15 その枠に使える部屋・設備が1つでも空いているか。
  ///
  /// Resource 未登録の施設では true（従来どおり施設定員だけで判定する）。
  bool hasResource({
    required ServiceDef service,
    required DateTime at,
    String? facilityId,
    String? excludeBookingId,
  }) {
    if (facilityId == null) return true;
    if (resources.isEmpty) return true;
    return resourceAvailable(
      resources: resources,
      allocations: resourceAllocations,
      facilityId: facilityId,
      kind: service.kind,
      from: at,
      to: at.add(Duration(minutes: service.durationMin)),
      requiredKinds: service.requiredResourceKinds,
      excludeBookingId: excludeBookingId,
    );
  }

  /// §23 管理者の「必要条件 vs 候補」表示用：空いているリソース一覧。
  List<OpsResource> availableResources({
    required ServiceDef service,
    required DateTime at,
    required String facilityId,
    String? excludeBookingId,
  }) => freeResources(
    resources: resources,
    allocations: resourceAllocations,
    facilityId: facilityId,
    kind: service.kind,
    from: at,
    to: at.add(Duration(minutes: service.durationMin)),
    overnight: service.kind == ServiceKind.stay,
    excludeBookingId: excludeBookingId,
  );

  /// §23 プランが求める設備のうち、その時間に空きが無い種別。
  List<ResourceKind> missingResourceKinds({
    required ServiceDef service,
    required DateTime at,
    required String facilityId,
    String? excludeBookingId,
  }) {
    if (service.requiredResourceKinds.isEmpty) return const [];
    final free = availableResources(
      service: service,
      at: at,
      facilityId: facilityId,
      excludeBookingId: excludeBookingId,
    ).map((r) => r.kind).toSet();
    final stocked = resources
        .where((r) => r.facilityId == facilityId && r.active)
        .map((r) => r.kind)
        .toSet();
    return service.requiredResourceKinds
        .where((k) => stocked.contains(k) && !free.contains(k))
        .toList();
  }

  /// 指定期間・開始時刻候補から、割当可能な枠のみを返す。
  List<SlotCandidate> searchSlots({
    required ServiceDef service,
    required DateTime from,
    required int days,
    required List<int> startMinutes,
    String? facilityId,
    String? areaCode,
    String? customerId,
    bool includeUnbookable = false,
  }) {
    final out = <SlotCandidate>[];
    for (var d = 0; d < days; d++) {
      final day = dayOf(from).add(Duration(days: d));
      for (final sm in startMinutes) {
        final at = day.add(Duration(minutes: sm));
        if (at.isBefore(DateTime.now())) continue;
        // 施設の同時受入人数（定員）— rules/resource_rules に委譲
        if (facilityId != null && facilities.isNotEmpty) {
          final fac = facilities.firstWhere(
            (f) => f.id == facilityId,
            orElse: () => facilities.first,
          );
          if (!facilityHasCapacity(
            facility: fac,
            bookings: bookings,
            day: day,
            startMin: sm,
            endMin: sm + service.durationMin,
          )) {
            continue;
          }
        }
        final slot = buildSlot(
          service: service,
          at: at,
          facilityId: facilityId,
          areaCode: areaCode,
          customerId: customerId,
        );
        if (slot.bookable || includeUnbookable) out.add(slot);
      }
    }
    return out;
  }

  /// §8.2 自動予約の判定順序に従う割当。
  AssignmentResult assign({
    required ServiceDef service,
    required DateTime at,
    String? facilityId,
    String? areaCode,
    String? customerId,
    List<ReasonCode> preExceptions = const [],
    List<int> altStartMinutes = const [540, 600, 660, 780, 840, 900],
  }) {
    final slot = buildSlot(
      service: service,
      at: at,
      facilityId: facilityId,
      areaCode: areaCode,
      customerId: customerId,
    );
    final exceptions = <ReasonCode>[...preExceptions];

    if (!slot.bookable) {
      exceptions.add(ReasonCode.noSlot);
      final alts = searchSlots(
        service: service,
        from: at,
        days: 10,
        startMinutes: altStartMinutes,
        facilityId: facilityId,
        areaCode: areaCode,
        customerId: customerId,
      ).take(6).toList();
      return AssignmentResult(
        slot: slot,
        exceptions: exceptions,
        alternatives: alts,
      );
    }

    // 宿泊は通常の空き枠ロジックで処理しない（付録C.7）
    if (service.kind == ServiceKind.stay) {
      exceptions.add(ReasonCode.stayService);
    }

    return AssignmentResult(
      slot: slot,
      assigned: exceptions.isEmpty ? slot.best : null,
      exceptions: exceptions,
    );
  }

  /// 監査用：割当が6条件を満たすかの事後検証（KPI「0件」を保証する門番）
  bool verifyAssignment({
    required OpsStaff s,
    required ServiceDef service,
    required DateTime at,
    String? facilityId,
    String? areaCode,
    String? excludeBookingId,
  }) {
    final e = evaluate(
      s: s,
      service: service,
      at: at,
      facilityId: facilityId,
      areaCode: areaCode,
      excludeBookingId: excludeBookingId,
    );
    return e.eligible;
  }

  /// 監査用：不適合の理由まで返す事後検証（管理者・KPIの原因表示に使う）
  List<RejectReason> verifyAssignmentReasons({
    required OpsStaff s,
    required ServiceDef service,
    required DateTime at,
    String? facilityId,
    String? areaCode,
    String? excludeBookingId,
  }) => evaluate(
    s: s,
    service: service,
    at: at,
    facilityId: facilityId,
    areaCode: areaCode,
    excludeBookingId: excludeBookingId,
  ).rejects;
}
