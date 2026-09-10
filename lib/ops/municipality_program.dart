// ============================================================================
// 自治体制度マスタ（要件再定義 2026-09）
//
// MAMOA は「自治体別の利用判定・行政申請案内・利用希望受付・日程調整・
// 問診・実績管理」をつなぐ一次受付基盤。STORES は最終的な予約・決済手段
// として残し、その手前を MAMOA が担う。
//
// このファイルは Pure Dart（Flutter を import しない）。
// 料金・対象条件をコードに直接書かず、有効期間付きルールとして
// 管理画面から更新できる設計にするための「型」だけを置く。
// ============================================================================

/// 自治体事業のサービス類型（産後ケア事業の3類型）。
///
/// アプリ内の ServiceKind（訪問／通所／宿泊／母乳外来）とは分けて持つ。
/// 母乳外来は自治体事業の類型に含まれない＝原則自費。
enum ProgramServiceType { dayCare, outreach, stay }

extension ProgramServiceTypeX on ProgramServiceType {
  String get label => switch (this) {
    ProgramServiceType.dayCare => '通所（デイケア）',
    ProgramServiceType.outreach => '訪問（アウトリーチ）',
    ProgramServiceType.stay => '宿泊',
  };

  String get code => switch (this) {
    ProgramServiceType.dayCare => 'DAY',
    ProgramServiceType.outreach => 'OUTREACH',
    ProgramServiceType.stay => 'STAY',
  };
}

/// 予約・日程調整の主体（自治体によって異なる）。
///
/// * municipality … 市と施設が日程調整し、市から利用者へ連絡（瀬戸市・小牧市）
/// * provider     … 利用者が事業所へ直接予約（名古屋市）
/// * shared       … 市または事業者から日程連絡（長久手市）
enum SchedulingAuthority { municipality, provider, shared }

extension SchedulingAuthorityX on SchedulingAuthority {
  String get label => switch (this) {
    SchedulingAuthority.municipality => '行政調整型',
    SchedulingAuthority.provider => '事業所調整型',
    SchedulingAuthority.shared => '市・事業者どちらか',
  };

  String get description => switch (this) {
    SchedulingAuthority.municipality =>
      '市と施設が日程を調整し、市から利用者へ連絡します。MAMOA では予約を確定せず「利用希望」として受け付けます。',
    SchedulingAuthority.provider =>
      '承認後、利用者が事業所へ直接予約します。MAMOA で仮予約を受け、スタッフ確認後に確定します。',
    SchedulingAuthority.shared =>
      '承認後、市または事業者から日程の連絡があります。クーポンの有無を確認してから仮予約を受けます。',
  };

  /// 行政側の調整を待つ必要があるか（利用希望受付 → 行政調整中）。
  bool get waitsForMunicipality => this == SchedulingAuthority.municipality;
}

/// 自治体への利用申請の進み具合（ご家族ごと）。
enum ApplicationStatus { notApplied, applied, approved, notEligible }

extension ApplicationStatusX on ApplicationStatus {
  String get label => switch (this) {
    ApplicationStatus.notApplied => '未申請',
    ApplicationStatus.applied => '申請中',
    ApplicationStatus.approved => '承認済み',
    ApplicationStatus.notEligible => '対象外',
  };

  String get familyHint => switch (this) {
    ApplicationStatus.notApplied => 'まず自治体へ利用申請が必要です。申請方法と必要なものをご案内します。',
    ApplicationStatus.applied => '自治体の決定通知・利用券が届くまでお待ちください。届いたらここで登録できます。',
    ApplicationStatus.approved => '自治体の承認を確認しました。ご利用希望を送れます。',
    ApplicationStatus.notEligible => '自治体事業の対象外です。自費でのご利用や、別の支援をご案内します。',
  };

  bool get canRequest => this == ApplicationStatus.approved;
}

/// 課税区分（料金の分岐に使う）。
enum TaxClass { taxable, exempt, welfare }

extension TaxClassX on TaxClass {
  String get label => switch (this) {
    TaxClass.taxable => '課税世帯',
    TaxClass.exempt => '市民税非課税世帯',
    TaxClass.welfare => '生活保護世帯',
  };
}

