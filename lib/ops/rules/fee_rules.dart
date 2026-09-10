// ============================================================================
// 料金計算要件（要件再定義 §4）— Pure Function
//
// 料金表示に必要な入力：
//   自治体／サービス／利用日／出産日・児の月齢／これまでの利用回数／
//   他施設での利用回数／課税・非課税区分／クーポン利用有無／子どもの人数／
//   キャンセル日時
//
// MAMOA の表示は原則「概算」。最終金額は利用券・自治体決定・
// スタッフ確認後に確定させる。ここでは決して「確定」を返さない。
// ============================================================================

import '../ops_models.dart';

/// 料金計算の材料。State から詰め替えるだけの入れ物。
class FeeContext {
  final MunicipalityProgram program;
  final ServiceDef service;
  final OpsChild child;
  final DateTime at;
  final FundingType funding;

  /// 何回目の利用か（当施設＋他施設）。1始まり。
  final int useIndex;
  final TaxClass taxClass;
  final bool couponUsed;

  const FeeContext({
    required this.program,
    required this.service,
    required this.child,
    required this.at,
    required this.useIndex,
    this.funding = FundingType.municipal,
    this.taxClass = TaxClass.taxable,
    this.couponUsed = false,
  });
}

/// 概算結果。金額が出せないときは [yen] が null で [reason] に理由。
class FeeEstimate {
  final int? yen;
  final String basis; // ご家族に見せる根拠
  final ReasonCode? reason; // 出せない理由（スタッフ確認へ）
  final bool isSelfPay;

  const FeeEstimate({
    required this.yen,
    required this.basis,
    this.reason,
    this.isSelfPay = false,
  });

  bool get determined => yen != null;
}

/// 概算を出す。順序：
///  1. 自費 → サービス定価
///  2. 自治体事業の類型に無いサービス（母乳外来）→ 自費として定価
///  3. 料金ルールに一致 → その金額
///  4. ルール未定義で助成額方式 → 定価 − 助成
///  5. どれにも当たらない → 概算不能（M-03）
FeeEstimate estimateFee(FeeContext c) {
  final price = c.service.priceYen;
  final type = c.service.kind.programType;

  if (c.funding == FundingType.selfPay) {
    return FeeEstimate(
      yen: price,
      basis: '自費でのご利用（${c.service.name} 定価）',
      isSelfPay: true,
    );
  }

  if (type == null) {
    return FeeEstimate(
      yen: price,
      basis: '${c.service.name}は自治体事業の対象外のため自費です',
      isSelfPay: true,
    );
  }

  if (c.program.feeRules.isNotEmpty) {
    final rule = c.program.feeRuleFor(
      service: type,
      taxClass: c.taxClass,
      couponUsed: c.couponUsed,
      useIndex: c.useIndex,
      plurality: c.child.plurality,
    );
    if (rule == null) {
      return const FeeEstimate(
        yen: null,
        basis: 'この条件に当たる料金の取り決めが見つかりません。スタッフが確認します。',
        reason: ReasonCode.feeUndetermined,
      );
    }
    final cond = rule.conditionLabel;
    return FeeEstimate(
      yen: rule.yen,
      basis:
          '${c.program.name}の${type.label}・${c.useIndex}回目'
          '${cond == '基本' ? '' : '・$cond'}',
    );
  }

  // 旧方式（助成額を定価から引く）。
  final net = (price - c.program.subsidyYen).clamp(0, 999999);
  return FeeEstimate(
    yen: net,
    basis:
        '${c.service.name} $price円 − ${c.program.name}の助成 ${c.program.subsidyYen}円',
  );
}

/// 自治体側のキャンセル料（事業所規定とは別）。未確認なら null。
int? municipalCancelFee({
  required MunicipalityProgram program,
  required DateTime bookingAt,
  required DateTime cancelAt,
}) {
  final r = program.cancelRule;
  if (!r.verified) return null;
  final h = r.deadlineHourDayBefore;
  if (h == null) return r.feeYen;
  final dayBefore = DateTime(
    bookingAt.year,
    bookingAt.month,
    bookingAt.day,
  ).subtract(const Duration(days: 1));
  final deadline = DateTime(dayBefore.year, dayBefore.month, dayBefore.day, h);
  return cancelAt.isBefore(deadline) ? 0 : r.feeYen;
}
