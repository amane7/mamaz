import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_nav.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../../charting/ui/chart_assist_screen.dart';
import '../../karte/ui/karte_screens.dart';
import '../../learning/ui/learning_room_screen.dart';
import '../matching_engine.dart';
import '../ops_models.dart';
import '../ops_state.dart';
import 'availability_screen.dart';
import 'ops_ui.dart';

/// 助産師向けワークスペース（M-01〜M-15 / 付録C.8）
/// 「今日のケア」を起点に、事前情報サマリー・専門判断キュー・OK／NG時間入力へ最短で到達する。
class MidwifeWorkspace extends StatefulWidget {
  const MidwifeWorkspace({super.key});

  @override
  State<MidwifeWorkspace> createState() => _MidwifeWorkspaceState();
}

class _MidwifeWorkspaceState extends State<MidwifeWorkspace> {
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

  /// 「メニューにもどる」と、先頭タブ（今日のケア）まで戻る。
  void _resetToFirstTab() {
    if (mounted && _tab != 0) setState(() => _tab = 0);
  }

  static const _tabs = [
    _TabDef('今日のケア', Icons.wb_sunny_outlined, Icons.wb_sunny_rounded, 'M-01'),
    _TabDef('判断キュー', Icons.flag_outlined, Icons.flag_rounded, 'M-04'),
    _TabDef(
      'OK／NG',
      Icons.event_available_outlined,
      Icons.event_available_rounded,
      'M-07',
    ),
    _TabDef('わたし', Icons.badge_outlined, Icons.badge_rounded, 'M-06'),
  ];

  @override
  Widget build(BuildContext context) {
    final ops = context.watch<OpsState>();
    final queue = ops.exceptionQueue;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _tab,
          children: [
            const _TodayCareTab(),
            const _JudgementQueueTab(),
            const AvailabilityScreen(),
            const _MyProfileTab(),
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
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: Semantics(
                      selected: _tab == i,
                      button: true,
                      label: _tabs[i].label,
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
                                  _tab == i
                                      ? _tabs[i].filled
                                      : _tabs[i].outline,
                                  size: 23,
                                  color: _tab == i
                                      ? AppColors.blushPinkDeep
                                      : AppColors.textMuted,
                                ),
                                if (i == 1 && queue.isNotEmpty)
                                  Positioned(
                                    right: -5,
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
                                        '${queue.length}',
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
                              _tabs[i].label,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: _tab == i
                                    ? AppColors.blushPinkDeep
                                    : AppColors.textMuted,
                              ),
                            ),
                          ],
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

class _TabDef {
  final String label;
  final IconData outline;
  final IconData filled;
  final String spec;
  const _TabDef(this.label, this.outline, this.filled, this.spec);
}

// =============================================================================
// M-01 今日のケア
// =============================================================================
class _TodayCareTab extends StatelessWidget {
  const _TodayCareTab();

