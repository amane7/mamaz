// ============================================================================
// ママズケア LINE業務アプリ化 v2.1 — データモデル（要件定義書 §12 / 付録C）
// 設計原則: Chatless by default, Human when it matters.
// ============================================================================

import 'package:flutter/material.dart';

import 'booking_mode.dart';
import 'municipality_program.dart';

export 'booking_mode.dart';
export 'municipality_program.dart';

// ---------------------------------------------------------------------------
// 共通ユーティリティ
// ---------------------------------------------------------------------------

/// 日付のみに丸める（可用性判定は「日 × 分」で行う）。
DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// 0:00からの経過分。
int minOfDay(DateTime d) => d.hour * 60 + d.minute;

String hhmm(int minutes) {
  final h = (minutes ~/ 60).toString().padLeft(2, '0');
  final m = (minutes % 60).toString().padLeft(2, '0');
  return '$h:$m';
}

// ---------------------------------------------------------------------------
// §12 Customer / Child / Address
// ---------------------------------------------------------------------------

/// 顧客（LINE表示名は主キーにしない ＝ §12 要件）
class OpsCustomer {
  final String id; // 内部ID（主キー）
  final String lineUserId; // 主キー候補（付録C.5）
  final String nameKanji;
  final String nameKana;
  final DateTime birth; // 西暦で保持（§12）
  final String phone; // 補助照合キー
  final String emergencyContact;
  final List<OpsChild> children;
  final OpsAddress address;
  final String municipalityId;
  final String? programNumber; // 自治体利用番号
  final int usedCount; // 累計利用回数（当施設）
  final bool isReturning;

  /// 自治体への利用申請の状態（未申請→申請中→承認済み／対象外）と、
  /// 確認した書類・課税区分・他施設での利用回数。
  final MunicipalApplication application;

  const OpsCustomer({
    required this.id,
    required this.lineUserId,
    required this.nameKanji,
    required this.nameKana,
    required this.birth,
    required this.phone,
    required this.emergencyContact,
    required this.children,
    required this.address,
    required this.municipalityId,
    this.programNumber,
    this.usedCount = 0,
    this.isReturning = false,
    this.application = const MunicipalApplication(),
  });

  String get maskedPhone => phone.length < 4
      ? phone
      : '${phone.substring(0, 3)}****${phone.substring(phone.length - 2)}';

  /// 何回目の利用になるか（当施設＋他施設の利用回数＋1）。
  /// 瀬戸市のように他施設分も合算して料金段階を決める自治体があるため。
  int get nextUseIndex => usedCount + application.otherFacilityUses + 1;

  OpsCustomer copyWith({
    String? municipalityId,
    String? programNumber,
    int? usedCount,
    MunicipalApplication? application,
    OpsAddress? address,
    List<OpsChild>? children,
  }) => OpsCustomer(
    id: id,
    lineUserId: lineUserId,
    nameKanji: nameKanji,
    nameKana: nameKana,
    birth: birth,
    phone: phone,
    emergencyContact: emergencyContact,
    children: children ?? this.children,
    address: address ?? this.address,
    municipalityId: municipalityId ?? this.municipalityId,
    programNumber: programNumber ?? this.programNumber,
    usedCount: usedCount ?? this.usedCount,
    isReturning: isReturning,
    application: application ?? this.application,
  );
}

class OpsChild {
  final String id;
  final String name;
  final String kana;
  final DateTime birth;
  final int birthOrder; // 第何子
  final bool multiple; // 多胎
  /// 何胎か（1=単胎、2=双子、3=三つ子）。multiple=true で未指定なら 2 とみなす。
  final int? pluralityValue;
  const OpsChild({
    required this.id,
    required this.name,
    required this.kana,
    required this.birth,
    this.birthOrder = 1,
    this.multiple = false,
    this.pluralityValue,
  });

  int get plurality => pluralityValue ?? (multiple ? 2 : 1);

  int ageDaysAt(DateTime at) => dayOf(at).difference(dayOf(birth)).inDays;
  int get ageDays => ageDaysAt(DateTime.now());
  String get ageLabel {
    final d = ageDays;
    if (d < 31) return '生後$d日';
    return '生後${(d / 30.4).floor()}か月';
  }
}

class OpsAddress {
  final String postal;
  final String city; // 市区町村
  final String line1;
  final String building;
  final String room;
  final bool isParentsHome; // 実家か
  final bool parkingOnSite; // 敷地内駐車場
  final bool parkingNearby; // 近隣駐車場
  final String areaCode; // 訪問エリア判定用
  const OpsAddress({
    required this.postal,
    required this.city,
    required this.line1,
    this.building = '',
    this.room = '',
    this.isParentsHome = false,
    this.parkingOnSite = true,
    this.parkingNearby = false,
    required this.areaCode,
  });

  String get short => '$city $line1${building.isEmpty ? '' : ' $building'}';
}

// ---------------------------------------------------------------------------
// §12 MunicipalityProgram（版管理 = A-08）
// ---------------------------------------------------------------------------

class MunicipalityProgram {
  final String id;
  final String name;
  final int version;
  final DateTime effectiveFrom;
  final bool requiresProgramNumber;
  final int maxUseCount;
  final int maxChildAgeDays;
  final int subsidyYen; // 1回あたり助成

  /// 同時に持てる「これからのご予約」の上限（§12 予約数制限）。
  /// 固定実装しないための自治体マスタ項目。0 = 制限なし。
  /// 1件も先の予約を許さない運用は現実にはないため、既定は 3 件。
  final int maxConcurrentBookings;
  final List<String> requiredDocs;

  // ---- 要件再定義：自治体制度マスタの追加項目 ----------------------------

  /// 適用終了日（null なら未定）。年度改定を跨いだときに旧版を残すため。
  final DateTime? effectiveTo;

  /// 最終確認日・確認担当者・公式情報URL・資料版数（出典管理）。
  final DateTime? lastVerifiedAt;
  final String verifiedBy;
  final String sourceUrl;
  final String sourceRevision;

  /// 居住地要件（例：名古屋市に住民登録がある方）。
  final String residencyRequirement;

  /// 申請可能時期・必要日数・申請方法・申請先。
  final String applicationWindow; // 例: 妊娠32週から
  final int applicationLeadDays; // 利用日の何日前まで（0=規定なし）
  final String applicationMethod; // 例: 電子申請・書面
  final String applicationContact; // 例: 子ども家庭課 母子保健係

  /// 予約・日程調整の主体。
  final SchedulingAuthority scheduling;

  /// 利用券／クーポン／承認通知の要否。
  final bool requiresVoucher;
  final bool requiresCoupon;
  final bool requiresDecisionNotice;

  /// 事前に自治体の承認（決定通知）が必要か。false なら申請なしでも受け付ける。
  final bool requiresApproval;

  /// サービス別の対象月齢（単胎・多胎）。空なら maxChildAgeDays を使う。
  final List<ServiceEligibility> serviceEligibility;

  /// 多胎児の受入条件（対象月齢以外の注記）。
  final String multipleBirthNote;

  /// 利用回数の数え方。
  final String useCountRule; // 例: 3類型合算7日
  final bool countsOtherFacilities; // 他施設利用分を含むか

  /// 料金ルール（有効期間付き・管理画面から更新）。空なら subsidyYen 方式。
  final List<FeeRule> feeRules;

  /// 自治体側のキャンセル規定。
  final MunicipalCancelRule cancelRule;

  /// 制度外の自費利用へ切り替える条件（文章）。
  final String selfPaySwitchNote;

  /// この自治体で MAMOA が「予約」まで担うか（false なら制度案内のみ）。
  final bool bookingEnabled;

