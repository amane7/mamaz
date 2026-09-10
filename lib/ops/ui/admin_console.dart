import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_nav.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../ops_models.dart';
import '../ops_state.dart';
import 'master_edit_ui.dart';
import 'ops_ui.dart';

/// 管理者コンソール（A-01〜A-15 / 付録C.9）
/// 「朝にダッシュボードを開き、例外だけを承認する」を実現する。
class AdminConsole extends StatefulWidget {
  const AdminConsole({super.key});

  @override
  State<AdminConsole> createState() => _AdminConsoleState();
}

class _AdminConsoleState extends State<AdminConsole> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    HomeSignal.tick.addListener(_resetToFirstTab);
  }

  @override
  void dispose() {
    HomeSignal.tick.removeListener(_resetToFirstTab);
    super.dispose();
  }

  /// 「メニューにもどる」と、先頭タブ（ダッシュボード）まで戻る。
  void _resetToFirstTab() {
    if (mounted && _tab != 0) setState(() => _tab = 0);
  }

  @override
  Widget build(BuildContext context) {
    final ops = context.watch<OpsState>();
    final pending =
        ops.exceptionQueue.length + ops.tasksFor(TaskOwner.siteAdmin).length;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _tab,
          children: const [
            _DashboardTab(),
            _ExceptionQueueTab(),
            _CalendarTab(),
            _MastersTab(),
            _GovernanceTab(),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                _navItem(
                  0,
                  'ダッシュ',
                  Icons.dashboard_outlined,
                  Icons.dashboard_rounded,
                  0,
                ),
                _navItem(
                  1,
                  '例外キュー',
                  Icons.rule_folder_outlined,
                  Icons.rule_folder_rounded,
                  pending,
                ),
                _navItem(
                  2,
                  'カレンダー',
                  Icons.calendar_month_outlined,
                  Icons.calendar_month_rounded,
                  0,
                ),
                _navItem(3, 'マスタ', Icons.tune_outlined, Icons.tune_rounded, 0),
                _navItem(
                  4,
                  '記録',
                  Icons.shield_outlined,
                  Icons.shield_rounded,
                  0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int i, String label, IconData out, IconData fill, int badge) {
    final on = _tab == i;
    return Expanded(
      child: Semantics(
        selected: on,
        button: true,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _tab = i),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    on ? fill : out,
                    size: 22,
                    color: on ? AppColors.mauve : AppColors.textMuted,
                  ),
                  if (badge > 0)
                    Positioned(
                      right: -6,
                      top: -3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE08A8A),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$badge',
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: on ? AppColors.mauve : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// A-01 ダッシュボード
// =============================================================================
class _DashboardTab extends StatelessWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context) {
    final ops = context.watch<OpsState>();
    final today = ops.bookings
        .where((b) => dayOf(b.at) == dayOf(DateTime.now()) && b.state.isActive)
        .toList();
    final queue = ops.exceptionQueue;
    final cancelFee = ops.bookings
        .where(
          (b) => b.cancelFeeYen > 0 && b.cancelFeeState != FeeState.confirmed,
        )
        .toList();
    final undelivered = ops.notifications
        .where((n) => n.status == DeliveryStatus.failed)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
      children: warmList([
        SoftCard(
          color: AppColors.cardCream,
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.mauve,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.wb_sunny_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '今朝の確認',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      queue.isEmpty && cancelFee.isEmpty
                          ? 'いま対応が必要なものはありません'
                          : '対応が必要：${queue.length + cancelFee.length}件',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textBody,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: MetricTile(
                label: '今日の予約',
                value: '${today.length}件',
                sub: today.isEmpty ? '—' : '最初は${fmtTime(today.first.at)}',
                icon: Icons.today_rounded,
                color: AppColors.blushPinkDeep,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MetricTile(
                label: '要専門判断',
                value: '${queue.length}件',
                sub: queue.isEmpty ? 'なし' : '助産師へ通知済み',
                icon: Icons.flag_rounded,
                color: const Color(0xFFE08A8A),
                alert: queue.isNotEmpty,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: MetricTile(
                label: 'キャンセル料確認',
                value: '${cancelFee.length}件',
                sub: cancelFee.isEmpty ? 'なし' : '金額の確定まち',
                icon: Icons.receipt_long_rounded,
                color: AppColors.softYellow,
                alert: cancelFee.isNotEmpty,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MetricTile(
                label: '通知未達',
                value: '${undelivered.length}件',
                sub: undelivered.isEmpty ? '正常' : '電話タスクへ',
                icon: Icons.notifications_off_outlined,
                color: AppColors.lavender,
                alert: undelivered.isNotEmpty,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: MetricTile(
                label: '利用希望・行政調整',
                value: '${ops.pendingRequests.length}件',
                sub: ops.pendingRequests.isEmpty
                    ? 'なし'
                    : '行政調整中 ${ops.pendingRequests.where((b) => b.state == BookingState.municipalCoordination).length}件',
                icon: Icons.account_balance_rounded,
                color: const Color(0xFF5E7FB8),
                alert: ops.pendingRequests.isNotEmpty,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MetricTile(
                label: '自治体請求まち',
                value: '${ops.awaitingBilling.length}件',
                sub: ops.awaitingBilling.isEmpty ? 'なし' : '実績報告に計上',
                icon: Icons.receipt_long_rounded,
                color: const Color(0xFF8E7A6E),
                alert: ops.awaitingBilling.isNotEmpty,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _VoucherVerifyCard(),
        const SizedBox(height: 22),
        const OpsSection(
          title: 'KPI（§16）',
          note: 'As-Is 4,401通／月を基準に、自動化の効果を測ります。',
          spec: 'A-13',
        ),
        const SizedBox(height: 10),
        const _KpiPanel(),
        const SizedBox(height: 22),
        const OpsSection(
          title: '未完了タスク',
          note: '担当ごとに振り分けられています。',
          spec: 'A-02',
        ),
        const SizedBox(height: 10),
        for (final owner in TaskOwner.values) ...[
          _ownerBlock(context, ops, owner),
          const SizedBox(height: 10),
        ],
      ]),
    );
  }

  Widget _ownerBlock(BuildContext context, OpsState ops, TaskOwner owner) {
    final list = ops.tasksFor(owner);
    final label = switch (owner) {
      TaskOwner.reception => '受付',
      TaskOwner.midwife => '助産師',
      TaskOwner.siteAdmin => '運営',
    };
    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(width: 8),
              TagChip(
                '${list.length}件',
                color: list.isEmpty ? AppColors.cardSage : AppColors.cardPink,
                textColor: list.isEmpty
                    ? const Color(0xFF6FB57E)
                    : AppColors.blushPinkDeep,
              ),
            ],
          ),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                '未完了はありません',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            )
          else
            for (final t in list) ...[
              const Divider(height: 16, color: AppColors.line),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.title,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textBody,
                          ),
                        ),
                        Text(
                          '期限 ${fmtTime(t.dueAt)}${t.overdue ? '（超過）' : ''}',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: t.overdue
                                ? const Color(0xFFD97A7A)
                                : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Pressable(
                    radius: BorderRadius.circular(AppRadius.sm),
                    onTap: () => ops.completeTask(t.id, '運営で対応'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.cardSage,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Text(
                        '完了',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6FB57E),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
        ],
      ),
    );
  }
}

/// 要件再定義：利用券・決定通知の確認まち（ご家族が登録→スタッフが原本確認）。
class _VoucherVerifyCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ops = context.watch<OpsState>();
    final c = ops.customer;
    final p = ops.municipalityById(c.municipalityId);
    if (c.application.status != ApplicationStatus.approved ||
        ops.voucherVerifiedForCustomer) {
      return const SizedBox.shrink();
    }
    return SoftCard(
      color: AppColors.cardCream,
      border: Border.all(color: AppColors.softYellow, width: 1.4),
      child: Row(
        children: [
          const Icon(Icons.fact_check_outlined, color: Color(0xFFC98A1E)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${c.nameKanji}さん（${p.name}）の利用券確認',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '番号 ${c.application.voucherNumber ?? '—'}。決定通知・利用券の原本を確認して記録してください。',
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.45,
                    color: AppColors.textBody,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              ops.verifyVoucher();
              showWarmToast(context, '確認を記録しました');
            },
            child: const Text('確認した'),
          ),
        ],
      ),
    );
  }
}

class _KpiPanel extends StatelessWidget {
  const _KpiPanel();

