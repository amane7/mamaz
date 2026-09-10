import '../ops_models.dart';

// ---------------------------------------------------------------------------
// §12 条件①〜⑤ 利用条件ルール（Pure Function）
//
// 家族側の「使えるか / 使えないか」を、State や UI から切り離して判定する。
// 判定結果は必ず ReasonCode に落とし、例外キューへそのまま流せる形にする。
// ---------------------------------------------------------------------------

/// 利用条件の判定材料。State から詰め替えるだけの入れ物。
class EligibilityContext {
  final ServiceDef service;
  final OpsChild child;
  final DateTime at;

  /// 自治体の事業要件（版付き）
  final MunicipalityProgram program;

  /// 自治体マスタ（分離済み）。未登録なら null で従来動作。
  final Municipality? municipality;

  final bool hasProgramNumber;
  final int usedCount;

  /// 現在有効な「これからのご予約」の件数（§12 予約数制限）。
  /// 上限そのものは program.maxConcurrentBookings が持つ。
  /// 1件でも先の予約があれば要確認、という運用にはしない
  /// （リピーターが毎回止まってしまい §21・§33 に反する）。
  final int futureBookingCount;

  // ---- 要件再定義：自治体制度・施設受入 -----------------------------------

  /// 自治体への利用申請の状態（未申請／申請中／承認済み／対象外）。
  final ApplicationStatus application;

  /// 利用券・クーポン・決定通知を確認済みか。
  final bool voucherVerified;

  /// 制度利用か自費か。自費なら自治体条件は見ない。
  final FundingType funding;

  /// 利用施設の受入条件（訪問は null でよい）。
  final OpsFacility? facility;

  /// 他施設での利用回数（回数上限の合算に使う自治体がある）。
  final int otherFacilityUses;

  const EligibilityContext({
    required this.service,
    required this.child,
    required this.at,
    required this.program,
    this.municipality,
    this.hasProgramNumber = true,
    this.usedCount = 0,
    this.futureBookingCount = 0,
    this.application = ApplicationStatus.approved,
    this.voucherVerified = true,
    this.funding = FundingType.municipal,
    this.facility,
    this.otherFacilityUses = 0,
  });

  bool get isSelfPay => funding == FundingType.selfPay;

  /// 回数上限の比較に使う利用回数（他施設分を含める自治体なら合算）。
  int get countedUses =>
      program.countsOtherFacilities ? usedCount + otherFacilityUses : usedCount;
}

/// 事業番号が必要なのに未提出。
bool programNumberMissing(EligibilityContext c) =>
    c.program.requiresProgramNumber && !c.hasProgramNumber;

/// 利用回数の上限超過。
bool useCountExceeded(EligibilityContext c) =>
    c.countedUses >= c.program.maxUseCount;

/// 残り利用可能回数（家族向け表示に使う。負値にはしない）。
int remainingUses(EligibilityContext c) {
  final left = c.program.maxUseCount - c.countedUses;
  return left < 0 ? 0 : left;
}

/// 自治体側の対象月齢上限（サービス別・単胎／多胎別があればそれを使う）。
int programMaxAgeDays(EligibilityContext c) {
  final type = c.service.kind.programType;
  if (type != null) {
    final e = c.program.eligibilityFor(type);
    if (e != null) return e.maxAgeDaysFor(c.child.plurality);
  }
  return c.program.maxChildAgeDays;
}

/// 月齢（日齢）が、サービス条件・自治体条件のどちらかを超えている。
bool childAgeOutOfRange(EligibilityContext c) {
  final ageDays = c.child.ageDaysAt(c.at);
  final munMax = c.isSelfPay ? 1 << 30 : programMaxAgeDays(c);
  return ageDays > c.service.maxChildAgeDays ||
      ageDays > munMax ||
      ageDays < c.service.minChildAgeDays;
}

/// 自治体への利用申請が承認されていない（承認が要る自治体・制度利用のみ）。
bool applicationNotApproved(EligibilityContext c) {
  if (c.isSelfPay) return false;
  if (!c.program.requiresApproval) return false;
  return !c.application.canRequest;
}

/// 利用券・クーポン・決定通知の確認が未完了。
bool voucherNotVerified(EligibilityContext c) {
  if (c.isSelfPay) return false;
  final needs =
      c.program.requiresVoucher ||
      c.program.requiresCoupon ||
      c.program.requiresDecisionNotice;
  return needs && !c.voucherVerified;
}

/// 自治体マスタの版が利用日に有効でない。
bool programNotEffective(EligibilityContext c) =>
    !c.isSelfPay && !c.program.isEffectiveAt(c.at);

/// 自治体がそのサービス類型を実施していない。
bool serviceNotOffered(EligibilityContext c) {
  if (c.isSelfPay) return false;
  final type = c.service.kind.programType;
  if (type == null) return false; // 母乳外来は制度外＝別扱い
  return !c.program.offeredServices.contains(type);
}

/// 施設・スタッフ側の受入条件を満たさない。
bool facilityCannotAccept(EligibilityContext c) {
  final f = c.facility;
  if (f == null) return false;
  if (!f.supports(c.service.kind)) return true;
  if (c.child.ageDaysAt(c.at) > f.maxChildAgeDays) return true;
  if (c.child.plurality > 1 && !f.acceptsMultiples) return true;
  return false;
}

