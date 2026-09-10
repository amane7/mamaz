import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_nav.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../ops_models.dart';
import '../ops_state.dart';
import 'ops_ui.dart';

/// ---------------------------------------------------------------------------
/// 自治体制度ガイド（要件再定義：自治体選択 → 対象可否の仮判定 → 行政申請案内
/// → 承認確認 → 利用希望受付 の「手前」を担う画面）
///
/// MAMOA は申請を代行しない。何を・どこへ・いつまでに申請するかを
/// 自治体マスタから案内し、届いた決定通知・利用券をここで登録してもらう。
/// AI や自動判定は最終的な対象可否を決めず、スタッフ確認へつなぐ。
/// ---------------------------------------------------------------------------
class MunicipalityGuideScreen extends StatelessWidget {
  const MunicipalityGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ops = context.watch<OpsState>();
    final c = ops.customer;
    final p = ops.municipalityById(c.municipalityId);
    final a = c.application;
    final child = c.children.first;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: const AppTopBar(
        title: '自治体の産後ケア事業',
        subtitle: '申請から利用までの流れ',
        background: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
        children: warmList([
          // --- 自治体の選択 ---
          const OpsSection(
            title: 'お住まいの自治体',
            note: '自治体によって、申請の流れ・料金・対象が変わります。',
          ),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in ops.municipalities)
                      ChoiceChip(
                        label: Text(m.name),
                        selected: m.id == p.id,
                        selectedColor: AppColors.cardPink,
                        onSelected: (_) {
                          if (m.id == p.id) return;
                          showWarmDialog(
                            context,
                            icon: Icons.apartment_rounded,
                            title: '${m.name}に変更しますか',
                            message:
                                '自治体を変えると、申請状態は「未申請」に戻ります。'
                                '（引っ越し・登録ミスの修正用です）',
                            primaryLabel: '変更する',
                            onPrimary: () => ops.switchMunicipality(m.id),
                            secondaryLabel: 'やめる',
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _Badge(
                      p.bookingEnabled ? 'MAMOAで予約まで' : '制度案内のみ',
                      p.bookingEnabled
                          ? const Color(0xFF6FB57E)
                          : AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    _Badge(p.scheduling.label, AppColors.mauve),
                    const SizedBox(width: 6),
                    _Badge(p.versionLabel, AppColors.textMuted),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // --- 申請の進み具合 ---
          const OpsSection(title: '申請の進み具合', note: '未申請 → 申請中 → 承認済み の順に進みます。'),
          _StatusStepper(status: a.status),
          const SizedBox(height: 10),
          InfoNote(
            icon: a.status.canRequest
                ? Icons.check_circle_outline_rounded
                : Icons.info_outline_rounded,
            color: a.status.canRequest
                ? AppColors.cardSage
                : AppColors.softYellow,
            title: a.status.label,
            text: a.status.familyHint,
          ),
          const SizedBox(height: 12),
          _ApplicationActions(program: p, application: a),
          const SizedBox(height: 18),

          // --- 対象の仮判定 ---
          const OpsSection(
            title: 'ご利用の目安（仮判定）',
            note: '最終的な対象可否は自治体とスタッフが確認します。',
          ),
          SoftCard(
            color: AppColors.cardCream,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv(
                  'お子さま',
                  '${child.name}（${child.ageLabel}${child.plurality > 1 ? '・多胎' : ''}）',
                ),
                _kv(
                  '居住地要件',
                  p.residencyRequirement.isEmpty ? '—' : p.residencyRequirement,
                ),
                for (final e in p.serviceEligibility)
                  _kv(
                    e.service.label,
                    '生後${(e.maxAgeDaysFor(child.plurality) / 30.4).floor()}か月まで'
                    '${e.note.isEmpty ? '' : '（${e.note}）'}',
                  ),
                _kv(
                  '回数の数え方',
                  p.useCountRule.isEmpty
                      ? '${p.maxUseCount}回まで'
                      : p.useCountRule,
                ),
                _kv(
                  'のこり回数',
                  'あと${(p.maxUseCount - c.usedCount - (p.countsOtherFacilities ? a.otherFacilityUses : 0)).clamp(0, 99)}回'
                      '${p.countsOtherFacilities ? '（他施設分を含む）' : ''}',
                ),
                if (p.multipleBirthNote.isNotEmpty)
                  _kv('多胎児', p.multipleBirthNote),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // --- 申請の方法 ---
          const OpsSection(
            title: '申請の方法',
            note: 'MAMOAは申請の代行はしません。自治体へ直接お手続きください。',
          ),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv(
                  '申請できる時期',
                  p.applicationWindow.isEmpty ? '—' : p.applicationWindow,
                ),
                if (p.applicationLeadDays > 0)
                  _kv('期限', '利用希望日の${p.applicationLeadDays}日前まで'),
                _kv(
                  '申請方法',
                  p.applicationMethod.isEmpty ? '—' : p.applicationMethod,
                ),
                _kv(
                  '申請先',
                  p.applicationContact.isEmpty ? '—' : p.applicationContact,
                ),
                _kv(
                  '届くもの',
                  [
                    if (p.requiresDecisionNotice) '決定（承認）通知',
                    if (p.requiresVoucher) '利用券',
                    if (p.requiresCoupon) 'クーポン券',
                  ].join('・'),
                ),
                _kv('当日ご用意', p.requiredDocs.join('・')),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // --- 料金の目安 ---
          const OpsSection(
            title: '料金の目安（概算）',
            note: '最終金額は利用券・自治体の決定・スタッフ確認後に確定します。',
          ),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final r in p.feeRules)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.mauve.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            r.service == ProgramServiceType.dayCare
                                ? '通所'
                                : r.service == ProgramServiceType.outreach
                                ? '訪問'
                                : '宿泊',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.mauve,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            r.conditionLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textBody,
                            ),
                          ),
                        ),
                        Text(
                          yen(r.yen),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 18, color: AppColors.line),
                _kv('自治体のキャンセル規定', p.cancelRule.label),
                if (p.selfPaySwitchNote.isNotEmpty)
                  _kv('自費への切替', p.selfPaySwitchNote),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // --- 流れ ---
          OpsSection(title: 'MAMOAでの流れ', note: p.scheduling.description),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, s) in _flowFor(p).indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.mauve.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.mauve,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            s,
                            style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.5,
                              color: AppColors.textBody,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          InfoNote(
            icon: Icons.verified_outlined,
            color: AppColors.lavender,
            title: '出典と確認日',
            text:
                '${p.sourceRevision.isEmpty ? '' : '${p.sourceRevision}\n'}'
                '最終確認 ${p.lastVerifiedAt == null ? '未確認' : fmtDate(p.lastVerifiedAt!)}'
                '（${p.verifiedBy}）\n${p.sourceUrl}',
          ),
        ]),
      ),
    );
  }

  static List<String> _flowFor(MunicipalityProgram p) => [
    '${p.name}へ利用申請（${p.applicationMethod}）',
    '決定通知${p.requiresVoucher ? '・利用券' : ''}${p.requiresCoupon ? '・クーポン' : ''}が届いたら、MAMOAに登録',
    'スタッフが書類を確認',
    switch (p.scheduling) {
      SchedulingAuthority.municipality => 'MAMOAで「利用希望を送る」→ 市と施設が日程調整 → 市からご連絡',
      SchedulingAuthority.provider => 'MAMOAで「仮予約を申し込む」→ スタッフ確認 → 「予約を確定する」',
      SchedulingAuthority.shared => 'MAMOAで「仮予約を申し込む」→ 市または事業者から日程のご連絡',
    },
    '確定後、問診票を入力 → 当日ご利用',
  ];

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 118,
          child: Text(
            k,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
    ),
  );
}

