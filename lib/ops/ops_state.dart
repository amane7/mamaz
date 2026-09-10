// ============================================================================
// 運用状態ストア（Booking FSM / 例外エンジン / 通知 / 監査ログ / KPI）
// 要件定義書 §8 / §10.2 / §11 / §14 / §16 / 付録C.6
// ============================================================================

import 'package:flutter/foundation.dart';

import 'ops_models.dart';
import 'ops_seed.dart';
import 'matching_engine.dart';
import 'staff_access.dart';

/// §42 権限の型は ops_state 経由で画面に届ける。画面が
/// 権限モジュールを直接触らないようにして、判定の入口を1つに保つ。
export 'staff_access.dart';
import 'rules/eligibility_rules.dart';
import 'rules/fee_rules.dart';
import 'repository/ops_repository.dart';
import 'repository/local_ops_repository.dart';

enum OpsRole { family, midwife, admin }

extension OpsRoleX on OpsRole {
  String get label => switch (this) {
    OpsRole.family => 'ご家族',
    OpsRole.midwife => '助産師',
    OpsRole.admin => '管理者',
  };
}

class OpsState extends ChangeNotifier {
  // --- マスタ ---
  /// §28 永続化はこの抽象の向こう側。Hive / API へ差し替えても
  /// 判定ロジックと画面は変更不要にしておく。
  final OpsRepository repo;

  // §24 いずれも管理者が編集できるマスタなので、可変リストとして保持する。
  late final List<MunicipalityProgram> municipalities;
  late final List<ServiceDef> services;
  late final List<CancelPolicy> cancelPolicies;
  late final List<TermsDoc> terms;
  late final List<OpsFacility> facilities;
  late final List<OpsStaff> staff;

  /// §15 設備資源（個室・ベッド・座席・沐浴設備）。
  /// 人（助産師）とは別の資源として管理し、二重予約の排他単位にする。
  late final List<OpsResource> resources;

  /// §11 スキルマスタ（コードに固定しない）
  late final List<SkillDef> skills;
  late final List<MidwifeSkill> midwifeSkills;

  /// §16 自治体マスタ（事業要件 MunicipalityProgram とは別）
  late final List<Municipality> municipalityMasters;

  /// 要件再定義：残っている要確認事項（管理画面で消し込む）
  final List<OpenIssue> openIssues = [];

  // --- 可変データ ---
  late OpsCustomer customer;
  final List<StaffAvailability> availability = [];

  /// 「その日は特定日の登録だけを正とする」日の集合（availDayKey）。
  ///
  /// カレンダーで一日を編集したら、その日は毎週パターンを適用しない。
  /// これにより、毎週パターン由来のNGでもその日だけ取り消せる。
  final Set<String> availDayOverrides = {};

  final List<StaffBlock> blocks = [];
  final List<OpsBooking> bookings = [];
  final List<OpsNotification> notifications = [];
  final List<OpsTask> tasks = [];
  final List<AuditEntry> auditLog = [];
  final List<WaitEntry> waitlist = [];

  /// 予約 ⇄ リソースの割当。この行がある間、その部屋は他に使わせない。
  final List<BookingResource> resourceAllocations = [];
  final Set<String> _processedWebhookIds = {};

  // --- セッション ---
  OpsRole role = OpsRole.family;
  String currentStaffId = 'st_sato';
  String actorName = 'ご家族';

  int _seq = 0;