/// 多胎児で、月齢条件または受入条件の人による確認が要る。
bool multipleBirthNeedsReview(EligibilityContext c) =>
    c.child.plurality > 1 &&
    (c.program.multipleBirthNote.isNotEmpty ||
        (c.facility?.multipleStaffRequired ?? 1) > 1);

/// 同時に持てる予約件数の上限に達している（0 = 制限なし）。
bool concurrentBookingLimitReached(EligibilityContext c) {
  final max = c.program.maxConcurrentBookings;
  if (max <= 0) return false;
  return c.futureBookingCount >= max;
}

/// その自治体がこの事業を実施しているか（自治体マスタ未登録なら true）。
bool municipalityOffersProgram(EligibilityContext c) {
  final m = c.municipality;
  if (m == null) return true;
  if (!m.active) return false;
  if (m.programIds.isEmpty) return true;
  return m.programIds.contains(c.program.id);
}

/// §12 条件①〜⑤の総合判定。空リスト＝自動処理可。
List<ReasonCode> evaluateEligibility(EligibilityContext c) {
  final out = <ReasonCode>[];
  // 自費は自治体条件を見ない（施設受入・予約数だけ）。
  if (!c.isSelfPay) {
    if (programNotEffective(c)) out.add(ReasonCode.programNotEffective);
    if (applicationNotApproved(c)) out.add(ReasonCode.applicationMissing);
    if (voucherNotVerified(c)) out.add(ReasonCode.voucherUnverified);
    if (programNumberMissing(c)) out.add(ReasonCode.eligibilityUnknown);
    if (useCountExceeded(c)) out.add(ReasonCode.eligibilityUnknown);
    if (childAgeOutOfRange(c)) out.add(ReasonCode.eligibilityUnknown);
    if (serviceNotOffered(c)) out.add(ReasonCode.eligibilityUnknown);
    if (!municipalityOffersProgram(c)) out.add(ReasonCode.eligibilityUnknown);
  } else if (childAgeOutOfRange(c)) {
    // 自費でもサービス自体の月齢条件は守る。
    out.add(ReasonCode.eligibilityUnknown);
  }
  if (facilityCannotAccept(c)) out.add(ReasonCode.facilityAcceptance);
  if (multipleBirthNeedsReview(c)) out.add(ReasonCode.multipleBirth);
  if (concurrentBookingLimitReached(c)) {
    out.add(ReasonCode.futureBookingLimit);
  }
  return <ReasonCode>{...out}.toList();
}

/// 「対象外」と言い切れる（人が見ても結論が変わらない）か。
///
/// 制度外への切替を案内するための判定。申請中・未確認は対象外ではない。
bool clearlyNotEligible(EligibilityContext c) {
  if (c.isSelfPay) return false;
  if (c.application == ApplicationStatus.notEligible) return true;
  if (useCountExceeded(c)) return true;
  // 月齢超過は決定的（自治体の対象月齢を超えたら戻らない）
  if (c.child.ageDaysAt(c.at) > programMaxAgeDays(c)) return true;
  if (serviceNotOffered(c)) return true;
  if (!municipalityOffersProgram(c)) return true;
  return false;
}

/// 家族に見せる説明文。理由を「言い換えない」ことが信頼につながる。
String eligibilityMessage(EligibilityContext c) {
  if (c.isSelfPay) {
    if (childAgeOutOfRange(c)) return 'お子さまの月齢が、このケアの対象範囲外です。';
    if (facilityCannotAccept(c)) return 'この院では受け入れ条件に合いません。別の院をご案内します。';
    return '自費でのご利用です。';
  }
  if (programNotEffective(c)) {
    return '${c.program.name}の制度情報が利用日に有効か確認中です。スタッフが確認します。';
  }
  if (c.application == ApplicationStatus.notEligible) {
    return '${c.program.name}の産後ケア事業の対象外です。自費でのご利用をご案内できます。';
  }
  if (applicationNotApproved(c)) {
    return c.application == ApplicationStatus.applied
        ? '${c.program.name}への申請は受付済みです。決定通知が届いてからご利用希望を送れます。'
        : '${c.program.name}への利用申請がまだです。まず申請をお願いします。';
  }
  if (voucherNotVerified(c)) {
    return '利用券・クーポン・決定通知の確認が必要です。スタッフが確認します。';
  }
  if (programNumberMissing(c)) return '自治体の利用券番号の確認が必要です。';
  if (useCountExceeded(c)) {
    return 'この事業の利用上限（${c.program.maxUseCount}回）に達しています。'
        '自費でのご利用をご案内できます。';
  }
  if (childAgeOutOfRange(c)) return 'お子さまの月齢が、この事業の対象範囲外です。';
  if (serviceNotOffered(c)) return '${c.program.name}では、この種類のケアは事業の対象外です。';
  if (!municipalityOffersProgram(c)) return 'お住まいの自治体では、この事業を実施していません。';
  if (facilityCannotAccept(c)) return 'この院では受け入れ条件に合いません。別の院をご案内します。';
  if (multipleBirthNeedsReview(c)) {
    return 'ふたご・みつごのお子さまは、担当人数と月齢をスタッフが確認します。';
  }
  if (concurrentBookingLimitReached(c)) {
    return 'これからのご予約が${c.program.maxConcurrentBookings}件そろっています。'
        '担当者が確認しますので、少しお待ちください。';
  }
  return 'ご利用いただけます。';
}