class _StatusStepper extends StatelessWidget {
  final ApplicationStatus status;
  const _StatusStepper({required this.status});

  @override
  Widget build(BuildContext context) {
    const steps = [
      ApplicationStatus.notApplied,
      ApplicationStatus.applied,
      ApplicationStatus.approved,
    ];
    final idx = status == ApplicationStatus.notEligible
        ? -1
        : steps.indexOf(status);
    return Row(
      children: [
        for (final (i, s) in steps.indexed) ...[
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i <= idx ? AppColors.blushPinkDeep : AppColors.line,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    i < idx
                        ? Icons.check_rounded
                        : i == idx
                        ? Icons.radio_button_checked_rounded
                        : Icons.circle_outlined,
                    size: 15,
                    color: i <= idx ? Colors.white : AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  s.label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: i == idx ? FontWeight.w800 : FontWeight.w600,
                    color: i <= idx ? AppColors.textDark : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (i < steps.length - 1)
            Container(
              width: 24,
              height: 2,
              margin: const EdgeInsets.only(bottom: 18),
              color: i < idx ? AppColors.blushPinkDeep : AppColors.line,
            ),
        ],
      ],
    );
  }
}

class _ApplicationActions extends StatelessWidget {
  final MunicipalityProgram program;
  final MunicipalApplication application;
  const _ApplicationActions({required this.program, required this.application});