  const MunicipalityProgram({
    required this.id,
    required this.name,
    required this.version,
    required this.effectiveFrom,
    this.requiresProgramNumber = true,
    this.maxUseCount = 7,
    this.maxChildAgeDays = 365,
    this.subsidyYen = 0,
    this.maxConcurrentBookings = 3,
    this.requiredDocs = const [],
    this.effectiveTo,
    this.lastVerifiedAt,
    this.verifiedBy = '',
    this.sourceUrl = '',
    this.sourceRevision = '',
    this.residencyRequirement = '',
    this.applicationWindow = '',
    this.applicationLeadDays = 0,
    this.applicationMethod = '',
    this.applicationContact = '',
    this.scheduling = SchedulingAuthority.provider,
    this.requiresVoucher = false,
    this.requiresCoupon = false,
    this.requiresDecisionNotice = false,
    this.requiresApproval = true,
    this.serviceEligibility = const [],
    this.multipleBirthNote = '',
    this.useCountRule = '',
    this.countsOtherFacilities = false,
    this.feeRules = const [],
    this.cancelRule = const MunicipalCancelRule(),
    this.selfPaySwitchNote = '',
    this.bookingEnabled = true,
  });

  String get versionLabel =>
      'v$version（${effectiveFrom.year}/${effectiveFrom.month}/${effectiveFrom.day}適用）';

  /// 指定日にこの版が有効か。
  bool isEffectiveAt(DateTime at) {
    final d = DateTime(at.year, at.month, at.day);
    if (d.isBefore(
      DateTime(effectiveFrom.year, effectiveFrom.month, effectiveFrom.day),
    )) {
      return false;
    }
    final to = effectiveTo;
    if (to != null && d.isAfter(DateTime(to.year, to.month, to.day))) {
      return false;
    }
    return true;
  }

  /// 最終確認から日数が経ちすぎている（年度改定の見落とし防止）。
  bool get verificationStale {
    final v = lastVerifiedAt;
    if (v == null) return true;
    return DateTime.now().difference(v).inDays > 90;
  }

  /// この自治体が実施している事業類型。
  Set<ProgramServiceType> get offeredServices => serviceEligibility.isEmpty
      ? {ProgramServiceType.dayCare, ProgramServiceType.outreach}
      : serviceEligibility.map((e) => e.service).toSet();

  ServiceEligibility? eligibilityFor(ProgramServiceType t) =>
      serviceEligibility.where((e) => e.service == t).firstOrNull;

  /// 料金ルールから概算を出す（一致しなければ null＝概算不能→スタッフ確認）。
  FeeRule? feeRuleFor({
    required ProgramServiceType service,
    required TaxClass taxClass,
    required bool couponUsed,
    required int useIndex,
    required int plurality,
  }) {
    for (final r in feeRules) {
      if (r.matches(
        service: service,
        taxClass: taxClass,
        couponUsed: couponUsed,
        useIndex: useIndex,
        plurality: plurality,
      )) {
        return r;
      }
    }
    return null;
  }

  /// §24 管理者による改定。§20 のため版番号は呼び出し側で必ず繰り上げる。
  MunicipalityProgram copyWith({
    String? name,
    int? version,
    DateTime? effectiveFrom,
    bool? requiresProgramNumber,
    int? maxUseCount,
    int? maxChildAgeDays,
    int? subsidyYen,
    int? maxConcurrentBookings,
    List<String>? requiredDocs,
    DateTime? effectiveTo,
    DateTime? lastVerifiedAt,
    String? verifiedBy,
    String? sourceUrl,
    String? sourceRevision,
    String? residencyRequirement,
    String? applicationWindow,
    int? applicationLeadDays,
    String? applicationMethod,
    String? applicationContact,
    SchedulingAuthority? scheduling,
    bool? requiresVoucher,
    bool? requiresCoupon,
    bool? requiresDecisionNotice,
    bool? requiresApproval,
    List<ServiceEligibility>? serviceEligibility,
    String? multipleBirthNote,
    String? useCountRule,
    bool? countsOtherFacilities,
    List<FeeRule>? feeRules,
    MunicipalCancelRule? cancelRule,
    String? selfPaySwitchNote,
    bool? bookingEnabled,
  }) => MunicipalityProgram(
    id: id,
    name: name ?? this.name,
    version: version ?? this.version,
    effectiveFrom: effectiveFrom ?? this.effectiveFrom,
    requiresProgramNumber: requiresProgramNumber ?? this.requiresProgramNumber,
    maxUseCount: maxUseCount ?? this.maxUseCount,
    maxChildAgeDays: maxChildAgeDays ?? this.maxChildAgeDays,
    subsidyYen: subsidyYen ?? this.subsidyYen,
    maxConcurrentBookings: maxConcurrentBookings ?? this.maxConcurrentBookings,
    requiredDocs: requiredDocs ?? this.requiredDocs,
    effectiveTo: effectiveTo ?? this.effectiveTo,
    lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
    verifiedBy: verifiedBy ?? this.verifiedBy,
    sourceUrl: sourceUrl ?? this.sourceUrl,
    sourceRevision: sourceRevision ?? this.sourceRevision,
    residencyRequirement: residencyRequirement ?? this.residencyRequirement,
    applicationWindow: applicationWindow ?? this.applicationWindow,
    applicationLeadDays: applicationLeadDays ?? this.applicationLeadDays,
    applicationMethod: applicationMethod ?? this.applicationMethod,
    applicationContact: applicationContact ?? this.applicationContact,
    scheduling: scheduling ?? this.scheduling,
    requiresVoucher: requiresVoucher ?? this.requiresVoucher,
    requiresCoupon: requiresCoupon ?? this.requiresCoupon,
    requiresDecisionNotice:
        requiresDecisionNotice ?? this.requiresDecisionNotice,
    requiresApproval: requiresApproval ?? this.requiresApproval,
    serviceEligibility: serviceEligibility ?? this.serviceEligibility,
    multipleBirthNote: multipleBirthNote ?? this.multipleBirthNote,
    useCountRule: useCountRule ?? this.useCountRule,
    countsOtherFacilities: countsOtherFacilities ?? this.countsOtherFacilities,
    feeRules: feeRules ?? this.feeRules,
    cancelRule: cancelRule ?? this.cancelRule,
    selfPaySwitchNote: selfPaySwitchNote ?? this.selfPaySwitchNote,
    bookingEnabled: bookingEnabled ?? this.bookingEnabled,
  );
}

// ---------------------------------------------------------------------------
// §12 Service（版管理 = A-09）
// ---------------------------------------------------------------------------

enum ServiceKind { visit, dayStay, stay, breastClinic }

extension ServiceKindX on ServiceKind {
  String get label => switch (this) {
    ServiceKind.visit => '訪問ケア',
    ServiceKind.dayStay => '通所（デイケア）',
    ServiceKind.stay => '宿泊ケア',
    ServiceKind.breastClinic => '母乳外来',
  };
  IconData get icon => switch (this) {
    ServiceKind.visit => Icons.directions_car_filled_outlined,
    ServiceKind.dayStay => Icons.chair_outlined,
    ServiceKind.stay => Icons.night_shelter_outlined,
    ServiceKind.breastClinic => Icons.water_drop_outlined,
  };

  /// 自治体事業の類型への対応。母乳外来は制度外（null）。
  ProgramServiceType? get programType => switch (this) {
    ServiceKind.visit => ProgramServiceType.outreach,
    ServiceKind.dayStay => ProgramServiceType.dayCare,
    ServiceKind.stay => ProgramServiceType.stay,
    ServiceKind.breastClinic => null,
  };
}