/// 予約の費用区分。制度利用か自費か。
enum FundingType { municipal, selfPay }

extension FundingTypeX on FundingType {
  String get label => switch (this) {
    FundingType.municipal => '自治体事業',
    FundingType.selfPay => '自費',
  };
}

/// 予約の行き先が「ケア」ではなくなったときの引継ぎ先。
enum HandoffKind { none, medicalReferral, continuedSupport }

extension HandoffKindX on HandoffKind {
  String get label => switch (this) {
    HandoffKind.none => 'なし',
    HandoffKind.medicalReferral => '医療機関受診をご案内',
    HandoffKind.continuedSupport => '継続支援へ引継ぎ',
  };
}

/// ご家族の「自治体への申請」の状態と、確認した書類。
class MunicipalApplication {
  final ApplicationStatus status;
  final String? voucherNumber; // 利用券・決定通知の番号
  final DateTime? appliedAt;
  final DateTime? approvedAt;
  final bool decisionNoticeChecked; // 決定通知を確認済み
  final bool voucherChecked; // 利用券を確認済み
  final int couponsLeft; // クーポン残枚数（長久手市など）
  final TaxClass taxClass;
  final int otherFacilityUses; // 他施設での利用回数（瀬戸市の6回目判定など）

  const MunicipalApplication({
    this.status = ApplicationStatus.notApplied,
    this.voucherNumber,
    this.appliedAt,
    this.approvedAt,
    this.decisionNoticeChecked = false,
    this.voucherChecked = false,
    this.couponsLeft = 0,
    this.taxClass = TaxClass.taxable,
    this.otherFacilityUses = 0,
  });

  bool get hasVoucher => voucherNumber != null && voucherNumber!.isNotEmpty;

  MunicipalApplication copyWith({
    ApplicationStatus? status,
    String? voucherNumber,
    DateTime? appliedAt,
    DateTime? approvedAt,
    bool? decisionNoticeChecked,
    bool? voucherChecked,
    int? couponsLeft,
    TaxClass? taxClass,
    int? otherFacilityUses,
  }) => MunicipalApplication(
    status: status ?? this.status,
    voucherNumber: voucherNumber ?? this.voucherNumber,
    appliedAt: appliedAt ?? this.appliedAt,
    approvedAt: approvedAt ?? this.approvedAt,
    decisionNoticeChecked: decisionNoticeChecked ?? this.decisionNoticeChecked,
    voucherChecked: voucherChecked ?? this.voucherChecked,
    couponsLeft: couponsLeft ?? this.couponsLeft,
    taxClass: taxClass ?? this.taxClass,
    otherFacilityUses: otherFacilityUses ?? this.otherFacilityUses,
  );
}

/// サービス類型ごとの対象月齢（単胎／多胎で異なる自治体がある）。
class ServiceEligibility {
  final ProgramServiceType service;
  final int minAgeDays;
  final int maxAgeDaysSingle; // 単胎
  final int? maxAgeDaysMultiple; // 多胎（null なら単胎と同じ）
  final String note;

  const ServiceEligibility({
    required this.service,
    this.minAgeDays = 0,
    required this.maxAgeDaysSingle,
    this.maxAgeDaysMultiple,
    this.note = '',
  });

  int maxAgeDaysFor(int plurality) => plurality > 1
      ? (maxAgeDaysMultiple ?? maxAgeDaysSingle)
      : maxAgeDaysSingle;
}

/// 料金ルール（1行＝1条件）。上から順に最初に一致した行を使う。
///
/// null の条件は「どれでも」。行が一致しなければ概算は出せず、
/// スタッフ確認へ回す（勝手に 0 円や定価を出さない）。
class FeeRule {
  final ProgramServiceType service;
  final TaxClass? taxClass;
  final bool? couponUsed;
  final int fromUse; // 何回目から（1始まり）
  final int? toUse; // 何回目まで（null なら上限なし）
  final int? plurality; // null=どれでも、2=双子、3=三つ子
  final int yen;
  final String label;

  const FeeRule({
    required this.service,
    required this.yen,
    this.taxClass,
    this.couponUsed,
    this.fromUse = 1,
    this.toUse,
    this.plurality,
    this.label = '',
  });