  @override
  Widget build(BuildContext context) {
    final ops = context.watch<OpsState>();
    final today = ops.todaysCare(ops.currentStaffId);
    final upcoming = ops
        .upcomingFor(ops.currentStaffId, days: 14)
        .where((b) => dayOf(b.at) != dayOf(DateTime.now()))
        .toList();
    final load = ops.loadMinutes(ops.currentStaffId, DateTime.now());
    final cap = ops.currentStaff.dailyMaxMin;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: warmList([
        _greeting(ops),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: MetricTile(
                label: '今日のケア',
                value: '${today.length}件',
                sub: today.isEmpty
                    ? 'ゆっくりできる日です'
                    : '最初は${fmtTime(today.first.at)}',
                icon: Icons.favorite_rounded,
                color: AppColors.blushPinkDeep,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MetricTile(
                label: '今日の稼働',
                value: '${(load / 60).toStringAsFixed(1)}h',
                sub: '上限 ${(cap / 60).toStringAsFixed(1)}h',
                icon: Icons.speed_rounded,
                color: load > cap
                    ? const Color(0xFFE08A8A)
                    : AppColors.lavender,
                alert: load > cap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const OpsSection(
          title: '今日のケア',
          note: '時間・場所・状態・事前情報の準備状況をひと目で。',
          spec: 'M-01',
        ),
        const SizedBox(height: 10),
        if (today.isEmpty)
          const WarmEmptyState(
            icon: Icons.wb_twilight_rounded,
            title: '今日の予定はありません',
            message: 'ゆっくり休んでくださいね。\n受けられる時間はいつでも変更できます。',
            color: AppColors.softYellow,
          )
        else
          for (final b in today) ...[
            _CareCard(booking: b, isToday: true),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 24),
        const OpsSection(title: 'これからの予定', note: '2週間先まで。', spec: 'M-02'),
        const SizedBox(height: 10),
        if (upcoming.isEmpty)
          const InfoNote(
            text: 'これからの予定はまだありません。',
            icon: Icons.event_outlined,
            color: AppColors.lavender,
          )
        else
          for (final b in upcoming.take(6)) ...[
            _CareCard(booking: b, isToday: false),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 24),
        const OpsSection(
          title: '記録をつくる',
          note: '乳房ケアカルテは下書きとして、この端末の中だけに保存します。会話からの下書きは試作です。',
          spec: '下書き',
        ),
        const SizedBox(height: 10),
        const KarteEntryCard(),
        const SizedBox(height: 10),
        const ChartAssistEntryCard(),
        const SizedBox(height: 24),
        const OpsSection(
          title: '学ぶ',
          note: '架空事例の演習です。実際のご家族の記録とはつながっていません。',
          spec: '教育試作0.2',
        ),
        const SizedBox(height: 10),
        const LearningRoomEntryCard(),
      ]),
    );
  }

  Widget _greeting(OpsState ops) {
    final h = DateTime.now().hour;
    final hello = h < 11
        ? 'おはようございます'
        : h < 18
        ? 'おつかれさまです'
        : 'こんばんは';
    return SoftCard(
      color: AppColors.cardCream,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.blushPink,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              ops.currentStaff.initial,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$hello、${ops.currentStaff.name}さん',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${DateTime.now().month}月${DateTime.now().day}日（${weekdayLabel(DateTime.now().weekday)}）',
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
    );
  }
}

class _CareCard extends StatelessWidget {
  final OpsBooking booking;
  final bool isToday;
  const _CareCard({required this.booking, required this.isToday});

