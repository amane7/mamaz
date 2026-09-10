// ============================================================================
// 予約詳細（C-09 / C-10 / C-11）
// 変更・キャンセルをアプリだけで完結。見込／確認中／確定を明示。
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_nav.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../matching_engine.dart';
import '../ops_models.dart';
import '../ops_state.dart';
import 'ops_ui.dart';

class BookingDetailScreen extends StatelessWidget {
  final String bookingId;
  const BookingDetailScreen({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context) {
    final ops = context.watch<OpsState>();
    final b = ops.bookings.firstWhere((e) => e.id == bookingId);
    final s = ops.serviceById(b.serviceId);
    final policy = ops.policyById(b.cancelPolicyId ?? 'cp_standard');
    final canChange = ops.canChange(b);
    final cancelFee = ops.cancelEstimate(b);
    final tier = ops.cancelTier(b);
    final editable =
        b.state.readyForService || b.state == BookingState.slotHeld;
    final program = ops.programOfBooking(b);
    final isStaff = ops.role != OpsRole.family;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppTopBar(
        title: b.code,
        subtitle: 'ご予約の詳細',
        background: Colors.white,
        actions: [
          Center(child: StateBadge(b.state)),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
        children: warmList([
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.cardPink,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        s.kind.icon,
                        size: 22,
                        color: AppColors.blushPinkDeep,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.name,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${fmtDateTime(b.at)}・${relativeDay(b.at)}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textBody,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24, color: AppColors.line),
                _kv('ご利用時間', fmtRange(b.at, b.durationMin)),
                _kv(
                  b.kind == ServiceKind.visit ? '訪問先' : 'ご利用の院',
                  b.kind == ServiceKind.visit
                      ? ops.customer.address.short
                      : (ops.facilityById(b.facilityId)?.name ?? '—'),
                ),
                _kv('担当', ops.staffById(b.staffId)?.name ?? '確認中'),
                if (b.needs.isNotEmpty) _kv('ご希望', b.needs.join('・')),
                if (b.intake['bath'] == true) _kv('沐浴', 'お手伝いします'),
                if (b.intake['meal'] == true)
                  _kv('お食事', 'あり／${_allergyText(b)}'),
              ],
            ),
          ),

          // --- 料金（三状態）---
          const SizedBox(height: 16),
          const OpsSection(title: 'お支払い', spec: 'C-09'),
          SoftCard(
            color: AppColors.cardCream,
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'ご負担額',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    FeeChip(yen: b.feeYen, state: b.feeState),
                  ],
                ),
                if (b.cancelFeeYen > 0) ...[
                  const Divider(height: 20, color: Colors.white),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'キャンセル料',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      FeeChip(yen: b.cancelFeeYen, state: b.cancelFeeState),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  b.feeState == FeeState.confirmed
                      ? 'この金額で確定しています。'
                      : b.feeState == FeeState.underReview
                      ? '料金の取り決めに当たらないため、スタッフが確認しています。'
                      : '概算です。最終金額は利用券・自治体の決定・スタッフ確認後に確定します。',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    height: 1.6,
                  ),
                ),
                const Divider(height: 18, color: Colors.white),
                _kv('ご利用のしかた', b.funding.label),
                if (b.feeBasis.isNotEmpty) _kv('根拠', b.feeBasis),
                if (!b.isSelfPay)
                  _kv(
                    '自治体マスタ',
                    '${program.name} v${b.municipalityProgramVersion ?? program.version}',
                  ),
                if (!b.isSelfPay)
                  _kv('利用券の確認', b.voucherVerified ? '確認済み' : '未確認'),
                if (!b.isSelfPay && program.cancelRule.verified)
                  _kv('自治体のキャンセル規定', program.cancelRule.label),
              ],
            ),
          ),

          // --- 要件再定義：状態の説明（確定前であることを言い切る）---
          if (b.state.familyHint.isNotEmpty) ...[
            const SizedBox(height: 16),
            InfoNote(
              icon: b.state.familyIcon,
              color: b.state.isConfirmedOrLater
                  ? AppColors.cardSage
                  : AppColors.cardLavender,
              title: b.state.familyLabel,
              text: b.state.familyHint,
            ),
          ],

          // --- ご家族：仮予約を確定する（事業所調整型）---
          if (!isStaff && b.state == BookingState.provisional) ...[
            const SizedBox(height: 16),
            _FamilyConfirmCard(booking: b),
          ],

          // --- ご家族：対象外 → 自費で続ける ---
          if (!isStaff && b.state == BookingState.notEligible) ...[
            const SizedBox(height: 16),
            SoftCard(
              child: _actionRow(
                context,
                icon: Icons.payments_outlined,
                title: '自費で利用する',
                sub: '${s.name} ${yen(s.priceYen)}（概算）。スタッフが再度ご案内します。',
                color: AppColors.mauve,
                onTap: () {
                  ops.switchToSelfPay(b, reason: 'ご家族の希望（対象外のため）');
                  showWarmToast(context, '自費でのご利用に切り替えました');
                },
              ),
            ),
          ],

          // --- スタッフ：受付基盤としての操作 ---
          if (isStaff) ...[
            const SizedBox(height: 16),
            _StaffActions(booking: b),
          ],

          // --- 例外・確認中 ---
          if (b.hasOpenException) ...[
            const SizedBox(height: 16),
            const OpsSection(title: '確認しています', spec: '§11'),
            ...b.openExceptions.map(
              (ex) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SoftCard(
                  color: ex.code == ReasonCode.redFlag
                      ? const Color(0xFFFDF0ED)
                      : AppColors.cardCream,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ReasonChip(ex.code, overdue: ex.overdue),
                      const SizedBox(height: 9),
                      Text(
                        _familyMessage(ex.code),
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textBody,
                          height: 1.7,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          // --- 変更・キャンセル ---
          if (editable) ...[
            const SizedBox(height: 16),
            OpsSection(
              title: '変更・お取消し',
              note: canChange
                  ? '${policy.changeDeadlineHours}時間前まで、アプリだけで変更できます。'
                  : '変更期限を過ぎています。ご希望はお預かりし、担当が調整します。',
              spec: 'C-10',
            ),
            SoftCard(
              child: Column(
                children: [
                  _actionRow(
                    context,
                    icon: Icons.edit_calendar_rounded,
                    title: '日時を変える',
                    sub: canChange ? '空いている時間からお選びいただけます' : '担当が調整します',
                    color: AppColors.mauve,
                    onTap: () => _changeSheet(context, ops, b),
                  ),
                  const Divider(height: 20, color: AppColors.line),
                  _actionRow(
                    context,
                    icon: Icons.event_busy_rounded,
                    title: 'お取消しする',
                    sub: cancelFee == 0
                        ? '${tier.label}・キャンセル料はかかりません'
                        : '${tier.label}・見込 ${yen(cancelFee)}',
                    color: cancelFee == 0
                        ? const Color(0xFF6FB57E)
                        : const Color(0xFFE0A83C),
                    onTap: () => _cancelSheet(context, ops, b),
                  ),
                ],
              ),
            ),
          ],

          // --- 同意スナップショット ---
          if (b.consent != null) ...[
            const SizedBox(height: 16),
            const OpsSection(
              title: 'このご予約に適用される規約',
              note: 'あとから規約が変わっても、この内容は変わりません。',
              spec: '§8.3',
            ),
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.verified_user_outlined,
                        size: 17,
                        color: Color(0xFF6FB57E),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          b.consent!.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.cardSage,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'v${b.consent!.version}',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF6FB57E),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _kv(
                    '改定日',
                    '${b.consent!.revisedAt.year}年${b.consent!.revisedAt.month}月${b.consent!.revisedAt.day}日',
                  ),
                  _kv('同意日時', fmtDateTime(b.consent!.agreedAt)),
                  _kv(
                    'キャンセル規定',
                    '${policy.name} v${b.cancelPolicyVersion ?? policy.version}',
                  ),
                ],
              ),
            ),
          ],

          // --- §23 必要条件 vs 候補（管理者・助産師のみ） ---
          //
          // §19 のとおり、NG理由や私的予定はご家族には出さない。
          // 「なぜ取れないか」は運用側だけが見る情報なので、
          // ご家族のロールではこのセクションを丸ごと出さない。
          if (ops.role != OpsRole.family) ...[
            const SizedBox(height: 16),
            const OpsSection(title: '必要条件と候補の照合', spec: '§23'),
            _MatchAuditCard(booking: b, service: s),
          ],

          // --- 状態履歴 ---
          const SizedBox(height: 16),
          const OpsSection(title: '手続きの履歴', spec: '付録C.6'),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: b.stateLog.isEmpty
                  ? [
                      const Text(
                        '履歴はまだありません。',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ]
                  : b.stateLog
                        .map(
                          (l) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 5),
                                  child: Icon(
                                    Icons.circle,
                                    size: 5,
                                    color: AppColors.blushPink,
                                  ),
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    l,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.textBody,
                                      height: 1.6,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
            ),
          ),
          const SizedBox(height: 22),
          const ReturnHomeCard(),
        ]),
      ),
    );
  }

  static String _allergyText(OpsBooking b) {
    final a = (b.intake['allergy'] as String?)?.trim() ?? '';
    return a.isEmpty ? 'アレルギーの記載なし' : a;
  }

  static String _familyMessage(ReasonCode code) => switch (code) {
    ReasonCode.redFlag =>
      'お知らせいただいた体調について、助産師が確認しています。ご予約はそのまま有効です。'
          'お急ぎのときは、いつでもお電話ください。',
    ReasonCode.eligibilityUnknown =>
      '自治体の利用条件を確認しています。追加でうかがうことがありますが、'
          'こちらから必要なことだけお聞きします。',
    ReasonCode.lateCancel => 'キャンセル料について担当が確認しています。ご事情によって変わることがあります。',
    ReasonCode.mealAllergy => 'お食事の内容を確認しています。安全にご用意できるよう調整しています。',
    ReasonCode.travelCondition => '訪問時の駐車場所を担当が確認しています。',
    ReasonCode.freeTextConsult => 'ご相談の内容を担当が読んでいます。折り返しご連絡します。',
    ReasonCode.noSlot => '担当の調整をしています。近い日程をご案内します。',
    ReasonCode.applicationMissing =>
      '自治体への利用申請がまだ確認できていません。決定通知が届いたら「自治体の制度・申請」から登録してください。',
    ReasonCode.voucherUnverified => '利用券・決定通知をスタッフが確認しています。',
    ReasonCode.feeUndetermined => '料金の取り決めに当たらない条件のため、スタッフが金額を確認しています。',
    ReasonCode.multipleBirth => 'ふたご・みつごのお子さまの担当人数と月齢を助産師が確認しています。',
    ReasonCode.programNotEffective => '自治体の制度情報を確認しています。',
    ReasonCode.facilityAcceptance => 'この院での受け入れ条件を確認しています。別の院をご案内することがあります。',
    _ => '担当が確認しています。少しお待ちください。',
  };

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            k,
            style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
              height: 1.5,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _actionRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String sub,
    required Color color,
    required VoidCallback onTap,
  }) => Pressable(
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: kMinTap),
      alignment: Alignment.center,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  sub,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: AppColors.textMuted,
          ),
        ],
      ),
    ),
  );

  // -------------------------------------------------------------------------
  // 日時変更シート
  // -------------------------------------------------------------------------
  void _changeSheet(BuildContext context, OpsState ops, OpsBooking b) {
    final s = ops.serviceById(b.serviceId);
    final slots = ops.engine.searchSlots(
      service: s,
      from: DateTime.now().add(const Duration(days: 1)),
      days: 14,
      startMinutes: const [540, 600, 660, 780, 840, 900],
      facilityId: b.facilityId,
      areaCode: ops.customer.address.areaCode,
      customerId: ops.customer.id,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _SheetShell(
        title: '日時を変える',
        subtitle: slots.isEmpty
            ? '今は空いている時間がありません。'
            : '担当できる助産師がいる時間だけをお出ししています。',
        child: slots.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: InfoNote(
                  icon: Icons.event_busy_rounded,
                  color: AppColors.softYellow,
                  text: '空きが出たらお知らせします。お急ぎのときはご相談ください。',
                ),
              )
            : Column(
                children: slots.take(14).map((c) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: ChoiceTile(
                      title: fmtDateTime(c.at),
                      subtitle: '${relativeDay(c.at)}・担当あり',
                      icon: Icons.schedule_rounded,
                      selected: false,
                      color: AppColors.mauve,
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: AppColors.textMuted,
                      ),
                      onTap: () {
                        Navigator.of(sheetCtx).pop();
                        final ok = ops.requestChange(b, c.at);
                        showWarmDialog(
                          context,
                          icon: ok
                              ? Icons.event_available_rounded
                              : Icons.hourglass_top_rounded,
                          title: ok ? '日程を変更しました' : 'ご希望をお預かりしました',
                          message: ok
                              ? '${fmtDateTime(c.at)}\n担当：${ops.staffById(b.staffId)?.name ?? '調整中'}\n'
                                    'ご都合に合わせて、いつでも変更いただけます。'
                              : '変更期限を過ぎているため、担当が調整しています。'
                                    'できるかぎりご希望に沿えるようにいたします。',
                          color: ok
                              ? const Color(0xFF6FB57E)
                              : const Color(0xFFE0A83C),
                          celebrate: ok,
                        );
                      },
                    ),
                  );
                }).toList(),
              ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // キャンセルシート
  // -------------------------------------------------------------------------
  void _cancelSheet(BuildContext context, OpsState ops, OpsBooking b) {
    final fee = ops.cancelEstimate(b);
    final tier = ops.cancelTier(b);
    const reasons = ['体調がすぐれない', 'お子さまの体調', '家族の予定が変わった', '別の日にしたい', 'その他'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _SheetShell(
        title: 'お取消しの手続き',
        subtitle: 'よろしければ理由をお選びください。無理のない範囲でどうぞ。',
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: fee == 0
                    ? AppColors.cardSage
                    : AppColors.softYellow.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  Icon(
                    fee == 0
                        ? Icons.check_circle_outline_rounded
                        : Icons.info_outline_rounded,
                    size: 19,
                    color: fee == 0
                        ? const Color(0xFF6FB57E)
                        : const Color(0xFFC9A227),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fee == 0 ? 'キャンセル料はかかりません' : 'キャンセル料の見込：${yen(fee)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          fee == 0
                              ? tier.label
                              : '${tier.label}。ご事情によって変わることがあります。'
                                    '担当が確認してからご連絡します。',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textBody,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...reasons.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: ChoiceTile(
                  title: r,
                  selected: false,
                  color: AppColors.textMuted,
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    ops.requestCancel(b, r);
                    showWarmDialog(
                      context,
                      icon: Icons.favorite_border_rounded,
                      title: fee == 0 ? 'お取消ししました' : 'お取消しをお預かりしました',
                      message: fee == 0
                          ? 'キャンセル料はかかりません。\n'
                                'またご都合のよいときに、いつでもお待ちしています。'
                          : '見込 ${yen(fee)} で担当が確認しています。'
                                'ご事情をうかがったうえでご連絡しますので、ご安心ください。',
                      color: AppColors.mauve,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 6),
            const InfoNote(
              icon: Icons.support_agent_rounded,
              color: AppColors.lavender,
              text: 'つらくてお手続きが難しいときは、そのままお電話でも承ります。',
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ボトムシートの共通枠
// ---------------------------------------------------------------------------
// =============================================================================
// 要件再定義：ご家族が仮予約を確定する（事業所調整型・スタッフ確認後）
// =============================================================================
class _FamilyConfirmCard extends StatelessWidget {
  final OpsBooking booking;
  const _FamilyConfirmCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final ops = context.watch<OpsState>();
    final canConfirm =
        !booking.hasOpenException &&
        (booking.isSelfPay || ops.voucherVerifiedForCustomer) &&
        booking.staffId != null;
    return SoftCard(
      color: AppColors.cardSage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'スタッフの確認が終わりました',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            canConfirm
                ? '内容をご確認のうえ「予約を確定する」を押してください。ここで確定します。'
                : '確定にはもう少し確認が必要です。スタッフからご連絡します。',
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
              color: AppColors.textBody,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6FB57E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              onPressed: canConfirm
                  ? () {
                      if (ops.familyConfirmProvisional(booking)) {
                        Celebration.show(context);
                        showWarmToast(
                          context,
                          'ご予約が確定しました',
                          icon: Icons.check_rounded,
                        );
                      }
                    }
                  : null,
              icon: const Icon(Icons.check_circle_rounded, size: 18),
              label: const Text(
                '予約を確定する',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 要件再定義：スタッフの一次受付操作
//   利用券確認／仮予約／確定／対象外／自費切替／問診済み／請求済み／引継ぎ
// =============================================================================
class _StaffActions extends StatelessWidget {
  final OpsBooking booking;
  const _StaffActions({required this.booking});

  @override
  Widget build(BuildContext context) {
    final ops = context.watch<OpsState>();
    final b = booking;
    final p = ops.programOfBooking(b);
    final needsDoc =
        !b.isSelfPay &&
        (p.requiresVoucher || p.requiresCoupon || p.requiresDecisionNotice);
    final docOk =
        b.isSelfPay || b.voucherVerified || ops.voucherVerifiedForCustomer;
    final rows = <Widget>[];

    void add(Widget w) {
      if (rows.isNotEmpty) {
        rows.add(const Divider(height: 20, color: AppColors.line));
      }
      rows.add(w);
    }

    if (needsDoc && !docOk) {
      add(
        _row(
          context,
          icon: Icons.fact_check_outlined,
          title: '利用券・決定通知を確認した',
          sub:
              '${p.name}：${[if (p.requiresDecisionNotice) '決定通知', if (p.requiresVoucher) '利用券', if (p.requiresCoupon) 'クーポン'].join('・')}の原本を確認して記録します',
          color: const Color(0xFFC98A1E),
          onTap: () {
            ops.verifyVoucher();
            showWarmToast(context, '利用券の確認を記録しました');
          },
        ),
      );
    }
    if (b.state.isPendingStaff && b.state != BookingState.provisional) {
      add(
        _row(
          context,
          icon: Icons.event_available_outlined,
          title: '仮予約にする',
          sub: p.scheduling == SchedulingAuthority.provider
              ? '事業所調整型：ご家族が「予約を確定する」を押せるようになります'
              : '日程を仮に押さえます（枠を占有）',
          color: AppColors.mauve,
          onTap: () {
            final ok = ops.setProvisional(b);
            showWarmToast(context, ok ? '仮予約にしました' : 'お部屋・設備が空いていません');
          },
        ),
      );
    }
    if (b.state.isPendingStaff || b.state == BookingState.slotHeld) {
      add(
        _row(
          context,
          icon: Icons.check_circle_outline_rounded,
          title: '予約を確定する',
          sub: docOk ? 'スタッフ確認のうえ確定します' : '利用券の確認が先に必要です',
          color: const Color(0xFF6FB57E),
          onTap: () {
            final ok = ops.approveRequest(b);
            showWarmToast(
              context,
              ok ? '確定しました' : '確定できません（未解決の確認事項・利用券・担当・設備）',
            );
          },
        ),
      );
      add(
        _row(
          context,
          icon: Icons.do_not_disturb_on_outlined,
          title: '自治体事業の対象外にする',
          sub: '月齢・回数・利用券の理由を残し、ご家族に自費案内を送ります',
          color: const Color(0xFFC07A7A),
          onTap: () => _reasonSheet(
            context,
            title: '対象外の理由',
            hint: '例：利用券が期限切れ／通所8日目以降',
            onSubmit: (r) => ops.markBookingNotEligible(b, reason: r),
          ),
        ),
      );
    }
    if (!b.isSelfPay &&
        (b.state.isPendingStaff ||
            b.state == BookingState.notEligible ||
            b.state == BookingState.confirmed)) {
      add(
        _row(
          context,
          icon: Icons.payments_outlined,
          title: '自費へ切り替える',
          sub: '料金を定価で再計算し、理由を履歴に残します',
          color: AppColors.mauve,
          onTap: () => _reasonSheet(
            context,
            title: '自費切替の理由',
            hint: '例：回数超過のためご家族の希望で自費',
            onSubmit: (r) => ops.switchToSelfPay(b, reason: r),
          ),
        ),
      );
    }
    if (b.state == BookingState.confirmed) {
      add(
        _row(
          context,
          icon: Icons.assignment_turned_in_outlined,
          title: '問診済みにする',
          sub: '問診票を受領しました',
          color: const Color(0xFF5FA872),
          onTap: () {
            ops.markIntakeDone(b);
            showWarmToast(context, '問診済みにしました');
          },
        ),
      );
    }
    if (b.state == BookingState.completed && ops.role == OpsRole.admin) {
      add(
        _row(
          context,
          icon: Icons.receipt_long_outlined,
          title: b.isSelfPay ? '精算済みにする' : '自治体へ請求済みにする',
          sub: b.isSelfPay ? '自費のため実績報告には計上しません' : '実績報告に計上し、利用回数を1増やします',
          color: const Color(0xFF8E7A6E),
          onTap: () {
            ops.markBilled(b);
            showWarmToast(context, '請求済みにしました');
          },
        ),
      );
    }
    if (b.state != BookingState.cancelled &&
        b.state != BookingState.handedOff &&
        b.state != BookingState.billed) {
      add(
        _row(
          context,
          icon: Icons.medical_services_outlined,
          title: '医療機関受診をご案内／継続支援へ引継ぎ',
          sub: '要配慮情報として監査ログに残ります',
          color: const Color(0xFF9C86C4),
          onTap: () => _handoffSheet(context, ops, b),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const OpsSection(
          title: '受付の操作（スタッフ）',
          note:
              '未申請 → 申請中 → 承認済み → 利用希望受付 → 行政調整中／スタッフ確認中 → 仮予約 → 確定 → 問診済み → 実施済み → 請求済み',
        ),
        if (rows.isEmpty)
          const InfoNote(text: 'この状態で行える操作はありません。', color: AppColors.lavender)
        else
          SoftCard(child: Column(children: rows)),
      ],
    );
  }

  Widget _row(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String sub,
    required Color color,
    required VoidCallback onTap,
  }) => Pressable(
    onTap: onTap,
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: const TextStyle(
                  fontSize: 10.5,
                  height: 1.4,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        const Icon(
          Icons.chevron_right_rounded,
          size: 20,
          color: AppColors.textMuted,
        ),
      ],
    ),
  );

  void _reasonSheet(
    BuildContext context, {
    required String title,
    required String hint,
    required bool Function(String) onSubmit,
  }) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _SheetShell(
          title: title,
          subtitle: 'ご家族への通知と監査ログに残ります。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: ctrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: hint,
                  filled: true,
                  fillColor: AppColors.cream,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.blushPinkDeep,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  onPressed: () {
                    final r = ctrl.text.trim();
                    if (r.isEmpty) return;
                    final ok = onSubmit(r);
                    Navigator.pop(ctx);
                    showWarmToast(context, ok ? '記録しました' : 'この状態では実行できません');
                  },
                  child: const Text(
                    '記録する',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handoffSheet(BuildContext context, OpsState ops, OpsBooking b) {
    final ctrl = TextEditingController();
    var kind = HandoffKind.medicalReferral;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: _SheetShell(
            title: '引継ぎ',
            subtitle: 'AIは診断や対象可否を決めません。人が判断して引き継ぎます。',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ChoiceTile(
                  title: HandoffKind.medicalReferral.label,
                  subtitle: '緊急・医療の判断が必要なとき',
                  icon: Icons.local_hospital_outlined,
                  selected: kind == HandoffKind.medicalReferral,
                  onTap: () =>
                      setSheet(() => kind = HandoffKind.medicalReferral),
                  color: const Color(0xFFE08A8A),
                ),
                const SizedBox(height: 8),
                ChoiceTile(
                  title: HandoffKind.continuedSupport.label,
                  subtitle: '保健センター・継続相談など',
                  icon: Icons.volunteer_activism_outlined,
                  selected: kind == HandoffKind.continuedSupport,
                  onTap: () =>
                      setSheet(() => kind = HandoffKind.continuedSupport),
                  color: AppColors.sageDeep,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'ご家族へ伝える内容（受診先・次の連絡など）',
                    filled: true,
                    fillColor: AppColors.cream,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.blushPinkDeep,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    onPressed: () {
                      final n = ctrl.text.trim();
                      if (n.isEmpty) return;
                      ops.handOff(b, kind: kind, note: n);
                      Navigator.pop(ctx);
                      showWarmToast(context, '引継ぎを記録しました');
                    },
                    child: const Text(
                      '引き継ぐ',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetShell extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  const _SheetShell({required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.94,
      minChildSize: 0.45,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textMuted,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.textMuted,
                    tooltip: 'とじる',
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.line),
            Expanded(
              child: SingleChildScrollView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// スロット候補の表示に使う軽量ラッパ（型参照の明示用）
typedef SlotList = List<SlotCandidate>;

// ============================================================================
// §23 必要条件 vs 候補の比較
//
// 目的はひとつ、「なぜこの枠が取れないのか」を管理者が一目で特定できること。
// 例外キューで止まった予約を人が動かすとき、調べ直す時間が一番のムダになる。
//
// 設計の約束：
//   * 判定はしない。Engine（MatchingEngine）の答えをそのまま並べるだけ。
//     ここで独自に条件を書くと、画面と判定が食い違う（§28）。
//   * 「必要」と「実際」を必ず横に並べる。片方だけでは不足が特定できない。
//   * ご家族には出さない（§19）。呼び出し側でロールを見て弾いている。
// ============================================================================

class _MatchAuditCard extends StatelessWidget {
  final OpsBooking booking;
  final ServiceDef service;
  const _MatchAuditCard({required this.booking, required this.service});

  @override
  Widget build(BuildContext context) {
    final ops = context.watch<OpsState>();

    // 自分自身の予約は除外して評価する。
    // 除外しないと「自分が埋めた枠」を理由に不足と出てしまう。
    final slot = ops.engine.buildSlot(
      service: service,
      at: booking.at,
      facilityId: booking.facilityId,
      areaCode: ops.customer.address.areaCode,
      customerId: booking.customerId,
      excludeBookingId: booking.id,
    );

    final assigned = booking.staffId == null
        ? null
        : ops.staffById(booking.staffId!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _summary(context, ops, slot, assigned),
        const SizedBox(height: 10),
        _skillRow(ops),
        const SizedBox(height: 10),
        _resourceRow(ops),
        const SizedBox(height: 10),
        _staffTable(ops, slot, assigned),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // 結論を先に出す。詳細は下に置く（探させない）。
  // -------------------------------------------------------------------------
  Widget _summary(
    BuildContext context,
    OpsState ops,
    SlotCandidate slot,
    OpsStaff? assigned,
  ) {
    final open = booking.exceptions.where((e) => e.resolvedAt == null).toList();
    final bookable = slot.bookable;

    // 「取れない一番の理由」をひとつに絞る。並べるだけでは判断が遅くなる。
    final String headline;
    final String detail;
    final Color tone;
    if (slot.resourceFull) {
      headline = 'お部屋・設備が空いていません';
      detail = '助産師が空いていても、この時間は成立しません（人と設備は別の資源です）。';
      tone = AppColors.blushPinkDeep;
    } else if (slot.eligible.isEmpty) {
      final top = _topReason(slot);
      headline = '割り当てられる助産師がいません';
      detail = top == null
          ? 'この時間に対応できる助産師が見つかりません。'
          : 'もっとも多い理由は「${top.label}」です。';
      tone = AppColors.blushPinkDeep;
    } else if (open.isNotEmpty) {
      headline = '枠は成立していますが、確認事項が残っています';
      detail = '不足しているのは条件ではなく確認です：${open.map((e) => e.code.label).join('・')}';
      tone = AppColors.mauve;
    } else {
      headline = 'すべての条件を満たしています';
      detail = assigned == null
          ? '担当は未確定ですが、${slot.eligible.length}名が割当可能です。'
          : '担当は${assigned.name}、ほかに${slot.eligible.length - 1}名が代替候補です。';
      tone = AppColors.sageDeep;
    }

    return SoftCard(
      color: bookable && open.isEmpty ? AppColors.cardSage : AppColors.cardPink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                bookable && open.isEmpty
                    ? Icons.verified_rounded
                    : Icons.help_center_rounded,
                size: 18,
                color: tone,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  headline,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: tone,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            detail,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textBody,
              height: 1.65,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            '照合した時間：${fmtDateTime(booking.at)}（${service.durationMin}分）'
            '${booking.facilityId == null ? '／ご自宅への訪問' : '／${ops.facilityById(booking.facilityId)?.name ?? '施設未設定'}'}',
            style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  /// 最頻の却下理由（家族非開示のものも含む＝運用側の画面なので出す）。
  RejectReason? _topReason(SlotCandidate slot) {
    final h = slot.rejectHistogram;
    if (h.isEmpty) return null;
    final sorted = h.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  // -------------------------------------------------------------------------
  // ① 必要スキル vs 持っている助産師
  // -------------------------------------------------------------------------
  Widget _skillRow(OpsState ops) {
    final need = service.requiredSkills;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _head('必要なスキル', '§11'),
          if (need.isEmpty)
            const Text(
              'このサービスに必要なスキルの指定はありません。',
              style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            )
          else
            for (final id in need) _skillLine(ops, id),
        ],
      ),
    );
  }

  Widget _skillLine(OpsState ops, String skillId) {
    // 保有者は付与テーブル（§11）を正とする。初期データではない。
    final holders = ops.staff
        .where((m) => ops.skillIdsOf(m.id).contains(skillId))
        .toList();
    final ok = holders.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.error_rounded,
            size: 15,
            color: ok ? AppColors.sageDeep : AppColors.blushPinkDeep,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ops.skillName(skillId),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ok
                      ? '持っている助産師：${holders.map((m) => m.name).join('・')}'
                      : '持っている助産師がいません（マスタでの付与が必要です）',
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.5,
                    color: ok ? AppColors.textMuted : AppColors.blushPinkDeep,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // ② 必要な設備 vs その時間に空いている設備（§15 人と設備は別資源）
  // -------------------------------------------------------------------------
  Widget _resourceRow(OpsState ops) {
    final fid = booking.facilityId;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _head('必要なお部屋・設備', '§15'),
          if (fid == null)
            const Text(
              'ご自宅への訪問なので、施設の設備は使いません。',
              style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            )
          else
            ..._resourceLines(ops, fid),
        ],
      ),
    );
  }

  List<Widget> _resourceLines(OpsState ops, String facilityId) {
    final free = ops.engine.availableResources(
      service: service,
      at: booking.at,
      facilityId: facilityId,
      excludeBookingId: booking.id,
    );
    final missing = ops.engine.missingResourceKinds(
      service: service,
      at: booking.at,
      facilityId: facilityId,
      excludeBookingId: booking.id,
    );
    final need = service.requiredResourceKinds;
    final stocked = ops.resources
        .where((r) => r.facilityId == facilityId && r.active)
        .toList();

    return [
      if (need.isEmpty)
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'このプランに必須の設備指定はありません（施設の定員だけで判定します）。',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
        ),
      for (final k in need)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                missing.contains(k)
                    ? Icons.error_rounded
                    : stocked.any((r) => r.kind == k)
                    ? Icons.check_circle_rounded
                    : Icons.remove_circle_rounded,
                size: 15,
                color: missing.contains(k)
                    ? AppColors.blushPinkDeep
                    : stocked.any((r) => r.kind == k)
                    ? AppColors.sageDeep
                    : AppColors.warmGray,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      k.label,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      !stocked.any((r) => r.kind == k)
                          ? 'この施設に登録がありません（マスタで追加が必要です）'
                          : missing.contains(k)
                          ? 'この時間はすべて使用中です（ほかのご予約が使っています）'
                          : '空いています',
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.5,
                        color: missing.contains(k)
                            ? AppColors.blushPinkDeep
                            : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      const Divider(height: 18, color: AppColors.line),
      Text(
        free.isEmpty
            ? 'この時間に空いている設備はありません。'
            : 'この時間に空いている設備：${free.map((r) => r.name).join('・')}',
        style: TextStyle(
          fontSize: 11,
          height: 1.55,
          color: free.isEmpty ? AppColors.blushPinkDeep : AppColors.textBody,
        ),
      ),
    ];
  }

  // -------------------------------------------------------------------------
  // ③ 助産師ごとの可否と、ダメだった理由
  //
  // ここが本題。「誰が」「なぜ」ダメなのかが分かれば、
  // 管理者は次の一手（OK時間を増やす／別の日を出す／設備を空ける）を選べる。
  // -------------------------------------------------------------------------
  Widget _staffTable(OpsState ops, SlotCandidate slot, OpsStaff? assigned) {
    final rows = [...slot.evaluations]
      ..sort((a, b) {
        if (a.eligible != b.eligible) return a.eligible ? -1 : 1;
        return b.score.compareTo(a.score);
      });

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _head('助産師ごとの可否', '§12'),
          for (final e in rows) _staffLine(e, assigned?.id == e.staff.id),
          const SizedBox(height: 4),
          const InfoNote(
            title: 'ここに出ている理由が、そのまま予約可否の理由です',
            text:
                '画面の説明と判定は同じ計算を使っています。'
                'この表で不足が埋まれば、ご家族の画面にもその枠が出るようになります。',
            color: AppColors.lavender,
          ),
        ],
      ),
    );
  }

  Widget _staffLine(StaffEvaluation e, bool isAssigned) {
    final ok = e.eligible;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: isAssigned
            ? AppColors.cardSage
            : ok
            ? AppColors.surface
            : AppColors.cardCream,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: isAssigned ? AppColors.sage : AppColors.line,
          width: isAssigned ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: ok ? AppColors.sageDeep : AppColors.warmGray,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                e.staff.name,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(width: 7),
              if (isAssigned) const TagChip('この予約の担当', color: AppColors.sage),
              const Spacer(),
              Text(
                ok ? '割当できます' : '割当できません',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: ok ? AppColors.sageDeep : AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (!ok)
            // 理由は1件ずつ出す。まとめると「何を直せばいいか」が消える。
            for (final r in e.rejects)
              Padding(
                padding: const EdgeInsets.only(top: 3, left: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '・',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.blushPinkDeep,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        r.label,
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.5,
                          color: AppColors.textBody,
                        ),
                      ),
                    ),
                  ],
                ),
              )
          else
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(
                'この日の実働 ${e.loadMinToday}分・${e.bookingsToday}件'
                '${e.travelPenaltyMin > 0 ? '／移動 ${e.travelPenaltyMin}分' : ''}'
                '${e.continuity ? '／前回と同じ担当' : ''}',
                style: const TextStyle(
                  fontSize: 10.5,
                  height: 1.5,
                  color: AppColors.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _head(String title, String spec) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(width: 7),
        Text(
          spec,
          style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted),
        ),
      ],
    ),
  );
}