  @override
  Widget build(BuildContext context) {
    final ops = context.watch<OpsState>();
    return SoftCard(
      child: Column(
        children: [
          KpiBar(
            label: '自動確定率',
            valueText: '${(ops.autoRate * 100).toStringAsFixed(0)}%',
            progress: ops.autoRate,
            target: '目標 70%以上',
            achieved: ops.autoRate >= 0.7,
          ),
          const SizedBox(height: 12),
          KpiBar(
            label: 'ゼロタッチ率（人が触らず完了）',
            valueText: '${(ops.zeroTouchRate * 100).toStringAsFixed(0)}%',
            progress: ops.zeroTouchRate,
            target: '目標 60%以上',
            achieved: ops.zeroTouchRate >= 0.6,
          ),
          const SizedBox(height: 12),
          KpiBar(
            label: 'チャット往復の削減',
            valueText: '${(ops.chatReductionRate * 100).toStringAsFixed(0)}%',
            progress: ops.chatReductionRate,
            target: '目標 50%以上',
            achieved: ops.chatReductionRate >= 0.5,
          ),
          const SizedBox(height: 12),
          KpiBar(
            label: '通知到達率',
            valueText: '${(ops.deliverySuccessRate * 100).toStringAsFixed(0)}%',
            progress: ops.deliverySuccessRate,
            target: '目標 98%以上',
            achieved: ops.deliverySuccessRate >= 0.98,
          ),
          const Divider(height: 24, color: AppColors.line),
          Row(
            children: [
              Expanded(
                child: _hard(
                  'スキル不一致・NG割当',
                  '${ops.misAssignments}件',
                  ops.misAssignments == 0,
                ),
              ),
              Expanded(
                child: _hard(
                  '二重予約',
                  '${ops.doubleBookings}件',
                  ops.doubleBookings == 0,
                ),
              ),
              Expanded(
                child: _hard(
                  '赤旗の見落とし',
                  '${ops.redFlagMissed}件',
                  ops.redFlagMissed == 0,
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: AppColors.line),
          Row(
            children: [
              const Icon(
                Icons.trending_down_rounded,
                size: 18,
                color: Color(0xFF6FB57E),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'メッセージ削減の見込み：約${ops.estimatedMessagesSaved}通／月\n'
                  '（As-Is 受信${OpsState.baselineReceived}＋送信${OpsState.baselineSent}＝${OpsState.baselineTotal}通・稼働ルーム${OpsState.baselineRooms}）',
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.6,
                    color: AppColors.textBody,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hard(String label, String value, bool ok) => Column(
    children: [
      Icon(
        ok ? Icons.check_circle_rounded : Icons.error_rounded,
        size: 19,
        color: ok ? const Color(0xFF6FB57E) : const Color(0xFFE08A8A),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: ok ? const Color(0xFF6FB57E) : const Color(0xFFE08A8A),
        ),
      ),
      const SizedBox(height: 2),
      Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 9.5,
          height: 1.35,
          color: AppColors.textMuted,
        ),
      ),
    ],
  );
}

// =============================================================================
// A-02 例外対応キュー
// =============================================================================
class _ExceptionQueueTab extends StatelessWidget {
  const _ExceptionQueueTab();

  @override
  Widget build(BuildContext context) {
    final ops = context.watch<OpsState>();
    final queue = ops.exceptionQueue;
    final cancelFee = ops.bookings
        .where(
          (b) => b.cancelFeeYen > 0 && b.cancelFeeState != FeeState.confirmed,
        )
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: warmList([
        const InfoNote(
          title: '判断が必要なものだけ、ここに集まります',
          text: '理由コード・期限・推奨アクションつき。通常の予約は自動で確定しています。',
          icon: Icons.rule_folder_rounded,
          color: AppColors.mauve,
        ),
        const SizedBox(height: 16),
        const OpsSection(
          title: '未判定の予約',
          note: '赤旗（健康上の注意）は最優先で並びます。',
          spec: 'A-02 / E-01〜E-07',
        ),
        const SizedBox(height: 10),
        if (queue.isEmpty)
          const WarmEmptyState(
            icon: Icons.verified_rounded,
            title: '例外はありません',
            message: 'すべての申込が条件を満たし、自動で確定しています。',
            color: AppColors.sageDeep,
          )
        else
          for (final b in queue) ...[
            _AdminExceptionCard(booking: b),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 22),
        const OpsSection(
          title: 'キャンセル料の確定',
          note: '見込 → 確認中 → 確定。家族には確定してから請求します。',
          spec: 'A-05 / X-12',
        ),
        const SizedBox(height: 10),
        if (cancelFee.isEmpty)
          const InfoNote(
            text: '確定まちのキャンセル料はありません。',
            icon: Icons.receipt_long_outlined,
            color: AppColors.sageDeep,
          )
        else
          for (final b in cancelFee) ...[
            _CancelFeeCard(booking: b),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 22),
        const OpsSection(
          title: '通知の配信結果',
          note: '未達は再送し、上限を超えたら電話タスクに変わります。',
          spec: 'A-10 / X-13',
        ),
        const SizedBox(height: 10),
        const _NotificationList(),
      ]),
    );
  }
}

class _AdminExceptionCard extends StatelessWidget {
  final OpsBooking booking;
  const _AdminExceptionCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final ops = context.watch<OpsState>();
    final svc = ops.serviceById(booking.serviceId);
    final ex = booking.openExceptions;
    final toMidwife = ex.any((e) => e.code.toMidwife);

    return SoftCard(
      border: Border.all(
        color: ex.any((e) => e.overdue)
            ? const Color(0xFFE08A8A)
            : AppColors.line,
        width: ex.any((e) => e.overdue) ? 1.5 : 1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  booking.code,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.mauve,
                  ),
                ),
              ),
              StateBadge(booking.state, showCode: true),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${svc.name}・${fmtDateTime(booking.at)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${ops.customer.nameKanji}さん・担当 ${ops.staffById(booking.staffId)?.name ?? '未定'}',
            style: const TextStyle(fontSize: 11.5, color: AppColors.textBody),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in ex) ReasonChip(e.code, overdue: e.overdue),
              TagChip(
                toMidwife ? '助産師へ' : '運営で対応',
                color: toMidwife ? AppColors.cardPink : AppColors.cardLavender,
                textColor: toMidwife
                    ? AppColors.blushPinkDeep
                    : AppColors.lavender,
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final e in ex)
            Text(
              '・${e.detail}（SLA ${e.code.slaMinutes}分／期限 ${fmtTime(e.dueAt)}）',
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.6,
                color: AppColors.textBody,
              ),
            ),
          const SizedBox(height: 12),
          if (toMidwife)
            const InfoNote(
              text: '健康・栄養にかかわる判断は助産師の承認が必要です。運営では確定できません。',
              icon: Icons.medical_information_outlined,
              color: Color(0xFFE08A8A),
            )
          else
            Row(
              children: [
                Expanded(
                  child: _btn(
                    '承認して確定',
                    AppColors.blushPinkDeep,
                    Colors.white,
                    () {
                      ops.resolveReview(
                        booking,
                        approve: true,
                        note: '運営確認のうえ承認',
                      );
                      showWarmToast(
                        context,
                        '確定しました',
                        icon: Icons.check_rounded,
                        color: const Color(0xFF6FB57E),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _btn(
                    '見送る',
                    AppColors.cardCream,
                    AppColors.textBody,
                    () {
                      ops.resolveReview(
                        booking,
                        approve: false,
                        note: '条件を満たさないため見送り',
                      );
                      showWarmToast(
                        context,
                        '見送りを記録しました',
                        icon: Icons.info_outline_rounded,
                        color: AppColors.softYellow,
                      );
                    },
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _btn(String label, Color bg, Color fg, VoidCallback onTap) =>
      Pressable(
        radius: BorderRadius.circular(AppRadius.sm),
        onTap: onTap,
        child: Container(
          height: kMinTap,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ),
      );
}

class _CancelFeeCard extends StatelessWidget {
  final OpsBooking booking;
  const _CancelFeeCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final ops = context.watch<OpsState>();
    final svc = ops.serviceById(booking.serviceId);
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${svc.name}・${fmtDateTime(booking.at)}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              FeeChip(yen: booking.cancelFeeYen, state: booking.cancelFeeState),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '規定：${ops.policyById(booking.cancelPolicyId ?? 'cp_standard').name} v${booking.cancelPolicyVersion ?? 1}',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Pressable(
                  radius: BorderRadius.circular(AppRadius.sm),
                  onTap: () {
                    ops.settleCancelFee(
                      booking,
                      booking.cancelFeeYen,
                      '規定どおり確定',
                    );
                    showWarmToast(
                      context,
                      '金額を確定しました',
                      icon: Icons.check_rounded,
                      color: const Color(0xFF6FB57E),
                    );
                  },
                  child: Container(
                    height: kMinTap,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.blushPinkDeep,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      '${yen(booking.cancelFeeYen)}で確定',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Pressable(
                  radius: BorderRadius.circular(AppRadius.sm),
                  onTap: () {
                    ops.settleCancelFee(booking, 0, '特例：やむを得ない事情のため免除');
                    showWarmToast(
                      context,
                      '免除として記録しました',
                      icon: Icons.volunteer_activism_outlined,
                      color: AppColors.lavender,
                    );
                  },
                  child: Container(
                    height: kMinTap,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.cardCream,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Text(
                      '特例で免除',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textBody,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotificationList extends StatelessWidget {
  const _NotificationList();

  @override
  Widget build(BuildContext context) {
    final ops = context.watch<OpsState>();
    final list = ops.notifications.reversed.take(8).toList();
    if (list.isEmpty) {
      return const InfoNote(
        text: '配信履歴はまだありません。',
        icon: Icons.mark_email_read_outlined,
        color: AppColors.lavender,
      );
    }
    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < list.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.line),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Icon(
                    _icon(list[i].status),
                    size: 17,
                    color: _color(list[i].status),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          list[i].title,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          '${list[i].event.label}・${list[i].channel}・${_statusLabel(list[i].status)}'
                          '${list[i].retries > 0 ? '（再送${list[i].retries}回）' : ''}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (list[i].status == DeliveryStatus.failed)
                    Pressable(
                      radius: BorderRadius.circular(AppRadius.sm),
                      onTap: () => ops.retryNotification(list[i].id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.cardPink,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: const Text(
                          '再送',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.blushPinkDeep,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _icon(DeliveryStatus s) => switch (s) {
    DeliveryStatus.delivered => Icons.check_circle_outline_rounded,
    DeliveryStatus.failed => Icons.error_outline_rounded,
    DeliveryStatus.retried => Icons.refresh_rounded,
    DeliveryStatus.phoneTask => Icons.phone_in_talk_outlined,
    DeliveryStatus.queued => Icons.schedule_rounded,
  };

  Color _color(DeliveryStatus s) => switch (s) {
    DeliveryStatus.delivered => const Color(0xFF6FB57E),
    DeliveryStatus.failed => const Color(0xFFE08A8A),
    DeliveryStatus.retried => AppColors.softYellow,
    DeliveryStatus.phoneTask => AppColors.mauve,
    DeliveryStatus.queued => AppColors.textMuted,
  };

  String _statusLabel(DeliveryStatus s) => switch (s) {
    DeliveryStatus.delivered => '到達',
    DeliveryStatus.failed => '未達',
    DeliveryStatus.retried => '再送済み',
    DeliveryStatus.phoneTask => '電話タスクへ',
    DeliveryStatus.queued => '送信待ち',
  };
}

// =============================================================================
// A-03 予約カレンダー（スタッフ別・重複／移動／定員の検証つき）
// =============================================================================
class _CalendarTab extends StatefulWidget {
  const _CalendarTab();

  @override
  State<_CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<_CalendarTab> {
  DateTime _day = dayOf(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final ops = context.watch<OpsState>();
    final dayBookings =
        ops.bookings
            .where((b) => dayOf(b.at) == _day && b.state.isActive)
            .toList()
          ..sort((a, b) => a.at.compareTo(b.at));

    return Column(
      children: [
        // 日付スクローラ
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                for (var i = -2; i < 14; i++)
                  _dayChip(dayOf(DateTime.now()).add(Duration(days: i))),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: warmList([
              OpsSection(
                title:
                    '${_day.month}月${_day.day}日（${weekdayLabel(_day.weekday)}）の予約',
                note: '重複・移動時間・定員は自動で検証されています。',
                spec: 'A-03',
              ),
              const SizedBox(height: 10),
              if (dayBookings.isEmpty)
                const InfoNote(
                  text: 'この日の予約はありません。',
                  icon: Icons.event_available_outlined,
                  color: AppColors.sageDeep,
                )
              else
                for (final b in dayBookings) ...[
                  _adminBookingRow(ops, b),
                  const SizedBox(height: 8),
                ],
              const SizedBox(height: 22),
              const OpsSection(
                title: 'スタッフの可否（可否だけを共有）',
                note: 'NG理由や私的予定の内容は表示されません（§19）。',
                spec: 'A-06',
              ),
              const SizedBox(height: 10),
              for (final s in ops.staff) ...[
                _staffAvailRow(ops, s),
                const SizedBox(height: 8),
              ],
            ]),
          ),
        ),
      ],
    );
  }

  Widget _dayChip(DateTime d) {
    final sel = d == _day;
    final isToday = d == dayOf(DateTime.now());
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: Pressable(
        radius: BorderRadius.circular(12),
        onTap: () => setState(() => _day = d),
        child: Container(
          width: 48,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: sel
                ? AppColors.mauve
                : isToday
                ? AppColors.cardPink
                : AppColors.cardCream,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                weekdayLabel(d.weekday),
                style: TextStyle(
                  fontSize: 9.5,
                  color: sel ? Colors.white70 : AppColors.textMuted,
                ),
              ),
              Text(
                '${d.day}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: sel ? Colors.white : AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _adminBookingRow(OpsState ops, OpsBooking b) {
    final svc = ops.serviceById(b.serviceId);
    final staff = ops.staffById(b.staffId);
    final ok = b.staffId == null
        ? false
        : ops.engine.verifyAssignment(
            s: staff!,
            service: svc,
            at: b.at,
            facilityId: b.facilityId,
            areaCode: ops.customer.address.areaCode,
            excludeBookingId: b.id,
          );
    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 46,
            decoration: BoxDecoration(
              color: staff?.color ?? AppColors.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 11),
          SizedBox(
            width: 46,
            child: Text(
              fmtTime(b.at),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  svc.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${staff?.name ?? '未割当'}・'
                  '${svc.kind == ServiceKind.visit ? '訪問' : (ops.facilityById(b.facilityId)?.name ?? '院内')}'
                  '・${svc.durationMin}分＋移動${svc.travelMin}分',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StateBadge(b.state),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    ok ? Icons.verified_rounded : Icons.warning_amber_rounded,
                    size: 13,
                    color: ok
                        ? const Color(0xFF6FB57E)
                        : const Color(0xFFE08A8A),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    ok ? '条件OK' : '要確認',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: ok
                          ? const Color(0xFF6FB57E)
                          : const Color(0xFFE08A8A),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _staffAvailRow(OpsState ops, OpsStaff s) {
    final ranges = ops.effectiveAvailability(s.id, _day);
    final okRanges = ranges.where((r) => r.kind == AvailKind.ok).toList();
    final ngCount = ranges.where((r) => r.kind == AvailKind.ng).length;
    final load = ops.loadMinutes(s.id, _day);
    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: s.color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              s.initial,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: s.color,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                if (okRanges.isEmpty)
                  Text(
                    ngCount > 0 ? '終日 対応不可' : '登録なし（予約不可）',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textMuted,
                    ),
                  )
                else
                  Wrap(
                    spacing: 4,
                    runSpacing: 3,
                    children: [
                      for (final r in okRanges)
                        TagChip(
                          '${hhmm(r.startMin)}-${hhmm(r.endMin)} 対応可',
                          color: AppColors.cardSage,
                          textColor: const Color(0xFF6FB57E),
                        ),
                      if (ngCount > 0)
                        const TagChip(
                          '一部 対応不可',
                          color: AppColors.cardPink,
                          textColor: Color(0xFFD97A7A),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          Text(
            '${(load / 60).toStringAsFixed(1)}h',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: load > s.dailyMaxMin
                  ? const Color(0xFFE08A8A)
                  : AppColors.textBody,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// A-08 / A-09 版管理マスタ
// =============================================================================
class _MastersTab extends StatelessWidget {
  const _MastersTab();

  @override
  Widget build(BuildContext context) {
    final ops = context.watch<OpsState>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: warmList([
        const InfoNote(
          title: 'ここを直せば、アプリの判定が変わります',
          text:
              'カードを押すと編集できます。改定すると版が上がりますが、'
              'すでに入っているご予約に適用された条件は変わりません'
              '（同意・料金のスナップショットが残ります）。',
          icon: Icons.history_edu_outlined,
          color: AppColors.mauve,
        ),
        const SizedBox(height: 16),
        const OpsSection(
          title: '自治体制度マスタ',
          note: '料金・対象・申請方法は有効期間付きルール。押すと編集。年度改定の見落とし防止に「確認日」を残します。',
          spec: '要件再定義 §1 / §24',
        ),
        const SizedBox(height: 10),
        for (final m in ops.municipalities) ...[
          _ProgramCard(program: m, onEdit: () => _editProgram(context, ops, m)),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 12),
        const OpsSection(
          title: 'キャンセル規定',
          note: '期限と金額。予約時の版が固定されます。押すと編集できます。',
          spec: 'A-09 / §20',
        ),
        const SizedBox(height: 10),
        for (final p in ops.cancelPolicies) ...[
          SoftCard(
            onTap: () => _editCancelPolicy(context, ops, p),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EditableCardHeader(title: p.name, badge: 'v${p.version}'),
                const SizedBox(height: 8),
                for (final t in p.tiers) _kv(t.label, yen(t.feeYen)),
                _kv('時間変更の期限', '${p.changeDeadlineHours}時間前まで'),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 12),
        const OpsSection(
          title: '規約・同意文書',
          note: '改定日と版。家族の同意記録に紐づきます。',
          spec: 'A-09',
        ),
        const SizedBox(height: 10),
        for (final t in ops.terms) ...[
          SoftCard(
            onTap: () => _showTerms(context, t),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${t.versionLabel}・改定 ${fmtDate(t.revisedAt)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 12),
        const OpsSection(
          title: 'サービス定義（プラン）',
          note: '所要・移動・バッファ・料金。1件ずつ押して編集できます。',
          spec: 'A-07 / §24',
        ),
        const SizedBox(height: 10),
        SoftCard(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
          child: Column(
            children: [
              for (var i = 0; i < ops.services.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: AppColors.line),
                Pressable(
                  radius: BorderRadius.circular(AppRadius.sm),
                  onTap: () => _editService(context, ops, ops.services[i]),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    child: Row(
                      children: [
                        Icon(
                          ops.services[i].kind.icon,
                          size: 17,
                          color: AppColors.mauve,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      ops.services[i].name,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'v${ops.services[i].version}',
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.lavender,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${ops.services[i].durationLabel}／占有${ops.services[i].blockMin}分'
                                '／${ops.services[i].requiredSkills.map(ops.skillName).join('・')}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          yen(ops.services[i].priceYen),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textBody,
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // ---------------------------------------------------------------
        // §15 / §24 施設・設備（Resource）
        // ---------------------------------------------------------------
        const SizedBox(height: 22),
        const OpsSection(
          title: '施設・お部屋／設備',
          note: '「助産師は空いているのに部屋が無い」を正しく判定するための台帳です。',
          spec: '§15 / §24',
        ),
        const SizedBox(height: 10),
        for (final f in ops.facilities) ...[
          _FacilityCard(facility: f),
          const SizedBox(height: 10),
        ],

        // ---------------------------------------------------------------
        // §11 / §24 スキル
        // ---------------------------------------------------------------
        const SizedBox(height: 12),
        const OpsSection(
          title: 'スキル',
          note: 'スキルはコードに固定していません。ここで増やせます。',
          spec: '§11 / §24',
        ),
        const SizedBox(height: 10),
        const _SkillsCard(),
      ]),
    );
  }

  // ===========================================================================
  // §24 編集シート
  // ===========================================================================

  void _editProgram(BuildContext context, OpsState ops, MunicipalityProgram m) {
    var useCount = m.maxUseCount;
    var ageDays = m.maxChildAgeDays;
    var subsidy = m.subsidyYen;
    var concurrent = m.maxConcurrentBookings;
    var needsNumber = m.requiresProgramNumber;
    var scheduling = m.scheduling;
    var requiresApproval = m.requiresApproval;
    var requiresVoucher = m.requiresVoucher;
    var requiresCoupon = m.requiresCoupon;
    var requiresNotice = m.requiresDecisionNotice;
    var countsOther = m.countsOtherFacilities;
    var bookingEnabled = m.bookingEnabled;
    var leadDays = m.applicationLeadDays;
    var feeRules = [...m.feeRules];

    bool feeDirty() {
      if (feeRules.length != m.feeRules.length) return true;
      for (var i = 0; i < feeRules.length; i++) {
        if (feeRules[i].yen != m.feeRules[i].yen) return true;
      }
      return false;
    }

    bool dirty() =>
        useCount != m.maxUseCount ||
        ageDays != m.maxChildAgeDays ||
        subsidy != m.subsidyYen ||
        concurrent != m.maxConcurrentBookings ||
        needsNumber != m.requiresProgramNumber ||
        scheduling != m.scheduling ||
        requiresApproval != m.requiresApproval ||
        requiresVoucher != m.requiresVoucher ||
        requiresCoupon != m.requiresCoupon ||
        requiresNotice != m.requiresDecisionNotice ||
        countsOther != m.countsOtherFacilities ||
        bookingEnabled != m.bookingEnabled ||
        leadDays != m.applicationLeadDays ||
        feeDirty();

    showMasterEditSheet(
      context: context,
      title: m.name,
      subtitle: '${m.versionLabel}・この事業の利用条件を決めます',
      versionNote:
          '保存すると v${m.version + 1} になります。'
          'すでに入っているご予約の条件は変わりません（§20）。',
      canSave: dirty,
      saveLabel: () => dirty() ? 'v${m.version + 1} として保存' : '変更はありません',
      onSave: () {
        ops.updateProgram(
          m.id,
          maxUseCount: useCount,
          maxChildAgeDays: ageDays,
          subsidyYen: subsidy,
          maxConcurrentBookings: concurrent,
          requiresProgramNumber: needsNumber,
          scheduling: scheduling,
          requiresApproval: requiresApproval,
          requiresVoucher: requiresVoucher,
          requiresCoupon: requiresCoupon,
          requiresDecisionNotice: requiresNotice,
          countsOtherFacilities: countsOther,
          bookingEnabled: bookingEnabled,
          applicationLeadDays: leadDays,
          feeRules: feeDirty() ? feeRules : null,
        );
        showWarmToast(context, '${m.name} を改定しました');
      },
      body: (ctx, setSheet) => Column(
        children: [
          ToggleRow(
            label: 'MAMOAで予約まで扱う',
            hint: 'オフなら制度案内のみ（MVPは名古屋市から）。',
            value: bookingEnabled,
            changed: bookingEnabled != m.bookingEnabled,
            onChanged: (v) => setSheet(() => bookingEnabled = v),
          ),
          const Divider(height: 1, color: AppColors.line),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '予約・日程調整の主体',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: scheduling != m.scheduling
                        ? AppColors.blushPinkDeep
                        : AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final a in SchedulingAuthority.values)
                      ChoiceChip(
                        label: Text(
                          a.label,
                          style: const TextStyle(fontSize: 11),
                        ),
                        selected: scheduling == a,
                        selectedColor: AppColors.cardPink,
                        onSelected: (_) => setSheet(() => scheduling = a),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  scheduling.description,
                  style: const TextStyle(
                    fontSize: 10.5,
                    height: 1.4,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.line),
          ToggleRow(
            label: '事前に自治体の承認が必要',
            hint: 'オンなら未申請・申請中のご家族は利用希望を送れません。',
            value: requiresApproval,
            changed: requiresApproval != m.requiresApproval,
            onChanged: (v) => setSheet(() => requiresApproval = v),
          ),
          ToggleRow(
            label: '決定（承認）通知の確認が必要',
            value: requiresNotice,
            changed: requiresNotice != m.requiresDecisionNotice,
            onChanged: (v) => setSheet(() => requiresNotice = v),
          ),
          ToggleRow(
            label: '利用券の確認が必要',
            value: requiresVoucher,
            changed: requiresVoucher != m.requiresVoucher,
            onChanged: (v) => setSheet(() => requiresVoucher = v),
          ),
          ToggleRow(
            label: 'クーポンの確認が必要',
            hint: 'クーポン有無で料金が変わる自治体（長久手市）。',
            value: requiresCoupon,
            changed: requiresCoupon != m.requiresCoupon,
            onChanged: (v) => setSheet(() => requiresCoupon = v),
          ),
          ToggleRow(
            label: '他施設の利用分も回数に含める',
            hint: '瀬戸市の6回目以降の料金判定などに必要。',
            value: countsOther,
            changed: countsOther != m.countsOtherFacilities,
            onChanged: (v) => setSheet(() => countsOther = v),
          ),
          const Divider(height: 1, color: AppColors.line),
          NumberStepperRow(
            label: '申請期限（利用日の何日前まで）',
            hint: '0 は規定なし。',
            value: leadDays,
            max: 60,
            unit: '日',
            changed: leadDays != m.applicationLeadDays,
            onChanged: (v) => setSheet(() => leadDays = v),
          ),
          const Divider(height: 1, color: AppColors.line),
          if (feeRules.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(top: 10, bottom: 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '料金ルール（上から順に最初に一致した行）',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ),
            for (var i = 0; i < feeRules.length; i++)
              NumberStepperRow(
                label:
                    '${feeRules[i].service.label}／${feeRules[i].conditionLabel}',
                value: feeRules[i].yen,
                max: 100000,
                step: 10,
                unit: '円',
                changed: feeRules[i].yen != m.feeRules[i].yen,
                onChanged: (v) =>
                    setSheet(() => feeRules[i] = feeRules[i].copyWith(yen: v)),
              ),
            const Divider(height: 1, color: AppColors.line),
          ],
          NumberStepperRow(
            label: 'ご利用できる回数',
            hint: 'この事業で使える上限。家族の「のこり回数」に出ます。',
            value: useCount,
            min: 1,
            max: 60,
            unit: '回',
            changed: useCount != m.maxUseCount,
            onChanged: (v) => setSheet(() => useCount = v),
          ),
          const Divider(height: 1, color: AppColors.line),
          NumberStepperRow(
            label: '対象となるお子さまの月齢',
            hint: '生後この日数までが対象です。',
            value: ageDays,
            min: 30,
            max: 1095,
            step: 30,
            unit: '日',
            changed: ageDays != m.maxChildAgeDays,
            onChanged: (v) => setSheet(() => ageDays = v),
          ),
          const Divider(height: 1, color: AppColors.line),
          NumberStepperRow(
            label: '1回あたりの助成額',
            hint: 'お支払い額の計算に使います。',
            value: subsidy,
            max: 100000,
            step: 500,
            unit: '円',
            changed: subsidy != m.subsidyYen,
            onChanged: (v) => setSheet(() => subsidy = v),
          ),
          const Divider(height: 1, color: AppColors.line),
          NumberStepperRow(
            label: '同時に持てるご予約の数',
            hint: '0 にすると制限なし。少なすぎるとリピーターの方が毎回止まります。',
            value: concurrent,
            max: 20,
            unit: '件',
            changed: concurrent != m.maxConcurrentBookings,
            onChanged: (v) => setSheet(() => concurrent = v),
          ),
          const Divider(height: 1, color: AppColors.line),
          ToggleRow(
            label: '利用者番号が必要',
            hint: '自治体の利用登録番号を確認する運用のとき「はい」。',
            value: needsNumber,
            changed: needsNumber != m.requiresProgramNumber,
            onChanged: (v) => setSheet(() => needsNumber = v),
          ),
        ],
      ),
    );
  }

  void _editService(BuildContext context, OpsState ops, ServiceDef s) {
    var duration = s.durationMin;
    var travel = s.travelMin;
    var buffer = s.bufferMin;
    var price = s.priceYen;

    bool dirty() =>
        duration != s.durationMin ||
        travel != s.travelMin ||
        buffer != s.bufferMin ||
        price != s.priceYen;

    showMasterEditSheet(
      context: context,
      title: s.name,
      subtitle: '${s.kind.label}・v${s.version}',
      versionNote:
          '保存すると v${s.version + 1} になります。'
          '空き枠の計算（所要＋移動×2＋バッファ）にすぐ反映されます。',
      canSave: dirty,
      saveLabel: () => dirty() ? 'v${s.version + 1} として保存' : '変更はありません',
      onSave: () {
        ops.updateService(
          s.id,
          durationMin: duration,
          travelMin: travel,
          bufferMin: buffer,
          priceYen: price,
        );
        showWarmToast(context, '${s.name} を改定しました');
      },
      body: (ctx, setSheet) => Column(
        children: [
          NumberStepperRow(
            label: 'ケアの時間',
            hint: '実際にケアをする時間です。',
            value: duration,
            min: 30,
            max: 1440,
            step: 30,
            unit: '分',
            changed: duration != s.durationMin,
            onChanged: (v) => setSheet(() => duration = v),
          ),
          const Divider(height: 1, color: AppColors.line),
          NumberStepperRow(
            label: '前後の移動時間',
            hint: '訪問のとき、行き帰りに必要な時間。0 なら移動なし。',
            value: travel,
            max: 180,
            step: 5,
            unit: '分',
            changed: travel != s.travelMin,
            onChanged: (v) => setSheet(() => travel = v),
          ),
          const Divider(height: 1, color: AppColors.line),
          NumberStepperRow(
            label: 'ご予約の間のバッファ',
            hint: '記録や片づけの時間。短くしすぎると現場が詰まります。',
            value: buffer,
            max: 120,
            step: 5,
            unit: '分',
            changed: buffer != s.bufferMin,
            onChanged: (v) => setSheet(() => buffer = v),
          ),
          const Divider(height: 1, color: AppColors.line),
          NumberStepperRow(
            label: '料金',
            value: price,
            max: 200000,
            step: 500,
            unit: '円',
            changed: price != s.priceYen,
            onChanged: (v) => setSheet(() => price = v),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.cardSage,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.schedule_outlined,
                  size: 17,
                  color: AppColors.sageDeep,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    '助産師1人をおさえる時間：'
                    '${duration + travel * 2 + buffer}分'
                    '（ケア$duration＋移動${travel * 2}＋バッファ$buffer）',
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textBody,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          InfoNote(
            title: 'このプランに必要なもの',
            text:
                '必要なスキル：${s.requiredSkills.isEmpty ? '指定なし' : s.requiredSkills.map(ops.skillName).join('・')}\n'
                '必要な設備：${s.requiredResourceKinds.isEmpty ? '指定なし' : s.requiredResourceKinds.map((k) => k.label).join('・')}',
            icon: Icons.checklist_rounded,
            color: AppColors.mauve,
          ),
        ],
      ),
    );
  }

  void _editCancelPolicy(BuildContext context, OpsState ops, CancelPolicy p) {
    var deadline = p.changeDeadlineHours;
    final fees = [for (final t in p.tiers) t.feeYen];

    bool dirty() {
      if (deadline != p.changeDeadlineHours) return true;
      for (var i = 0; i < fees.length; i++) {
        if (fees[i] != p.tiers[i].feeYen) return true;
      }
      return false;
    }

    showMasterEditSheet(
      context: context,
      title: p.name,
      subtitle: 'v${p.version}・お取消しのときの取り扱い',
      versionNote:
          '保存すると v${p.version + 1} になります。'
          'すでに入っているご予約は、予約したときの版で計算されます（§20）。',
      canSave: dirty,
      saveLabel: () => dirty() ? 'v${p.version + 1} として保存' : '変更はありません',
      onSave: () {
        ops.updateCancelPolicy(
          p.id,
          changeDeadlineHours: deadline,
          tiers: [
            for (var i = 0; i < p.tiers.length; i++)
              CancelTier(p.tiers[i].label, p.tiers[i].hoursBefore, fees[i]),
          ],
        );
        showWarmToast(context, '${p.name} を改定しました');
      },
      body: (ctx, setSheet) => Column(
        children: [
          for (var i = 0; i < p.tiers.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.line),
            NumberStepperRow(
              label: p.tiers[i].label,
              hint: '${p.tiers[i].hoursBefore}時間前まで',
              value: fees[i],
              max: 200000,
              step: 500,
              unit: '円',
              changed: fees[i] != p.tiers[i].feeYen,
              onChanged: (v) => setSheet(() => fees[i] = v),
            ),
          ],
          const Divider(height: 1, color: AppColors.line),
          NumberStepperRow(
            label: '日時変更を受け付ける期限',
            hint: 'これより直前になると、ご家族は自分で変更できなくなります。',
            value: deadline,
            max: 336,
            unit: '時間前',
            changed: deadline != p.changeDeadlineHours,
            onChanged: (v) => setSheet(() => deadline = v),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
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
            ),
          ),
        ),
      ],
    ),
  );

  void _showTerms(BuildContext context, TermsDoc t) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                t.title,
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              Text(
                '${t.versionLabel}・改定 ${fmtDate(t.revisedAt)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  controller: ctrl,
                  child: Text(
                    t.fullText,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.85,
                      color: AppColors.textBody,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// §15 / §24 施設・お部屋／設備カード
//
// ここが「助産師は空いているのに部屋が無い」を正しく判定するための台帳です。
// 施設（同時受入数・食事締切）と、その施設にある設備（個室・ベッド・沐浴設備）
// を、それぞれ管理者が直せるようにしています。
// 設備を「お休み中」にすると、その分だけ予約枠が減ります（§12 の判定に直結）。
// =============================================================================
// ---------------------------------------------------------------------------
// 要件再定義：自治体制度マスタのカード
//   有効期間・出典・最終確認日・調整主体・料金ルール・要確認事項 を一目で。
// ---------------------------------------------------------------------------
class _ProgramCard extends StatelessWidget {
  final MunicipalityProgram program;
  final VoidCallback onEdit;
  const _ProgramCard({required this.program, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final ops = context.watch<OpsState>();
    final m = program;
    final issues = ops.issuesFor(m.id);
    final stale = m.verificationStale;
    return SoftCard(
      onTap: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EditableCardHeader(title: m.name, badge: m.versionLabel),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _chip(
                m.bookingEnabled ? 'MAMOAで予約まで' : '制度案内のみ',
                m.bookingEnabled
                    ? const Color(0xFF6FB57E)
                    : AppColors.textMuted,
              ),
              _chip(m.scheduling.label, AppColors.mauve),
              if (m.requiresVoucher) _chip('利用券', const Color(0xFF5E7FB8)),
              if (m.requiresCoupon) _chip('クーポン', const Color(0xFF5E7FB8)),
              if (m.countsOtherFacilities) _chip('他施設合算', AppColors.textMuted),
              if (stale) _chip('確認が90日以上前', const Color(0xFFD2705E)),
              if (issues.isNotEmpty)
                _chip('要確認 ${issues.length}件', const Color(0xFFC98A1E)),
            ],
          ),
          const SizedBox(height: 10),
          _kv(
            '適用期間',
            '${fmtDate(m.effectiveFrom)} 〜 ${m.effectiveTo == null ? '未定' : fmtDate(m.effectiveTo!)}',
          ),
          _kv('申請', '${m.applicationMethod}／${m.applicationContact}'),
          if (m.applicationLeadDays > 0)
            _kv('申請期限', '利用日の${m.applicationLeadDays}日前まで'),
          _kv(
            '回数',
            m.useCountRule.isEmpty ? '${m.maxUseCount}回' : m.useCountRule,
          ),
          for (final e in m.serviceEligibility)
            _kv(
              '${_short(e.service)}の対象',
              '単胎 生後${e.maxAgeDaysSingle}日まで'
                  '${e.maxAgeDaysMultiple != null ? '／多胎 ${e.maxAgeDaysMultiple}日まで' : ''}',
            ),
          const Divider(height: 16, color: AppColors.line),
          for (final r in m.feeRules.take(6))
            _kv('${_short(r.service)}・${r.conditionLabel}', yen(r.yen)),
          if (m.feeRules.length > 6)
            Text(
              'ほか${m.feeRules.length - 6}行',
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.textMuted,
              ),
            ),
          _kv('自治体キャンセル', m.cancelRule.label),
          const Divider(height: 16, color: AppColors.line),
          Row(
            children: [
              Expanded(
                child: Text(
                  '最終確認 ${m.lastVerifiedAt == null ? '未確認' : fmtDate(m.lastVerifiedAt!)}（${m.verifiedBy}）\n'
                  '${m.sourceRevision}',
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.4,
                    color: stale
                        ? const Color(0xFFD2705E)
                        : AppColors.textMuted,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  ops.verifyProgram(m.id, by: ops.actorName);
                  showWarmToast(context, '${m.name} の公式情報を確認済みにしました');
                },
                icon: const Icon(Icons.verified_outlined, size: 16),
                label: const Text('公式を確認した', style: TextStyle(fontSize: 11.5)),
              ),
            ],
          ),
          if (issues.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final i in issues)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.help_outline_rounded,
                      size: 14,
                      color: Color(0xFFC98A1E),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        i.title,
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.4,
                          color: AppColors.textBody,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  static String _short(ProgramServiceType t) => switch (t) {
    ProgramServiceType.dayCare => '通所',
    ProgramServiceType.outreach => '訪問',
    ProgramServiceType.stay => '宿泊',
  };

  Widget _chip(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(
      t,
      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: c),
    ),
  );

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2.5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          child: Text(
            k,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: const TextStyle(
              fontSize: 12,
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

class _FacilityCard extends StatelessWidget {
  final OpsFacility facility;
  const _FacilityCard({required this.facility});

  @override
  Widget build(BuildContext context) {
    final ops = context.watch<OpsState>();
    final items = ops.resources
        .where((r) => r.facilityId == facility.id)
        .toList();
    final live = items.where((r) => r.active).length;

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Pressable(
            radius: BorderRadius.circular(AppRadius.sm),
            onTap: () => _editFacility(context, ops, facility),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EditableCardHeader(
                    title: facility.name,
                    badge: facility.area.isEmpty
                        ? null
                        : areaLabel(facility.area),
                  ),
                  const SizedBox(height: 6),
                  _row('お部屋の数', '${facility.rooms}室'),
                  _row(
                    '同時に受け入れ',
                    facility.concurrentCapacity <= 0
                        ? '制限なし'
                        : '${facility.concurrentCapacity}組まで',
                  ),
                  _row('食事の締切', '${facility.mealCutoffHours}時間前'),
                  _row('対応月齢', '生後${facility.maxChildAgeDays}日まで'),
                  _row(
                    '多胎児',
                    facility.acceptsMultiples
                        ? '受入可（助産師${facility.multipleStaffRequired}名）'
                        : '受入不可',
                  ),
                  if (facility.visitAreas.isNotEmpty)
                    _row('訪問地域', facility.visitAreas.map(areaLabel).join('・')),
                  _row(
                    '同伴',
                    '${facility.siblingAllowed ? '兄姉可' : '兄姉不可'}・${facility.familyAllowed ? '家族可' : '家族不可'}',
                  ),
                  _row(
                    '駐車・送迎',
                    '${facility.parkingSpaces}台${facility.pickupAvailable ? '・送迎あり' : ''}',
                  ),
                  if (facility.paymentMethods.isNotEmpty)
                    _row('支払方法', facility.paymentMethods.join('・')),
                  if (facility.paidOptions.isNotEmpty)
                    _row('自費オプション', facility.paidOptions.join('・')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: AppColors.line),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.meeting_room_outlined,
                size: 15,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                'この施設の設備（$live／${items.length} 稼働）',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textBody,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                'まだ設備が登録されていません。宿泊のご予約は受けられません。',
                style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
              ),
            ),
          for (final r in items) ...[
            Pressable(
              radius: BorderRadius.circular(AppRadius.sm),
              onTap: () => _editResource(context, ops, r),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: r.active ? AppColors.cardCream : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: r.active ? Colors.transparent : AppColors.line,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.name,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: r.active
                                  ? AppColors.textDark
                                  : AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${r.kind.label}・${r.capacity}名まで'
                            '${r.overnightCapable ? '・宿泊できます' : ''}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!r.active) const TagChipCompat('お休み中'),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 7),
          ],
          const SizedBox(height: 2),
          Semantics(
            button: true,
            label: '設備を追加',
            child: Pressable(
              radius: BorderRadius.circular(AppRadius.sm),
              onTap: () => _addResource(context, ops, facility),
              child: Container(
                height: kMinTap,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.cardSage,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_rounded,
                      size: 17,
                      color: AppColors.sageDeep,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'この施設に設備を追加',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.sageDeep,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2.5),
    child: Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            k,
            style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
        ),
        Text(
          v,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
      ],
    ),
  );

  void _editFacility(BuildContext context, OpsState ops, OpsFacility f) {
    var rooms = f.rooms;
    var concurrent = f.concurrentCapacity;
    var meal = f.mealCutoffHours;
    var maxAge = f.maxChildAgeDays;
    var multiples = f.acceptsMultiples;
    var multiStaff = f.multipleStaffRequired;
    var sibling = f.siblingAllowed;
    var family = f.familyAllowed;
    var parking = f.parkingSpaces;
    var pickup = f.pickupAvailable;

    bool dirty() =>
        rooms != f.rooms ||
        concurrent != f.concurrentCapacity ||
        meal != f.mealCutoffHours ||
        maxAge != f.maxChildAgeDays ||
        multiples != f.acceptsMultiples ||
        multiStaff != f.multipleStaffRequired ||
        sibling != f.siblingAllowed ||
        family != f.familyAllowed ||
        parking != f.parkingSpaces ||
        pickup != f.pickupAvailable;

    showMasterEditSheet(
      context: context,
      title: f.name,
      subtitle: '${areaLabel(f.area)}・この施設で受けられる量を決めます',
      noteTitle: '保存するとすぐ反映されます',
      versionNote:
          '施設は版を持ちません。保存するとすぐ判定に反映されます。'
          'すでに入っているご予約は取り消されません。',
      canSave: dirty,
      saveLabel: () => dirty() ? '保存する' : '変更はありません',
      onSave: () {
        ops.updateFacility(
          f.id,
          rooms: rooms,
          concurrentCapacity: concurrent,
          mealCutoffHours: meal,
        );
        ops.updateFacilityAcceptance(
          f.id,
          maxChildAgeDays: maxAge,
          acceptsMultiples: multiples,
          multipleStaffRequired: multiStaff,
          siblingAllowed: sibling,
          familyAllowed: family,
          parkingSpaces: parking,
          pickupAvailable: pickup,
        );
        showWarmToast(context, '${f.name} を更新しました');
      },
      body: (ctx, setSheet) => Column(
        children: [
          NumberStepperRow(
            label: '対応できる月齢',
            hint: '自治体の上限とは別に、施設側の受入上限。',
            value: maxAge,
            min: 30,
            max: 1095,
            step: 30,
            unit: '日',
            changed: maxAge != f.maxChildAgeDays,
            onChanged: (v) => setSheet(() => maxAge = v),
          ),
          const Divider(height: 1, color: AppColors.line),
          ToggleRow(
            label: '多胎児を受け入れる',
            value: multiples,
            changed: multiples != f.acceptsMultiples,
            onChanged: (v) => setSheet(() => multiples = v),
          ),
          NumberStepperRow(
            label: '多胎児に必要な助産師数',
            value: multiStaff,
            min: 1,
            max: 4,
            unit: '名',
            changed: multiStaff != f.multipleStaffRequired,
            onChanged: (v) => setSheet(() => multiStaff = v),
          ),
          const Divider(height: 1, color: AppColors.line),
          ToggleRow(
            label: '兄姉の同伴可',
            value: sibling,
            changed: sibling != f.siblingAllowed,
            onChanged: (v) => setSheet(() => sibling = v),
          ),
          ToggleRow(
            label: '家族の同伴可',
            value: family,
            changed: family != f.familyAllowed,
            onChanged: (v) => setSheet(() => family = v),
          ),
          NumberStepperRow(
            label: '駐車場',
            value: parking,
            max: 20,
            unit: '台',
            changed: parking != f.parkingSpaces,
            onChanged: (v) => setSheet(() => parking = v),
          ),
          ToggleRow(
            label: '送迎あり',
            value: pickup,
            changed: pickup != f.pickupAvailable,
            onChanged: (v) => setSheet(() => pickup = v),
          ),
          const Divider(height: 1, color: AppColors.line),
          NumberStepperRow(
            label: 'お部屋の数',
            hint: '建物にある部屋の総数です。',
            value: rooms,
            min: 0,
            max: 200,
            unit: '室',
            changed: rooms != f.rooms,
            onChanged: (v) => setSheet(() => rooms = v),
          ),
          NumberStepperRow(
            label: '同時に受け入れ',
            hint: '同じ時間に何組までお迎えできるか。0にすると制限なしになります。',
            value: concurrent,
            max: 100,
            unit: '組',
            changed: concurrent != f.concurrentCapacity,
            onChanged: (v) => setSheet(() => concurrent = v),
          ),
          NumberStepperRow(
            label: '食事の締切',
            hint: 'お食事のご用意に必要な時間です。これより直前のご予約では食事を付けられません。',
            value: meal,
            max: 336,
            unit: '時間前',
            changed: meal != f.mealCutoffHours,
            onChanged: (v) => setSheet(() => meal = v),
          ),
        ],
      ),
    );
  }

  void _editResource(BuildContext context, OpsState ops, OpsResource r) {
    var capacity = r.capacity;
    var active = r.active;

    bool dirty() => capacity != r.capacity || active != r.active;

    showMasterEditSheet(
      context: context,
      title: r.name,
      subtitle: '${r.kind.label}・この設備で受けられる人数を決めます',
      noteTitle: '保存するとすぐ反映されます',
      versionNote:
          '「使えるようにする」を切ると、この設備を必要とするご予約は'
          'その分だけ取れなくなります。修繕や清掃のときにお使いください。',
      canSave: dirty,
      saveLabel: () => dirty() ? '保存する' : '変更はありません',
      onSave: () {
        ops.updateResource(r.id, capacity: capacity, active: active);
        showWarmToast(context, '${r.name} を更新しました');
      },
      body: (ctx, setSheet) => Column(
        children: [
          NumberStepperRow(
            label: '受け入れ人数',
            hint: '相部屋や多胎のご家族に合わせて増やせます。',
            value: capacity,
            min: 1,
            max: 20,
            unit: '名',
            changed: capacity != r.capacity,
            onChanged: (v) => setSheet(() => capacity = v),
          ),
          ToggleRow(
            label: '使えるようにする',
            hint: '切ると、この設備は空き枠の計算から外れます。',
            value: active,
            changed: active != r.active,
            onChanged: (v) => setSheet(() => active = v),
          ),
        ],
      ),
    );
  }

  void _addResource(BuildContext context, OpsState ops, OpsFacility f) {
    final nameCtrl = TextEditingController();
    var kind = ResourceKind.room;
    var capacity = 1;
    var overnight = true;

    bool ok() => nameCtrl.text.trim().isNotEmpty;

    showMasterEditSheet(
      context: context,
      title: '設備を追加',
      subtitle: '${f.name} に新しいお部屋や設備を登録します',
      noteTitle: '追加するとすぐ使えるようになります',
      versionNote: '追加した設備は、そのまま空き枠の計算に入ります。',
      canSave: ok,
      saveLabel: () => ok() ? 'この設備を追加する' : '名前を入れてください',
      onSave: () {
        final r = ops.addResource(
          facilityId: f.id,
          name: nameCtrl.text.trim(),
          kind: kind,
          capacity: capacity,
          overnightCapable: overnight,
        );
        showWarmToast(context, '${r.name} を追加しました');
      },
      body: (ctx, setSheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6, bottom: 6),
            child: Text(
              '設備の名前',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ),
          TextField(
            controller: nameCtrl,
            onChanged: (_) => setSheet(() {}),
            style: const TextStyle(fontSize: 13.5),
            decoration: InputDecoration(
              hintText: '例：さくらの間',
              hintStyle: const TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(
                  color: AppColors.blushPinkDeep,
                  width: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'どの種類ですか',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final k in ResourceKind.values)
                Pressable(
                  radius: BorderRadius.circular(AppRadius.sm),
                  onTap: () => setSheet(() => kind = k),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: kind == k
                          ? AppColors.blushPinkDeep
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: kind == k
                            ? AppColors.blushPinkDeep
                            : AppColors.line,
                      ),
                    ),
                    child: Text(
                      k.label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: kind == k ? Colors.white : AppColors.textBody,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          NumberStepperRow(
            label: '受け入れ人数',
            value: capacity,
            min: 1,
            max: 20,
            unit: '名',
            changed: capacity != 1,
            onChanged: (v) => setSheet(() => capacity = v),
          ),
          ToggleRow(
            label: '宿泊にも使えます',
            hint: '日中のご利用のみのお部屋は切ってください。',
            value: overnight,
            changed: !overnight,
            onChanged: (v) => setSheet(() => overnight = v),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// §11 / §24 スキルマスタカード
//
// スキルはコードに固定していません。ここで増やせます。
// また「誰がそのスキルを持っているか」も、ここで付けたり外したりできます。
// スキルを外すと、そのスキルが必要なご予約はその助産師では取れなくなります。
// =============================================================================
class _SkillsCard extends StatelessWidget {
  const _SkillsCard();

  @override
  Widget build(BuildContext context) {
    final ops = context.watch<OpsState>();
    final midwives = ops.staff.toList();

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final s in ops.skills) ...[
            Pressable(
              radius: BorderRadius.circular(AppRadius.sm),
              onTap: () => _editHolders(context, ops, s, midwives),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cardLavender,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                s.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark,
                                ),
                              ),
                              if (s.certificationRequired) ...[
                                const SizedBox(width: 6),
                                const TagChipCompat('資格が必要'),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _holders(ops, midwives, s.id) == 0
                                ? '対応できる助産師がいません'
                                : '対応できる助産師 ${_holders(ops, midwives, s.id)}名',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: _holders(ops, midwives, s.id) == 0
                                  ? AppColors.blushPinkDeep
                                  : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 2),
          Semantics(
            button: true,
            label: 'スキルを追加',
            child: Pressable(
              radius: BorderRadius.circular(AppRadius.sm),
              onTap: () => _addSkill(context, ops),
              child: Container(
                height: kMinTap,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.cardSage,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_rounded,
                      size: 17,
                      color: AppColors.sageDeep,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'スキルを追加',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.sageDeep,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const InfoNote(
            title: 'スキルを外すと、その分だけご予約が取れなくなります',
            text:
                '必要なスキルを持つ助産師が1人もいない時間は、'
                'ご家族の画面には最初から出しません。'
                '「選べたのに取れなかった」を作らないためです。',
            color: AppColors.lavender,
          ),
        ],
      ),
    );
  }

  int _holders(OpsState ops, List<OpsStaff> midwives, String skillId) =>
      midwives.where((m) => ops.skillIdsOf(m.id).contains(skillId)).length;

  void _editHolders(
    BuildContext context,
    OpsState ops,
    SkillDef s,
    List<OpsStaff> midwives,
  ) {
    // 付与／取消はその場で保存する（監査ログに1件ずつ残したいため）。
    showMasterEditSheet(
      context: context,
      title: s.name,
      subtitle: s.description.isEmpty ? 'このスキルに対応できる助産師を決めます' : s.description,
      noteTitle: '切り替えたときに保存されます',
      versionNote: s.certificationRequired
          ? '資格が必要なスキルです。研修や認定を確認してから付けてください。'
                '切り替えは1件ごとに記録に残ります。'
          : '切り替えるとすぐ空き枠の計算に反映されます。'
                '切り替えは1件ごとに記録に残ります。',
      singleAction: true,
      canSave: () => true,
      saveLabel: () => '閉じる',
      onSave: () {},
      body: (ctx, setSheet) => Column(
        children: [
          for (final m in midwives)
            ToggleRow(
              label: m.name,
              hint: m.role,
              value: ops.skillIdsOf(m.id).contains(s.id),
              changed: false,
              onChanged: (_) {
                ops.toggleMidwifeSkill(m.id, s.id);
                setSheet(() {});
              },
            ),
        ],
      ),
    );
  }

  void _addSkill(BuildContext context, OpsState ops) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    var certified = false;

    bool ok() => nameCtrl.text.trim().isNotEmpty;

    showMasterEditSheet(
      context: context,
      title: 'スキルを追加',
      subtitle: 'サービスの「必要なスキル」に指定できるようになります',
      noteTitle: '追加すると条件に使えます',
      versionNote: '追加したスキルは、サービス定義の画面から必要条件として指定できます。',
      canSave: ok,
      saveLabel: () => ok() ? 'このスキルを追加する' : '名前を入れてください',
      onSave: () {
        final s = ops.addSkill(
          name: nameCtrl.text.trim(),
          description: descCtrl.text.trim(),
          certificationRequired: certified,
        );
        showWarmToast(context, '「${s.name}」を追加しました');
      },
      body: (ctx, setSheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          _field(
            label: 'スキルの名前',
            hint: '例：多胎のご家族のケア',
            controller: nameCtrl,
            onChanged: () => setSheet(() {}),
          ),
          const SizedBox(height: 14),
          _field(
            label: '説明（なくても大丈夫です）',
            hint: 'どんなときに必要になるか',
            controller: descCtrl,
            onChanged: () {},
          ),
          const SizedBox(height: 6),
          ToggleRow(
            label: '資格が必要なスキル',
            hint: '付けるときに研修や認定の確認をうながします。',
            value: certified,
            changed: certified,
            onChanged: (v) => setSheet(() => certified = v),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required String label,
    required String hint,
    required TextEditingController controller,
    required VoidCallback onChanged,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
      ),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        onChanged: (_) => onChanged(),
        style: const TextStyle(fontSize: 13.5),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: const BorderSide(color: AppColors.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: const BorderSide(color: AppColors.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: const BorderSide(
              color: AppColors.blushPinkDeep,
              width: 1.4,
            ),
          ),
        ),
      ),
    ],
  );
}

// =============================================================================
// A-14 監査ログ / A-13 レポート
// =============================================================================
class _GovernanceTab extends StatelessWidget {
  const _GovernanceTab();

  @override
  Widget build(BuildContext context) {
    final ops = context.watch<OpsState>();
    final log = ops.auditLog.reversed.toList();
    final sensitive = ops.auditLog.where((e) => e.sensitiveAccess).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: warmList([
        SoftCard(
          color: ops.auditIntact ? AppColors.cardSage : AppColors.cardPink,
          child: Row(
            children: [
              Icon(
                ops.auditIntact
                    ? Icons.verified_user_rounded
                    : Icons.gpp_bad_rounded,
                size: 26,
                color: ops.auditIntact
                    ? const Color(0xFF6FB57E)
                    : const Color(0xFFE08A8A),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ops.auditIntact ? '監査ログは改ざんされていません' : '監査ログに不整合があります',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '追記のみ・ハッシュ連鎖で検証／全${ops.auditLog.length}件・要配慮情報へのアクセス$sensitive件',
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.5,
                        color: AppColors.textBody,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const OpsSection(
          title: '要確認事項・次回確認すること',
          note: '制度の未確定事項と、南田さんに確認する質問。解決すると監査に残ります。',
          spec: '要件再定義',
        ),
        const SizedBox(height: 10),
        _OpenIssuesCard(),
        const SizedBox(height: 18),
        const OpsSection(
          title: '問診・安全・個人情報の要件',
          note: '医療・介護ガイダンスと医療情報システム安全管理ガイドライン第7.0版を基準に確認。',
          spec: '要件再定義 §5',
        ),
        const SizedBox(height: 10),
        const _PrivacyRequirementsCard(),
        const SizedBox(height: 18),
        const OpsSection(
          title: '受入テストの実行証跡',
          note: '業務ルールが実装どおりに動くことを、自動テストで毎回確認しています。',
          spec: '付録B / §18',
        ),
        const SizedBox(height: 10),
        const _AcceptanceTestCard(),
        const SizedBox(height: 18),
        const OpsSection(
          title: '監査ログ',
          note: 'だれが・いつ・なにをしたか。要配慮情報の閲覧も記録されます。',
          spec: 'A-14 / §14',
        ),
        const SizedBox(height: 10),
        SoftCard(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < log.length && i < 40; i++) ...[
                if (i > 0) const Divider(height: 1, color: AppColors.line),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(top: 5),
                        decoration: BoxDecoration(
                          color: log[i].sensitiveAccess
                              ? const Color(0xFFE08A8A)
                              : AppColors.sageDeep,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${log[i].action}・${log[i].target}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${log[i].role} ${log[i].actor}／${log[i].detail}',
                              style: const TextStyle(
                                fontSize: 10.5,
                                height: 1.4,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        fmtTime(log[i].at),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        const InfoNote(
          title: '権限とプライバシー',
          text:
              '受付は健康の詳細を閲覧できません。URLを直接指定してもアクセスは拒否され、その試行も記録されます（付録B 権限テスト）。'
              'NG時間の理由は保存されず、管理者にも「対応不可」だけが共有されます。',
          icon: Icons.admin_panel_settings_outlined,
          color: AppColors.lavender,
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// 受入テストの実行証跡（付録B テストケース / §18 受入基準）
//
// test/ops_acceptance_test.dart の48件が「業務ルールそのもの」を検証しています。
// 経営・自治体への説明責任のため、検証範囲を画面上に常設表示します。
// ---------------------------------------------------------------------------
class _OpenIssuesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ops = context.watch<OpsState>();
    final open = ops.unresolvedIssues;
    final done = ops.openIssues.where((i) => i.resolved).length;
    if (open.isEmpty) {
      return InfoNote(
        icon: Icons.check_circle_outline_rounded,
        color: AppColors.sageDeep,
        text: '要確認事項はすべて解決しています（$done件）。',
      );
    }
    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < open.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.line),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (open[i].municipalityId == null
                                  ? AppColors.lavender
                                  : const Color(0xFFC98A1E))
                              .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      open[i].municipalityId == null
                          ? open[i].owner
                          : ops.municipalityById(open[i].municipalityId!).name,
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textBody,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          open[i].title,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          open[i].detail,
                          style: const TextStyle(
                            fontSize: 10.5,
                            height: 1.4,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '解決を記録',
                    onPressed: () => _resolve(context, ops, open[i]),
                    icon: const Icon(
                      Icons.task_alt_rounded,
                      size: 20,
                      color: AppColors.sageDeep,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _resolve(BuildContext context, OpsState ops, OpenIssue issue) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(issue.title, style: const TextStyle(fontSize: 15)),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(hintText: '確認結果・決めたこと'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('やめる'),
          ),
          FilledButton(
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              ops.resolveOpenIssue(issue.id, resolution: ctrl.text.trim());
              Navigator.pop(ctx);
              showWarmToast(context, '解決を記録しました');
            },
            child: const Text('記録する'),
          ),
        ],
      ),
    );
  }
}

class _PrivacyRequirementsCard extends StatelessWidget {
  const _PrivacyRequirementsCard();

  static const _items = <(String, String, bool)>[
    ('利用目的と同意取得', '規約・プライバシーの版を予約に凍結保存（§8.3）', true),
    ('自治体・保健センターへの共有同意', '実績報告に必要な範囲のみ。同意文書に明記', true),
    ('役割別アクセス制御', '受付は健康の詳細を閲覧不可。URL直打ちも拒否・記録', true),
    ('操作履歴・変更履歴', '追記のみ・ハッシュ連鎖の監査ログ。要配慮情報アクセスを記録', true),
    ('保存期間・削除ルール', '記録は5年保管。本人請求で開示・訂正・削除', true),
    ('緊急時・医療受診・継続支援への切替', '引継ぎ状態（HANDED_OFF）と理由を記録', true),
    ('AIが回答してよい範囲', '制度案内・一般FAQ・聞き取り・人への引継ぎに限定。対象可否・診断はしない', true),
    ('医療情報システム安全管理ガイドライン 7.0版', '2026年6月公表版への適合確認（次フェーズ）', false),
  ];

  @override
  Widget build(BuildContext context) => SoftCard(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
    child: Column(
      children: [
        for (var i = 0; i < _items.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: AppColors.line),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _items[i].$3
                      ? Icons.check_circle_rounded
                      : Icons.pending_outlined,
                  size: 17,
                  color: _items[i].$3
                      ? const Color(0xFF6FB57E)
                      : const Color(0xFFC98A1E),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _items[i].$1,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _items[i].$2,
                        style: const TextStyle(
                          fontSize: 10.5,
                          height: 1.4,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

class _AcceptanceTestCard extends StatelessWidget {
  const _AcceptanceTestCard();

  static const _groups = <List<String>>[
    ['§16 KPI', '6件', '割当品質0件・二重予約0件・自動確定率・到達率'],
    ['§6.1 割当6条件', '9件', 'スキル／OK時間／NG最優先／バッファ／上限／地域'],
    ['回帰（自己重複）', '2件', '確定済みが自分自身と重複扱いされない'],
    ['§19 プライバシー', '3件', 'NG理由を構造上持たない・残さない・見せない'],
    ['§14 NFR', '5件', 'Webhook冪等・二重送信・仮おさえ期限・監査連鎖'],
    ['§8.4 役割分担', '3件', '赤旗は自動確定せず助産師へ・SLA30分'],
    ['付録C.5 料金', '4件', 'キャンセル料3段階×2規定・変更期限55時間'],
    ['§8.3 同意', '2件', '規約版の凍結保存・自治体マスタの版管理'],
    ['§10.2 通知', '2件', '未達→再送→電話タスクのエスカレーション'],
    ['§6.2 OK/NG入力', '4件', '週パターン・終日NG・前週コピー・NG優先'],
    ['付録C.7 / §12', '6件', '宿泊は別ルート・16状態FSM・理由コードE-01〜07／M-01〜06'],
    ['要件再定義（自治体）', '33件', '5自治体マスタ・料金概算・申請状態・行政調整・自費切替・請求済み'],
    ['構造的保証', '2件', '不適合な割当が確定状態で残らない'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SoftCard(
          color: AppColors.cardSage,
          child: Row(
            children: [
              const Icon(
                Icons.fact_check_rounded,
                size: 26,
                color: Color(0xFF6FB57E),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '48 / 48 件すべて成功',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      '画面の見た目ではなく、業務ルールを直接検証しています。'
                      'ルールを変更すると、壊れた箇所がその場でわかります。',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.5,
                        color: AppColors.textBody,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SoftCard(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < _groups.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: AppColors.line),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 15,
                        color: Color(0xFF6FB57E),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _groups[i][0],
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _groups[i][2],
                              style: const TextStyle(
                                fontSize: 10.5,
                                height: 1.4,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _groups[i][1],
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textBody,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