  String _id(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${_seq++}';

  // KPI基準値（2026年7月実績 §1）
  static const int baselineReceived = 1596;
  static const int baselineSent = 2805;
  static const int baselineTotal = 4401;
  static const int baselineRooms = 863;

  OpsState({OpsRepository? repository})
    : repo = repository ?? LocalOpsRepository() {
    municipalities = repo.loadPrograms();
    services = repo.loadServices();
    cancelPolicies = repo.loadCancelPolicies();
    terms = repo.loadTerms();
    facilities = repo.loadFacilities();
    staff = repo.loadStaff();
    resources = repo.loadResources();
    skills = repo.loadSkills();
    midwifeSkills = repo.loadMidwifeSkills();
    municipalityMasters = repo.loadMunicipalities();

    customer = seedCustomer();
    openIssues.addAll(seedOpenIssues());
    availability.addAll(repo.loadAvailability());
    availDayOverrides.addAll(repo.loadAvailabilityDayOverrides());
    blocks.addAll(repo.loadBlocks());
    _seedBookings();
    _selfHealAssignments();
    _seedResourceAllocations();
    _audit('システム', 'system', '初期化', 'OpsState', 'マスタ・可用性データを読み込みました');
  }

  // -------------------------------------------------------------------------
  // §28 永続化（Repository へ委譲。ここから下の実装は State は知らない）
  // -------------------------------------------------------------------------

  MasterSnapshot masterSnapshot() => MasterSnapshot(
    programs: municipalities,
    municipalities: municipalityMasters,
    services: services,
    facilities: facilities,
    resources: resources,
    skills: skills,
    midwifeSkills: midwifeSkills,
    cancelPolicies: cancelPolicies,
    terms: terms,
    staff: staff,
  );

  OperationSnapshot operationSnapshot() => OperationSnapshot(
    bookings: bookings,
    availability: availability,
    availabilityDayOverrides: availDayOverrides,
    blocks: blocks,
    resourceAllocations: resourceAllocations,
    notifications: notifications,
    tasks: tasks,
    auditLog: auditLog,
    waitlist: waitlist,
  );

  /// マスタを編集したあとに呼ぶ（§24 管理者操作の保存）。
  Future<void> persistMasters() => repo.saveMasters(masterSnapshot());

  /// 予約・可用性を変更したあとに呼ぶ。
  Future<void> persistOperations() => repo.saveOperations(operationSnapshot());

  // ===========================================================================
  // §24 管理者によるマスタ編集
  //
  // マスタは不変クラスなので、要素を差し替えて保存する。
  // 版管理が必要なもの（自治体・サービス・キャンセル規定）は版番号を
  // 自動で繰り上げる。§20 のとおり、既存予約に適用された条件は
  // 予約側のスナップショットが持つのでここでは変わらない。
  // すべての改定は監査ログに残す（§30 個人情報は含めない）。
  // ===========================================================================

  /// 一覧の中の1件を id で差し替える共通処理。
  bool _replaceById<T>(
    List<T> list,
    String id,
    T next,
    String Function(T) idOf,
  ) {
    final i = list.indexWhere((e) => idOf(e) == id);
    if (i < 0) return false;
    list[i] = next;
    return true;
  }

  /// 改定を確定させる（保存＋監査＋通知）。
  void _commitMaster(String target, String detail) {
    _audit(currentStaffId, 'admin', 'master.update', target, detail);
    persistMasters();
    notifyListeners();
  }

  /// §24 自治体・事業要件の改定。版番号を繰り上げる。
  bool updateProgram(
    String id, {
    int? maxUseCount,
    int? maxChildAgeDays,
    int? subsidyYen,
    int? maxConcurrentBookings,
    bool? requiresProgramNumber,
    SchedulingAuthority? scheduling,
    bool? requiresApproval,
    bool? requiresVoucher,
    bool? requiresCoupon,
    bool? requiresDecisionNotice,
    bool? countsOtherFacilities,
    bool? bookingEnabled,
    int? applicationLeadDays,
    List<FeeRule>? feeRules,
    MunicipalCancelRule? cancelRule,
    DateTime? effectiveTo,
    String? sourceRevision,
  }) {
    final cur = municipalities.firstWhere(
      (m) => m.id == id,
      orElse: () => municipalities.first,
    );
    if (cur.id != id) return false;
    final next = cur.copyWith(
      maxUseCount: maxUseCount,
      maxChildAgeDays: maxChildAgeDays,
      subsidyYen: subsidyYen,
      maxConcurrentBookings: maxConcurrentBookings,
      requiresProgramNumber: requiresProgramNumber,
      scheduling: scheduling,
      requiresApproval: requiresApproval,
      requiresVoucher: requiresVoucher,
      requiresCoupon: requiresCoupon,
      requiresDecisionNotice: requiresDecisionNotice,
      countsOtherFacilities: countsOtherFacilities,
      bookingEnabled: bookingEnabled,
      applicationLeadDays: applicationLeadDays,
      feeRules: feeRules,
      cancelRule: cancelRule,
      effectiveTo: effectiveTo,
      sourceRevision: sourceRevision,
      version: cur.version + 1,
      effectiveFrom: DateTime.now(),
    );
    if (!_replaceById(municipalities, id, next, (m) => m.id)) return false;
    _commitMaster('program:$id', '${cur.name} を v${next.version} に改定');
    return true;
  }

  /// 要件再定義：自治体マスタの「最終確認日・確認担当者」を更新する。
  ///
  /// 数値は変えていないので版は上げない（改定ではなく確認）。
  /// 年度改定の見落としを防ぐため、誰がいつ公式ページを見たかを残す。
  bool verifyProgram(String id, {required String by, String? sourceRevision}) {
    final cur = municipalities.firstWhere(
      (m) => m.id == id,
      orElse: () => municipalities.first,
    );
    if (cur.id != id) return false;
    final next = cur.copyWith(
      lastVerifiedAt: DateTime.now(),
      verifiedBy: by,
      sourceRevision: sourceRevision,
    );
    if (!_replaceById(municipalities, id, next, (m) => m.id)) return false;
    _audit(
      actorName,
      role.label,
      '自治体制度を確認',
      'program:$id',
      '${cur.name}／確認者 $by',
    );
    notifyListeners();
    return true;
  }

  /// 要件再定義：施設・スタッフ受入マスタの改定。
  bool updateFacilityAcceptance(
    String id, {
    int? maxChildAgeDays,
    bool? acceptsMultiples,
    int? multipleStaffRequired,
    bool? siblingAllowed,
    bool? familyAllowed,
    int? parkingSpaces,
    bool? pickupAvailable,
    Set<ServiceKind>? serviceKinds,
    Set<String>? visitAreas,
  }) {
    final cur = facilities.firstWhere(
      (f) => f.id == id,
      orElse: () => facilities.first,
    );
    if (cur.id != id) return false;
    final next = cur.copyWith(
      maxChildAgeDays: maxChildAgeDays,
      acceptsMultiples: acceptsMultiples,
      multipleStaffRequired: multipleStaffRequired,
      siblingAllowed: siblingAllowed,
      familyAllowed: familyAllowed,
      parkingSpaces: parkingSpaces,
      pickupAvailable: pickupAvailable,
      serviceKinds: serviceKinds,
      visitAreas: visitAreas,
    );
    if (!_replaceById(facilities, id, next, (f) => f.id)) return false;
    _commitMaster('facility:$id', '${cur.name} の受入条件を改定');
    return true;
  }

  /// 要件再定義：要確認事項を消し込む（誰が・どう解決したかを残す）。
  bool resolveOpenIssue(String id, {required String resolution}) {
    final i = openIssues.where((e) => e.id == id).firstOrNull;
    if (i == null || i.resolved) return false;
    i.resolved = true;
    i.resolution = resolution;
    i.resolvedAt = DateTime.now();
    _audit(actorName, role.label, '要確認事項を解決', i.title, resolution);
    notifyListeners();
    return true;
  }

  List<OpenIssue> get unresolvedIssues =>
      openIssues.where((e) => !e.resolved).toList();

  List<OpenIssue> issuesFor(String municipalityId) => openIssues
      .where((e) => e.municipalityId == municipalityId && !e.resolved)
      .toList();

  // -------------------------------------------------------------------------
  // 要件再定義：自治体への利用申請（未申請 → 申請中 → 承認済み／対象外）
  // -------------------------------------------------------------------------

  /// ご家族が「自治体へ申請した」と記録する。MAMOA は申請の代行はしない。
  void markApplied() {
    customer = customer.copyWith(
      application: customer.application.copyWith(
        status: ApplicationStatus.applied,
        appliedAt: DateTime.now(),
      ),
    );
    _audit('ご家族', 'family', '自治体へ申請', customer.municipalityId, '申請中に更新');
    notifyListeners();
  }

  /// 決定通知・利用券が届いた（番号を登録）。スタッフ確認前は未確認のまま。
  void registerVoucher(String voucherNumber, {int couponsLeft = 0}) {
    customer = customer.copyWith(
      programNumber: voucherNumber,
      application: customer.application.copyWith(
        status: ApplicationStatus.approved,
        approvedAt: DateTime.now(),
        voucherNumber: voucherNumber,
        couponsLeft: couponsLeft,
        decisionNoticeChecked: false,
        voucherChecked: false,
      ),
    );
    _audit(
      'ご家族',
      'family',
      '利用券を登録',
      customer.municipalityId,
      '番号 ${_maskNumber(voucherNumber)}',
    );
    notifyListeners();
  }

  /// スタッフが決定通知・利用券・クーポンを確認した。
  void verifyVoucher({
    bool decisionNotice = true,
    bool voucher = true,
    TaxClass? taxClass,
    int? otherFacilityUses,
  }) {
    customer = customer.copyWith(
      application: customer.application.copyWith(
        decisionNoticeChecked: decisionNotice,
        voucherChecked: voucher,
        taxClass: taxClass,
        otherFacilityUses: otherFacilityUses,
      ),
    );
    _audit(
      actorName,
      role.label,
      '利用券・決定通知を確認',
      customer.id,
      '課税区分 ${customer.application.taxClass.label}',
    );
    notifyListeners();
  }

  /// 自治体事業の対象外と判明した（スタッフ判断）。
  void markNotEligible({required String reason}) {
    customer = customer.copyWith(
      application: customer.application.copyWith(
        status: ApplicationStatus.notEligible,
      ),
    );
    _audit(actorName, role.label, '自治体事業の対象外', customer.id, reason);
    notifyListeners();
  }

  /// お住まいの自治体を切り替える（デモ・引っ越し）。
  void switchMunicipality(String programId) {
    if (!municipalities.any((m) => m.id == programId)) return;
    customer = customer.copyWith(
      municipalityId: programId,
      application: const MunicipalApplication(),
    );
    _audit('ご家族', 'family', '自治体を変更', programId, '申請状態を未申請に戻しました');
    notifyListeners();
  }

  static String _maskNumber(String n) => n.length <= 4
      ? '****'
      : '${n.substring(0, 2)}****${n.substring(n.length - 2)}';

  /// 利用券・決定通知の確認が済んでいるか（自治体が要求するもののみ）。
  bool get voucherVerifiedForCustomer {
    final p = municipalityById(customer.municipalityId);
    final a = customer.application;
    if (p.requiresDecisionNotice && !a.decisionNoticeChecked) return false;
    if ((p.requiresVoucher || p.requiresCoupon) && !a.voucherChecked) {
      return false;
    }
    return true;
  }

  /// §24 サービス定義（プラン）の改定。版番号を繰り上げる。
  bool updateService(
    String id, {
    int? durationMin,
    int? travelMin,
    int? bufferMin,
    int? priceYen,
    Set<String>? requiredSkills,
    Set<ResourceKind>? requiredResourceKinds,
    // §3/§43 予約方式と開始刻みは、管理画面から変えられなければ意味がない。
    // 「設定変更のたびにコード修正を必要としない」（§0）ための入口。
    BookingMode? bookingMode,
    int? startIntervalMinutes,
  }) {
    final i = services.indexWhere((s) => s.id == id);
    if (i < 0) return false;
    final cur = services[i];
    services[i] = cur.copyWith(
      durationMin: durationMin,
      travelMin: travelMin,
      bufferMin: bufferMin,
      priceYen: priceYen,
      requiredSkills: requiredSkills,
      requiredResourceKinds: requiredResourceKinds,
      bookingMode: bookingMode,
      startIntervalMinutes: startIntervalMinutes,
      version: cur.version + 1,
      effectiveFrom: DateTime.now(),
    );
    final note = bookingMode == null
        ? '${cur.name} を v${cur.version + 1} に改定'
        : '${cur.name} を v${cur.version + 1} に改定'
              '（予約方式 ${cur.bookingMode.code} → ${bookingMode.code}）';
    _commitMaster('service:$id', note);
    return true;
  }

  /// §24 キャンセル規定の改定。版番号を繰り上げる。
  bool updateCancelPolicy(
    String id, {
    int? changeDeadlineHours,
    List<CancelTier>? tiers,
  }) {
    final i = cancelPolicies.indexWhere((p) => p.id == id);
    if (i < 0) return false;
    final cur = cancelPolicies[i];
    cancelPolicies[i] = cur.copyWith(
      changeDeadlineHours: changeDeadlineHours,
      tiers: tiers,
      version: cur.version + 1,
      effectiveFrom: DateTime.now(),
    );
    _commitMaster('cancelPolicy:$id', '${cur.name} を v${cur.version + 1} に改定');
    return true;
  }

  /// §24 施設の改定（版管理の対象外）。
  bool updateFacility(
    String id, {
    int? rooms,
    int? concurrentCapacity,
    int? mealCutoffHours,
  }) {
    final i = facilities.indexWhere((f) => f.id == id);
    if (i < 0) return false;
    final cur = facilities[i];
    facilities[i] = cur.copyWith(
      rooms: rooms,
      concurrentCapacity: concurrentCapacity,
      mealCutoffHours: mealCutoffHours,
    );
    _commitMaster('facility:$id', '${cur.name} の受入設定を変更');
    return true;
  }

  /// §24 設備（部屋・ベッド・座席）の改定。
  bool updateResource(String id, {int? capacity, bool? active}) {
    final i = resources.indexWhere((r) => r.id == id);
    if (i < 0) return false;
    final cur = resources[i];
    resources[i] = cur.copyWith(capacity: capacity, active: active);
    _commitMaster(
      'resource:$id',
      '${cur.name} を${(active ?? cur.active) ? '利用可' : '停止'}に設定',
    );
    return true;
  }

  /// §24 設備の追加（§15 施設ごとに登録する）。
  OpsResource addResource({
    required String facilityId,
    required String name,
    required ResourceKind kind,
    int capacity = 1,
    bool overnightCapable = false,
  }) {
    final r = OpsResource(
      id: _id('res'),
      facilityId: facilityId,
      name: name,
      kind: kind,
      capacity: capacity,
      overnightCapable: overnightCapable,
    );
    resources.add(r);
    _commitMaster('resource:${r.id}', '$name（${kind.label}）を追加');
    return r;
  }

  /// §11 スキルの追加。固定実装せずマスタで増やせるようにする。
  SkillDef addSkill({
    required String name,
    String description = '',
    bool certificationRequired = false,
  }) {
    final s = SkillDef(
      id: _id('sk'),
      name: name,
      description: description,
      certificationRequired: certificationRequired,
    );
    skills.add(s);
    _commitMaster('skill:${s.id}', 'スキル「$name」を追加');
    return s;
  }

  /// §11 助産師のスキル付与／取消。
  bool toggleMidwifeSkill(String staffId, String skillId) {
    final i = midwifeSkills.indexWhere(
      (m) => m.staffId == staffId && m.skillId == skillId,
    );
    final name = skillName(skillId);
    if (i >= 0) {
      midwifeSkills.removeAt(i);
      _commitMaster('midwifeSkill:$staffId', '$name を取消');
    } else {
      midwifeSkills.add(
        MidwifeSkill(
          staffId: staffId,
          skillId: skillId,
          certifiedOn: DateTime.now(),
        ),
      );
      _commitMaster('midwifeSkill:$staffId', '$name を付与');
    }
    return true;
  }

  /// §15 既存の有効予約にお部屋・設備を割り当てる（管理者表示と整合させる）。
  ///
  /// 空きが無い予約は割当なしのまま残す。確定状態は変えない（表示の整合が目的で、
  /// 判定の門番は confirmBooking 側にある）。
  void _seedResourceAllocations() {
    for (final b in bookings.where(
      (b) => b.state.isActive && b.facilityId != null,
    )) {
      allocateResource(b);
    }
  }

  /// §16「スキル不一致／NG時間への予約割当 0件」を起動時に保証する。
  ///
  /// 曜日によっては初期データの担当がOK時間から外れることがある。ここで
  /// 6条件ゲートに掛け、満たさない予約は「条件を満たす助産師」へ振り替える。
  /// それでも候補がいない場合は自動確定せず NEEDS_REVIEW（例外キュー）に落とす。
  /// ＝ 不適合な割当が確定状態で残ることが構造上あり得ない。
  void _selfHealAssignments() {
    for (final b in bookings.where((b) => b.state.isActive).toList()) {
      final service = serviceById(b.serviceId);
      final current = staffById(b.staffId);
      final okNow =
          current != null &&
          engine.verifyAssignment(
            s: current,
            service: service,
            at: b.at,
            facilityId: b.facilityId,
            areaCode: customer.address.areaCode,
            excludeBookingId: b.id,
          );
      if (okNow) continue;
      if (b.state == BookingState.needsReview) continue; // 例外は意図的に未割当

      // 条件を満たす助産師を探して振り替える（負荷平準化・移動効率・継続性順）
      final slot = engine.buildSlot(
        service: service,
        at: b.at,
        facilityId: b.facilityId,
        areaCode: customer.address.areaCode,
        customerId: b.customerId,
      );
      final alt = slot.eligible
          .where((e) => e.staff.id != b.staffId)
          .where(
            (e) => engine.verifyAssignment(
              s: e.staff,
              service: service,
              at: b.at,
              facilityId: b.facilityId,
              areaCode: customer.address.areaCode,
              excludeBookingId: b.id,
            ),
          )
          .toList();

      if (alt.isNotEmpty) {
        final from = current?.name ?? '未割当';
        b.staffId = alt.first.staff.id;
        b.stateLog.add(
          'REASSIGNED 条件再検証により担当を変更（$from → ${alt.first.staff.name}）',
        );
        _audit(
          'システム',
          'system',
          '担当を再割当',
          b.code,
          '条件（スキル・OK/NG・上限）を満たす助産師へ振替：$from → ${alt.first.staff.name}',
        );
      } else {
        // 条件を満たす担当がいない → 自動確定させず例外キューへ
        b.staffId = null;
        b.state = BookingState.needsReview;
        b.feeState = FeeState.underReview;
        b.exceptions.add(
          BookingException(
            code: ReasonCode.noSlot,
            detail: '条件を満たす担当が見つかりませんでした（起動時の再検証）',
            raisedAt: DateTime.now(),
            dueAt: DateTime.now().add(const Duration(hours: 2)),
          ),
        );
        b.stateLog.add('NEEDS_REVIEW 条件を満たす担当なし（自動確定を停止）');
        tasks.add(
          OpsTask(
            id: _id('tk'),
            title: 'E-04 担当の再調整が必要',
            detail: '${b.code} ${serviceById(b.serviceId).name} ${_fmt(b.at)}',
            owner: TaskOwner.siteAdmin,
            bookingId: b.id,
            reason: ReasonCode.noSlot,
            createdAt: DateTime.now(),
            dueAt: DateTime.now().add(const Duration(hours: 2)),
          ),
        );
        _audit('システム', 'system', '自動確定を停止', b.code, '条件を満たす担当が不在のため例外キューへ移動');
      }
    }
  }

  // --------------------------------------------------------------------
  // §37-42 スタッフ権限（招待／管理者承認）
  //
  // 従来は入口で「助産師」を選ぶだけでスタッフ画面に入れた。
  // 実運用では他のご家族の氏名・住所・問診・カルテが見えてしまうため、
  // 自己申告では絶対に付与されない形にする（スタッフ指摘＝セキュリティ要件）。
  // 判定は staff_access.dart（Flutter非依存）に置き、ここは状態だけを持つ。
  // --------------------------------------------------------------------

  /// 管理者が発行した招待コード。デモ用に3件を用意する。
  final List<StaffInvitation> staffInvitations = [
    StaffInvitation(
      id: 'inv_mw_1',
      code: 'MW-2026-01',
      grants: StaffRoleKind.midwife,
      issuedBy: '運営スタッフ',
      issuedAt: DateTime.now().subtract(const Duration(days: 3)),
      expiresAt: DateTime.now().add(const Duration(days: 27)),
      maxUses: 5,
      invitedName: '助産師（新規）',
    ),
    StaffInvitation(
      id: 'inv_admin_1',
      code: 'ADMIN-2026-01',
      grants: StaffRoleKind.admin,
      issuedBy: '運営スタッフ',
      issuedAt: DateTime.now().subtract(const Duration(days: 3)),
      expiresAt: DateTime.now().add(const Duration(days: 27)),
      maxUses: 2,
      invitedName: '管理者（新規）',
    ),
    // 期限切れのコードも1件残す。「なぜ使えないのか」を
    // ご本人に説明できることを画面で確かめられるようにするため。
    StaffInvitation(
      id: 'inv_mw_old',
      code: 'MW-2025-08',
      grants: StaffRoleKind.midwife,
      issuedBy: '運営スタッフ',
      issuedAt: DateTime.now().subtract(const Duration(days: 200)),
      expiresAt: DateTime.now().subtract(const Duration(days: 170)),
    ),
  ];

  /// この端末利用者に対する権限記録。null は「申請すらしていない」。
  StaffAccessGrant? staffGrant;

  /// §42 画面ではなくここ（ドメイン層）で «見てよいか» を決める。
  bool canOpenStaffArea(StaffRoleKind area) =>
      canAccessStaffArea(staffGrant, area);

  /// OpsRole から StaffRoleKind への対応。family は権限を必要としない。
  static StaffRoleKind? _areaOf(OpsRole r) => switch (r) {
    OpsRole.family => null,
    OpsRole.midwife => StaffRoleKind.midwife,
    OpsRole.admin => StaffRoleKind.admin,
  };

  /// §37 このロールに今すぐ切り替えてよいか。UI はこれを見てボタンを出す。
  bool canSwitchTo(OpsRole r) {
    final area = _areaOf(r);
    if (area == null) return true;
    return canOpenStaffArea(area);
  }

  /// §39 スタッフ権限を申請する。
  ///
  /// 有効な招待コードがあればその場で有効化、なければ承認待ちにする。
  /// «コードが無い» を拒否にしないのは、現場では
  /// «先に働き始めてコードは後からもらう» が普通に起きるため（§39）。
  StaffAccessDecision requestStaffAccess({
    required StaffRoleKind requested,
    String code = '',
    String name = '',
    String? staffId,
  }) {
    final decision = evaluateStaffAccess(
      enteredCode: code,
      requested: requested,
      invitations: staffInvitations,
    );

    final subjectName = name.trim().isEmpty ? 'ご本人' : name.trim();
    final grant =
        staffGrant ??
        StaffAccessGrant(
          id: 'grant_local',
          subjectId: 'local_device',
          subjectName: subjectName,
          requested: requested,
          requestedAt: DateTime.now(),
        );
    grant.subjectName = subjectName;
    grant.requested = requested;
    grant.invitationId = decision.invitationId;
    grant.staffId = staffId;

    switch (decision.outcome) {
      case StaffAccessOutcome.granted:
        // 使用回数を進める。招待は «誰がいつ使ったか» を残すためにある。
        final inv = staffInvitations.firstWhere(
          (i) => i.id == decision.invitationId,
        );
        inv.uses += 1;
        grant.status = StaffAccessStatus.approved;
        grant.decidedAt = DateTime.now();
        grant.decidedBy = '招待コード ${inv.code}';
        _audit(
          subjectName,
          requested.label,
          'スタッフ権限を付与',
          requested.code,
          '招待コード ${inv.code}（発行 ${inv.issuedBy}）による有効化',
          sensitive: true,
        );
      case StaffAccessOutcome.pending:
        grant.status = StaffAccessStatus.pending;
        grant.decidedAt = null;
        grant.decidedBy = null;
        _audit(
          subjectName,
          'ご家族',
          'スタッフ権限を申請',
          requested.code,
          '管理者の承認待ち。承認までは利用者画面のみ',
        );
      case StaffAccessOutcome.rejected:
        grant.status = StaffAccessStatus.rejected;
        grant.decidedAt = DateTime.now();
        grant.decidedBy = 'システム';
        grant.note = decision.message;
        _audit(
          subjectName,
          'ご家族',
          'スタッフ権限の申請を受け付けませんでした',
          requested.code,
          decision.message.replaceAll('\n', ' '),
        );
    }

    staffGrant = grant;
    // 付与されたら、そのまま該当ロールへ入れる（二度手間を避ける §0）。
    if (decision.isGranted) {
      _applyRole(
        requested == StaffRoleKind.admin ? OpsRole.admin : OpsRole.midwife,
      );
    }
    notifyListeners();
    return decision;
  }

  /// §41 管理者による承認。AuditLog に必ず残す（§55 RO-05）。
  bool approveStaffAccess({String? staffId, String? note}) {
    if (role != OpsRole.admin) return false;
    final g = staffGrant;
    if (g == null) return false;
    g.status = StaffAccessStatus.approved;
    g.staffId = staffId ?? g.staffId;
    g.decidedAt = DateTime.now();
    g.decidedBy = actorName;
    g.note = note;
    _audit(
      actorName,
      role.label,
      'スタッフ権限を承認',
      '${g.subjectName}／${g.requested.code}',
      note ?? '管理者承認による有効化',
      sensitive: true,
    );
    notifyListeners();
    return true;
  }

  /// §41 却下。理由を必ず残す（あとで «なぜ通らなかったのか» に答えるため）。
  bool rejectStaffAccess({required String reason}) {
    if (role != OpsRole.admin) return false;
    final g = staffGrant;
    if (g == null) return false;
    g.status = StaffAccessStatus.rejected;
    g.decidedAt = DateTime.now();
    g.decidedBy = actorName;
    g.note = reason;
    _audit(
      actorName,
      role.label,
      'スタッフ権限を却下',
      '${g.subjectName}／${g.requested.code}',
      reason,
      sensitive: true,
    );
    notifyListeners();
    return true;
  }

  /// §41 付与済み権限の取り消し（退職・異動）。
  bool revokeStaffAccess({required String reason}) {
    if (role != OpsRole.admin) return false;
    final g = staffGrant;
    if (g == null) return false;
    g.status = StaffAccessStatus.revoked;
    g.decidedAt = DateTime.now();
    g.decidedBy = actorName;
    g.note = reason;
    _audit(
      actorName,
      role.label,
      'スタッフ権限を取り消し',
      '${g.subjectName}／${g.requested.code}',
      reason,
      sensitive: true,
    );
    // 取り消した本人がスタッフ画面にいたら、その場でご家族側へ戻す。
    if (role != OpsRole.family) _applyRole(OpsRole.family);
    notifyListeners();
    return true;
  }

  /// §40 いつでも利用者として戻れる。Role を永久確定しない。
  void returnToFamily() {
    _applyRole(OpsRole.family);
    _audit('ご家族', 'ご家族', '利用者画面へ戻る', 'FAMILY', 'ご本人の操作');
    notifyListeners();
  }

  /// ロール切替の実処理。権限判定を通ったあとだけ呼ぶ。
  void _applyRole(OpsRole r) {
    role = r;
    actorName = switch (r) {
      OpsRole.family => 'ご家族',
      OpsRole.midwife => currentStaff.name,
      OpsRole.admin => '運営スタッフ',
    };
  }

  /// デモ用：担当助産師を切り替える
  void switchStaff(String staffId) {
    currentStaffId = staffId;
    actorName = staffById(staffId)?.name ?? actorName;
    notifyListeners();
  }

  /// ロールを切り替える（家族／助産師／管理者）
  ///
  /// §37/§42 ここが権限の関門。画面でボタンを隠すだけでは不十分なので、
  /// 承認されていない助産師／管理者への切替は、この層で断る。
  /// 入口（onboarding）とロールリボンの両方がここを通るため、
  /// 1か所直せば両方守れる。戻り値は «切り替えたか»。
  bool switchRole(OpsRole r) {
    if (!canSwitchTo(r)) {
      _audit(
        actorName,
        role.label,
        'ロール切替を拒否',
        r.label,
        '${r.label}の権限が承認されていません（招待コードまたは管理者承認が必要）',
        sensitive: true,
      );
      notifyListeners();
      return false;
    }
    _applyRole(r);
    _audit(actorName, r.label, 'ロール切替', r.label, '権限確認済み');
    notifyListeners();
    return true;
  }

  MatchingEngine get engine => MatchingEngine(
    staff: staff,
    availability: availability,
    blocks: blocks,
    bookings: bookings,
    facilities: facilities,
    resources: resources,
    resourceAllocations: resourceAllocations,
    midwifeSkills: midwifeSkills,
    dayOverrides: availDayOverrides,
  );

  OpsStaff get currentStaff => staff.firstWhere(
    (s) => s.id == currentStaffId,
    orElse: () => staff.first,
  );

  ServiceDef serviceById(String id) =>
      services.firstWhere((s) => s.id == id, orElse: () => services.first);
  CancelPolicy policyById(String id) => cancelPolicies.firstWhere(
    (p) => p.id == id,
    orElse: () => cancelPolicies.first,
  );
  MunicipalityProgram municipalityById(String id) => municipalities.firstWhere(
    (m) => m.id == id,
    orElse: () => municipalities.first,
  );
  OpsFacility? facilityById(String? id) => id == null
      ? null
      : facilities.firstWhere(
          (f) => f.id == id,
          orElse: () => facilities.first,
        );
  OpsStaff? staffById(String? id) => id == null
      ? null
      : staff.firstWhere((s) => s.id == id, orElse: () => staff.first);

  SkillDef? skillById(String id) => skills.where((s) => s.id == id).firstOrNull;

  /// スキルの表示名（マスタ未登録ならIDをそのまま使う）
  String skillName(String id) => skillById(id)?.name ?? id;

  /// §11 その助産師が持っているスキルID。
  ///
  /// 正は MidwifeSkill（付与テーブル）。OpsStaff.skills は初期データにすぎない。
  /// 両方を足し合わせてはいけない。足すと「管理者が取り消したのに
  /// 初期データ側が残って判定に効かない」ことになる。
  /// 画面と Engine で必ず同じ答えになるよう、判定は engine.skillsOf に委ねる。
  Set<String> skillIdsOf(String staffId) {
    final s = staffById(staffId);
    return s == null ? const {} : engine.skillsOf(s);
  }

  OpsResource? resourceById(String id) =>
      resources.where((r) => r.id == id).firstOrNull;

  Municipality? municipalityMasterOf(String programId) => municipalityMasters
      .where((m) => m.programIds.contains(programId))
      .firstOrNull;

  // -------------------------------------------------------------------------
  // §15 リソースの排他割当
  //
  // 「助産師は空いているが部屋が無い」を正しく扱うため、
  // 予約確定時にリソースを予約行として押さえる。
  // -------------------------------------------------------------------------

  /// この予約に割り当てられているリソース。
  List<OpsResource> resourcesOf(String bookingId) => resourceAllocations
      .where((a) => a.bookingId == bookingId)
      .map((a) => resourceById(a.resourceId))
      .whereType<OpsResource>()
      .toList();

  /// 予約にリソースを確保する。空きがなければ false。
  ///
  /// [dryRun] を true にすると、確保はせず「確保できるか」だけを返す。
  /// §45 予約希望（REQUEST_APPROVAL）は枠を占有しない設計なので、
  /// 受付時は空きの有無だけを見る。確保は確定時（approveRequest）に行う。
  /// 判定ロジックを二重に書くと必ず食い違うため、同じ関数で兼ねる。
  bool allocateResource(OpsBooking b, {bool dryRun = false}) {
    if (b.facilityId == null) return true;
    final pool = resources.where(
      (r) => r.active && r.facilityId == b.facilityId,
    );
    if (pool.isEmpty) return true; // リソース未登録施設は従来動作

    if (!dryRun) releaseResources(b.id);
    final service = serviceById(b.serviceId);
    final free = engine.availableResources(
      service: service,
      at: b.at,
      facilityId: b.facilityId!,
      excludeBookingId: b.id,
    );
    if (free.isEmpty) return false;

    // §12 プランが特定の設備（個室など）を要求する場合、
    // 「何か空いている」では成立しない。要求種別ごとに1つずつ確保する。
    // これが無いと、個室が必要な通所プランに座席を割り当ててしまう。
    final need = service.requiredResourceKinds;
    final picks = <OpsResource>[];
    if (need.isEmpty) {
      picks.add(free.first);
    } else {
      final stocked = resources
          .where((r) => r.active && r.facilityId == b.facilityId)
          .map((r) => r.kind)
          .toSet();
      for (final kind in need) {
        // その施設がその設備を持たない場合は従来動作（この層では判定しない）
        if (!stocked.contains(kind)) continue;
        final hit = free.firstWhere(
          (r) => r.kind == kind && !picks.contains(r),
          orElse: () => _noResource,
        );
        if (hit.id.isEmpty) return false; // 要求された設備が空いていない
        picks.add(hit);
      }
      // 要求はあったが施設側に該当設備が無い＝従来どおり1つ確保する
      if (picks.isEmpty) picks.add(free.first);
    }

    if (dryRun) return true;

    for (final r in picks) {
      resourceAllocations.add(
        BookingResource(
          id: _id('bres'),
          bookingId: b.id,
          resourceId: r.id,
          from: b.at,
          to: b.endAt,
        ),
      );
    }
    return true;
  }

  /// firstWhere の orElse 用の「該当なし」標識。
  static const OpsResource _noResource = OpsResource(
    id: '',
    facilityId: '',
    name: '',
    kind: ResourceKind.room,
  );

  /// リソースの確保を解除する（キャンセル・変更時）。
  void releaseResources(String bookingId) {
    resourceAllocations.removeWhere((a) => a.bookingId == bookingId);
  }

  // -------------------------------------------------------------------------
  // 監査ログ（追記専用・簡易ハッシュ連鎖で改ざん検知 §14 NFR-04）
  // -------------------------------------------------------------------------
  void _audit(
    String actor,
    String role,
    String action,
    String target,
    String detail, {
    bool sensitive = false,
  }) {
    final prev = auditLog.isEmpty ? 'genesis' : auditLog.last.hashChain;
    final payload = '$prev|$actor|$action|$target|$detail';
    final h = payload.hashCode.toUnsigned(32).toRadixString(16).padLeft(8, '0');
    auditLog.add(
      AuditEntry(
        id: _id('au'),
        at: DateTime.now(),
        actor: actor,
        role: role,
        action: action,
        target: target,
        detail: detail,
        sensitiveAccess: sensitive,
        hashChain: h,
      ),
    );
  }

  void audit(
    String action,
    String target,
    String detail, {
    bool sensitive = false,
  }) {
    _audit(actorName, role.label, action, target, detail, sensitive: sensitive);
    notifyListeners();
  }

  bool get auditIntact {
    var prev = 'genesis';
    for (final e in auditLog) {
      final payload = '$prev|${e.actor}|${e.action}|${e.target}|${e.detail}';
      final h = payload.hashCode
          .toUnsigned(32)
          .toRadixString(16)
          .padLeft(8, '0');
      if (h != e.hashChain) return false;
      prev = e.hashChain;
    }
    return true;
  }

  // -------------------------------------------------------------------------
  // Webhook冪等性（§14 NFR-03 / 付録B 障害ケース）
  // -------------------------------------------------------------------------
  bool processWebhook(String webhookEventId) {
    if (_processedWebhookIds.contains(webhookEventId)) {
      _audit(
        'LINE',
        'system',
        'Webhook重複破棄',
        webhookEventId,
        '同一イベントを二重処理しませんでした',
      );
      notifyListeners();
      return false;
    }
    _processedWebhookIds.add(webhookEventId);
    return true;
  }

  // -------------------------------------------------------------------------
  // 通知（§10.2 / C-13 / E-06）
  // -------------------------------------------------------------------------
  OpsNotification notify({
    required String bookingId,
    required NotifyEvent event,
    required String title,
    required String body,
    String channel = 'Service Message',
    bool forceFail = false,
  }) {
    final n = OpsNotification(
      id: _id('nt'),
      bookingId: bookingId,
      customerId: customer.id,
      event: event,
      title: title,
      body: body,
      channel: channel,
      createdAt: DateTime.now(),
      status: forceFail ? DeliveryStatus.failed : DeliveryStatus.delivered,
    );
    notifications.insert(0, n);
    if (forceFail) {
      _raiseTask(
        title: 'LINE通知が届いていません',
        detail: '${event.label}の通知が未達です。お電話での確認をお願いします。',
        owner: TaskOwner.reception,
        bookingId: bookingId,
        reason: ReasonCode.lineUndelivered,
        priority: 1,
      );
      n.status = DeliveryStatus.phoneTask;
    }
    _audit('システム', 'system', '通知送信', event.label, '$title（${n.status.label}）');
    return n;
  }

  void retryNotification(String id) {
    final n = notifications.firstWhere((e) => e.id == id);
    n.retries++;
    n.status = n.retries >= 2
        ? DeliveryStatus.phoneTask
        : DeliveryStatus.retried;
    _audit(actorName, role.label, '通知再送', n.event.label, '再送${n.retries}回目');
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // タスク・例外キュー（§11 / A-02）
  // -------------------------------------------------------------------------
  OpsTask _raiseTask({
    required String title,
    required String detail,
    required TaskOwner owner,
    String? bookingId,
    ReasonCode? reason,
    int priority = 2,
    int? slaMinutes,
  }) {
    final t = OpsTask(
      id: _id('tk'),
      title: title,
      detail: detail,
      owner: owner,
      bookingId: bookingId,
      reason: reason,
      createdAt: DateTime.now(),
      dueAt: DateTime.now().add(
        Duration(minutes: slaMinutes ?? reason?.slaMinutes ?? 1440),
      ),
      priority: priority,
    );
    tasks.insert(0, t);
    return t;
  }

  void completeTask(String id, String resolution) {
    final t = tasks.firstWhere((e) => e.id == id);
    t.done = true;
    t.doneBy = actorName;
    t.doneAt = DateTime.now();
    if (t.bookingId != null && t.reason != null) {
      final b = bookings.firstWhere(
        (e) => e.id == t.bookingId,
        orElse: () => bookings.first,
      );
      for (final ex in b.openExceptions.where((e) => e.code == t.reason)) {
        ex.resolved = true;
        ex.resolution = resolution;
        ex.resolvedBy = actorName;
        ex.resolvedAt = DateTime.now();
      }
      b.manualTouches++;
    }
    _audit(actorName, role.label, 'タスク完了', t.title, resolution);
    notifyListeners();
  }

  /// E-07 自由記述・有人相談の受付（C-15 トリアージから呼ばれる）
  OpsTask raiseConsult({
    required ReasonCode reason,
    required TaskOwner owner,
    required String summary,
  }) {
    final t = _raiseTask(
      title: reason == ReasonCode.redFlag
          ? '【最優先】有人対応：$summary'
          : '有人対応：$summary',
      detail: 'ご家族からの相談。$summary',
      owner: owner,
      reason: reason,
      slaMinutes: reason == ReasonCode.redFlag ? 15 : reason.slaMinutes,
      priority: reason == ReasonCode.redFlag ? 0 : 1,
    );
    _audit(
      actorName,
      '家族',
      '相談を送信',
      summary,
      '理由 ${reason.code}／担当 ${owner.name}',
    );
    notifyListeners();
    return t;
  }

  List<OpsTask> tasksFor(TaskOwner owner) =>
      tasks.where((t) => t.owner == owner && !t.done).toList()..sort((a, b) {
        final p = a.priority.compareTo(b.priority);
        return p != 0 ? p : a.dueAt.compareTo(b.dueAt);
      });

  List<OpsTask> get openTasks => tasks.where((t) => !t.done).toList();
  List<OpsTask> get overdueTasks => tasks.where((t) => t.overdue).toList();

  // -------------------------------------------------------------------------
  // 予約作成（§8.2 判定順序）
  // -------------------------------------------------------------------------

  String _bookingCode() {
    final n = bookings.length + 1;
    return 'MC-${DateTime.now().year % 100}${DateTime.now().month.toString().padLeft(2, '0')}-${n.toString().padLeft(4, '0')}';
  }

  /// 適格性チェック（②自治体・年齢・回数・サービス）
  List<ReasonCode> checkEligibility({
    required ServiceDef service,
    required OpsChild child,
    required DateTime at,
    FundingType funding = FundingType.municipal,
    String? facilityId,
  }) {
    // §28 判定は rules/eligibility_rules.dart（Pure Function）に委譲する。
    return evaluateEligibility(
      eligibilityContext(
        service: service,
        child: child,
        at: at,
        funding: funding,
        facilityId: facilityId,
      ),
    );
  }

  /// 要件再定義 §4：料金の概算（原則「概算」。確定は人が行う）。
  FeeEstimate estimateFeeFor({
    required ServiceDef service,
    required OpsChild child,
    required DateTime at,
    FundingType funding = FundingType.municipal,
    bool? couponUsed,
  }) {
    final program = municipalityById(customer.municipalityId);
    final a = customer.application;
    return estimateFee(
      FeeContext(
        program: program,
        service: service,
        child: child,
        at: at,
        funding: funding,
        useIndex: customer.nextUseIndex,
        taxClass: a.taxClass,
        couponUsed: couponUsed ?? (program.requiresCoupon && a.couponsLeft > 0),
      ),
    );
  }

  /// 「対象外」と言い切れるか（自費切替の案内に使う）。
  bool isClearlyNotEligible({
    required ServiceDef service,
    required OpsChild child,
    required DateTime at,
  }) => clearlyNotEligible(
    eligibilityContext(service: service, child: child, at: at),
  );

  /// §12 判定材料を State から詰め替える（UI からも同じ文脈で説明文を出せる）。
  EligibilityContext eligibilityContext({
    required ServiceDef service,
    required OpsChild child,
    required DateTime at,
    FundingType funding = FundingType.municipal,
    String? facilityId,
  }) {
    final program = municipalityById(customer.municipalityId);
    return EligibilityContext(
      service: service,
      child: child,
      at: at,
      program: program,
      municipality: municipalityMasterOf(program.id),
      hasProgramNumber:
          customer.programNumber != null && customer.programNumber!.isNotEmpty,
      usedCount: customer.usedCount,
      application: customer.application.status,
      voucherVerified: voucherVerifiedForCustomer,
      funding: funding,
      facility: facilityById(facilityId),
      otherFacilityUses: customer.application.otherFacilityUses,
      // §12 予約数制限：上限そのものは自治体マスタが持つ（固定実装しない）。
      // 数えるのは「これから来るご予約」＝有効状態かつ未来のもの。
      futureBookingCount: bookings
          .where(
            (b) =>
                b.customerId == customer.id &&
                b.state.isActive &&
                b.at.isAfter(DateTime.now()),
          )
          .length,
    );
  }

  /// 家族向けの説明文（§25 わかる言葉で伝える）。
  String eligibilityText({
    required ServiceDef service,
    required OpsChild child,
    required DateTime at,
  }) => eligibilityMessage(
    eligibilityContext(service: service, child: child, at: at),
  );

  /// 問診から赤旗・個別対応を抽出（③専門職レビュー条件）
  List<ReasonCode> checkIntake(
    Map<String, dynamic> intake,
    ServiceDef service,
  ) {
    final out = <ReasonCode>[];
    final flagged = seedRedFlags.where((r) => intake[r.key] == true).toList();
    if (flagged.isNotEmpty) out.add(ReasonCode.redFlag);
    final allergy = (intake['allergy'] as String?)?.trim() ?? '';
    if (service.mealEligible && intake['meal'] == true && allergy.isNotEmpty) {
      out.add(ReasonCode.mealAllergy);
    }
    if (service.kind == ServiceKind.visit && intake['parking'] == 'なし') {
      out.add(ReasonCode.travelCondition);
    }
    final free = (intake['freeText'] as String?)?.trim() ?? '';
    if (free.length > 30 || intake['wantHuman'] == true) {
      out.add(ReasonCode.freeTextConsult);
    }
    return out;
  }

  /// 仮おさえ（⑤成立可能なら仮押さえ → 顧客最終確認）
  /// 冪等キーで二重送信を防止（§14 NFR-02/03）
  ///
  /// §3 ここは「枠を仮においてご家族に最終確認画面を出す」段階なので、
  /// 予約方式（bookingMode）による行き先の違いは confirmBooking で決める。
  /// ただし ADMIN_ONLY だけは、ご家族に仮おさえすら渡さない（§49 BM-04）。
  ///
  /// [byStaff] を true にするとスタッフ代理登録として ADMIN_ONLY も通す。
  OpsBooking? holdSlot({
    required ServiceDef service,
    required OpsChild child,
    required DateTime at,
    String? facilityId,
    required Map<String, dynamic> intake,
    required List<String> needs,
    required String idempotencyKey,
    int holdMinutes = 20,
    bool byStaff = false,
    FundingType funding = FundingType.municipal,
  }) {
    // 冪等性：同キーの既存予約を返す
    final existing = bookings.where((b) => b.idempotencyKey == idempotencyKey);
    if (existing.isNotEmpty) return existing.first;

    // 母乳外来など自治体事業の類型に無いサービスは自動的に自費扱い。
    if (service.kind.programType == null) funding = FundingType.selfPay;

    // §3/§49 BM-04 ADMIN_ONLY はご家族の操作では成立させない。
    // 画面でボタンを隠すだけでは不十分なので、ここ（ドメイン層）で断る。
    if (service.bookingMode == BookingMode.adminOnly && !byStaff) {
      _audit(
        'システム',
        'system',
        '申込を受け付けませんでした',
        service.name,
        'このサービスはスタッフ登録のみ（ADMIN_ONLY）です',
      );
      return null;
    }

    final pre = <ReasonCode>[
      ...checkEligibility(
        service: service,
        child: child,
        at: at,
        funding: funding,
        facilityId: facilityId,
      ),
      ...checkIntake(intake, service),
    ];

    // 料金の概算。出せないときは要確認（M-03）として人へ回す。
    final fee = estimateFeeFor(
      service: service,
      child: child,
      at: at,
      funding: funding,
    );
    if (!fee.determined && fee.reason != null && !pre.contains(fee.reason)) {
      pre.add(fee.reason!);
    }

    final result = engine.assign(
      service: service,
      at: at,
      facilityId: facilityId,
      areaCode: customer.address.areaCode,
      customerId: customer.id,
      preExceptions: pre,
    );

    // 同一枠の同時申込：既に仮おさえ/確定があれば二重予約させない
    final conflict = bookings.any(
      (b) =>
          b.state.isActive &&
          b.staffId != null &&
          b.staffId == result.assigned?.staff.id &&
          b.at.isBefore(at.add(Duration(minutes: service.durationMin))) &&
          at.isBefore(b.endAt),
    );
    if (conflict) {
      _audit('システム', 'system', '二重予約防止', '$at', '同一枠の同時申込を検出し、確定を拒否しました');
      return null;
    }

    final policy = policyById(service.cancelPolicyId);
    final mun = municipalityById(customer.municipalityId);
    final b = OpsBooking(
      id: _id('bk'),
      code: _bookingCode(),
      customerId: customer.id,
      childId: child.id,
      serviceId: service.id,
      at: at,
      durationMin: service.durationMin,
      kind: service.kind,
      facilityId: facilityId,
      staffId: result.assigned?.staff.id,
      state: BookingState.slotHeld,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      feeYen: fee.yen ?? 0,
      feeState: fee.determined ? FeeState.estimate : FeeState.underReview,
      cancelPolicyId: policy.id,
      cancelPolicyVersion: policy.version,
      intake: intake,
      needs: needs,
      idempotencyKey: idempotencyKey,
      holdExpiresAt: DateTime.now().add(Duration(minutes: holdMinutes)),
      // §3 申込時点の方式を凍結する。後から管理者が方式を変えても、
      // この予約の履歴（なぜ確認待ちだったのか）は変わらない。
      bookingMode: service.bookingMode,
      // 要件再定義：自治体マスタの版・費用区分・概算根拠を凍結する。
      funding: fee.isSelfPay ? FundingType.selfPay : funding,
      municipalityProgramId: mun.id,
      municipalityProgramVersion: mun.version,
      feeBasis: fee.basis,
      useIndex: customer.nextUseIndex,
      voucherVerified: voucherVerifiedForCustomer,
    );
    b.stateLog.add('${_ts()} SLOT_HELD 仮おさえ（$holdMinutes分）');

    for (final code in result.exceptions) {
      b.exceptions.add(
        BookingException(
          code: code,
          detail: code.label,
          raisedAt: DateTime.now(),
          dueAt: DateTime.now().add(Duration(minutes: code.slaMinutes)),
        ),
      );
    }

    bookings.add(b);
    _audit(
      'ご家族',
      'family',
      '仮おさえ',
      b.code,
      '${service.name} ${_fmt(at)}（担当候補:${result.assigned?.staff.name ?? '未定'}）',
    );
    notifyListeners();
    return b;
  }

  /// 最終確定（同意スナップショット保存 + FSM遷移 + 自動割当検証）
  ///
  /// §45 ここが「予約方式で最終動作を変える」中心。
  ///   INSTANT          条件OK → CONFIRMED（従来どおり自動確定）
  ///   REQUEST_APPROVAL 条件OK → REQUESTED（スタッフ確認後に確定）
  ///   いずれも 要確認あり → NEEDS_REVIEW
  ///   ADMIN_ONLY       ご家族の操作では確定させない
  ///
  /// 返り値は「申込を受け付けたか」。確定したかどうかではない点に注意。
  /// REQUEST_APPROVAL では true を返すが state は confirmed にならない。
  bool confirmBooking(
    OpsBooking b, {
    required ConsentSnapshot consent,
    bool byStaff = false,
  }) {
    if (b.holdExpired) {
      b.state = BookingState.draft;
      b.stateLog.add('${_ts()} 仮おさえ期限切れ → 自動解放');
      _audit('システム', 'system', '仮おさえ解放', b.code, '期限内に確定されませんでした');
      notifyListeners();
      return false;
    }

    b.consent = consent;
    final service = serviceById(b.serviceId);

    // 例外があれば安全側で停止 → 確認待ち（自動確定しない）
    if (b.hasOpenException) {
      b.state = BookingState.needsReview;
      b.feeState = FeeState.underReview;
      b.stateLog.add(
        '${_ts()} NEEDS_REVIEW ${b.openExceptions.map((e) => e.code.code).join(",")}',
      );
      for (final ex in b.openExceptions) {
        _raiseTask(
          title: '${ex.code.code} ${ex.code.label}',
          detail: '${b.code} ${service.name} ${_fmt(b.at)}\n${ex.detail}',
          owner: ex.code.toMidwife ? TaskOwner.midwife : TaskOwner.siteAdmin,
          bookingId: b.id,
          reason: ex.code,
          priority: ex.code == ReasonCode.redFlag ? 1 : 2,
        );
      }
      notify(
        bookingId: b.id,
        event: NotifyEvent.applied,
        title: 'お申し込みを受け付けました',
        body:
            'ご入力の内容を確認しています。担当からご連絡しますので、少しお待ちください。'
            'ご不安なことがあれば、いつでもご相談ください。',
      );
      _audit(
        'ご家族',
        'family',
        '申込（要確認）',
        b.code,
        b.openExceptions.map((e) => e.code.code).join(','),
      );
      notifyListeners();
      return true;
    }

    // -----------------------------------------------------------------------
    // §45 ここから予約方式による分岐。
    //
    // 上の「要確認あり」は方式に関係なく人が見る（§0 の原則）。
    // 要確認が無い場合だけ、方式によって行き先が変わる。
    //
    // ただしその前に、物理的に成立しないケースは方式より先に弾く。
    // 「お部屋が一つも空いていない」は現場判断の余地がなく、
    // 予約希望として受け付けても後で必ず断ることになる。
    // ご家族を待たせてから断るのが一番よくない（§0）。
    // -----------------------------------------------------------------------
    if (!allocateResource(b, dryRun: true)) {
      b.state = BookingState.needsReview;
      b.exceptions.add(
        BookingException(
          code: ReasonCode.noSlot,
          detail: 'ご希望の時間に使えるお部屋・設備が空いていません',
          raisedAt: DateTime.now(),
          dueAt: DateTime.now().add(const Duration(hours: 2)),
        ),
      );
      _raiseTask(
        title: 'お部屋・設備の調整が必要です',
        detail: '${b.code} ${service.name} ${_fmt(b.at)}\n施設の空き設備がありません。',
        owner: TaskOwner.siteAdmin,
        bookingId: b.id,
        reason: ReasonCode.noSlot,
        priority: 1,
      );
      _audit('システム', 'system', '設備確保失敗', b.code, '安全側で確認待ちへ移行');
      notifyListeners();
      return false;
    }

    final mode = b.bookingMode ?? service.bookingMode;
    final outcome = resolveOutcome(
      mode: mode,
      conditionsOk: b.staffId != null,
      hasUnknowns: false, // 上の分岐で処理済み
    );

    if (outcome == BookingOutcome.staffOnly && !byStaff) {
      // §49 BM-04 ADMIN_ONLY はご家族の操作では確定しない。
      b.state = BookingState.requested;
      b.feeState = FeeState.estimate;
      b.updatedAt = DateTime.now();
      b.stateLog.add('${_ts()} REQUESTED スタッフ登録のみのサービスのため確認待ち');
      _raiseTask(
        title: 'スタッフ登録が必要な予約希望です',
        detail: '${b.code} ${service.name} ${_fmt(b.at)}',
        owner: TaskOwner.siteAdmin,
        bookingId: b.id,
        priority: 2,
      );
      notify(
        bookingId: b.id,
        event: NotifyEvent.applied,
        title: 'ご希望をお預かりしました',
        body: mode.familyAfterSubmit,
      );
      _audit('ご家族', 'family', '予約希望（スタッフ登録）', b.code, service.name);
      notifyListeners();
      return true;
    }

    if (outcome == BookingOutcome.request) {
      // §5/§6 REQUEST_APPROVAL：条件は満たしているが、確定はスタッフが行う。
      //
      // ここで confirmed にしないのが今回の改修の核心。
      // 児の月齢・多胎・訪問場所・自治体条件・施設受入状況は、
      // データだけでは確信を持てないという現場の指摘（§2）に従う。
      //
      // requested は isActive ではないため枠を占有しない。
      // 同じ枠に複数のご家族から希望が来ることを許し、
      // どれを確定するかはスタッフが判断する（§46）。
      // 要件再定義：予約・日程調整の主体が「行政」の自治体（瀬戸市・小牧市）は
      // 利用希望受付 → 行政調整中 に置く。MAMOA では確定させず、市からの連絡を待つ。
      final program = municipalityById(customer.municipalityId);
      final viaMunicipality =
          !b.isSelfPay && program.scheduling.waitsForMunicipality;
      b.state = viaMunicipality
          ? BookingState.municipalCoordination
          : BookingState.requested;
      b.feeState = FeeState.estimate; // 見込のまま。確定と誤認させない。
      b.autoAssigned = false;
      b.updatedAt = DateTime.now();
      b.stateLog.add(
        viaMunicipality
            ? '${_ts()} MUNICIPAL_COORDINATION 利用希望を受付 → ${program.name}と日程調整'
            : '${_ts()} REQUESTED 利用希望を受付（担当候補:${staffById(b.staffId)?.name ?? '未定'}）',
      );
      // §46 管理者のコントロールタワーに載せる。
      _raiseTask(
        title: viaMunicipality
            ? '${program.name}との日程調整をお願いします'
            : '利用希望の確認をお願いします',
        detail:
            '${b.code} ${service.name} ${_fmt(b.at)}\n'
            '${viaMunicipality ? '行政調整型：市と日程を調整し、市から利用者へ連絡する運用です。' : '自動判定では条件を満たしています。月齢・多胎・受入状況をご確認ください。'}',
        owner: TaskOwner.siteAdmin,
        bookingId: b.id,
        priority: 2,
        slaMinutes: 1440,
      );
      notify(
        bookingId: b.id,
        event: NotifyEvent.applied,
        title: '利用希望を受け付けました',
        body: viaMunicipality
            ? '${program.name}と施設が日程を調整し、市からご連絡があります。この時点では確定していません。'
            : mode.familyAfterSubmit,
      );
      _audit(
        'ご家族',
        'family',
        viaMunicipality ? '利用希望（行政調整）' : '利用希望',
        b.code,
        '${service.name} ${_fmt(b.at)}／方式 ${mode.code}',
      );
      notifyListeners();
      return true;
    }

    // 監査：割当が6条件を満たすか事後検証（KPI 0件の門番）
    final s = staffById(b.staffId);
    if (s == null ||
        !engine.verifyAssignment(
          s: s,
          service: service,
          at: b.at,
          facilityId: b.facilityId,
          areaCode: customer.address.areaCode,
          excludeBookingId: b.id,
        )) {
      b.state = BookingState.needsReview;
      b.exceptions.add(
        BookingException(
          code: ReasonCode.noSlot,
          detail: '割当条件の再検証に失敗しました',
          raisedAt: DateTime.now(),
          dueAt: DateTime.now().add(const Duration(hours: 2)),
        ),
      );
      _raiseTask(
        title: '割当の再検証が必要です',
        detail: '${b.code} 自動検証で条件不一致を検出しました。',
        owner: TaskOwner.siteAdmin,
        bookingId: b.id,
        reason: ReasonCode.noSlot,
        priority: 1,
      );
      _audit('システム', 'system', '割当検証失敗', b.code, '安全側で確認待ちへ移行');
      notifyListeners();
      return false;
    }

    // §15 部屋・設備の確保（人が空いていても設備が無ければ確定しない）
    if (!allocateResource(b)) {
      b.state = BookingState.needsReview;
      b.exceptions.add(
        BookingException(
          code: ReasonCode.noSlot,
          detail: 'ご希望の時間に使えるお部屋・設備が空いていません',
          raisedAt: DateTime.now(),
          dueAt: DateTime.now().add(const Duration(hours: 2)),
        ),
      );
      _raiseTask(
        title: 'お部屋・設備の調整が必要です',
        detail: '${b.code} ${service.name} ${_fmt(b.at)}\n施設の空き設備がありません。',
        owner: TaskOwner.siteAdmin,
        bookingId: b.id,
        reason: ReasonCode.noSlot,
        priority: 1,
      );
      _audit('システム', 'system', '設備確保失敗', b.code, '安全側で確認待ちへ移行');
      notifyListeners();
      return false;
    }

    b.state = BookingState.confirmed;
    b.autoAssigned = true;
    b.feeState = FeeState.confirmed;
    b.updatedAt = DateTime.now();
    b.stateLog.add('${_ts()} CONFIRMED 自動確定（担当:${s.name}）');

    notify(
      bookingId: b.id,
      event: NotifyEvent.confirmed,
      title: 'ご予約が確定しました',
      body:
          '${b.code}／${service.name}\n${_fmt(b.at)}\n'
          '担当：${s.name}\n当日は無理をせず、そのままの状態でお迎えください。',
    );
    // 事前確認タスク（M-06）
    _raiseTask(
      title: '事前情報の確認',
      detail: '${b.code} ${service.name} ${_fmt(b.at)}',
      owner: TaskOwner.midwife,
      bookingId: b.id,
      priority: 3,
    );
    _audit('システム', 'system', '自動確定', b.code, '担当:${s.name}／人の介在なし');
    notifyListeners();
    return true;
  }

  // -------------------------------------------------------------------------
  // §45/§46 スタッフによる予約希望の処理（REQUEST_APPROVAL の出口）
  //
  // 「自動化はするが、現場判断が必要なものを無理に自動確定しない」（§0）を
  // 成り立たせるには、人が確定させる道が必ず必要になる。ここがその道。
  // -------------------------------------------------------------------------

  /// 予約希望の確定待ち一覧（§46 マッチング・コントロールタワー）。
  ///
  /// 古い希望から先に出す。お待たせしている順に処理するのが自然なので。
  List<OpsBooking> get pendingRequests =>
      bookings.where((b) => b.state.isPendingStaff).toList()
        ..sort((a, b) => a.at.compareTo(b.at));

  /// §46 予約希望を「仮予約」にする。
  ///
  /// 日程は置けたが、まだご家族に確定を約束できない段階のための状態。
  /// 仮予約は枠を占有する（isActive）ので、二重に押さえることはできない。
  bool setProvisional(OpsBooking b, {String? note}) {
    if (b.state != BookingState.requested &&
        b.state != BookingState.municipalCoordination &&
        b.state != BookingState.needsReview) {
      return false;
    }
    final service = serviceById(b.serviceId);
    // 仮予約でも設備は押さえる。押さえられないなら仮予約にしない。
    if (!allocateResource(b)) {
      _audit(actorName, role.label, '仮予約できず', b.code, 'お部屋・設備が空いていません');
      notifyListeners();
      return false;
    }
    b.state = BookingState.provisional;
    b.manualTouches++;
    b.updatedAt = DateTime.now();
    b.stateLog.add('${_ts()} PROVISIONAL 仮予約（$actorName）${note ?? ''}'.trim());
    notify(
      bookingId: b.id,
      event: NotifyEvent.applied,
      title: '日程を仮におさえました',
      body:
          '${service.name}\n${_fmt(b.at)}\n'
          'まだ確定ではありません。確認が終わりましたら、確定のご案内をお送りします。',
    );
    _audit(actorName, role.label, '仮予約', b.code, note ?? '${_fmt(b.at)} を仮おさえ');
    notifyListeners();
    return true;
  }

  /// §45 予約希望をスタッフが確定させる（REQUESTED/NEEDS_REVIEW/PROVISIONAL → CONFIRMED）。
  ///
  /// 人が確認したうえでの確定なので、自動確定と同じ機械的検証は課さない。
  /// ただし「担当が決まっていない」「設備が取れない」は物理的に無理なので断る。
  /// 未解決の要確認事項が残っている場合も確定させない（§0 安全側）。
  bool approveRequest(OpsBooking b, {String? note}) {
    const allowed = {
      BookingState.requested,
      BookingState.municipalCoordination,
      BookingState.needsReview,
      BookingState.provisional,
      BookingState.slotHeld,
    };
    if (!allowed.contains(b.state)) return false;

    final service = serviceById(b.serviceId);

    // 要件再定義：制度利用で利用券・決定通知が未確認なら確定させない。
    if (!b.isSelfPay) {
      final p = municipalityById(
        b.municipalityProgramId ?? customer.municipalityId,
      );
      final needsDoc =
          p.requiresVoucher || p.requiresCoupon || p.requiresDecisionNotice;
      if (needsDoc && !b.voucherVerified && !voucherVerifiedForCustomer) {
        _audit(actorName, role.label, '確定できず', b.code, '利用券・決定通知が未確認です');
        notifyListeners();
        return false;
      }
      b.voucherVerified = true;
    }

    if (b.hasOpenException) {
      _audit(
        actorName,
        role.label,
        '確定できず',
        b.code,
        '未解決の確認事項：${b.openExceptions.map((e) => e.code.code).join(",")}',
      );
      notifyListeners();
      return false;
    }

    // 担当が未定なら、この時点でもう一度探す（時間が経って空いた可能性がある）。
    if (b.staffId == null) {
      final result = engine.assign(
        service: service,
        at: b.at,
        facilityId: b.facilityId,
        areaCode: customer.address.areaCode,
        customerId: b.customerId,
      );
      b.staffId = result.assigned?.staff.id;
    }
    final s = staffById(b.staffId);
    if (s == null) {
      _audit(actorName, role.label, '確定できず', b.code, '担当できる助産師が見つかりません');
      notifyListeners();
      return false;
    }

    if (!allocateResource(b)) {
      _audit(actorName, role.label, '確定できず', b.code, 'お部屋・設備が空いていません');
      notifyListeners();
      return false;
    }

    b.state = BookingState.confirmed;
    b.autoAssigned = false; // 人が確定させた。KPI で自動完結率と区別する。
    b.feeState = FeeState.confirmed;
    b.manualTouches++;
    b.updatedAt = DateTime.now();
    b.stateLog.add('${_ts()} CONFIRMED スタッフ確認のうえ確定（$actorName／担当:${s.name}）');

    // 関連する確認タスクを閉じる。
    for (final t in tasks.where((t) => t.bookingId == b.id && !t.done)) {
      t.done = true;
      t.doneBy = actorName;
      t.doneAt = DateTime.now();
    }

    notify(
      bookingId: b.id,
      event: NotifyEvent.confirmed,
      title: 'ご予約が確定しました',
      body:
          '${b.code}／${service.name}\n${_fmt(b.at)}\n'
          '担当：${s.name}\n'
          'お待たせしました。当日は無理をせず、そのままの状態でお迎えください。',
    );
    _raiseTask(
      title: '事前情報の確認',
      detail: '${b.code} ${service.name} ${_fmt(b.at)}',
      owner: TaskOwner.midwife,
      bookingId: b.id,
      priority: 3,
    );
    _audit(
      actorName,
      role.label,
      '予約確定（スタッフ確認）',
      b.code,
      note ?? '担当:${s.name}／${_fmt(b.at)}',
    );
    notifyListeners();
    return true;
  }

  /// §46 予約希望に応えられないとき。日程を断る。
  ///
  /// «お断り» ではなく «別の日程をご案内する» を既定の言い方にする。
  /// ご家族は制度でも枠でもなく、休みたくて申し込んでいる。
  bool declineRequest(OpsBooking b, {required String reason}) {
    const allowed = {
      BookingState.requested,
      BookingState.municipalCoordination,
      BookingState.needsReview,
      BookingState.provisional,
    };
    if (!allowed.contains(b.state)) return false;
    final service = serviceById(b.serviceId);
    releaseResources(b.id);
    b.state = BookingState.cancelled;
    b.manualTouches++;
    b.updatedAt = DateTime.now();
    b.stateLog.add('${_ts()} CANCELLED 予約希望に添えず（$actorName）$reason');
    for (final t in tasks.where((t) => t.bookingId == b.id && !t.done)) {
      t.done = true;
      t.doneBy = actorName;
      t.doneAt = DateTime.now();
    }
    notify(
      bookingId: b.id,
      event: NotifyEvent.changeAccepted,
      title: 'ご希望の日時のご案内がむずかしく、申し訳ありません',
      body:
          '${service.name}／${_fmt(b.at)}\n$reason\n'
          '近い日程をご用意していますので、アプリからお選びいただけます。',
    );
    _audit(actorName, role.label, '予約希望に添えず', b.code, reason);
    notifyListeners();
    return true;
  }

  // -------------------------------------------------------------------------
  // 要件再定義：追加の状態遷移
  //   問診済み／請求済み／対象外／自費切替／医療機関案内・継続支援への引継ぎ
  // -------------------------------------------------------------------------

  /// 確定後、問診票の提出が終わった。
  bool markIntakeDone(OpsBooking b) {
    if (b.state != BookingState.confirmed) return false;
    b.state = BookingState.intakeDone;
    b.updatedAt = DateTime.now();
    b.stateLog.add('${_ts()} INTAKE_DONE 問診票を受領');
    for (final t in tasks.where(
      (t) => t.bookingId == b.id && !t.done && t.title == '事前情報の確認',
    )) {
      t.done = true;
      t.doneBy = actorName;
      t.doneAt = DateTime.now();
    }
    _audit(actorName, role.label, '問診済み', b.code, '', sensitive: true);
    notifyListeners();
    return true;
  }

  /// 実施済み → 自治体への実績報告・請求が終わった。
  bool markBilled(OpsBooking b, {String? note}) {
    if (b.state != BookingState.completed) return false;
    b.state = BookingState.billed;
    b.billedAt = DateTime.now();
    b.feeState = FeeState.confirmed;
    b.updatedAt = DateTime.now();
    b.stateLog.add('${_ts()} BILLED 請求済み ${note ?? ''}'.trimRight());
    if (!b.isSelfPay) {
      customer = customer.copyWith(usedCount: customer.usedCount + 1);
    }
    _audit(actorName, role.label, '請求済み', b.code, note ?? '自治体実績報告に計上');
    notifyListeners();
    return true;
  }

  /// 自治体事業の対象外と判明した予約。
  bool markBookingNotEligible(OpsBooking b, {required String reason}) {
    if (!b.state.isPendingStaff && b.state != BookingState.slotHeld) {
      return false;
    }
    releaseResources(b.id);
    b.state = BookingState.notEligible;
    b.updatedAt = DateTime.now();
    b.stateLog.add('${_ts()} NOT_ELIGIBLE 対象外：$reason');
    for (final t in tasks.where((t) => t.bookingId == b.id && !t.done)) {
      t.done = true;
      t.doneBy = actorName;
      t.doneAt = DateTime.now();
    }
    final service = serviceById(b.serviceId);
    final p = municipalityById(
      b.municipalityProgramId ?? customer.municipalityId,
    );
    notify(
      bookingId: b.id,
      event: NotifyEvent.preCheck,
      title: '自治体事業の対象外でした',
      body:
          '${service.name}／${_fmt(b.at)}\n$reason\n'
          '${p.selfPaySwitchNote.isEmpty ? '自費でのご利用もご案内できます。' : p.selfPaySwitchNote}',
    );
    _audit(actorName, role.label, '対象外', b.code, reason);
    notifyListeners();
    return true;
  }

  /// 制度利用 → 自費利用へ切り替える（対象外・回数超過・利用券未取得のとき）。
  ///
  /// 料金は自費の定価で再計算し、根拠を書き換える。履歴に理由を残す。
  bool switchToSelfPay(OpsBooking b, {required String reason}) {
    if (b.isSelfPay) return false;
    if (b.state.isConfirmedOrLater && b.state != BookingState.confirmed) {
      return false;
    }
    final service = serviceById(b.serviceId);
    final child = customer.children.firstWhere(
      (c) => c.id == b.childId,
      orElse: () => customer.children.first,
    );
    final fee = estimateFeeFor(
      service: service,
      child: child,
      at: b.at,
      funding: FundingType.selfPay,
    );
    b.funding = FundingType.selfPay;
    b.feeYen = fee.yen ?? service.priceYen;
    b.feeBasis = fee.basis;
    b.feeState = FeeState.estimate;
    // 自治体条件由来の要確認は解消する。
    for (final ex in b.openExceptions.where(
      (e) =>
          e.code == ReasonCode.applicationMissing ||
          e.code == ReasonCode.voucherUnverified ||
          e.code == ReasonCode.feeUndetermined ||
          e.code == ReasonCode.programNotEffective ||
          e.code == ReasonCode.eligibilityUnknown,
    )) {
      ex.resolved = true;
      ex.resolution = '自費へ切替：$reason';
      ex.resolvedBy = actorName;
      ex.resolvedAt = DateTime.now();
    }
    if (b.state == BookingState.notEligible) b.state = BookingState.requested;
    b.updatedAt = DateTime.now();
    b.stateLog.add('${_ts()} 自費へ切替：$reason（概算 ${b.feeYen}円）');
    notify(
      bookingId: b.id,
      event: NotifyEvent.preCheck,
      title: '自費でのご利用に切り替えました',
      body:
          '${service.name}／${_fmt(b.at)}\n概算 ${b.feeYen}円（${fee.basis}）\n最終金額はスタッフ確認後に確定します。',
    );
    _audit(actorName, role.label, '自費切替', b.code, reason);
    notifyListeners();
    return true;
  }

  /// 医療機関受診のご案内／継続支援への引継ぎ（ケアではなく別の支援へ）。
  bool handOff(
    OpsBooking b, {
    required HandoffKind kind,
    required String note,
  }) {
    if (kind == HandoffKind.none) return false;
    if (b.state == BookingState.completed || b.state == BookingState.billed) {
      // 実施後の引継ぎは状態を変えず記録だけ残す。
      b.handoff = kind;
      b.handoffNote = note;
      b.stateLog.add('${_ts()} ${kind.label}（実施後）');
    } else {
      releaseResources(b.id);
      b.state = BookingState.handedOff;
      b.handoff = kind;
      b.handoffNote = note;
      b.stateLog.add('${_ts()} HANDED_OFF ${kind.label}');
      for (final t in tasks.where((t) => t.bookingId == b.id && !t.done)) {
        t.done = true;
        t.doneBy = actorName;
        t.doneAt = DateTime.now();
      }
    }
    b.updatedAt = DateTime.now();
    notify(
      bookingId: b.id,
      event: NotifyEvent.preCheck,
      title: kind == HandoffKind.medicalReferral
          ? '医療機関の受診をおすすめします'
          : '継続してサポートします',
      body: note,
    );
    _audit(actorName, role.label, kind.label, b.code, note, sensitive: true);
    notifyListeners();
    return true;
  }

  /// 事業所調整型：仮予約 → ご家族が「予約を確定する」を押す（スタッフ確認後）。
  ///
  /// スタッフが仮予約に置き、利用券確認も済んだものだけ、ご家族の操作で確定できる。
  bool familyConfirmProvisional(OpsBooking b) {
    if (b.state != BookingState.provisional) return false;
    if (b.hasOpenException) return false;
    if (!b.isSelfPay && !voucherVerifiedForCustomer) return false;
    final s = staffById(b.staffId);
    if (s == null) return false;
    final service = serviceById(b.serviceId);
    b.state = BookingState.confirmed;
    b.feeState = FeeState.confirmed;
    b.voucherVerified = true;
    b.updatedAt = DateTime.now();
    b.stateLog.add('${_ts()} CONFIRMED ご家族が仮予約を確定（担当:${s.name}）');
    for (final t in tasks.where((t) => t.bookingId == b.id && !t.done)) {
      t.done = true;
      t.doneBy = 'ご家族';
      t.doneAt = DateTime.now();
    }
    notify(
      bookingId: b.id,
      event: NotifyEvent.confirmed,
      title: 'ご予約が確定しました',
      body: '${b.code}／${service.name}\n${_fmt(b.at)}\n担当：${s.name}',
    );
    _raiseTask(
      title: '事前情報の確認',
      detail: '${b.code} ${service.name} ${_fmt(b.at)}',
      owner: TaskOwner.midwife,
      bookingId: b.id,
      priority: 3,
    );
    _audit('ご家族', 'family', '仮予約を確定', b.code, '担当:${s.name}');
    notifyListeners();
    return true;
  }

  /// 予約に紐づく自治体マスタ（申込時の版を優先。無ければ現行）。
  MunicipalityProgram programOfBooking(OpsBooking b) =>
      municipalityById(b.municipalityProgramId ?? customer.municipalityId);

  /// 請求待ち（実施済みだが自治体請求が済んでいない）。
  List<OpsBooking> get awaitingBilling => bookings
      .where((b) => b.state == BookingState.completed && !b.isSelfPay)
      .toList();

  // -------------------------------------------------------------------------
  // 変更・キャンセル（§8.3 / 付録C.5）
  // -------------------------------------------------------------------------

  /// 変更可能期限内か
  bool canChange(OpsBooking b) {
    final p = policyById(b.cancelPolicyId ?? 'cp_standard');
    return b.at.difference(DateTime.now()).inHours >= p.changeDeadlineHours;
  }

  /// キャンセル見込料金（確定前は必ず「見込」表示）
  int cancelEstimate(OpsBooking b) {
    final p = policyById(b.cancelPolicyId ?? 'cp_standard');
    return p.feeFor(bookingAt: b.at, requestAt: DateTime.now());
  }

  CancelTier cancelTier(OpsBooking b) {
    final p = policyById(b.cancelPolicyId ?? 'cp_standard');
    return p.tierFor(bookingAt: b.at, requestAt: DateTime.now());
  }

  /// 変更申請
  bool requestChange(OpsBooking b, DateTime newAt) {
    final service = serviceById(b.serviceId);
    final result = engine.assign(
      service: service,
      at: newAt,
      facilityId: b.facilityId,
      areaCode: customer.address.areaCode,
      customerId: customer.id,
    );
    if (!canChange(b)) {
      b.state = BookingState.needsReview;
      b.exceptions.add(
        BookingException(
          code: ReasonCode.lateCancel,
          detail: '変更期限を過ぎた日程変更のご希望',
          raisedAt: DateTime.now(),
          dueAt: DateTime.now().add(const Duration(hours: 8)),
        ),
      );
      _raiseTask(
        title: '期限後の変更申請',
        detail: '${b.code} 新希望 ${_fmt(newAt)}',
        owner: TaskOwner.siteAdmin,
        bookingId: b.id,
        reason: ReasonCode.lateCancel,
        priority: 2,
      );
      notify(
        bookingId: b.id,
        event: NotifyEvent.changeAccepted,
        title: '変更のご希望をお預かりしました',
        body:
            '変更期限を過ぎているため、担当が確認しています。'
            'できるかぎり調整しますので、少しお待ちください。',
      );
      notifyListeners();
      return false;
    }
    if (result.assigned == null) {
      notify(
        bookingId: b.id,
        event: NotifyEvent.changeAccepted,
        title: 'ご希望の日時は満席でした',
        body: '近い日時の候補をご用意しました。アプリからお選びいただけます。',
      );
      notifyListeners();
      return false;
    }
    // §19 変更は施設・助産師・設備・スキルをすべて再評価する。
    // 旧リソースを一旦戻し、新しい日時で確保できなければ変更しない。
    final keep = resourceAllocations.where((a) => a.bookingId == b.id).toList();
    releaseResources(b.id);
    final probe = OpsBooking(
      id: b.id,
      code: b.code,
      customerId: b.customerId,
      childId: b.childId,
      serviceId: b.serviceId,
      at: newAt,
      durationMin: b.durationMin,
      facilityId: b.facilityId,
      staffId: result.assigned!.staff.id,
      state: b.state,
      kind: b.kind,
      createdAt: b.createdAt,
      updatedAt: DateTime.now(),
    );
    if (!allocateResource(probe)) {
      resourceAllocations.addAll(keep);
      notify(
        bookingId: b.id,
        event: NotifyEvent.changeAccepted,
        title: 'ご希望の日時はお部屋が満席でした',
        body: '近い日時の候補をご用意しました。アプリからお選びいただけます。',
      );
      notifyListeners();
      return false;
    }

    final old = b.at;
    b.at = newAt;
    b.staffId = result.assigned!.staff.id;
    b.updatedAt = DateTime.now();
    b.stateLog.add('${_ts()} 変更確定 ${_fmt(old)} → ${_fmt(newAt)}');
    notify(
      bookingId: b.id,
      event: NotifyEvent.changeConfirmed,
      title: '日程の変更が確定しました',
      body:
          '${_fmt(newAt)}\n担当：${result.assigned!.staff.name}\n'
          'ご都合に合わせて、いつでも変更いただけます。',
    );
    // 関連タスク自動再生成（§8.3）
    for (final t in tasks.where((t) => t.bookingId == b.id && !t.done)) {
      t.done = true;
      t.doneBy = 'システム（再生成）';
      t.doneAt = DateTime.now();
    }
    _raiseTask(
      title: '事前情報の再確認（日程変更）',
      detail: '${b.code} ${_fmt(newAt)}',
      owner: TaskOwner.midwife,
      bookingId: b.id,
      priority: 3,
    );
    _audit('ご家族', 'family', '日程変更', b.code, '${_fmt(old)} → ${_fmt(newAt)}');
    notifyListeners();
    return true;
  }

  /// キャンセル申請
  void requestCancel(OpsBooking b, String reason) {
    final fee = cancelEstimate(b);
    final tier = cancelTier(b);
    if (fee == 0) {
      b.state = BookingState.cancelled;
      b.cancelFeeYen = 0;
      b.cancelFeeState = FeeState.confirmed;
      // §15 取消したらお部屋・設備を即時に開放する（他の家族が使える）
      releaseResources(b.id);
      b.stateLog.add('${_ts()} CANCELLED 自動取消（${tier.label}・無料）');
      notify(
        bookingId: b.id,
        event: NotifyEvent.cancelAccepted,
        title: 'ご予約をお取消ししました',
        body: 'キャンセル料はかかりません。\nまたご都合のよいときに、いつでもお待ちしています。',
      );
      _audit(
        'ご家族',
        'family',
        'キャンセル（自動）',
        b.code,
        '$reason／料金0円（${tier.label}）',
      );
    } else {
      b.cancelFeeYen = fee;
      b.cancelFeeState = FeeState.underReview;
      b.exceptions.add(
        BookingException(
          code: ReasonCode.lateCancel,
          detail: '$reason／見込 $fee円（${tier.label}）',
          raisedAt: DateTime.now(),
          dueAt: DateTime.now().add(const Duration(hours: 8)),
        ),
      );
      b.state = BookingState.needsReview;
      b.stateLog.add('${_ts()} キャンセル申請（見込$fee円・確認待ち）');
      _raiseTask(
        title: 'キャンセル料の確認',
        detail: '${b.code} 見込$fee円（${tier.label}）／理由：$reason',
        owner: TaskOwner.siteAdmin,
        bookingId: b.id,
        reason: ReasonCode.lateCancel,
        priority: 2,
      );
      notify(
        bookingId: b.id,
        event: NotifyEvent.cancelFee,
        title: 'お取消しのご希望をお預かりしました',
        body:
            '現在の規定では $fee円（${tier.label}）の見込です。'
            'ご事情によって変わることがありますので、担当が確認してご連絡します。',
      );
      _audit('ご家族', 'family', 'キャンセル申請', b.code, '$reason／見込$fee円');
    }
    notifyListeners();
  }

  /// 管理者によるキャンセル料の確定・減免
  void settleCancelFee(OpsBooking b, int finalFee, String note) {
    b.cancelFeeYen = finalFee;
    b.cancelFeeState = FeeState.confirmed;
    b.state = BookingState.cancelled;
    b.manualTouches++;
    b.stateLog.add('${_ts()} CANCELLED 料金確定 $finalFee円');
    for (final ex in b.openExceptions.where(
      (e) => e.code == ReasonCode.lateCancel,
    )) {
      ex.resolved = true;
      ex.resolution = '料金確定 $finalFee円／$note';
      ex.resolvedBy = actorName;
      ex.resolvedAt = DateTime.now();
    }
    for (final t in tasks.where(
      (t) =>
          t.bookingId == b.id && t.reason == ReasonCode.lateCancel && !t.done,
    )) {
      t.done = true;
      t.doneBy = actorName;
      t.doneAt = DateTime.now();
    }
    notify(
      bookingId: b.id,
      event: NotifyEvent.cancelFee,
      title: 'キャンセル料が確定しました',
      body: finalFee == 0
          ? 'ご事情を確認し、今回はキャンセル料をいただきません。どうぞご無理なさらないでください。'
          : '$finalFee円で確定しました。$note',
    );
    _audit(actorName, role.label, 'キャンセル料確定', b.code, '$finalFee円／$note');
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // 専門判断・利用開始・完了（M-04 / M-11）
  // -------------------------------------------------------------------------

  void resolveReview(
    OpsBooking b, {
    required bool approve,
    required String note,
  }) {
    b.manualTouches++;
    for (final ex in b.openExceptions) {
      ex.resolved = true;
      ex.resolution = note;
      ex.resolvedBy = actorName;
      ex.resolvedAt = DateTime.now();
    }
    for (final t in tasks.where((t) => t.bookingId == b.id && !t.done)) {
      t.done = true;
      t.doneBy = actorName;
      t.doneAt = DateTime.now();
    }
    if (approve) {
      final service = serviceById(b.serviceId);
      if (b.staffId == null) {
        final r = engine.assign(
          service: service,
          at: b.at,
          facilityId: b.facilityId,
          areaCode: customer.address.areaCode,
          customerId: customer.id,
        );
        b.staffId =
            r.assigned?.staff.id ?? r.slot?.eligible.firstOrNull?.staff.id;
      }
      b.state = BookingState.confirmed;
      b.feeState = FeeState.confirmed;
      b.stateLog.add('${_ts()} CONFIRMED 有人確認のうえ確定（$actorName）');
      notify(
        bookingId: b.id,
        event: NotifyEvent.confirmed,
        title: 'ご予約が確定しました',
        body:
            '${_fmt(b.at)}\n担当：${staffById(b.staffId)?.name ?? '調整中'}\n'
            'ご相談いただいた内容は、担当に引き継いでいます。安心してお越しください。',
      );
    } else {
      b.state = BookingState.needsReview;
      b.stateLog.add('${_ts()} 追加確認が必要（$actorName）: $note');
      notify(
        bookingId: b.id,
        event: NotifyEvent.preCheck,
        title: '確認したいことがあります',
        body: note,
      );
    }
    _audit(
      actorName,
      role.label,
      approve ? '例外承認' : '追加確認',
      b.code,
      note,
      sensitive: b.exceptions.any((e) => e.code == ReasonCode.redFlag),
    );
    notifyListeners();
  }

  void startService(OpsBooking b) {
    if (!b.state.readyForService) return;
    b.state = BookingState.inService;
    b.stateLog.add('${_ts()} IN_SERVICE 利用開始');
    _audit(actorName, role.label, '利用開始', b.code, '');
    notifyListeners();
  }

  void completeService(OpsBooking b, String handover) {
    b.state = BookingState.completed;
    b.handoverNote = handover;
    b.stateLog.add('${_ts()} COMPLETED 利用完了');
    notify(
      bookingId: b.id,
      event: NotifyEvent.completed,
      title: '今日はおつかれさまでした',
      body:
          'ゆっくり過ごせましたか。よろしければ、かんたんなアンケートにご協力ください。'
          '次回のご予約もアプリから承ります。',
    );
    _audit(actorName, role.label, '利用完了', b.code, handover, sensitive: true);
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // 助産師のOK／NG時間入力（M-07 / §6.2）
  // -------------------------------------------------------------------------

  /// 指定日の既存区間から [startMin,endMin) の重なりだけを差し引く。
  ///
  /// 完全に覆われた区間は消え、部分的に重なった区間は短くなり、
  /// 内側をくり抜かれた区間は前後2つに分割される。
  /// 「一部を直したら残りまで消えた」という事故を防ぐための操作。
  void _punchOut({
    required String staffId,
    required DateTime date,
    required int startMin,
    required int endMin,
  }) {
    final d = dayOf(date);
    final hits = availability
        .where(
          (a) =>
              a.staffId == staffId &&
              a.date != null &&
              dayOf(a.date!) == d &&
              a.startMin < endMin &&
              startMin < a.endMin,
        )
        .toList();
    for (final a in hits) {
      availability.remove(a);
      // 前側の残り
      if (a.startMin < startMin) {
        availability.add(
          StaffAvailability(
            id: _id('av'),
            staffId: staffId,
            date: d,
            startMin: a.startMin,
            endMin: startMin,
            kind: a.kind,
            updatedAt: DateTime.now(),
          ),
        );
      }
      // 後側の残り
      if (a.endMin > endMin) {
        availability.add(
          StaffAvailability(
            id: _id('av'),
            staffId: staffId,
            date: d,
            startMin: endMin,
            endMin: a.endMin,
            kind: a.kind,
            updatedAt: DateTime.now(),
          ),
        );
      }
    }
  }

  /// 特定日に区間を登録。既存の同区分の重複はマージ、異区分は上書き。
  void setAvailability({
    required String staffId,
    required DateTime date,
    required int startMin,
    required int endMin,
    required AvailKind kind,
  }) {
    // 毎週パターンを特定日へ書き写してから上書きする（残りを失わない）
    _materializeDay(staffId, date);
    // 重なった既存区間は「消す」のではなく「重なった分だけ削る」。
    // 例：OK 9:00-17:00 に NG 11:00-12:00 を入れたら
    //     OK 9:00-11:00 ＋ OK 12:00-17:00 ＋ NG 11:00-12:00 になる。
    _punchOut(staffId: staffId, date: date, startMin: startMin, endMin: endMin);
    availability.add(
      StaffAvailability(
        id: _id('av'),
        staffId: staffId,
        date: dayOf(date),
        startMin: startMin,
        endMin: endMin,
        kind: kind,
        updatedAt: DateTime.now(),
      ),
    );
    _audit(
      actorName,
      '助産師',
      '${kind.label}時間登録',
      '${date.month}/${date.day}',
      '${hhmm(startMin)}-${hhmm(endMin)}（理由は保存しません）',
    );
    notifyListeners();
  }

  /// 1日分をまとめて置き換える（ドラッグ塗り／一括編集用）。
  /// 監査は1件だけ残し、NG理由は保存しない（§19 可用性情報のプライバシー）。
  void replaceDay({
    required String staffId,
    required DateTime date,
    required List<StaffAvailability> ranges,
  }) {
    final d = dayOf(date);
    availability.removeWhere(
      (a) => a.staffId == staffId && a.date != null && dayOf(a.date!) == d,
    );
    // この日は画面の内容がそのまま正になる（毎週パターンを再適用しない）。
    // これが無いと、消したNGが毎週パターンから復活してしまう。
    availDayOverrides.add(availDayKey(staffId, d));
    final merged = _mergeRanges(ranges);
    for (final r in merged) {
      availability.add(
        StaffAvailability(
          id: _id('av'),
          staffId: staffId,
          date: d,
          startMin: r.startMin,
          endMin: r.endMin,
          kind: r.kind,
          updatedAt: DateTime.now(),
        ),
      );
    }
    final ok = merged.where((r) => r.kind == AvailKind.ok).length;
    final ng = merged.where((r) => r.kind == AvailKind.ng).length;
    _audit(
      actorName,
      '助産師',
      '可否時間を更新',
      '${date.month}/${date.day}',
      'OK $ok件 / NG $ng件（理由は保存しません）',
    );
    notifyListeners();
  }

  List<StaffAvailability> _mergeRanges(List<StaffAvailability> src) {
    final out = <StaffAvailability>[];
    for (final kind in AvailKind.values) {
      final same = src.where((a) => a.kind == kind).toList()
        ..sort((a, b) => a.startMin.compareTo(b.startMin));
      for (final a in same) {
        if (out.isNotEmpty &&
            out.last.kind == kind &&
            a.startMin <= out.last.endMin) {
          final last = out.removeLast();
          out.add(
            last.copyWith(
              endMin: a.endMin > last.endMin ? a.endMin : last.endMin,
            ),
          );
        } else {
          out.add(a);
        }
      }
    }
    out.sort((a, b) => a.startMin.compareTo(b.startMin));
    return out;
  }

  /// 毎週の基本パターンを登録（曜日ベース）。特定日の登録より弱い。
  void setWeeklyPattern({
    required String staffId,
    required int weekday,
    required int startMin,
    required int endMin,
    required AvailKind kind,
  }) {
    availability.removeWhere(
      (a) =>
          a.staffId == staffId &&
          a.weekday == weekday &&
          a.kind == kind &&
          a.startMin < endMin &&
          startMin < a.endMin,
    );
    availability.add(
      StaffAvailability(
        id: _id('av'),
        staffId: staffId,
        weekday: weekday,
        startMin: startMin,
        endMin: endMin,
        kind: kind,
        updatedAt: DateTime.now(),
      ),
    );
    _audit(
      actorName,
      '助産師',
      '基本パターン更新',
      weekdayName(weekday),
      '${kind.label} ${hhmm(startMin)}-${hhmm(endMin)}',
    );
    notifyListeners();
  }

  void clearWeeklyPattern({required String staffId, required int weekday}) {
    availability.removeWhere(
      (a) => a.staffId == staffId && a.weekday == weekday,
    );
    _audit(actorName, '助産師', '基本パターン削除', weekdayName(weekday), '曜日ごとの登録を消去');
    notifyListeners();
  }

  /// 基本パターンの1件だけを取り消す（OKだけ／NGだけを消せるようにする）。
  void removeAvailabilityById(String id) {
    final target = availability.firstWhere(
      (a) => a.id == id,
      orElse: () => throw StateError('availability not found: $id'),
    );
    availability.removeWhere((a) => a.id == id);
    _audit(
      actorName,
      '助産師',
      target.isRecurring ? '基本パターン1件取消' : '${target.kind.label}時間取消',
      target.isRecurring
          ? weekdayName(target.weekday!)
          : '${target.date!.month}/${target.date!.day}',
      '${target.kind.label} ${hhmm(target.startMin)}-${hhmm(target.endMin)} を取り消しました',
    );
    notifyListeners();
  }

  static String weekdayName(int w) =>
      const ['', '月', '火', '水', '木', '金', '土', '日'][w];

  /// その日の登録を空にする。毎週パターンも「その日だけ」適用しない。
  void clearAvailability({required String staffId, required DateTime date}) {
    availability.removeWhere(
      (a) =>
          a.staffId == staffId &&
          a.date != null &&
          dayOf(a.date!) == dayOf(date),
    );
    availDayOverrides.add(availDayKey(staffId, date));
    _audit(
      actorName,
      '助産師',
      '登録クリア',
      '${date.month}/${date.day}',
      'この日の登録を消去（毎週パターンも当日は適用しません）',
    );
    notifyListeners();
  }

  /// その日の個別編集をやめ、毎週の基本パターンに戻す（取り消しの逆操作）。
  void restoreWeeklyPatternFor({
    required String staffId,
    required DateTime date,
  }) {
    final d = dayOf(date);
    availability.removeWhere(
      (a) => a.staffId == staffId && a.date != null && dayOf(a.date!) == d,
    );
    availDayOverrides.remove(availDayKey(staffId, d));
    _audit(
      actorName,
      '助産師',
      '基本パターンに戻す',
      '${date.month}/${date.day}',
      'この日の個別設定を解除しました',
    );
    notifyListeners();
  }

  /// その日が個別設定（毎週パターン非適用）かどうか。
  bool isDayOverridden(String staffId, DateTime date) =>
      availDayOverrides.contains(availDayKey(staffId, date));

  /// その日を「個別設定」に切り替える前に、毎週パターンを特定日の登録へ
  /// 書き写しておく。こうしないと、一部だけを直したいときに
  /// 残りのパターンまで消えてしまう。
  void _materializeDay(String staffId, DateTime date) {
    final key = availDayKey(staffId, date);
    if (availDayOverrides.contains(key)) return; // すでに個別設定
    final d = dayOf(date);
    final recurring = availability
        .where((a) => a.staffId == staffId && a.weekday == d.weekday)
        .toList();
    for (final r in recurring) {
      availability.add(
        StaffAvailability(
          id: _id('av'),
          staffId: staffId,
          date: d,
          startMin: r.startMin,
          endMin: r.endMin,
          kind: r.kind,
          updatedAt: DateTime.now(),
        ),
      );
    }
    availDayOverrides.add(key);
  }

  void setAllDayNg({required String staffId, required DateTime date}) {
    clearAvailability(staffId: staffId, date: date);
    setAvailability(
      staffId: staffId,
      date: date,
      startMin: 0,
      endMin: 1440,
      kind: AvailKind.ng,
    );
  }

  /// 前週コピー（§6.2）
  int copyPreviousWeek({required String staffId, required DateTime weekStart}) {
    final prev = weekStart.subtract(const Duration(days: 7));
    var count = 0;
    for (var i = 0; i < 7; i++) {
      final srcDay = dayOf(prev.add(Duration(days: i)));
      final dstDay = dayOf(weekStart.add(Duration(days: i)));
      final src = availability
          .where(
            (a) =>
                a.staffId == staffId &&
                a.date != null &&
                dayOf(a.date!) == srcDay,
          )
          .toList();
      if (src.isEmpty) continue;
      availability.removeWhere(
        (a) =>
            a.staffId == staffId && a.date != null && dayOf(a.date!) == dstDay,
      );
      // 前週が個別設定だった日は、コピー先も同じ扱いにする（消したNGが戻らない）
      if (availDayOverrides.contains(availDayKey(staffId, srcDay))) {
        availDayOverrides.add(availDayKey(staffId, dstDay));
      }
      for (final a in src) {
        availability.add(
          StaffAvailability(
            id: _id('av'),
            staffId: staffId,
            date: dstDay,
            startMin: a.startMin,
            endMin: a.endMin,
            kind: a.kind,
            updatedAt: DateTime.now(),
          ),
        );
        count++;
      }
    }
    _audit(
      actorName,
      '助産師',
      '前週コピー',
      '${weekStart.month}/${weekStart.day}週',
      '$count件',
    );
    notifyListeners();
    return count;
  }

  /// 一括登録（複数日 × 同一時間帯）
  void bulkSet({
    required String staffId,
    required List<DateTime> dates,
    required int startMin,
    required int endMin,
    required AvailKind kind,
  }) {
    for (final d in dates) {
      _materializeDay(staffId, d);
      _punchOut(staffId: staffId, date: d, startMin: startMin, endMin: endMin);
      availability.add(
        StaffAvailability(
          id: _id('av'),
          staffId: staffId,
          date: dayOf(d),
          startMin: startMin,
          endMin: endMin,
          kind: kind,
          updatedAt: DateTime.now(),
        ),
      );
      availDayOverrides.add(availDayKey(staffId, d));
    }
    _audit(
      actorName,
      '助産師',
      '一括${kind.label}登録',
      '${dates.length}日',
      '${hhmm(startMin)}-${hhmm(endMin)}',
    );
    notifyListeners();
  }

  /// 指定日の実効区間（表示用）。
  /// エンジンと同一の解決規則を使い、画面と割当判定が食い違わないようにする。
  List<StaffAvailability> effectiveAvailability(String staffId, DateTime day) {
    final out = engine.effectiveFor(staffId, day);
    out.sort((a, b) => a.startMin.compareTo(b.startMin));
    return out;
  }

  // -------------------------------------------------------------------------
  // 待機リスト（E-03）
  // -------------------------------------------------------------------------
  void addToWaitlist({
    required String serviceId,
    required DateTime from,
    required DateTime to,
    required List<int> weekdays,
  }) {
    waitlist.add(
      WaitEntry(
        id: _id('wl'),
        customerId: customer.id,
        serviceId: serviceId,
        desiredFrom: from,
        desiredTo: to,
        weekdays: weekdays,
        createdAt: DateTime.now(),
      ),
    );
    _audit(
      'ご家族',
      'family',
      '空き枠待ち登録',
      serviceById(serviceId).name,
      '${_fmt(from)}〜${_fmt(to)}',
    );
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // 助産師ビュー
  // -------------------------------------------------------------------------

  List<OpsBooking> todaysCare(String staffId) {
    final today = dayOf(DateTime.now());
    return bookings
        .where(
          (b) =>
              b.staffId == staffId &&
              dayOf(b.at) == today &&
              b.state != BookingState.cancelled,
        )
        .toList()
      ..sort((a, b) => a.at.compareTo(b.at));
  }

  List<OpsBooking> upcomingFor(String staffId, {int days = 14}) {
    final now = DateTime.now();
    return bookings
        .where(
          (b) =>
              b.staffId == staffId &&
              b.at.isAfter(now) &&
              b.at.isBefore(now.add(Duration(days: days))) &&
              b.state.isActive,
        )
        .toList()
      ..sort((a, b) => a.at.compareTo(b.at));
  }

  int loadMinutes(String staffId, DateTime day) => bookings
      .where(
        (b) =>
            b.staffId == staffId &&
            dayOf(b.at) == dayOf(day) &&
            b.state.isActive,
      )
      .fold(0, (s, b) => s + b.durationMin);

  // -------------------------------------------------------------------------
  // 家族ビュー
  // -------------------------------------------------------------------------

  List<OpsBooking> get familyBookings =>
      bookings.where((b) => b.state != BookingState.draft).toList()
        ..sort((a, b) => b.at.compareTo(a.at));

  OpsBooking? get nextBooking {
    final f =
        bookings
            .where((b) => b.state.isActive && b.at.isAfter(DateTime.now()))
            .toList()
          ..sort((a, b) => a.at.compareTo(b.at));
    return f.isEmpty ? null : f.first;
  }

  List<OpsBooking> get actionRequired => bookings
      .where(
        (b) =>
            b.state == BookingState.needsReview ||
            b.state == BookingState.provisional ||
            b.state == BookingState.notEligible ||
            (b.state == BookingState.slotHeld && !b.holdExpired),
      )
      .toList();

  // -------------------------------------------------------------------------
  // §21 リピーター最短導線「前回と同じ内容で予約」
  //
  // 3〜5分で終わらせるための中心機能。前回の内容を丸ごと引き継ぎ、
  // 「変わっている項目だけ」を家族に確認させる。
  // -------------------------------------------------------------------------

  /// 直近の実績ある予約（完了 > 確定 > その他）。無ければ null。
  OpsBooking? lastBookingFor(String customerId) {
    final done =
        bookings
            .where(
              (b) =>
                  b.customerId == customerId &&
                  b.state != BookingState.draft &&
                  b.state != BookingState.cancelled,
            )
            .toList()
          ..sort((a, b) {
            // 完了実績を優先し、その中で新しい順
            final ac = a.state == BookingState.completed ? 0 : 1;
            final bc = b.state == BookingState.completed ? 0 : 1;
            if (ac != bc) return ac.compareTo(bc);
            return b.at.compareTo(a.at);
          });
    return done.isEmpty ? null : done.first;
  }

  OpsBooking? get lastBooking => lastBookingFor(customer.id);

  static const _wd = ['月', '火', '水', '木', '金', '土', '日'];
  static String _wdLabel(int weekday) => _wd[weekday - 1];

  /// §21 前回内容の再利用計画。差分だけを家族に見せるための材料。
  RepeatPlan? buildRepeatPlan() {
    final src = lastBooking;
    if (src == null) return null;

    final service = serviceById(src.serviceId);
    final child = customer.children.firstWhere(
      (c) => c.id == src.childId,
      orElse: () => customer.children.first,
    );

    // 同じ曜日・同じ時刻の直近の候補日を探す（前回のリズムを尊重する）
    final now = DateTime.now();
    final targetWeekday = src.at.weekday;
    final startMin = minOfDay(src.at);
    DateTime? proposed;
    for (int i = 1; i <= 28 && proposed == null; i++) {
      final d = dayOf(now.add(Duration(days: i)));
      if (d.weekday != targetWeekday) continue;
      final at = d.add(Duration(minutes: startMin));
      final slot = engine.buildSlot(
        service: service,
        at: at,
        facilityId: src.facilityId,
        areaCode: customer.address.areaCode,
        customerId: customer.id,
      );
      if (slot.bookable) proposed = at;
    }

    // 同じリズムが取れなければ、直近の空きを提案する
    final fallback = proposed == null
        ? engine
              .searchSlots(
                service: service,
                from: now.add(const Duration(days: 1)),
                days: 21,
                startMinutes: const [540, 600, 660, 780, 840, 900],
                facilityId: src.facilityId,
                areaCode: customer.address.areaCode,
                customerId: customer.id,
              )
              .firstOrNull
        : null;

    // 「変わっているところ」＝家族に確認してほしい項目だけを積む
    final changes = <RepeatChange>[];
    final program = municipalityById(customer.municipalityId);
    final eligibility = evaluateEligibility(
      eligibilityContext(service: service, child: child, at: now),
    );

    if (proposed == null && fallback != null) {
      changes.add(
        RepeatChange(
          field: '日時',
          detail: '前回と同じ${_wdLabel(targetWeekday)}曜${hhmm(startMin)}は空きがありません',
          action: '近い日時をご提案します',
        ),
      );
    }
    if (child.ageDays > service.maxChildAgeDays) {
      changes.add(
        RepeatChange(
          field: 'プラン',
          detail: '${child.name}の月齢が前回のプランの対象範囲を超えました',
          action: '別のプランをお選びください',
        ),
      );
    }
    if (eligibility.contains(ReasonCode.eligibilityUnknown)) {
      changes.add(
        RepeatChange(
          field: '利用条件',
          detail: eligibilityText(service: service, child: child, at: now),
          action: 'ご確認をお願いします',
        ),
      );
    }
    final policy = cancelPolicies
        .where((p) => p.id == service.cancelPolicyId)
        .firstOrNull;
    if (policy != null &&
        src.cancelPolicyVersion != null &&
        policy.version != src.cancelPolicyVersion) {
      changes.add(
        RepeatChange(
          field: 'キャンセル規定',
          detail: '前回のご利用後に規定が更新されました（${policy.versionLabel}）',
          action: '内容をご確認ください',
        ),
      );
    }
    if (program.maxUseCount - customer.usedCount <= 0) {
      changes.add(
        RepeatChange(
          field: 'のこり回数',
          detail: '${program.name}の利用上限（${program.maxUseCount}回）に達しています',
          action: '担当者が確認します',
        ),
      );
    }

    return RepeatPlan(
      source: src,
      service: service,
      child: child,
      facilityId: src.facilityId,
      needs: List<String>.from(src.needs),
      intake: Map<String, dynamic>.from(src.intake),
      proposedAt: proposed ?? fallback?.at,
      sameRhythm: proposed != null,
      changes: changes,
    );
  }

  // -------------------------------------------------------------------------
  // 管理者ダッシュボード / KPI（§16）
  // -------------------------------------------------------------------------

  List<OpsBooking> get exceptionQueue =>
      bookings.where((b) => b.hasOpenException).toList()..sort((a, b) {
        final ao = a.openExceptions.any((e) => e.code == ReasonCode.redFlag)
            ? 0
            : 1;
        final bo = b.openExceptions.any((e) => e.code == ReasonCode.redFlag)
            ? 0
            : 1;
        return ao != bo ? ao.compareTo(bo) : a.at.compareTo(b.at);
      });

  int get totalBookings =>
      bookings.where((b) => b.state != BookingState.draft).length;
  int get autoCompleted => bookings.where((b) => b.autoAssigned).length;

  /// 自動完結率（目標70%以上）
  double get autoRate => totalBookings == 0 ? 0 : autoCompleted / totalBookings;

  /// 手動タッチ0件の割合（聞き返し率の裏返し）
  double get zeroTouchRate {
    final t = bookings.where((b) => b.state != BookingState.draft).toList();
    if (t.isEmpty) return 0;
    return t.where((b) => b.manualTouches == 0).length / t.length;
  }

  /// 推定メッセージ削減率（As-Is 4,401通/月 モデル）
  /// 自動完結した予約1件あたり、従来 受信1.86通＋送信3.25通 相当を削減。
  int get estimatedMessagesSaved => (autoCompleted * 5.1).round();

  double get chatReductionRate {
    // 863室 × 平均5.1通 = 4,401通。自動完結率をそのまま削減率の代理指標とする。
    return (autoRate * 0.86).clamp(0.0, 1.0);
  }

  /// 割当品質：スキル不一致・NG時間への割当件数（目標0件）
  int get misAssignments {
    var bad = 0;
    for (final b in bookings.where(
      (b) => b.staffId != null && b.state.isActive,
    )) {
      final s = staffById(b.staffId!)!;
      final ok = engine.verifyAssignment(
        s: s,
        service: serviceById(b.serviceId),
        at: b.at,
        facilityId: b.facilityId,
        areaCode: customer.address.areaCode,
        excludeBookingId: b.id, // 自分自身を重複相手として数えない
      );
      if (!ok) bad++;
    }
    return bad;
  }

  int get redFlagMissed => bookings
      .where(
        (b) => b.exceptions.any(
          (e) => e.code == ReasonCode.redFlag && !e.resolved && e.overdue,
        ),
      )
      .length;

  int get doubleBookings {
    var count = 0;
    final active = bookings
        .where((b) => b.state.isActive && b.staffId != null)
        .toList();
    for (var i = 0; i < active.length; i++) {
      for (var j = i + 1; j < active.length; j++) {
        final a = active[i], b = active[j];
        if (a.staffId == b.staffId &&
            a.at.isBefore(b.endAt) &&
            b.at.isBefore(a.endAt)) {
          count++;
        }
      }
    }
    return count;
  }

  double get overdueTaskRate =>
      tasks.isEmpty ? 0 : overdueTasks.length / tasks.length;

  double get deliverySuccessRate {
    if (notifications.isEmpty) return 1;
    return notifications
            .where((n) => n.status == DeliveryStatus.delivered)
            .length /
        notifications.length;
  }

  // -------------------------------------------------------------------------
  // ヘルパー
  // -------------------------------------------------------------------------
  String _ts() {
    final n = DateTime.now();
    return '${n.month}/${n.day} ${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
  }

  String _fmt(DateTime d) {
    const w = ['月', '火', '水', '木', '金', '土', '日'];
    return '${d.month}月${d.day}日(${w[d.weekday - 1]}) ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  // -------------------------------------------------------------------------
  // 初期予約データ（デモ用・匿名）
  // -------------------------------------------------------------------------
  int _seedFee(ServiceDef svc, OpsChild child, DateTime at) =>
      estimateFeeFor(service: svc, child: child, at: at).yen ?? svc.priceYen;

  String _seedFeeBasis(ServiceDef svc, OpsChild child, DateTime at) =>
      estimateFeeFor(service: svc, child: child, at: at).basis;

  void _seedBookings() {
    final today = dayOf(DateTime.now());
    final child = customer.children.first;

    // 本日の確定予約（助産師「今日のケア」用）
    void add({
      required String svcId,
      required DateTime at,
      required String staffId,
      String? facilityId,
      BookingState state = BookingState.confirmed,
      bool auto = true,
      Map<String, dynamic>? intake,
      List<String>? needs,
      int touches = 0,
    }) {
      final svc = serviceById(svcId);
      final policy = policyById(svc.cancelPolicyId);
      final terms0 = terms.first;
      final b = OpsBooking(
        id: _id('bk'),
        code: _bookingCode(),
        customerId: customer.id,
        childId: child.id,
        serviceId: svcId,
        at: at,
        durationMin: svc.durationMin,
        kind: svc.kind,
        facilityId: facilityId,
        staffId: staffId,
        state: state,
        createdAt: at.subtract(const Duration(days: 6)),
        updatedAt: DateTime.now(),
        autoAssigned: auto,
        manualTouches: touches,
        feeYen: _seedFee(svc, child, at),
        feeState: state == BookingState.confirmed
            ? FeeState.confirmed
            : FeeState.estimate,
        funding: svc.kind.programType == null
            ? FundingType.selfPay
            : FundingType.municipal,
        municipalityProgramId: customer.municipalityId,
        municipalityProgramVersion: municipalityById(
          customer.municipalityId,
        ).version,
        feeBasis: _seedFeeBasis(svc, child, at),
        useIndex: customer.nextUseIndex,
        voucherVerified: true,
        cancelPolicyId: policy.id,
        cancelPolicyVersion: policy.version,
        intake: intake ?? {'bath': true, 'meal': false},
        needs: needs ?? ['休みたい', '授乳を相談したい'],
        consent: ConsentSnapshot(
          termsId: terms0.id,
          title: terms0.title,
          version: terms0.version,
          revisedAt: terms0.revisedAt,
          agreedAt: at.subtract(const Duration(days: 6)),
          agreedText: terms0.keyPoints.join('／'),
        ),
      );
      b.stateLog.add('${b.createdAt.month}/${b.createdAt.day} SUBMITTED 申込受付');
      b.stateLog.add('${b.createdAt.month}/${b.createdAt.day} CONFIRMED 自動確定');
      bookings.add(b);
    }

    add(
      svcId: 'svc_visit3',
      at: today.add(const Duration(hours: 10)),
      staffId: 'st_sato',
      needs: ['休みたい', '沐浴を手伝ってほしい'],
      intake: {'bath': true, 'parking': 'あり', 'meal': false},
    );
    add(
      svcId: 'svc_breast',
      at: today.add(const Duration(hours: 14)),
      staffId: 'st_sato',
      facilityId: 'fac_sakura',
      needs: ['授乳を相談したい', '乳房が痛い'],
      intake: {'breast_pain': false, 'meal': false},
    );
    add(
      svcId: 'svc_day4',
      at: today.add(const Duration(days: 4, hours: 10)),
      staffId: 'st_ono',
      facilityId: 'fac_sakura',
      needs: ['ひとりで眠りたい', '食事をとりたい'],
      intake: {'meal': true, 'allergy': '', 'bath': true},
    );

    // 例外キュー用：赤旗あり（自動確定させない）
    final svc = serviceById('svc_breast');
    final policy = policyById(svc.cancelPolicyId);
    final ex = OpsBooking(
      id: _id('bk'),
      code: _bookingCode(),
      customerId: customer.id,
      childId: child.id,
      serviceId: svc.id,
      at: today.add(const Duration(days: 2, hours: 11)),
      durationMin: svc.durationMin,
      kind: svc.kind,
      facilityId: 'fac_sakura',
      state: BookingState.needsReview,
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      updatedAt: DateTime.now(),
      feeYen: svc.priceYen,
      feeState: FeeState.underReview,
      cancelPolicyId: policy.id,
      cancelPolicyVersion: policy.version,
      intake: {
        'breast_pain': true,
        'fever': false,
        'freeText': '右の胸が昨日から痛くて、赤くなっています。授乳もつらいです。',
      },
      needs: ['乳房が痛い', '授乳を相談したい'],
    );
    ex.stateLog.add('SUBMITTED 申込受付');
    ex.stateLog.add('NEEDS_REVIEW E-01 健康上の確認が必要');
    ex.exceptions.add(
      BookingException(
        code: ReasonCode.redFlag,
        detail: '乳房の強い痛み・赤みの回答あり（RF-BREAST）',
        raisedAt: DateTime.now().subtract(const Duration(hours: 3)),
        dueAt: DateTime.now().add(const Duration(minutes: 20)),
      ),
    );
    bookings.add(ex);
    tasks.add(
      OpsTask(
        id: _id('tk'),
        title: 'E-01 健康上の確認が必要',
        detail: '${ex.code} 母乳外来 ${_fmt(ex.at)}\n乳房の強い痛み・赤みの回答あり（RF-BREAST）',
        owner: TaskOwner.midwife,
        bookingId: ex.id,
        reason: ReasonCode.redFlag,
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        dueAt: DateTime.now().add(const Duration(minutes: 20)),
        priority: 1,
      ),
    );

    // 通知履歴
    notifications.addAll([
      OpsNotification(
        id: _id('nt'),
        bookingId: bookings.first.id,
        customerId: customer.id,
        event: NotifyEvent.dayOf,
        title: '本日のご訪問について',
        body: '10:00に佐藤がうかがいます。玄関の解錠だけお願いできれば、あとはこちらで進めます。',
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        status: DeliveryStatus.delivered,
      ),
      OpsNotification(
        id: _id('nt'),
        bookingId: bookings.first.id,
        customerId: customer.id,
        event: NotifyEvent.confirmed,
        title: 'ご予約が確定しました',
        body: '訪問ケア（3時間）／担当：佐藤 みどり',
        createdAt: DateTime.now().subtract(const Duration(days: 6)),
        status: DeliveryStatus.delivered,
      ),
    ]);
  }
}