class ServiceDef {
  final String id;
  final String name;
  final ServiceKind kind;
  final int durationMin;
  final Set<String> requiredSkills;
  final int minChildAgeDays;
  final int maxChildAgeDays;
  final bool mealEligible; // 3時間以上など食事提供対象（付録C.4）
  final bool bathEligible; // 沐浴対象月齢
  final int travelMin; // 前後移動時間（訪問）
  final int bufferMin; // 予約間バッファ
  final int priceYen;
  final String cancelPolicyId;
  final int version;
  final DateTime effectiveFrom;
  final String description;
  final List<String> needTags; // ニーズ選択（C-05）とのマッピング

  /// §6 「利用形態」と「プラン」の分離。
  ///
  /// 同じ利用形態の中に複数のプラン（3時間／2時間など）がある。
  /// 未指定なら kind をグループキーとして扱う（後方互換）。
  final String? planGroupId;

  /// 家族に見せるプラン名（未指定なら所要時間を使う）
  final String? planLabel;

  /// このプランに必要な設備種別（§15）。空なら施設側の既定で判定。
  final Set<ResourceKind> requiredResourceKinds;

  /// §3 予約の成立のしかた。管理画面から変えられる（§43）。
  ///
  /// 既定を instant にしてあるのは、既存の保存データ・既存テストの
  /// 振る舞いを変えないため（後方互換）。産後ケアの各サービスは
  /// 初期データ側で requestApproval を明示する（§4）。
  final BookingMode bookingMode;

  /// §12 開始時刻の刻み（分）。所要時間とは分離する。
  ///
  /// 例：母乳外来は durationMin=60 だが 09:00 / 09:30 / 10:00 と
  /// 30分刻みで始められる。両者を一緒にしていたため
  /// 「60分なら毎時しか始まらない」という制限になっていた。
  /// null のときは durationMin にフォールバックする（後方互換）。
  final int? startIntervalMinutes;

  /// 開始時刻の刻み（未設定なら所要時間）。
  int get startInterval => startIntervalMinutes ?? durationMin;

  const ServiceDef({
    required this.id,
    required this.name,
    required this.kind,
    required this.durationMin,
    required this.requiredSkills,
    this.minChildAgeDays = 0,
    this.maxChildAgeDays = 365,
    this.mealEligible = false,
    this.bathEligible = false,
    this.travelMin = 0,
    this.bufferMin = 15,
    required this.priceYen,
    required this.cancelPolicyId,
    this.version = 1,
    required this.effectiveFrom,
    this.description = '',
    this.needTags = const [],
    this.planGroupId,
    this.planLabel,
    this.requiredResourceKinds = const {},
    this.bookingMode = BookingMode.instant,
    this.startIntervalMinutes,
  });

  /// 前後の占有を含めた総拘束時間（移動＋バッファ）
  int get blockMin => durationMin + travelMin * 2 + bufferMin;
  String get durationLabel => durationMin % 60 == 0
      ? '${durationMin ~/ 60}時間'
      : '${durationMin ~/ 60}時間${durationMin % 60}分';

  /// 利用形態のグループキー（未設定なら kind）
  String get groupId => planGroupId ?? kind.name;

  /// プランの表示名（未設定なら所要時間）
  String get planName => planLabel ?? durationLabel;

  /// §24 管理者による改定。§20 のため版番号は呼び出し側で必ず繰り上げる。
  ServiceDef copyWith({
    String? name,
    int? durationMin,
    Set<String>? requiredSkills,
    int? minChildAgeDays,
    int? maxChildAgeDays,
    bool? mealEligible,
    bool? bathEligible,
    int? travelMin,
    int? bufferMin,
    int? priceYen,
    String? cancelPolicyId,
    int? version,
    DateTime? effectiveFrom,
    String? description,
    String? planLabel,
    Set<ResourceKind>? requiredResourceKinds,
    BookingMode? bookingMode,
    int? startIntervalMinutes,
  }) => ServiceDef(
    id: id,
    name: name ?? this.name,
    kind: kind,
    durationMin: durationMin ?? this.durationMin,
    requiredSkills: requiredSkills ?? this.requiredSkills,
    minChildAgeDays: minChildAgeDays ?? this.minChildAgeDays,
    maxChildAgeDays: maxChildAgeDays ?? this.maxChildAgeDays,
    mealEligible: mealEligible ?? this.mealEligible,
    bathEligible: bathEligible ?? this.bathEligible,
    travelMin: travelMin ?? this.travelMin,
    bufferMin: bufferMin ?? this.bufferMin,
    priceYen: priceYen ?? this.priceYen,
    cancelPolicyId: cancelPolicyId ?? this.cancelPolicyId,
    version: version ?? this.version,
    effectiveFrom: effectiveFrom ?? this.effectiveFrom,
    description: description ?? this.description,
    needTags: needTags,
    planGroupId: planGroupId,
    planLabel: planLabel ?? this.planLabel,
    requiredResourceKinds: requiredResourceKinds ?? this.requiredResourceKinds,
    bookingMode: bookingMode ?? this.bookingMode,
    startIntervalMinutes: startIntervalMinutes ?? this.startIntervalMinutes,
  );
}

// ---------------------------------------------------------------------------
// §12 CancelPolicy（固定実装せず版番号＋適用開始日 = 付録C.5）
// ---------------------------------------------------------------------------

class CancelTier {
  final String label;
  final int hoursBefore; // この時間前まで
  final int feeYen;
  const CancelTier(this.label, this.hoursBefore, this.feeYen);
}

class CancelPolicy {
  final String id;
  final String name;
  final int version;
  final DateTime effectiveFrom;
  final int changeDeadlineHours; // 利用時間の変更受付期限
  final List<CancelTier> tiers; // hoursBefore 降順
  final String fullText;
  const CancelPolicy({
    required this.id,
    required this.name,
    required this.version,
    required this.effectiveFrom,
    required this.changeDeadlineHours,
    required this.tiers,
    required this.fullText,
  });

  String get versionLabel => '$name v$version';

  /// 申請時刻から見込キャンセル料を算出。
  int feeFor({required DateTime bookingAt, required DateTime requestAt}) {
    final hours = bookingAt.difference(requestAt).inMinutes / 60.0;
    for (final t in tiers) {
      if (hours >= t.hoursBefore) return t.feeYen;
    }
    return tiers.isEmpty ? 0 : tiers.last.feeYen;
  }

  CancelTier tierFor({
    required DateTime bookingAt,
    required DateTime requestAt,
  }) {
    final hours = bookingAt.difference(requestAt).inMinutes / 60.0;
    for (final t in tiers) {
      if (hours >= t.hoursBefore) return t;
    }
    return tiers.last;
  }

  /// §24 管理者による改定。
  /// §20「予約時点の規定版を保存」のため、既存予約の ruleVersion は
  /// この改定で変わらない（予約側がスナップショットを持つ）。
  CancelPolicy copyWith({
    String? name,
    int? version,
    DateTime? effectiveFrom,
    int? changeDeadlineHours,
    List<CancelTier>? tiers,
    String? fullText,
  }) => CancelPolicy(
    id: id,
    name: name ?? this.name,
    version: version ?? this.version,
    effectiveFrom: effectiveFrom ?? this.effectiveFrom,
    changeDeadlineHours: changeDeadlineHours ?? this.changeDeadlineHours,
    tiers: tiers ?? this.tiers,
    fullText: fullText ?? this.fullText,
  );
}

// ---------------------------------------------------------------------------
// §12 Consent（規約版スナップショット = §8.3 / 付録C.5）
// ---------------------------------------------------------------------------