  @override
  Widget build(BuildContext context) {
    final ops = context.watch<OpsState>();
    final svc = ops.serviceById(booking.serviceId);
    final cust = ops.customer;
    final fac = ops.facilityById(booking.facilityId);
    final intakeDone = booking.intake.isNotEmpty;
    final urgent = booking.openExceptions.any((e) => e.code.toMidwife);

    return SoftCard(
      border: urgent
          ? Border.all(color: const Color(0xFFE08A8A), width: 1.4)
          : null,
      onTap: () => Navigator.push(
        context,
        warmRoute(_PreCareSummaryScreen(bookingId: booking.id)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: isToday ? AppColors.cardPink : AppColors.cardLavender,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    if (!isToday)
                      Text(
                        relativeDay(booking.at),
                        style: const TextStyle(
                          fontSize: 9.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    Text(
                      fmtTime(booking.at),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      '${svc.durationMin}分',
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            svc.name,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        StateBadge(booking.state),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          svc.kind == ServiceKind.visit
                              ? Icons.directions_car_outlined
                              : Icons.home_work_outlined,
                          size: 13,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            svc.kind == ServiceKind.visit
                                ? '訪問・${cust.address.short}'
                                : (fac?.name ?? '院内'),
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textBody,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline_rounded,
                          size: 13,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${cust.nameKanji}さん・${cust.children.first.ageLabel}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textBody,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              TagChip(
                intakeDone ? '事前情報あり' : '事前情報まち',
                color: intakeDone ? AppColors.cardSage : AppColors.cardCream,
                textColor: intakeDone
                    ? const Color(0xFF6FB57E)
                    : AppColors.warmGray,
                icon: intakeDone
                    ? Icons.check_circle_outline_rounded
                    : Icons.schedule_rounded,
              ),
              const SizedBox(width: 6),
              if (urgent)
                const TagChip(
                  '要確認',
                  color: AppColors.cardPink,
                  textColor: Color(0xFFD97A7A),
                  icon: Icons.priority_high_rounded,
                ),
              const Spacer(),
              const Text(
                '事前情報を見る →',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.mauve,
                ),
              ),
            ],
          ),
          if (isToday && booking.state.readyForService) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.blushPinkDeep,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                onPressed: () => ops.startService(booking),
                icon: const Icon(Icons.play_arrow_rounded, size: 19),
                label: const Text(
                  'ケアを開始する',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
          if (booking.state == BookingState.inService) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6FB57E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                onPressed: () => _handoverSheet(context, ops, booking),
                icon: const Icon(Icons.check_rounded, size: 19),
                label: const Text(
                  '完了して申し送りを書く',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // M-11 / M-12 利用完了 + 申し送り
  void _handoverSheet(BuildContext context, OpsState ops, OpsBooking b) {
    final ctrl = TextEditingController(text: b.handoverNote ?? '');
    final tags = <String>{};
    const presets = [
      '授乳姿勢を一緒に確認しました',
      '乳房の状態は落ち着いています',
      '休息がとれていました',
      '沐浴を一緒に行いました',
      '次回までに様子を見たい点あり',
      '継続でのフォローをおすすめ',
    ];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, set) {
          return Padding(
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
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 26),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '申し送り',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '次に担当する人と、ご家族に伝わることばで。',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final p in presets)
                          Pressable(
                            radius: BorderRadius.circular(14),
                            onTap: () => set(() {
                              if (tags.contains(p)) {
                                tags.remove(p);
                              } else {
                                tags.add(p);
                              }
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: tags.contains(p)
                                    ? AppColors.blushPink
                                    : AppColors.cardCream,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                p,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: tags.contains(p)
                                      ? Colors.white
                                      : AppColors.textBody,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: ctrl,
                      maxLines: 4,
                      style: const TextStyle(fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: 'そのほか、伝えておきたいこと',
                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                        filled: true,
                        fillColor: AppColors.cream,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF6FB57E),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                        onPressed: () {
                          final note = [
                            ...tags,
                            ctrl.text.trim(),
                          ].where((e) => e.isNotEmpty).join('／');
                          ops.completeService(b, note);
                          Navigator.pop(ctx);
                          Celebration.show(context);
                          showWarmToast(
                            context,
                            'おつかれさまでした。完了しました',
                            icon: Icons.favorite_rounded,
                            color: AppColors.blushPinkDeep,
                          );
                        },
                        child: const Text(
                          '完了する',
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
          );
        },
      ),
    );
  }
}

// =============================================================================
// M-03 事前情報サマリー（1画面・差分つき）
// =============================================================================
class _PreCareSummaryScreen extends StatelessWidget {
  final String bookingId;
  const _PreCareSummaryScreen({required this.bookingId});

  @override
  Widget build(BuildContext context) {
    final ops = context.watch<OpsState>();
    final b = ops.bookings.firstWhere((e) => e.id == bookingId);
    final svc = ops.serviceById(b.serviceId);
    final cust = ops.customer;
    final child = cust.children.firstWhere(
      (c) => c.id == b.childId,
      orElse: () => cust.children.first,
    );
    final intake = b.intake;
    final flags = seedRedFlagsFor(intake);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppTopBar(title: '事前情報サマリー', subtitle: b.code),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: warmList([
          if (flags.isNotEmpty) ...[
            InfoNote(
              title: '先に確認したいこと',
              text: flags.join('\n'),
              icon: Icons.priority_high_rounded,
              color: const Color(0xFFE08A8A),
            ),
            const SizedBox(height: 14),
          ],
          SoftCard(
            color: AppColors.cardPink,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${cust.nameKanji}さん',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    StateBadge(b.state),
                  ],
                ),
                Text(
                  cust.nameKana,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
                const Divider(height: 22, color: Colors.white54),
                _row('お子さま', '${child.name}・${child.ageLabel}'),
                _row('サービス', '${svc.name}（${svc.durationLabel}）'),
                _row('日時', fmtDateTime(b.at)),
                _row(
                  '場所',
                  svc.kind == ServiceKind.visit
                      ? '訪問：${cust.address.short}'
                      : (ops.facilityById(b.facilityId)?.name ?? '院内'),
                ),
                if (svc.kind == ServiceKind.visit)
                  _row(
                    '駐車',
                    cust.address.parkingOnSite
                        ? '敷地内にあり'
                        : cust.address.parkingNearby
                        ? '近隣にあり（要確認）'
                        : 'なし',
                  ),
                _row('ご利用回数', '${cust.usedCount}回目のご利用'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const OpsSection(
            title: '今いちばん、してほしいこと',
            note: 'ご家族が選んだニーズ。',
            spec: 'M-03',
          ),
          const SizedBox(height: 8),
          SoftCard(
            child: b.needs.isEmpty
                ? const Text(
                    '選択なし',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                    ),
                  )
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final n in b.needs)
                        TagChip(
                          n,
                          color: AppColors.cardLavender,
                          textColor: AppColors.lavender,
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 18),
          const OpsSection(title: '問診・当日の状況', spec: 'M-03'),
          const SizedBox(height: 8),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (intake['allergy'] != null &&
                    (intake['allergy'] as String).trim().isNotEmpty)
                  _hi(
                    'アレルギー',
                    intake['allergy'] as String,
                    const Color(0xFFE08A8A),
                  ),
                if (intake['bath'] == true) _row('沐浴', 'ご希望あり'),
                if (intake['free'] != null &&
                    (intake['free'] as String).trim().isNotEmpty)
                  _row('相談したいこと', intake['free'] as String),
                if (intake['wantHuman'] == true)
                  _hi('ご希望', '人に相談したい', AppColors.lavender),
                if (intake.isEmpty)
                  const Text(
                    '回答はまだありません。当日にお伺いします。',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const OpsSection(
            title: '同意の記録',
            note: '同意した時点の版が保存されています（改定後も遡って変わりません）。',
            spec: 'M-13',
          ),
          const SizedBox(height: 8),
          SoftCard(
            child: b.consent == null
                ? const Text(
                    '記録なし',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _row(b.consent!.title, 'v${b.consent!.version}'),
                      _row('同意日時', fmtDateTime(b.consent!.agreedAt)),
                    ],
                  ),
          ),
          if (b.handoverNote != null && b.handoverNote!.isNotEmpty) ...[
            const SizedBox(height: 18),
            const OpsSection(title: '前回の申し送り', spec: 'M-12'),
            const SizedBox(height: 8),
            SoftCard(
              color: AppColors.cardSage,
              child: Text(
                b.handoverNote!,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: AppColors.textBody,
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          const InfoNote(
            text: 'この画面の情報は、ケアに必要な範囲のみが表示されます。閲覧は監査ログに記録されます。',
            icon: Icons.lock_outline_rounded,
            color: AppColors.warmGray,
          ),
        ]),
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            k,
            style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _hi(String k, String v, Color c) => Container(
    margin: const EdgeInsets.symmetric(vertical: 4),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      border: Border.all(color: c.withValues(alpha: 0.4)),
    ),
    child: Row(
      children: [
        Icon(Icons.info_outline_rounded, size: 15, color: c),
        const SizedBox(width: 7),
        Text(
          '$k：',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c),
        ),
        Expanded(
          child: Text(
            v,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
        ),
      ],
    ),
  );
}

/// 問診の赤旗回答を、助産師向けの短い文に変換
List<String> seedRedFlagsFor(Map<String, dynamic> intake) {
  final out = <String>[];
  const map = {
    'fever': '38℃以上の発熱があるとのことです',
    'breast_pain': '乳房の強い痛み・しこりの訴えがあります',
    'bleeding': '出血が増えているとのことです',
    'infection': '傷の赤み・熱感の訴えがあります',
    'baby_weight': 'お子さまの体重・哺乳に不安があります',
    'mood': '気分の落ち込みが続いているとのことです',
  };
  for (final e in map.entries) {
    if (intake[e.key] == true) out.add('・${e.value}');
  }
  return out;
}

// =============================================================================
// M-04 専門判断キュー
// =============================================================================
class _JudgementQueueTab extends StatelessWidget {
  const _JudgementQueueTab();

  @override
  Widget build(BuildContext context) {
    final ops = context.watch<OpsState>();
    final queue = ops.exceptionQueue;
    final myTasks = ops.tasksFor(TaskOwner.midwife);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: warmList([
        const OpsSection(
          title: '専門判断キュー',
          note: '理由・優先度・期限つき。判断した結果はそのまま記録されます。',
          spec: 'M-04',
        ),
        const SizedBox(height: 10),
        if (queue.isEmpty)
          const WarmEmptyState(
            icon: Icons.verified_outlined,
            title: '判断まちはありません',
            message: 'いまのところ、すべて自動で調整できています。',
            color: AppColors.sageDeep,
          )
        else
          for (final b in queue) ...[
            _QueueCard(booking: b),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 22),
        const OpsSection(
          title: 'わたしのタスク',
          note: '期限を過ぎたものは赤く表示されます。',
          spec: 'M-05',
        ),
        const SizedBox(height: 10),
        if (myTasks.isEmpty)
          const InfoNote(
            text: 'タスクはありません。',
            icon: Icons.check_circle_outline_rounded,
            color: AppColors.sageDeep,
          )
        else
          for (final t in myTasks) ...[
            _TaskRow(task: t),
            const SizedBox(height: 8),
          ],
      ]),
    );
  }
}

class _QueueCard extends StatelessWidget {
  final OpsBooking booking;
  const _QueueCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final ops = context.watch<OpsState>();
    final svc = ops.serviceById(booking.serviceId);
    final ex = booking.openExceptions;
    final overdue = ex.any((e) => e.overdue);

    return SoftCard(
      border: Border.all(
        color: overdue ? const Color(0xFFE08A8A) : AppColors.line,
        width: overdue ? 1.5 : 1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${svc.name}・${fmtDateTime(booking.at)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              StateBadge(booking.state),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in ex) ReasonChip(e.code, overdue: e.overdue),
            ],
          ),
          const SizedBox(height: 8),
          for (final e in ex)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.subdirectory_arrow_right_rounded,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      '${e.detail}（期限 ${fmtTime(e.dueAt)}）',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textBody,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          const Divider(height: 16, color: AppColors.line),
          const Text(
            '推奨アクション',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _advice(ex),
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: AppColors.textBody,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Pressable(
                  radius: BorderRadius.circular(AppRadius.sm),
                  onTap: () => Navigator.push(
                    context,
                    warmRoute(_PreCareSummaryScreen(bookingId: booking.id)),
                  ),
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.cardCream,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Text(
                      '事前情報',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textBody,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Pressable(
                  radius: BorderRadius.circular(AppRadius.sm),
                  onTap: () => _decide(context, ops, booking),
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.blushPinkDeep,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Text(
                      '判断する',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
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

  String _advice(List<BookingException> ex) {
    if (ex.any((e) => e.code == ReasonCode.redFlag)) {
      return 'まずお電話で状態を確認し、受診の必要性を判断してください。予約はその判断のあとで確定します。';
    }
    if (ex.any((e) => e.code == ReasonCode.mealAllergy)) {
      return 'アレルギー内容を確認し、提供可否と代替メニューを決めてください。可否確定まで自動確定はされません。';
    }
    if (ex.any((e) => e.code == ReasonCode.eligibilityUnknown)) {
      return '自治体の利用要件（番号・回数・月齢）を確認し、不足があればご家族に必要書類を案内してください。';
    }
    return '内容を確認し、承認または見送りを選んでください。判断理由は記録に残ります。';
  }

  void _decide(BuildContext context, OpsState ops, OpsBooking b) {
    final ctrl = TextEditingController();
    var approve = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, set) {
          return Padding(
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
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '専門判断の記録',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '判断した内容と理由は監査ログに残ります。',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceTile(
                          title: '承認する',
                          subtitle: 'このまま予約を確定します',
                          icon: Icons.check_circle_outline_rounded,
                          color: const Color(0xFF6FB57E),
                          selected: approve,
                          onTap: () => set(() => approve = true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceTile(
                          title: '見送る',
                          subtitle: '別のご案内をします',
                          icon: Icons.pan_tool_outlined,
                          color: const Color(0xFFE08A8A),
                          selected: !approve,
                          onTap: () => set(() => approve = false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: ctrl,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText: '判断の理由・確認したこと',
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                      filled: true,
                      fillColor: AppColors.cream,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.blushPinkDeep,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      onPressed: () {
                        ops.resolveReview(
                          b,
                          approve: approve,
                          note: ctrl.text.trim().isEmpty
                              ? '（記載なし）'
                              : ctrl.text.trim(),
                        );
                        Navigator.pop(ctx);
                        showWarmToast(
                          context,
                          approve ? '承認しました' : '見送りを記録しました',
                          icon: approve
                              ? Icons.check_rounded
                              : Icons.info_outline_rounded,
                          color: approve
                              ? const Color(0xFF6FB57E)
                              : AppColors.softYellow,
                        );
                      },
                      child: const Text(
                        '記録する',
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
          );
        },
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final OpsTask task;
  const _TaskRow({required this.task});

  @override
  Widget build(BuildContext context) {
    final ops = context.read<OpsState>();
    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: task.overdue
          ? Border.all(color: const Color(0xFFE08A8A), width: 1.3)
          : null,
      child: Row(
        children: [
          Icon(
            task.done
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 20,
            color: task.done
                ? const Color(0xFF6FB57E)
                : task.overdue
                ? const Color(0xFFE08A8A)
                : AppColors.textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${task.detail}・期限 ${fmtTime(task.dueAt)}${task.overdue ? '（超過）' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    color: task.overdue
                        ? const Color(0xFFD97A7A)
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (!task.done)
            Pressable(
              radius: BorderRadius.circular(AppRadius.sm),
              onTap: () => ops.completeTask(task.id, '対応済み'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cardSage,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Text(
                  '完了',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6FB57E),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// M-06 スキル・対応範囲の確認 + M-08 負荷
// =============================================================================
class _MyProfileTab extends StatelessWidget {
  const _MyProfileTab();

  @override
  Widget build(BuildContext context) {
    final ops = context.watch<OpsState>();
    final s = ops.currentStaff;
    final week = List.generate(
      7,
      (i) => dayOf(DateTime.now()).add(Duration(days: i)),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: warmList([
        SoftCard(
          color: AppColors.cardLavender,
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.lavender,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  s.initial,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
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
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      s.role,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              _staffSwitch(context, ops),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const LearningRoomEntryCard(),
        const SizedBox(height: 18),
        const OpsSection(
          title: 'できること（スキル）',
          note: 'このスキルに合う予約だけが自動で届きます。',
          spec: 'M-06',
        ),
        const SizedBox(height: 8),
        SoftCard(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final k in s.skills)
                TagChip(
                  k,
                  color: AppColors.cardSage,
                  textColor: const Color(0xFF6FB57E),
                  icon: Icons.verified_outlined,
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const OpsSection(title: '対応サービス・地域', spec: 'M-06'),
        const SizedBox(height: 8),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final k in s.services)
                    TagChip(
                      k.label,
                      color: AppColors.cardPink,
                      textColor: AppColors.blushPinkDeep,
                    ),
                ],
              ),
              const Divider(height: 20, color: AppColors.line),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final a in s.areas)
                    TagChip(
                      _areaLabel(a),
                      color: AppColors.cardCream,
                      textColor: AppColors.mauve,
                      icon: Icons.place_outlined,
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const OpsSection(
          title: '負荷とバッファ',
          note: '1日の上限・連続対応・移動時間は自動で守られます。',
          spec: 'M-08',
        ),
        const SizedBox(height: 8),
        SoftCard(
          child: Column(
            children: [
              _capRow('1日の上限', '${(s.dailyMaxMin / 60).toStringAsFixed(1)}時間'),
              _capRow('連続対応の上限', '${s.consecutiveMax}件'),
              _capRow('予約間バッファ', '${s.bufferMin}分'),
              const Divider(height: 20, color: AppColors.line),
              for (final d in week)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 52,
                        child: Text(
                          '${d.month}/${d.day}（${weekdayLabel(d.weekday)}）',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (ops.loadMinutes(s.id, d) / s.dailyMaxMin)
                                .clamp(0.0, 1.0),
                            minHeight: 7,
                            backgroundColor: AppColors.line,
                            valueColor: AlwaysStoppedAnimation(
                              ops.loadMinutes(s.id, d) > s.dailyMaxMin
                                  ? const Color(0xFFE08A8A)
                                  : AppColors.sageDeep,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(ops.loadMinutes(s.id, d) / 60).toStringAsFixed(1)}h',
                        style: const TextStyle(
                          fontSize: 10.5,
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
        const InfoNote(
          title: 'NGの理由は保存されません',
          text:
              '「受けられない時間」は、理由を書かずに登録できます。管理者やご家族には可否だけが共有され、私的な予定の内容は表示されません。',
          icon: Icons.privacy_tip_outlined,
          color: AppColors.lavender,
        ),
      ]),
    );
  }

  // エリア名は ops_ui.dart の areaLabel() に統一した（表記ゆれを作らない）。
  static String _areaLabel(String code) => areaLabel(code);

  Widget _capRow(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            k,
            style: const TextStyle(fontSize: 12.5, color: AppColors.textBody),
          ),
        ),
        Text(
          v,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
      ],
    ),
  );

  Widget _staffSwitch(BuildContext context, OpsState ops) => Pressable(
    radius: BorderRadius.circular(AppRadius.sm),
    onTap: () => showModalBottomSheet(
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
              '担当を切り替える（デモ）',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),
            for (final s in ops.staff) ...[
              ChoiceTile(
                title: s.name,
                subtitle: s.skills.join('・'),
                icon: Icons.person_outline_rounded,
                selected: ops.currentStaffId == s.id,
                onTap: () {
                  ops.switchStaff(s.id);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    ),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white70,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: const Text(
        '切替',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: AppColors.lavender,
        ),
      ),
    ),
  );
}

/// 依存を明示（将来の枠検証UIで使用）
typedef EngineRef = MatchingEngine;