  bool matches({
    required ProgramServiceType service,
    required TaxClass taxClass,
    required bool couponUsed,
    required int useIndex,
    required int plurality,
  }) {
    if (this.service != service) return false;
    if (this.taxClass != null && this.taxClass != taxClass) return false;
    if (this.couponUsed != null && this.couponUsed != couponUsed) return false;
    if (useIndex < fromUse) return false;
    if (toUse != null && useIndex > toUse!) return false;
    if (this.plurality != null && this.plurality != plurality) return false;
    return true;
  }

  FeeRule copyWith({int? yen}) => FeeRule(
    service: service,
    yen: yen ?? this.yen,
    taxClass: taxClass,
    couponUsed: couponUsed,
    fromUse: fromUse,
    toUse: toUse,
    plurality: plurality,
    label: label,
  );

  String get conditionLabel {
    final parts = <String>[];
    if (taxClass != null) parts.add(taxClass!.label);
    if (couponUsed == true) parts.add('クーポン利用');
    if (couponUsed == false) parts.add('クーポン未利用');
    if (toUse != null) {
      parts.add(fromUse == toUse ? '$fromUse回目' : '$fromUse〜$toUse回目');
    } else if (fromUse > 1) {
      parts.add('$fromUse回目以降');
    }
    if (plurality == 2) parts.add('双子');
    if (plurality == 3) parts.add('三つ子');
    return parts.isEmpty ? '基本' : parts.join('・');
  }
}

/// 自治体側のキャンセル規定（事業所規定とは別に持つ）。
class MunicipalCancelRule {
  /// 前日の何時以降が有料か（null なら未確認）
  final int? deadlineHourDayBefore;
  final int feeYen;
  final bool verified;
  final String note;

  const MunicipalCancelRule({
    this.deadlineHourDayBefore,
    this.feeYen = 0,
    this.verified = false,
    this.note = '',
  });

  String get label => !verified
      ? '未確認（自治体へ確認中）'
      : deadlineHourDayBefore == null
      ? (feeYen == 0 ? 'キャンセル料なし' : '¥$feeYen')
      : '前日$deadlineHourDayBefore時以降 ¥$feeYen';

  MunicipalCancelRule copyWith({
    int? deadlineHourDayBefore,
    int? feeYen,
    bool? verified,
    String? note,
  }) => MunicipalCancelRule(
    deadlineHourDayBefore: deadlineHourDayBefore ?? this.deadlineHourDayBefore,
    feeYen: feeYen ?? this.feeYen,
    verified: verified ?? this.verified,
    note: note ?? this.note,
  );
}

/// 「現時点で残っている要確認事項」「次回確認すべきこと」を
/// コードやメモではなくデータとして持ち、管理画面で消し込む。
class OpenIssue {
  final String id;
  final String? municipalityId; // null なら全体
  final String title;
  final String detail;
  final String owner; // 誰が確認するか
  bool resolved;
  String? resolution;
  DateTime? resolvedAt;

  OpenIssue({
    required this.id,
    this.municipalityId,
    required this.title,
    required this.detail,
    this.owner = '運営',
    this.resolved = false,
    this.resolution,
    this.resolvedAt,
  });
}

/// 自治体ごとに変わるボタン文言（要件：画面上のボタンも自治体によって変える）。
///
///  * 未申請           → 「自治体へ利用申請する」
///  * 行政調整型       → 「利用希望を送る」
///  * 事業所調整型     → 「仮予約を申し込む」
///  * 即時確定サービス → 「この日時で予約する」
///  * 自費             → 「この内容で申し込む」
String familyCtaFor({
  required ApplicationStatus application,
  required SchedulingAuthority scheduling,
  required bool instant,
  required bool selfPay,
  required bool requiresApproval,
}) {
  if (selfPay) return instant ? 'この日時で予約する' : 'この内容で申し込む';
  if (requiresApproval && !application.canRequest) return '自治体へ利用申請する';
  if (instant) return 'この日時で予約する';
  return switch (scheduling) {
    SchedulingAuthority.municipality => '利用希望を送る',
    SchedulingAuthority.provider => '仮予約を申し込む',
    SchedulingAuthority.shared => '仮予約を申し込む',
  };
}