class TermsDoc {
  final String id;
  final String title;
  final int version;
  final DateTime revisedAt;
  final List<String> keyPoints; // 要点
  final String fullText;
  const TermsDoc({
    required this.id,
    required this.title,
    required this.version,
    required this.revisedAt,
    required this.keyPoints,
    required this.fullText,
  });
  String get versionLabel =>
      'v$version（${revisedAt.year}年${revisedAt.month}月${revisedAt.day}日改定）';
}

/// 予約に凍結保存される同意スナップショット。後日の改定で過去予約を変えない。
class ConsentSnapshot {
  final String termsId;
  final String title;
  final int version;
  final DateTime revisedAt;
  final DateTime agreedAt;
  final String agreedText; // 同意した文面（要点）
  const ConsentSnapshot({
    required this.termsId,
    required this.title,
    required this.version,
    required this.revisedAt,
    required this.agreedAt,
    required this.agreedText,
  });
}

// ---------------------------------------------------------------------------
// §12 Staff / Skill / StaffAvailability（本システムの中核）
// ---------------------------------------------------------------------------

class OpsStaff {
  final String id;
  final String name;
  final String role; // 助産師 / 看護師
  final Set<String> skills;
  final Set<ServiceKind> services;
  final Set<String> areas; // 訪問対応エリア
  final Set<String> facilityIds;
  final int bufferMin; // 予約間バッファ
  final int dailyMaxMin; // 1日上限（実働分）
  final int consecutiveMax; // 連続対応上限（件）
  final Color color;

  const OpsStaff({
    required this.id,
    required this.name,
    this.role = '助産師',
    required this.skills,
    required this.services,
    required this.areas,
    required this.facilityIds,
    this.bufferMin = 15,
    this.dailyMaxMin = 420,
    this.consecutiveMax = 3,
    required this.color,
  });

  String get initial => name.substring(0, 1);
}

/// OK＝仕事を受けられる時間 / NG＝受けられない時間。
/// NG が OK より優先。未登録（空欄）は原則予約不可。NG理由は保存しない（§12 / §19）。
enum AvailKind { ok, ng }

extension AvailKindX on AvailKind {
  String get label => this == AvailKind.ok ? 'OK' : 'NG';
  String get longLabel =>
      this == AvailKind.ok ? 'OK（お仕事を受けられます）' : 'NG（お仕事を受けられません）';
}

/// 「この日は特定日の登録だけを正とする（毎週パターンを適用しない）」印のキー。
///
/// カレンダーで一日を編集した時点で、その日は毎週パターンの支配から外れる。
/// これが無いと、毎週パターン由来のNGを消しても再読込で復活し、
/// 「一度登録したNGが取り消せない」不具合になる。
String availDayKey(String staffId, DateTime day) {
  final d = dayOf(day);
  return '$staffId|${d.year}-${d.month}-${d.day}';
}

class StaffAvailability {
  final String id;
  final String staffId;
  final DateTime? date; // 特定日（nullなら毎週パターン）
  final int? weekday; // 1=月 … 7=日（毎週パターン）
  final int startMin;
  final int endMin;
  final AvailKind kind;
  final DateTime updatedAt;

  const StaffAvailability({
    required this.id,
    required this.staffId,
    this.date,
    this.weekday,
    required this.startMin,
    required this.endMin,
    required this.kind,
    required this.updatedAt,
  });

  bool get isRecurring => weekday != null;

  bool appliesTo(DateTime day) {
    if (date != null) return dayOf(date!) == dayOf(day);
    return weekday == day.weekday;
  }

  StaffAvailability copyWith({int? startMin, int? endMin, AvailKind? kind}) =>
      StaffAvailability(
        id: id,
        staffId: staffId,
        date: date,
        weekday: weekday,
        startMin: startMin ?? this.startMin,
        endMin: endMin ?? this.endMin,
        kind: kind ?? this.kind,
        updatedAt: DateTime.now(),
      );
}

/// 休暇・確定予約以外の占有（管理者設定）
class StaffBlock {
  final String id;
  final String staffId;
  final DateTime date;
  final int startMin;
  final int endMin;
  final String reason; // 休暇・研修など（業務理由のみ）
  const StaffBlock({
    required this.id,
    required this.staffId,
    required this.date,
    required this.startMin,
    required this.endMin,
    required this.reason,
  });
}

// ---------------------------------------------------------------------------
// §12 Intake（動的問診 / C-06 / 付録C.4）
// ---------------------------------------------------------------------------

class IntakeAnswer {
  final Map<String, dynamic> values;
  final DateTime savedAt;
  final bool complete;
  const IntakeAnswer({
    required this.values,
    required this.savedAt,
    this.complete = false,
  });
}

/// 健康上の赤旗（E-01）。診断はしない。定義済み質問のみで判定。
class RedFlagRule {
  final String key;
  final String question;
  final String hint;
  final String reasonCode;
  final bool urgent; // 即時通知
  const RedFlagRule({
    required this.key,
    required this.question,
    required this.hint,
    required this.reasonCode,
    this.urgent = false,
  });
}

// ---------------------------------------------------------------------------
// §8.1 予約状態（9状態FSM）
// ---------------------------------------------------------------------------

enum BookingState {
  draft, // 入力途中
  submitted, // 申込受付
  requested, // §6 予約希望を受け付けた（REQUEST_APPROVAL の入口）＝利用希望受付
  municipalCoordination, // 行政調整中（市と施設が日程調整し、市から利用者へ連絡）
  needsReview, // スタッフ確認中 / 専門職確認待ち
  provisional, // §6 仮予約（スタッフが日程を仮に置いた）
  slotHeld, // 仮おさえ（システムが枠を確保している短時間の状態）
  confirmed, // 予約確定
  intakeDone, // 問診済み（確定後、問診票の提出が終わった）
  inService, // 利用中
  completed, // 利用完了（実施済み）
  billed, // 請求済み（自治体への実績報告・請求が終わった）
  cancelled, // キャンセル確定
  noShow, // 無断キャンセル
  notEligible, // 対象外（自治体事業の対象ではないと判明）
  handedOff, // 医療機関案内／継続支援への引継ぎ
}

extension BookingStateX on BookingState {
  String get code => switch (this) {
    BookingState.draft => 'DRAFT',
    BookingState.submitted => 'SUBMITTED',
    BookingState.requested => 'REQUESTED',
    BookingState.municipalCoordination => 'MUNICIPAL_COORDINATION',
    BookingState.needsReview => 'NEEDS_REVIEW',
    BookingState.provisional => 'PROVISIONAL',
    BookingState.slotHeld => 'SLOT_HELD',
    BookingState.confirmed => 'CONFIRMED',
    BookingState.intakeDone => 'INTAKE_DONE',
    BookingState.inService => 'IN_SERVICE',
    BookingState.completed => 'COMPLETED',
    BookingState.billed => 'BILLED',
    BookingState.cancelled => 'CANCELLED',
    BookingState.noShow => 'NO_SHOW',
    BookingState.notEligible => 'NOT_ELIGIBLE',
    BookingState.handedOff => 'HANDED_OFF',
  };

  String get label => switch (this) {
    BookingState.draft => '入力途中',
    BookingState.submitted => '申込受付',
    BookingState.requested => '利用希望受付',
    BookingState.municipalCoordination => '行政調整中',
    BookingState.needsReview => 'スタッフ確認中',
    BookingState.provisional => '仮予約',
    BookingState.slotHeld => '仮おさえ',
    BookingState.confirmed => '予約確定',
    BookingState.intakeDone => '問診済み',
    BookingState.inService => '利用中',
    BookingState.completed => '実施済み',
    BookingState.billed => '請求済み',
    BookingState.cancelled => 'キャンセル',
    BookingState.noShow => '無断キャンセル',
    BookingState.notEligible => '対象外',
    BookingState.handedOff => '引継ぎ',
  };

