import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_nav.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../ops_models.dart';
import '../ops_state.dart';
import 'booking_detail_screen.dart';
import 'booking_wizard_screen.dart';
import 'municipality_guide_screen.dart';
import 'ops_ui.dart';

/// 家族向けシェル（§10.1 リッチメニュー / 付録C.2）
/// LINEを開く → 用件を選ぶ → 条件に合う枠を選ぶ → 確認して終わり。
/// チャットは例外・緊急・人の判断が必要なときだけ。
class FamilyShell extends StatelessWidget {
  const FamilyShell({super.key});

  @override
  Widget build(BuildContext context) {
    final ops = context.watch<OpsState>();
    final next = ops.nextBooking;
    final action = ops.actionRequired;
    final history = ops.familyBookings
        .where(
          (b) =>
              b.state == BookingState.completed ||
              b.state == BookingState.cancelled,
        )
        .toList();

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: warmList([
            _header(context, ops),
            const SizedBox(height: 12),
            _ApplicationBanner(),
            const SizedBox(height: 18),

            // 要対応（最優先）
            if (action.isNotEmpty) ...[
              const OpsSection(
                title: 'ご確認をお願いします',
                note: 'いま、あなたの手続きでとまっているものです。',
                spec: 'C-04',
              ),
              const SizedBox(height: 10),
              for (final b in action) ...[
                _ActionCard(booking: b),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 12),
            ],

            // 次回予約
            const OpsSection(title: '次のご予約', spec: 'C-03'),
            const SizedBox(height: 10),
            if (next == null)
              const WarmEmptyState(
                icon: Icons.event_available_outlined,
                title: 'ご予約はまだありません',
                message: 'したいことを選ぶだけで、\n条件に合う時間をおすすめします。',
                color: AppColors.blushPink,
              )
            else
              _NextBookingCard(booking: next),

            const SizedBox(height: 22),

            // リッチメニュー相当
            const OpsSection(
              title: 'できること',
              note: 'ボタンで終わります。文章を書く必要はありません。',
              spec: 'C-02 / §10.1',
            ),
            const SizedBox(height: 12),
            _menuGrid(context, ops),

            const SizedBox(height: 22),

            // 履歴
            if (history.isNotEmpty) ...[
              const OpsSection(title: 'これまでのご利用', spec: 'C-12'),
              const SizedBox(height: 10),
              for (final b in history.take(4)) ...[
                _historyRow(context, ops, b),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 12),
            ],

            const InfoNote(
              title: 'いつでも人につながります',
              text:
                  '不安なとき、いそぐとき、うまく言えないとき。「相談する」から助産師・スタッフに直接つながります。ボタンで解決しないことは、人が受け取ります。',
              icon: Icons.volunteer_activism_outlined,
              color: AppColors.lavender,
            ),
          ]),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, OpsState ops) {
    final c = ops.customer;
    final child = c.children.first;
    final m = ops.municipalityById(c.municipalityId);
    final remain =
        (m.maxUseCount -
                c.usedCount -
                (m.countsOtherFacilities ? c.application.otherFacilityUses : 0))
            .clamp(0, 99);
    final app = c.application.status;
    return SoftCard(
      color: AppColors.cardPink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const MamoaLogo(size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${c.nameKanji}さん、こんにちは',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${child.name}・${child.ageLabel}',
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
          const Divider(height: 22, color: Colors.white70),
          Row(
            children: [
              Expanded(
                child: _stat(
                  'のこり回数',
                  '$remain回',
                  remain <= 1 ? const Color(0xFFD97A7A) : AppColors.mauve,
                ),
              ),
              Container(width: 1, height: 30, color: Colors.white),
              Expanded(
                child: _stat(
                  '申請',
                  app.label,
                  app.canRequest
                      ? const Color(0xFF6FB57E)
                      : const Color(0xFFC98A1E),
                ),
              ),
              Container(width: 1, height: 30, color: Colors.white),
              Expanded(child: _stat('自治体', m.name, AppColors.mauve)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String k, String v, Color c) => Column(
    children: [
      Text(
        v,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c),
      ),
      const SizedBox(height: 2),
      Text(k, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
    ],
  );

  /// §5 家族トップの5カテゴリ。「予約を確認・変更する」は1つに束ね、
  /// 「どれを選べばよいか相談する」を独立させる（迷いを画面に置かない）。
  Widget _menuGrid(BuildContext context, OpsState ops) {
    final items = <_MenuItem>[
      _MenuItem(
        '産後ケアを利用する',
        '訪問・通所・宿泊から',
        Icons.spa_outlined,
        AppColors.blushPinkDeep,
        () => _go(context, BookingPurpose.newBooking),
      ),
      _MenuItem(
        '母乳・授乳の相談をする',
        'そのまま予約できます',
        Icons.water_drop_outlined,
        AppColors.mauve,
        () => _goBreast(context, ops),
      ),
      _MenuItem(
        'イベント・講座',
        'あつまる・まなぶ',
        Icons.groups_2_outlined,
        AppColors.softYellow,
        () => _events(context),
      ),
      _MenuItem(
        '予約を確認・変更する',
        '変更・お取消し・キャンセル待ち',
        Icons.event_note_outlined,
        AppColors.lavender,
        () => _manageBookings(context, ops),
      ),
      _MenuItem(
        'どれを選べばよいか相談する',
        '人がお返事します',
        Icons.chat_bubble_outline_rounded,
        AppColors.sageDeep,
        () => _triage(context, ops),
      ),
      _MenuItem(
        '自治体の制度・申請',
        '申請の流れ・料金の目安',
        Icons.account_balance_outlined,
        const Color(0xFF5E7FB8),
        () =>
            Navigator.push(context, warmRoute(const MunicipalityGuideScreen())),
      ),
    ];

    // §21 リピーターには最短導線を最上段に単独で出す（最優先）
    final plan = ops.buildRepeatPlan();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (plan != null && !plan.unavailable) ...[
          _RepeatCta(plan: plan),
          const SizedBox(height: 12),
        ],
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.32,
          children: [
            for (final it in items)
              Semantics(
                button: true,
                label: '${it.title}。${it.sub}',
                child: Pressable(
                  radius: BorderRadius.circular(AppRadius.lg),
                  onTap: it.onTap,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      boxShadow: AppShadows.card,
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: it.color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(it.icon, size: 20, color: it.color),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              it.title,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              it.sub,
                              style: const TextStyle(
                                fontSize: 10.5,
                                height: 1.3,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  void _go(BuildContext context, BookingPurpose p) {
    Navigator.push(context, warmRoute(BookingWizardScreen(purpose: p)));
  }

  /// §7 母乳外来は即時予約（用件が決まっているので目的選択を飛ばす）
  void _goBreast(BuildContext context, OpsState ops) {
    Navigator.push(
      context,
      warmRoute(
        const BookingWizardScreen(presetKind: ServiceKind.breastClinic),
      ),
    );
  }

  /// §5 イベント・講座（P2 の本実装は行わず、導線と案内だけ用意する）
  void _events(BuildContext context) {
    showWarmDialog(
      context,
      icon: Icons.groups_2_outlined,
      title: 'イベント・講座',
      message:
          'おっぱい教室、ベビーマッサージ、産後ヨガなどのご案内です。'
          '開催が決まりしだい、こちらとLINEでお知らせします。',
      color: AppColors.softYellow,
      primaryLabel: 'とじる',
    );
  }

  /// §5 「予約を確認・変更する」— 変更・取消・キャンセル待ちを1つに束ねる
  void _manageBookings(BuildContext context, OpsState ops) {
    final active = ops.familyBookings.where((b) => b.state.isActive).toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
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
              'ご予約について',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              active.isEmpty
                  ? 'いま、有効なご予約はありません。'
                  : '${active.length}件のご予約があります。',
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 14),
            ChoiceTile(
              title: '日時を変える',
              subtitle: '規定内なら自動で調整します',
              icon: Icons.edit_calendar_outlined,
              selected: false,
              color: AppColors.lavender,
              onTap: () {
                Navigator.pop(context);
                _changeOrCancel(context, ops, true);
              },
            ),
            const SizedBox(height: 8),
            ChoiceTile(
              title: 'お取消し',
              subtitle: '料金は先にお伝えします',
              icon: Icons.event_busy_outlined,
              selected: false,
              color: const Color(0xFFE08A8A),
              onTap: () {
                Navigator.pop(context);
                _changeOrCancel(context, ops, false);
              },
            ),
            const SizedBox(height: 8),
            ChoiceTile(
              title: 'キャンセル待ちにする',
              subtitle: '空きが出たらお知らせします',
              icon: Icons.notifications_active_outlined,
              selected: false,
              color: AppColors.softYellow,
              onTap: () {
                Navigator.pop(context);
                _go(context, BookingPurpose.waitlist);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _changeOrCancel(BuildContext context, OpsState ops, bool change) {
    final list = ops.familyBookings.where((b) => b.state.isActive).toList();
    if (list.isEmpty) {
      showWarmDialog(
        context,
        icon: Icons.event_available_outlined,
        title: 'ご予約がありません',
        message: '変更・お取消しできるご予約は、いまありません。',
        color: AppColors.lavender,
        primaryLabel: 'とじる',
      );
      return;
    }
    if (list.length == 1) {
      Navigator.push(
        context,
        warmRoute(BookingDetailScreen(bookingId: list.first.id)),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
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
            Text(
              change ? 'どのご予約を変えますか' : 'どのご予約をお取消ししますか',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),
            for (final b in list) ...[
              ChoiceTile(
                title: ops.serviceById(b.serviceId).name,
                subtitle: fmtDateTime(b.at),
                icon: Icons.event_rounded,
                selected: false,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    warmRoute(BookingDetailScreen(bookingId: b.id)),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  // C-15 / E-07 相談トリアージ
  void _triage(BuildContext context, OpsState ops) {
    Navigator.push(context, warmRoute(const ConsultTriageScreen()));
  }

  Widget _historyRow(BuildContext context, OpsState ops, OpsBooking b) {
    final svc = ops.serviceById(b.serviceId);
    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      onTap: () => Navigator.push(
        context,
        warmRoute(BookingDetailScreen(bookingId: b.id)),
      ),
      child: Row(
        children: [
          Icon(svc.kind.icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  svc.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  fmtDateTime(b.at),
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          StateBadge(b.state),
        ],
      ),
    );
  }
}

/// 要件再定義：申請状態が「承認済み」でないご家族には、まず制度案内へ誘導する。
class _ApplicationBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ops = context.watch<OpsState>();
    final p = ops.municipalityById(ops.customer.municipalityId);
    final a = ops.customer.application.status;
    if (a.canRequest && ops.voucherVerifiedForCustomer) {
      return const SizedBox.shrink();
    }
    final (title, sub, icon, color) = switch (a) {
      ApplicationStatus.notApplied => (
        '${p.name}への利用申請がまだです',
        'まず自治体へ申請します。流れと必要なものをご案内します。',
        Icons.account_balance_outlined,
        const Color(0xFF5E7FB8),
      ),
      ApplicationStatus.applied => (
        '${p.name}へ申請中です',
        '決定通知・利用券が届いたら、ここで登録してください。',
        Icons.mark_email_unread_outlined,
        const Color(0xFFC98A1E),
      ),
      ApplicationStatus.approved => (
        '利用券をスタッフが確認しています',
        '確認が終わると、ご利用希望を送れるようになります。',
        Icons.hourglass_top_rounded,
        const Color(0xFFC98A1E),
      ),
      ApplicationStatus.notEligible => (
        '自治体事業の対象外です',
        '自費でのご利用や、ほかの支援をご案内できます。',
        Icons.info_outline_rounded,
        const Color(0xFFC07A7A),
      ),
    };
    return SoftCard(
      color: color.withValues(alpha: 0.08),
      border: Border.all(color: color.withValues(alpha: 0.35)),
      onTap: () =>
          Navigator.push(context, warmRoute(const MunicipalityGuideScreen())),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
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
                    fontSize: 11.5,
                    height: 1.45,
                    color: AppColors.textBody,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _MenuItem {
  final String title;
  final String sub;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  _MenuItem(this.title, this.sub, this.icon, this.color, this.onTap);
}

/// §21 リピーター最優先導線。前回内容を引き継いだ状態でウィザードへ入る。
class _RepeatCta extends StatelessWidget {
  final RepeatPlan plan;
  const _RepeatCta({required this.plan});

  @override
  Widget build(BuildContext context) {
    final clean = plan.changes.isEmpty;
    return Semantics(
      button: true,
      label: '前回と同じ内容で予約する',
      child: Pressable(
        radius: BorderRadius.circular(AppRadius.lg),
        onTap: () => Navigator.push(
          context,
          warmRoute(const BookingWizardScreen(purpose: BookingPurpose.repeat)),
        ),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF6D9DF), Color(0xFFEFE2F0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.replay_rounded,
                  size: 22,
                  color: AppColors.blushPinkDeep,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '前回と同じ内容で予約',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      plan.proposedAt == null
                          ? '${plan.service.name}・${plan.service.planName}'
                          : '${plan.service.name}／'
                                '${fmtDate(plan.proposedAt!)} ${fmtTime(plan.proposedAt!)}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.3,
                        color: AppColors.textBody,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TagChip(
                      clean ? '確認は不要です' : '${plan.changes.length}件だけご確認',
                      color: clean
                          ? const Color(0xFF6FB57E)
                          : const Color(0xFFCE8A2E),
                      textColor: Colors.white,
                      icon: clean
                          ? Icons.check_rounded
                          : Icons.error_outline_rounded,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextBookingCard extends StatelessWidget {
  final OpsBooking booking;
  const _NextBookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final ops = context.watch<OpsState>();
    final svc = ops.serviceById(booking.serviceId);
    final staff = ops.staffById(booking.staffId);
    return SoftCard(
      onTap: () => Navigator.push(
        context,
        warmRoute(BookingDetailScreen(bookingId: booking.id)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  relativeDay(booking.at),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.blushPinkDeep,
                  ),
                ),
              ),
              StateBadge(booking.state),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              BreathingGlow(
                color: AppColors.blushPink,
                child: Container(
                  width: 50,
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.cardPink,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    svc.kind.icon,
                    size: 23,
                    color: AppColors.blushPinkDeep,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      svc.name,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      fmtDateTime(booking.at),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textBody,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      staff == null ? '担当を調整しています' : '担当：${staff.name}さん',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: AppColors.line),
          Row(
            children: [
              FeeChip(
                yen: booking.feeYen,
                state: booking.feeState,
                prefix: 'ご利用料金',
              ),
              const Spacer(),
              const Text(
                '変更・お取消しもここから →',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.mauve,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final OpsBooking booking;
  const _ActionCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final ops = context.watch<OpsState>();
    final svc = ops.serviceById(booking.serviceId);
    return SoftCard(
      color: AppColors.cardCream,
      border: Border.all(color: AppColors.softYellow, width: 1.4),
      onTap: () => Navigator.push(
        context,
        warmRoute(BookingDetailScreen(bookingId: booking.id)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 22,
            color: Color(0xFFD9A84E),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${svc.name}・${fmtDateTime(booking.at)}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  switch (booking.state) {
                    BookingState.needsReview =>
                      'スタッフが内容を確認しています。分かりしだいお知らせします。',
                    BookingState.provisional =>
                      'スタッフ確認が終わりました。内容を見て「予約を確定する」を押してください。',
                    BookingState.notEligible => '自治体事業の対象外でした。自費でのご利用をご案内できます。',
                    _ => 'お手続きの途中です。つづきから再開できます。',
                  },
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.45,
                    color: AppColors.textBody,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

// =============================================================================
// C-15 / E-07 相談トリアージ（事務／ケア／緊急）
// =============================================================================
class ConsultTriageScreen extends StatelessWidget {
  const ConsultTriageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ops = context.watch<OpsState>();
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: const AppTopBar(title: '相談する', subtitle: '人が受け取ります'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
        children: warmList([
          const Text(
            'どんなことでしょうか',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              height: 1.4,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '選んでいただくと、いちばん早くお答えできる人につながります。',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.6,
              color: AppColors.textBody,
            ),
          ),
          const SizedBox(height: 20),
          _card(
            context,
            ops,
            title: 'いますぐ助けてほしい',
            sub: '出血が多い・強い痛み・赤ちゃんの様子が心配',
            note: 'すぐに助産師へつなぎます（目安15分以内）',
            icon: Icons.emergency_outlined,
            color: const Color(0xFFE08A8A),
            reason: ReasonCode.redFlag,
            owner: TaskOwner.midwife,
            urgent: true,
          ),
          const SizedBox(height: 10),
          _card(
            context,
            ops,
            title: 'からだ・授乳のこと',
            sub: '乳房が痛い・母乳のこと・体の回復・気持ちのこと',
            note: '助産師がお返事します（目安2時間以内）',
            icon: Icons.favorite_outline_rounded,
            color: AppColors.blushPinkDeep,
            reason: ReasonCode.freeTextConsult,
            owner: TaskOwner.midwife,
            urgent: false,
          ),
          const SizedBox(height: 10),
          _card(
            context,
            ops,
            title: '予約・料金・手続きのこと',
            sub: '日時・持ち物・助成・書類・領収書など',
            note: '受付がお返事します（目安当日中）',
            icon: Icons.help_outline_rounded,
            color: AppColors.mauve,
            reason: ReasonCode.freeTextConsult,
            owner: TaskOwner.reception,
            urgent: false,
          ),
          const SizedBox(height: 22),
          const InfoNote(
            title: 'アプリは診断をしません',
            text: 'ここでのやりとりは、受診の判断を助けるためのものです。緊急のときは迷わず119番、または産院にご連絡ください。',
            icon: Icons.health_and_safety_outlined,
            color: AppColors.warmGray,
          ),
        ]),
      ),
    );
  }

  Widget _card(
    BuildContext context,
    OpsState ops, {
    required String title,
    required String sub,
    required String note,
    required IconData icon,
    required Color color,
    required ReasonCode reason,
    required TaskOwner owner,
    required bool urgent,
  }) {
    return SoftCard(
      onTap: () {
        ops.raiseConsult(reason: reason, owner: owner, summary: title);
        showWarmDialog(
          context,
          icon: urgent
              ? Icons.phone_in_talk_rounded
              : Icons.mark_email_read_rounded,
          title: urgent ? 'すぐにご連絡します' : 'お預かりしました',
          message: urgent
              ? '助産師に最優先でお伝えしました。\nお電話でご連絡します。すぐに危険を感じるときは119番へ。'
              : '$noteでお返事します。\nこのままアプリをとじても大丈夫です。',
          color: color,
          primaryLabel: 'ホームにもどる',
          onPrimary: () => Navigator.pop(context),
        );
      },
      border: urgent ? Border.all(color: color, width: 1.5) : null,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  sub,
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.45,
                    color: AppColors.textBody,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  note,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