  @override
  Widget build(BuildContext context) {
    final ops = context.read<OpsState>();
    switch (application.status) {
      case ApplicationStatus.notApplied:
        return _btn(
          context,
          label: '自治体へ利用申請する（申請したと記録）',
          icon: Icons.open_in_new_rounded,
          color: AppColors.blushPinkDeep,
          onTap: () => showWarmDialog(
            context,
            icon: Icons.account_balance_rounded,
            title: '${program.name}へ申請',
            message:
                '${program.applicationMethod}で ${program.applicationContact} へお手続きください。\n\n'
                '申請が済んだら「申請したと記録」を押してください。決定通知が届くまで、MAMOAでは利用希望を送れません。',
            primaryLabel: '申請したと記録',
            onPrimary: ops.markApplied,
            secondaryLabel: 'あとで',
          ),
        );
      case ApplicationStatus.applied:
        return _btn(
          context,
          label: '決定通知・利用券が届いた',
          icon: Icons.mark_email_read_outlined,
          color: AppColors.mauve,
          onTap: () => _registerVoucher(context, ops),
        );
      case ApplicationStatus.approved:
        final verified = ops.voucherVerifiedForCustomer;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SoftCard(
              color: verified ? AppColors.cardSage : AppColors.cardCream,
              child: Row(
                children: [
                  Icon(
                    verified
                        ? Icons.verified_rounded
                        : Icons.hourglass_top_rounded,
                    color: verified
                        ? const Color(0xFF6FB57E)
                        : const Color(0xFFC98A1E),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      verified
                          ? '利用券・決定通知をスタッフが確認しました（番号 ${application.voucherNumber ?? '—'}）'
                          : '利用券番号 ${application.voucherNumber ?? '—'} を登録済み。スタッフが確認中です。',
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: AppColors.textBody,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (program.requiresCoupon) ...[
              const SizedBox(height: 8),
              Text(
                'クーポン残り ${application.couponsLeft}枚',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ],
        );
      case ApplicationStatus.notEligible:
        return const InfoNote(
          icon: Icons.volunteer_activism_outlined,
          color: AppColors.lavender,
          text: '自費でのご利用や、ほかの支援をご案内できます。「どれを選べばよいか相談する」からお声がけください。',
        );
    }
  }

  void _registerVoucher(BuildContext context, OpsState ops) {
    final ctrl = TextEditingController();
    var coupons = 0;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '決定通知・利用券の登録',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '番号を入力してください。スタッフが原本を確認したあと、利用希望を送れるようになります。',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.textBody,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: ctrl,
                  decoration: InputDecoration(
                    labelText: '決定通知・利用券の番号',
                    filled: true,
                    fillColor: AppColors.cream,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (_) => setSheet(() {}),
                ),
                if (program.requiresCoupon) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('クーポン枚数', style: TextStyle(fontSize: 12.5)),
                      ),
                      IconButton(
                        onPressed: coupons > 0
                            ? () => setSheet(() => coupons--)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        '$coupons枚',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      IconButton(
                        onPressed: () => setSheet(() => coupons++),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.blushPinkDeep,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    onPressed: ctrl.text.trim().isEmpty
                        ? null
                        : () {
                            ops.registerVoucher(
                              ctrl.text.trim(),
                              couponsLeft: coupons,
                            );
                            Navigator.pop(ctx);
                            showWarmToast(context, '登録しました。スタッフが確認します');
                          },
                    child: const Text(
                      '登録する',
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

  Widget _btn(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) => SizedBox(
    height: 50,
    child: FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    ),
  );
}