  Color get color => switch (this) {
    BookingState.draft => const Color(0xFFA89F9B),
    BookingState.submitted => const Color(0xFF7FA8D4),
    BookingState.requested => const Color(0xFF6E93C4),
    BookingState.municipalCoordination => const Color(0xFF5E7FB8),
    BookingState.needsReview => const Color(0xFFC98A1E),
    BookingState.provisional => const Color(0xFFB8891C),
    BookingState.slotHeld => const Color(0xFFA8871F),
    BookingState.confirmed => const Color(0xFF6FB57E),
    BookingState.intakeDone => const Color(0xFF5FA872),
    BookingState.inService => const Color(0xFF4F9E86),
    BookingState.completed => const Color(0xFFB68A73),
    BookingState.billed => const Color(0xFF8E7A6E),
    BookingState.cancelled => const Color(0xFFB9AFAB),
    BookingState.noShow => const Color(0xFFD2705E),
    BookingState.notEligible => const Color(0xFFC07A7A),
    BookingState.handedOff => const Color(0xFF9C86C4),
  };

  bool get isActive =>
      this == BookingState.slotHeld ||
      this == BookingState.provisional ||
      this == BookingState.confirmed ||
      this == BookingState.intakeDone ||
      this == BookingState.inService;

  /// 確定以降（スタッフとしては「入っている予約」として扱うもの）。
  bool get isConfirmedOrLater =>
      this == BookingState.confirmed ||
      this == BookingState.intakeDone ||
      this == BookingState.inService ||
      this == BookingState.completed ||
      this == BookingState.billed;

  /// 実施を待っている（スタッフが当日ケアを始められる）。
  bool get readyForService =>
      this == BookingState.confirmed || this == BookingState.intakeDone;

  /// スタッフの確認・行政の調整を待っている（確定前）。
  bool get isPendingStaff =>
      this == BookingState.requested ||
      this == BookingState.municipalCoordination ||
      this == BookingState.needsReview ||
      this == BookingState.provisional;

  /// §6 ご家族の画面に出す言葉。内部状態をそのまま見せない。
  ///
  /// 「予約希望受付」と「予約確定」を絶対に混同させないことが目的。
  /// SLOT_HELD のような社内用語はご家族には意味がないので出さない。
  String get familyLabel => switch (this) {
    BookingState.draft => '申込入力中',
    BookingState.submitted => 'お申し込み受付',
    BookingState.requested => '利用希望を受付',
    BookingState.municipalCoordination => '市と日程を調整中',
    BookingState.needsReview => 'スタッフ確認中',
    BookingState.provisional => '仮予約（確定前）',
    BookingState.slotHeld => 'お席をおさえています',
    BookingState.confirmed => '予約確定',
    BookingState.intakeDone => '予約確定（問診済み）',
    BookingState.inService => 'ご利用中',
    BookingState.completed => 'ご利用ありがとうございました',
    BookingState.billed => 'ご利用ありがとうございました',
    BookingState.cancelled => 'キャンセル済み',
    BookingState.noShow => 'ご来院がありませんでした',
    BookingState.notEligible => '自治体事業の対象外でした',
    BookingState.handedOff => '別のご支援をご案内しました',
  };

  /// §6/§47 ご家族向けの一言説明。確定前であることを必ず言い切る。
  String get familyHint => switch (this) {
    BookingState.requested => 'スタッフが利用条件と受入状況を確認しています。確定はまだです。',
    BookingState.municipalCoordination =>
      '市と施設が日程を調整しています。市からご連絡があります。確定はまだです。',
    BookingState.needsReview => 'ご入力の内容を確認しています。確定はまだです。',
    BookingState.provisional => '日程を仮におさえています。確定のご案内をお待ちください。',
    BookingState.confirmed => 'この日時で確定しています。当日までに問診票のご入力をお願いします。',
    BookingState.intakeDone => 'この日時で確定しています。問診も揃いました。当日お待ちしています。',
    BookingState.notEligible => '自費でのご利用や、別の支援をご案内できます。',
    BookingState.handedOff => '担当からご案内した内容をご確認ください。',
    _ => '',
  };

  /// §47 色だけに頼らないための記号（色覚特性・モノクロ環境でも判別可能）。
  IconData get familyIcon => switch (this) {
    BookingState.confirmed => Icons.check_circle_rounded,
    BookingState.intakeDone => Icons.assignment_turned_in_rounded,
    BookingState.requested => Icons.hourglass_top_rounded,
    BookingState.municipalCoordination => Icons.account_balance_rounded,
    BookingState.needsReview => Icons.pending_actions_rounded,
    BookingState.provisional => Icons.event_available_rounded,
    BookingState.slotHeld => Icons.lock_clock_rounded,
    BookingState.cancelled => Icons.cancel_rounded,
    BookingState.noShow => Icons.error_rounded,
    BookingState.completed => Icons.favorite_rounded,
    BookingState.billed => Icons.receipt_long_rounded,
    BookingState.inService => Icons.volunteer_activism_rounded,
    BookingState.notEligible => Icons.do_not_disturb_on_rounded,
    BookingState.handedOff => Icons.medical_services_rounded,
    _ => Icons.edit_note_rounded,
  };
}

/// §8.4 料金表示の三状態。見込を確定と誤認させない。
enum FeeState { estimate, underReview, confirmed }

extension FeeStateX on FeeState {
  String get label => switch (this) {
    FeeState.estimate => '見込',
    FeeState.underReview => '確認中',
    FeeState.confirmed => '確定',
  };
  Color get color => switch (this) {
    FeeState.estimate => const Color(0xFFA89F9B),
    FeeState.underReview => const Color(0xFFE0A83C),
    FeeState.confirmed => const Color(0xFF6FB57E),
  };
}

/// 例外理由コード（§11 / 付録C.7）
enum ReasonCode {
  redFlag, // E-01 健康上の赤旗
  eligibilityUnknown, // E-02 対象条件・自治体番号不明
  noSlot, // E-03 枠不足
  duplicateCustomer, // E-04 重複顧客
  lateCancel, // E-05 期限後キャンセル
  lineUndelivered, // E-06 LINE未達
  freeTextConsult, // E-07 自由文相談
  mealAllergy, // アレルギー・食事個別対応
  travelCondition, // 駐車・移動条件
  stayService, // 宿泊など通常ロジック外
  futureBookingLimit, // 予約数制限
  applicationMissing, // 自治体への利用申請が未完了（未申請／申請中）
  voucherUnverified, // 利用券・クーポン・決定通知の確認が未完了
  feeUndetermined, // 料金ルールに一致しない（概算を出せない）
  multipleBirth, // 多胎の受入条件（人員・月齢）の確認
  programNotEffective, // 自治体マスタの有効期間外／未確認
  facilityAcceptance, // 施設・スタッフの受入条件（月齢・エリア・同時受入）
}

extension ReasonCodeX on ReasonCode {
  String get code => switch (this) {
    ReasonCode.redFlag => 'E-01',
    ReasonCode.eligibilityUnknown => 'E-02',
    ReasonCode.noSlot => 'E-03',
    ReasonCode.duplicateCustomer => 'E-04',
    ReasonCode.lateCancel => 'E-05',
    ReasonCode.lineUndelivered => 'E-06',
    ReasonCode.freeTextConsult => 'E-07',
    ReasonCode.mealAllergy => 'X-11',
    ReasonCode.travelCondition => 'X-12',
    ReasonCode.stayService => 'X-13',
    ReasonCode.futureBookingLimit => 'X-14',
    ReasonCode.applicationMissing => 'M-01',
    ReasonCode.voucherUnverified => 'M-02',
    ReasonCode.feeUndetermined => 'M-03',
    ReasonCode.multipleBirth => 'M-04',
    ReasonCode.programNotEffective => 'M-05',
    ReasonCode.facilityAcceptance => 'M-06',
  };

  String get label => switch (this) {
    ReasonCode.redFlag => '健康上の確認が必要',
    ReasonCode.eligibilityUnknown => '対象条件が確認できない',
    ReasonCode.noSlot => '条件に合う枠がない',
    ReasonCode.duplicateCustomer => '顧客情報の重複候補',
    ReasonCode.lateCancel => '期限後キャンセルの料金確認',
    ReasonCode.lineUndelivered => 'LINE通知が未達',
    ReasonCode.freeTextConsult => '自由文での相談',
    ReasonCode.mealAllergy => '食事・アレルギーの個別対応',
    ReasonCode.travelCondition => '訪問・駐車条件の確認',
    ReasonCode.stayService => '宿泊サービスの調整',
    ReasonCode.futureBookingLimit => '未来予約ありのため要確認',
    ReasonCode.applicationMissing => '自治体への利用申請が未完了',
    ReasonCode.voucherUnverified => '利用券・クーポンの確認が必要',
    ReasonCode.feeUndetermined => '料金の概算が出せない',
    ReasonCode.multipleBirth => '多胎児の受入条件の確認',
    ReasonCode.programNotEffective => '自治体制度の有効期間・確認日の確認',
    ReasonCode.facilityAcceptance => '施設・スタッフの受入条件の確認',
  };

  /// 専門職（助産師）が判断すべきものか、事務（管理者）か。
  bool get toMidwife =>
      this == ReasonCode.redFlag ||
      this == ReasonCode.mealAllergy ||
      this == ReasonCode.multipleBirth;

  /// SLA（分）
  int get slaMinutes => switch (this) {
    ReasonCode.redFlag => 30,
    ReasonCode.lineUndelivered => 60,
    ReasonCode.freeTextConsult => 240,
    ReasonCode.lateCancel => 480,
    _ => 1440,
  };
}

// ---------------------------------------------------------------------------
// §12 Booking
// ---------------------------------------------------------------------------

class BookingException {
  final ReasonCode code;
  final String detail;
  final DateTime raisedAt;
  final DateTime dueAt;
  bool resolved;
  String? resolution;
  String? resolvedBy;
  DateTime? resolvedAt;

  BookingException({
    required this.code,
    required this.detail,
    required this.raisedAt,
    required this.dueAt,
    this.resolved = false,
    this.resolution,
    this.resolvedBy,
    this.resolvedAt,
  });

  bool get overdue => !resolved && DateTime.now().isAfter(dueAt);
}

class OpsBooking {
  final String id;
  final String code; // 予約番号
  final String customerId;
  final String childId;
  final String serviceId;
  DateTime at;
  int durationMin;
  String? facilityId;
  String? staffId;
  BookingState state;
  final ServiceKind kind;
  final DateTime createdAt;
  DateTime updatedAt;

  // 判定・自動化
  bool autoAssigned; // 自動割当で成立したか
  int manualTouches; // 人が触った回数（KPI）
  final List<BookingException> exceptions;
  final List<String> stateLog;

  // 料金
  int feeYen;
  FeeState feeState;
  int cancelFeeYen;
  FeeState cancelFeeState;

  // 同意・規約スナップショット
  ConsentSnapshot? consent;
  String? cancelPolicyId;
  int? cancelPolicyVersion;

  // 内容
  final Map<String, dynamic> intake;
  final List<String> needs;
  String? handoverNote; // 申し送り
  DateTime? holdExpiresAt; // 仮おさえ期限
  String? idempotencyKey;

  /// §21 この予約が「前回と同じ内容で予約」由来なら、元の予約ID。
  /// KPI（リピート予約の所要時間・割合）の集計に使う。
  String? repeatOfBookingId;

  /// §3 申込時点のサービスの予約方式を凍結して持つ。
  ///
  /// キャンセル規定の版を凍結するのと同じ理由。管理者が後から
  /// 「通所ケアを REQUEST_APPROVAL → INSTANT に変える」と、
  /// 過去の予約希望が遡って「即時確定だったはず」に見えてしまう。
  /// それは監査上も家族への説明上も誤りなので、申込時の方式を保存する。
  ///
  /// null は「まだ判定していない／旧データ」。読み出し側は
  /// `b.bookingMode ?? service.bookingMode` で解決する。
  BookingMode? bookingMode;

  // ---- 要件再定義：自治体制度とのつなぎ ----------------------------------

  /// 制度利用か自費か。自費切替はこの値を変えて履歴に残す。
  FundingType funding;

  /// 申込時点の自治体マスタの版（凍結）。後の改定で過去の予約を変えない。
  String? municipalityProgramId;
  int? municipalityProgramVersion;

  /// 概算の根拠（ご家族に「なぜこの金額か」を見せる）。
  String feeBasis;

  /// 何回目の利用として概算したか（瀬戸市の6回目判定など）。
  int? useIndex;

  /// スタッフが確認した書類（決定通知・利用券・クーポン）。
  bool voucherVerified;

  /// 医療機関案内／継続支援への引継ぎ。
  HandoffKind handoff;
  String? handoffNote;

  /// 自治体への実績報告・請求を行った日。
  DateTime? billedAt;

  OpsBooking({
    required this.id,
    required this.code,
    required this.customerId,
    required this.childId,
    required this.serviceId,
    required this.at,
    required this.durationMin,
    required this.kind,
    this.facilityId,
    this.staffId,
    this.state = BookingState.draft,
    required this.createdAt,
    required this.updatedAt,
    this.autoAssigned = false,
    this.manualTouches = 0,
    List<BookingException>? exceptions,
    List<String>? stateLog,
    this.feeYen = 0,
    this.feeState = FeeState.estimate,
    this.cancelFeeYen = 0,
    this.cancelFeeState = FeeState.estimate,
    this.consent,
    this.cancelPolicyId,
    this.cancelPolicyVersion,
    Map<String, dynamic>? intake,
    List<String>? needs,
    this.handoverNote,
    this.holdExpiresAt,
    this.idempotencyKey,
    this.repeatOfBookingId,
    this.bookingMode,
    this.funding = FundingType.municipal,
    this.municipalityProgramId,
    this.municipalityProgramVersion,
    this.feeBasis = '',
    this.useIndex,
    this.voucherVerified = false,
    this.handoff = HandoffKind.none,
    this.handoffNote,
    this.billedAt,
  }) : exceptions = exceptions ?? [],
       stateLog = stateLog ?? [],
       intake = intake ?? {},
       needs = needs ?? [];

  DateTime get endAt => at.add(Duration(minutes: durationMin));
  List<BookingException> get openExceptions =>
      exceptions.where((e) => !e.resolved).toList();
  bool get hasOpenException => openExceptions.isNotEmpty;
  bool get holdExpired =>
      holdExpiresAt != null && DateTime.now().isAfter(holdExpiresAt!);

  /// §21 リピート由来の予約か
  bool get isRepeat => repeatOfBookingId != null;

  bool get isSelfPay => funding == FundingType.selfPay;
}

// ---------------------------------------------------------------------------
// §21 リピーター最短導線（「前回と同じ内容で予約」の判定材料）
//
// 前回内容をそのまま引き継ぎ、「変わっているところだけ」を家族に確認させる。
// UI はこの2クラスを読むだけでよく、差分計算のロジックを持たない。
// ---------------------------------------------------------------------------

/// 前回と今回で「変わってしまった」1項目。
class RepeatChange {
  /// 変わった項目名（日時・プラン・利用条件・キャンセル規定 など）
  final String field;

  /// 何が変わったか（家族にそのまま見せる文章）
  final String detail;

  /// 家族に何をしてほしいか
  final String action;

  const RepeatChange({
    required this.field,
    required this.detail,
    required this.action,
  });
}

/// 前回内容の再利用計画。
class RepeatPlan {
  /// 元になった予約
  final OpsBooking source;
  final ServiceDef service;
  final OpsChild child;
  final String? facilityId;
  final List<String> needs;
  final Map<String, dynamic> intake;

  /// 提案する日時（候補が無ければ null）
  final DateTime? proposedAt;

  /// 前回と同じ曜日・時刻が取れたか
  final bool sameRhythm;

  /// 確認が必要な項目だけ
  final List<RepeatChange> changes;

  const RepeatPlan({
    required this.source,
    required this.service,
    required this.child,
    required this.facilityId,
    required this.needs,
    required this.intake,
    required this.proposedAt,
    required this.sameRhythm,
    required this.changes,
  });

  /// 確認項目ゼロ＝そのまま確定まで進める（§33 3〜5分の達成条件）
  bool get isClean => changes.isEmpty && proposedAt != null;

  /// 日時候補すら無い（＝リピート導線を出さない）
  bool get unavailable => proposedAt == null;
}

// ---------------------------------------------------------------------------
// §12 Notification（LINE配信 / §10.2）
// ---------------------------------------------------------------------------

enum NotifyEvent {
  applied, // 申込受付
  confirmed, // 予約確定
  preCheck, // 事前確認
  changeAccepted, // 変更受付
  changeConfirmed, // 変更確定
  cancelAccepted, // キャンセル受付
  cancelFee, // 料金確認
  dayOf, // 当日案内
  completed, // 利用完了
}

extension NotifyEventX on NotifyEvent {
  String get label => switch (this) {
    NotifyEvent.applied => '申込受付',
    NotifyEvent.confirmed => '予約確定',
    NotifyEvent.preCheck => '事前確認のお願い',
    NotifyEvent.changeAccepted => '変更受付',
    NotifyEvent.changeConfirmed => '変更確定',
    NotifyEvent.cancelAccepted => 'キャンセル受付',
    NotifyEvent.cancelFee => 'キャンセル料の確認',
    NotifyEvent.dayOf => '当日のご案内',
    NotifyEvent.completed => '利用完了',
  };
}

enum DeliveryStatus { queued, delivered, failed, retried, phoneTask }

extension DeliveryStatusX on DeliveryStatus {
  String get label => switch (this) {
    DeliveryStatus.queued => '送信待ち',
    DeliveryStatus.delivered => '送達',
    DeliveryStatus.failed => '未達',
    DeliveryStatus.retried => '再送',
    DeliveryStatus.phoneTask => '電話タスク',
  };
  Color get color => switch (this) {
    DeliveryStatus.delivered => const Color(0xFF6FB57E),
    DeliveryStatus.failed => const Color(0xFFD2705E),
    DeliveryStatus.phoneTask => const Color(0xFFE0A83C),
    _ => const Color(0xFFA89F9B),
  };
}

class OpsNotification {
  final String id;
  final String bookingId;
  final String customerId;
  final NotifyEvent event;
  final String title;
  final String body;
  final String channel; // Service Message / Push / アプリ内
  DeliveryStatus status;
  final DateTime createdAt;
  int retries;
  final bool inAppRetained; // 重要通知はアプリ内にも残す（C-13）

  OpsNotification({
    required this.id,
    required this.bookingId,
    required this.customerId,
    required this.event,
    required this.title,
    required this.body,
    this.channel = 'Service Message',
    this.status = DeliveryStatus.queued,
    required this.createdAt,
    this.retries = 0,
    this.inAppRetained = true,
  });
}

// ---------------------------------------------------------------------------
// §12 Task（役割別キュー）
// ---------------------------------------------------------------------------

enum TaskOwner { reception, midwife, siteAdmin }

extension TaskOwnerX on TaskOwner {
  String get label => switch (this) {
    TaskOwner.reception => '受付',
    TaskOwner.midwife => '助産師',
    TaskOwner.siteAdmin => '拠点管理者',
  };
}

class OpsTask {
  final String id;
  final String title;
  final String detail;
  final TaskOwner owner;
  final String? bookingId;
  final ReasonCode? reason;
  final DateTime createdAt;
  final DateTime dueAt;
  bool done;
  String? doneBy;
  DateTime? doneAt;
  final int priority; // 1=高

  OpsTask({
    required this.id,
    required this.title,
    required this.detail,
    required this.owner,
    this.bookingId,
    this.reason,
    required this.createdAt,
    required this.dueAt,
    this.done = false,
    this.doneBy,
    this.doneAt,
    this.priority = 2,
  });

  bool get overdue => !done && DateTime.now().isAfter(dueAt);
}

// ---------------------------------------------------------------------------
// §12 AuditLog（追記専用 / §14 NFR-04）
// ---------------------------------------------------------------------------

class AuditEntry {
  final String id;
  final DateTime at;
  final String actor; // 実行者
  final String role;
  final String action;
  final String target;
  final String detail;
  final bool sensitiveAccess; // 要配慮個人情報へのアクセス
  final String hashChain; // 改ざん検知用（簡易連鎖ハッシュ）

  const AuditEntry({
    required this.id,
    required this.at,
    required this.actor,
    required this.role,
    required this.action,
    required this.target,
    required this.detail,
    this.sensitiveAccess = false,
    required this.hashChain,
  });
}

// ---------------------------------------------------------------------------
// 待機リスト（E-03 / C.2 キャンセル待ち）
// ---------------------------------------------------------------------------

class WaitEntry {
  final String id;
  final String customerId;
  final String serviceId;
  final DateTime desiredFrom;
  final DateTime desiredTo;
  final List<int> weekdays;
  final DateTime createdAt;
  bool notified;
  WaitEntry({
    required this.id,
    required this.customerId,
    required this.serviceId,
    required this.desiredFrom,
    required this.desiredTo,
    required this.weekdays,
    required this.createdAt,
    this.notified = false,
  });
}

// ---------------------------------------------------------------------------
// 施設 / 部屋（A-07）
// ---------------------------------------------------------------------------

class OpsFacility {
  final String id;
  final String name;
  final String area;
  final int rooms;
  final int concurrentCapacity;
  final int mealCutoffHours; // 食事締切
  final String access;

  // ---- 要件再定義：施設・スタッフ受入マスタ ----------------------------
  //
  // 自治体上は利用可能でも、ママズケア側の人員・設備で受け入れられないことがある。

  /// この施設で対応できるサービス種別（空ならすべて）。
  final Set<ServiceKind> serviceKinds;

  /// 対応可能月齢（日）。自治体の上限とは別に、施設側の上限を持つ。
  final int maxChildAgeDays;

  /// 多胎児の受入可否と必要人数。
  final bool acceptsMultiples;
  final int multipleStaffRequired;

  /// 訪問可能地域（areaCode）。空ならスタッフのエリアに従う。
  final Set<String> visitAreas;

  /// 兄姉同伴・家族同伴・駐車場・送迎・持ち物・支払方法。
  final bool siblingAllowed;
  final bool familyAllowed;
  final int parkingSpaces;
  final bool pickupAvailable;
  final List<String> bringItems;
  final List<String> paymentMethods;

  /// オプション（自治体サービスとは区分して自費で案内するもの）。
  final List<String> paidOptions;

  const OpsFacility({
    required this.id,
    required this.name,
    required this.area,
    required this.rooms,
    required this.concurrentCapacity,
    this.mealCutoffHours = 48,
    this.access = '',
    this.serviceKinds = const {},
    this.maxChildAgeDays = 365,
    this.acceptsMultiples = true,
    this.multipleStaffRequired = 2,
    this.visitAreas = const {},
    this.siblingAllowed = false,
    this.familyAllowed = true,
    this.parkingSpaces = 0,
    this.pickupAvailable = false,
    this.bringItems = const [],
    this.paymentMethods = const [],
    this.paidOptions = const [],
  });

  bool supports(ServiceKind k) =>
      serviceKinds.isEmpty || serviceKinds.contains(k);

  /// §24 管理者による改定。
  OpsFacility copyWith({
    String? name,
    String? area,
    int? rooms,
    int? concurrentCapacity,
    int? mealCutoffHours,
    String? access,
    Set<ServiceKind>? serviceKinds,
    int? maxChildAgeDays,
    bool? acceptsMultiples,
    int? multipleStaffRequired,
    Set<String>? visitAreas,
    bool? siblingAllowed,
    bool? familyAllowed,
    int? parkingSpaces,
    bool? pickupAvailable,
    List<String>? bringItems,
    List<String>? paymentMethods,
    List<String>? paidOptions,
  }) => OpsFacility(
    id: id,
    name: name ?? this.name,
    area: area ?? this.area,
    rooms: rooms ?? this.rooms,
    concurrentCapacity: concurrentCapacity ?? this.concurrentCapacity,
    mealCutoffHours: mealCutoffHours ?? this.mealCutoffHours,
    access: access ?? this.access,
    serviceKinds: serviceKinds ?? this.serviceKinds,
    maxChildAgeDays: maxChildAgeDays ?? this.maxChildAgeDays,
    acceptsMultiples: acceptsMultiples ?? this.acceptsMultiples,
    multipleStaffRequired: multipleStaffRequired ?? this.multipleStaffRequired,
    visitAreas: visitAreas ?? this.visitAreas,
    siblingAllowed: siblingAllowed ?? this.siblingAllowed,
    familyAllowed: familyAllowed ?? this.familyAllowed,
    parkingSpaces: parkingSpaces ?? this.parkingSpaces,
    pickupAvailable: pickupAvailable ?? this.pickupAvailable,
    bringItems: bringItems ?? this.bringItems,
    paymentMethods: paymentMethods ?? this.paymentMethods,
    paidOptions: paidOptions ?? this.paidOptions,
  );
}

// ---------------------------------------------------------------------------
// §15 / §16 Resource（部屋・ベッド・座席・定員）
//
// STORESでは「スタッフ」に人・施設枠・サービス枠が混在していた。
// MAMOAでは Midwife（人）と Resource（設備）を明確に分離する。
// これにより「助産師は空いているが部屋が無い」を正しく判定できる。
// ---------------------------------------------------------------------------

enum ResourceKind { room, bed, seat, bath, parking }

extension ResourceKindX on ResourceKind {
  String get label => switch (this) {
    ResourceKind.room => '個室',
    ResourceKind.bed => 'ベッド',
    ResourceKind.seat => '座席',
    ResourceKind.bath => '沐浴設備',
    ResourceKind.parking => '駐車スペース',
  };

  /// 宿泊で必ず確保が必要な種類か（付録C.7）
  bool get stayCritical =>
      this == ResourceKind.room || this == ResourceKind.bed;
}

/// 予約時に排他確保される物理リソース。
/// capacity は「同時に何人受け入れられるか」（相部屋・多胎対応）。
class OpsResource {
  final String id;
  final String facilityId;
  final String name;
  final ResourceKind kind;
  final int capacity;

  /// このリソースが対応できるサービス種別（空なら制限なし）
  final Set<ServiceKind> serviceKinds;

  /// 宿泊可否（部屋でも日中利用のみの場合がある）
  final bool overnightCapable;
  final bool active;

  const OpsResource({
    required this.id,
    required this.facilityId,
    required this.name,
    required this.kind,
    this.capacity = 1,
    this.serviceKinds = const {},
    this.overnightCapable = false,
    this.active = true,
  });

  bool supports(ServiceKind k) =>
      serviceKinds.isEmpty || serviceKinds.contains(k);

  OpsResource copyWith({
    String? name,
    int? capacity,
    bool? overnightCapable,
    bool? active,
  }) => OpsResource(
    id: id,
    facilityId: facilityId,
    name: name ?? this.name,
    kind: kind,
    capacity: capacity ?? this.capacity,
    serviceKinds: serviceKinds,
    overnightCapable: overnightCapable ?? this.overnightCapable,
    active: active ?? this.active,
  );
}

/// 予約 ⇄ リソースの割当（§16 BookingResource）。
/// 二重予約防止の排他単位はこの行であり、施設単位の粗い定員ではない。
class BookingResource {
  final String id;
  final String bookingId;
  final String resourceId;
  final DateTime from;
  final DateTime to;

  const BookingResource({
    required this.id,
    required this.bookingId,
    required this.resourceId,
    required this.from,
    required this.to,
  });

  bool overlapsWith(DateTime s, DateTime e) =>
      from.isBefore(e) && s.isBefore(to);
}

// ---------------------------------------------------------------------------
// §11 / §24 Skill マスタ
//
// スキルをコードに固定せず、管理画面から追加・改廃できるようにする。
// ---------------------------------------------------------------------------

class SkillDef {
  final String id; // 例: 'breast'
  final String name; // 例: '母乳ケア'
  final String description;

  /// 有資格者のみ（管理者が付与を制限すべきスキル）
  final bool certificationRequired;
  final bool active;

  const SkillDef({
    required this.id,
    required this.name,
    this.description = '',
    this.certificationRequired = false,
    this.active = true,
  });

  SkillDef copyWith({
    String? name,
    String? description,
    bool? certificationRequired,
    bool? active,
  }) => SkillDef(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    certificationRequired: certificationRequired ?? this.certificationRequired,
    active: active ?? this.active,
  );
}

/// Midwife ⇄ Skill の関連（§16 MidwifeSkill）。
/// 習熟度・認定日を保持でき、将来の割当優先度に使える。
class MidwifeSkill {
  final String staffId;
  final String skillId;
  final int level; // 1..3
  final DateTime? certifiedOn;

  const MidwifeSkill({
    required this.staffId,
    required this.skillId,
    this.level = 1,
    this.certifiedOn,
  });
}

// ---------------------------------------------------------------------------
// §16 Municipality（自治体そのもの）
//
// 既存の MunicipalityProgram は「事業要件（版管理）」。
// 自治体エンティティを分離し、1自治体が複数の事業を持てるようにする。
// ---------------------------------------------------------------------------

class Municipality {
  final String id;
  final String name; // 例: '西宮市'
  final String prefecture;

  /// この自治体が実施している事業要件（MunicipalityProgram.id）
  final List<String> programIds;
  final bool active;

  const Municipality({
    required this.id,
    required this.name,
    required this.prefecture,
    this.programIds = const [],
    this.active = true,
  });

  Municipality copyWith({
    String? name,
    List<String>? programIds,
    bool? active,
  }) => Municipality(
    id: id,
    name: name ?? this.name,
    prefecture: prefecture,
    programIds: programIds ?? this.programIds,
    active: active ?? this.active,
  );
}
