import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/facility.dart';
import '../services/care_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import 'epds_screen.dart';
import 'online_visit_screen.dart';
import '../widgets/app_nav.dart';

/// 健康管理（RPM）：血圧・心拍・体温・睡眠 とウェアラブル連携
class HealthScreen extends StatelessWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final care = context.watch<CareState>();
    final latest = care.latestVital;
    final alerts = care.alertVitals;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('健康管理'),
        actions: const [HomeButton(), SizedBox(width: 8)],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            const FadeSlideIn(
              child: Text(
                '産後6週までは、血圧の変化に注意が必要な時期です。基準を超えると助産師へ自動でお知らせします。',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textBody,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 18),
            FadeSlideIn(
              delay: const Duration(milliseconds: 60),
              child: _todayCard(context, latest),
            ),
            const SizedBox(height: 16),
            FadeSlideIn(
              delay: const Duration(milliseconds: 110),
              child: _quickInput(context),
            ),
            const SizedBox(height: 22),
            const FadeSlideIn(
              delay: Duration(milliseconds: 160),
              child: SectionTitle(
                '今週のからだレポート',
                subtitle: '助産師と共有できる、あなたの1週間のまとめ',
              ),
            ),
            const SizedBox(height: 12),
            FadeSlideIn(
              delay: const Duration(milliseconds: 200),
              child: _weeklyReportCard(context, care),
            ),
            const SizedBox(height: 22),
            const FadeSlideIn(
              delay: Duration(milliseconds: 240),
              child: SectionTitle(
                '血圧の推移（直近7日・収縮期）',
                subtitle: '基準線 140 mmHg を超えると助産師へアラート',
              ),
            ),
            const SizedBox(height: 12),
            FadeSlideIn(
              delay: const Duration(milliseconds: 280),
              child: _bpChart(care),
            ),
            const SizedBox(height: 20),
            const FadeSlideIn(
              delay: Duration(milliseconds: 320),
              child: SectionTitle('こころの状態', subtitle: 'からだと同じく、こころもケアの対象です'),
            ),
            const SizedBox(height: 12),
            FadeSlideIn(
              delay: const Duration(milliseconds: 360),
              child: _epdsCard(context, care),
            ),
            const SizedBox(height: 20),
            const FadeSlideIn(
              delay: Duration(milliseconds: 400),
              child: SectionTitle('ウェアラブル連携', subtitle: '測定データを自動で取り込みます'),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < care.devices.length; i++) ...[
              FadeSlideIn(
                delay: Duration(milliseconds: 430 + i * 50),
                child: _deviceTile(context, care.devices[i]),
              ),
              const SizedBox(height: 9),
            ],
            const SizedBox(height: 12),
            if (alerts.isNotEmpty) ...[
              const SectionTitle('アラート履歴', subtitle: '基準を超えた測定の記録'),
              const SizedBox(height: 12),
              for (final v in alerts.take(5)) ...[
                _alertTile(v),
                const SizedBox(height: 9),
              ],
              const SizedBox(height: 12),
            ],
            const SectionTitle('測定履歴'),
            const SizedBox(height: 12),
            if (care.vitals.isEmpty)
              const WarmEmptyState(
                icon: Icons.monitor_heart_outlined,
                title: 'まだ記録がありません',
                message:
                    '上のボタンから、今の血圧や体温をひとつだけ記録してみませんか。\n数字を見るだけでも、安心につながります。',
              ),
            for (final v in care.vitals.take(10)) ...[
              _vitalTile(v),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------- RPM 週次レポート（Step3） ----------------
  Widget _weeklyReportCard(BuildContext context, CareState care) {
    final r = care.weeklyReport;
    final df = DateFormat('M/d', 'ja');
    final ringColor = r.conditionScore >= 0.85
        ? const Color(0xFF6FB57E)
        : r.conditionScore >= 0.6
        ? AppColors.sageDeep
        : r.conditionScore >= 0.4
        ? const Color(0xFFF1B07A)
        : const Color(0xFFE89AA8);

    return SoftCard(
      color: Colors.white,
      shadow: AppShadows.soft,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GentleRing(
                progress: r.conditionScore,
                size: 78,
                stroke: 8,
                color: ringColor,
                center: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedCountText(
                      (r.conditionScore * 100).round(),
                      duration: const Duration(milliseconds: 900),
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: ringColor,
                      ),
                    ),
                    const Text(
                      '点',
                      style: TextStyle(fontSize: 9, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.conditionLabel,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${df.format(r.from)}〜${df.format(r.to)}\n'
                      '測定${r.measurements}回・アラート${r.alertCount}回',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _reportMetric(
                  '平均血圧',
                  r.avgSystolic == null
                      ? '—'
                      : '${r.avgSystolic!.round()}/${r.avgDiastolic?.round() ?? '—'}',
                  'mmHg',
                ),
              ),
              Expanded(
                child: _reportMetric(
                  '平均心拍',
                  r.avgPulse == null ? '—' : '${r.avgPulse!.round()}',
                  'bpm',
                ),
              ),
              Expanded(
                child: _reportMetric(
                  '平均睡眠',
                  r.avgSleep == null ? '—' : r.avgSleep!.toStringAsFixed(1),
                  '時間',
                ),
              ),
              Expanded(
                child: _reportMetric(
                  '授乳',
                  r.feedPerDay <= 0 ? '—' : r.feedPerDay.toStringAsFixed(1),
                  '回/日',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardSage,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 15,
                      color: Color(0xFF6FB57E),
                    ),
                    SizedBox(width: 7),
                    Text(
                      'AIからの気づき',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (var i = 0; i < r.findings.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: i == r.findings.length - 1 ? 0 : 8,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 5, right: 8),
                          child: Icon(
                            Icons.circle,
                            size: 5,
                            color: AppColors.sageDeep,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            r.findings[i],
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textBody,
                              height: 1.7,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '※ この内容は助産師が確認・修正したうえで、ケアの参考にしています。',
            style: TextStyle(fontSize: 10, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Pressable(
                  onTap: () {
                    care.sendWeeklyReport();
                    AppMotion.celebrate();
                    showWarmToast(
                      context,
                      '助産師にレポートをお送りしました',
                      icon: Icons.send_rounded,
                    );
                  },
                  child: Container(
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.blushPinkDeep,
                      borderRadius: BorderRadius.circular(23),
                    ),
                    child: const Text(
                      '助産師に共有する',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Pressable(
                  onTap: () => Navigator.push(
                    context,
                    warmRoute(const OnlineVisitScreen()),
                  ),
                  child: Container(
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.cardLavender,
                      borderRadius: BorderRadius.circular(23),
                    ),
                    child: const Text(
                      '面談を予約',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.mauve,
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

  Widget _reportMetric(String label, String value, String unit) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          unit,
          style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _todayCard(BuildContext context, VitalReading? v) {
    return SoftCard(
      color: Colors.white,
      shadow: AppShadows.soft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '直近の測定',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (v != null)
                Text(
                  '${DateFormat('M/d HH:mm').format(v.time)}・${v.source}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _metric(
                  '血圧',
                  v?.systolic != null ? '${v!.systolic}/${v.diastolic}' : '—',
                  'mmHg',
                  Icons.monitor_heart_outlined,
                  v?.bpAlert == true
                      ? const Color(0xFFE07C93)
                      : AppColors.blushPinkDeep,
                  alert: v?.bpAlert ?? false,
                ),
              ),
              Expanded(
                child: _metric(
                  '心拍',
                  v?.pulse?.toString() ?? '—',
                  'bpm',
                  Icons.favorite_border_rounded,
                  v?.pulseAlert == true
                      ? const Color(0xFFE07C93)
                      : AppColors.lavender,
                  alert: v?.pulseAlert ?? false,
                ),
              ),
              Expanded(
                child: _metric(
                  '体温',
                  v?.temperature?.toStringAsFixed(1) ?? '—',
                  '℃',
                  Icons.thermostat_outlined,
                  v?.feverAlert == true
                      ? const Color(0xFFE07C93)
                      : AppColors.sageDeep,
                  alert: v?.feverAlert ?? false,
                ),
              ),
              Expanded(
                child: _metric(
                  '体重',
                  v?.weight?.toStringAsFixed(1) ?? '—',
                  'kg',
                  Icons.scale_outlined,
                  AppColors.mauve,
                ),
              ),
            ],
          ),
          if (v?.hasAlert == true) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFDEBEE),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: const [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: Color(0xFFE07C93),
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      '基準値を超えています。担当助産師に自動通知済みです。強い頭痛・目のちらつき・みぞおちの痛みがあるときは、すぐに産科へご連絡ください。',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textBody,
                        height: 1.5,
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

  Widget _metric(
    String label,
    String value,
    String unit,
    IconData icon,
    Color color, {
    bool alert = false,
  }) {
    return Column(
      children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: alert ? const Color(0xFFE07C93) : AppColors.textDark,
          ),
        ),
        Text(
          unit,
          style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _quickInput(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _actionBtn(
            context,
            '血圧を記録',
            Icons.monitor_heart_outlined,
            AppColors.cardPink,
            AppColors.blushPinkDeep,
            () => _openBpSheet(context),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _actionBtn(
            context,
            '体温・体重',
            Icons.thermostat_outlined,
            AppColors.cardSage,
            const Color(0xFF6FB57E),
            () => _openTempSheet(context),
          ),
        ),
      ],
    );
  }

  Widget _actionBtn(
    BuildContext context,
    String label,
    IconData icon,
    Color bg,
    Color fg,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          children: [
            Icon(icon, size: 21, color: fg),
            const SizedBox(height: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bpChart(CareState care) {
    final data = care.bpTrend;
    final now = DateTime.now();
    return SoftCard(
      color: Colors.white,
      child: Column(
        children: [
          SizedBox(
            height: 130,
            child: Stack(
              children: [
                // 基準線 140
                Positioned(
                  left: 0,
                  right: 0,
                  top: 130 - (140 - 90) / 80 * 110,
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 1,
                          color: const Color(0xFFF0B9C4),
                        ),
                      ),
                      const Text(
                        ' 140',
                        style: TextStyle(fontSize: 9, color: Color(0xFFE07C93)),
                      ),
                    ],
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (i) {
                    final v = data[i];
                    final h = v == 0
                        ? 4.0
                        : ((v - 90) / 80 * 110).clamp(6.0, 118.0);
                    final alert = v >= 140;
                    final d = now.subtract(Duration(days: 6 - i));
                    return Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            v == 0 ? '' : v.round().toString(),
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: alert
                                  ? const Color(0xFFE07C93)
                                  : AppColors.textBody,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            height: h,
                            margin: const EdgeInsets.symmetric(horizontal: 7),
                            decoration: BoxDecoration(
                              color: alert
                                  ? const Color(0xFFE89AA8)
                                  : AppColors.blushPink,
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            DateFormat('M/d').format(d),
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _epdsCard(BuildContext context, CareState care) {
    final latest = care.latestEpds;
    return SoftCard(
      color: AppColors.cardLavender,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const EpdsScreen()),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite_border_rounded,
              size: 22,
              color: AppColors.lavender,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'EPDS 産後うつスクリーニング',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  latest != null
                      ? '前回 $latest点／${CareState.epdsJudgement(latest)}'
                      : '10項目・約2分。2週間おきのチェックをおすすめします。',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textBody,
                    height: 1.4,
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

  Widget _deviceTile(BuildContext context, WearableDevice d) {
    return SoftCard(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: d.connected ? AppColors.cardSage : AppColors.cream,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              d.icon,
              size: 19,
              color: d.connected
                  ? const Color(0xFF6FB57E)
                  : AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${d.vendor}・${d.metrics.join('／')}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: d.connected,
            activeThumbColor: const Color(0xFF6FB57E),
            onChanged: (_) => context.read<CareState>().toggleDevice(d.id),
          ),
        ],
      ),
    );
  }

  Widget _alertTile(VitalReading v) {
    final reasons = <String>[];
    if (v.bpAlert) reasons.add('血圧 ${v.systolic}/${v.diastolic}');
    if (v.feverAlert) reasons.add('体温 ${v.temperature}℃');
    if (v.pulseAlert) reasons.add('心拍 ${v.pulse}');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDEBEE),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: Color(0xFFE07C93),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reasons.join('／'),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${DateFormat('M月d日 HH:mm').format(v.time)}・助産師へ通知済み',
                  style: const TextStyle(
                    fontSize: 10.5,
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

  Widget _vitalTile(VitalReading v) {
    final parts = <String>[];
    if (v.systolic != null) parts.add('${v.systolic}/${v.diastolic} mmHg');
    if (v.pulse != null) parts.add('${v.pulse} bpm');
    if (v.temperature != null) {
      parts.add('${v.temperature!.toStringAsFixed(1)}℃');
    }
    if (v.weight != null) parts.add('${v.weight!.toStringAsFixed(1)}kg');
    if (v.sleepHours != null) {
      parts.add('睡眠${v.sleepHours!.toStringAsFixed(1)}h');
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Icon(
            v.hasAlert
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            size: 17,
            color: v.hasAlert ? const Color(0xFFE07C93) : AppColors.sageDeep,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              parts.join('・'),
              style: const TextStyle(fontSize: 12, height: 1.4),
            ),
          ),
          Text(
            DateFormat('M/d HH:mm').format(v.time),
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  // ---------------- 入力シート ----------------
  void _openBpSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _BpSheet(),
    );
  }

  void _openTempSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _TempSheet(),
    );
  }
}

class _BpSheet extends StatefulWidget {
  const _BpSheet();
  @override
  State<_BpSheet> createState() => _BpSheetState();
}

class _BpSheetState extends State<_BpSheet> {
  int _sys = 120;
  int _dia = 78;
  int _pulse = 80;

  @override
  Widget build(BuildContext context) {
    final alert = _sys >= 140 || _dia >= 90;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 22,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            '血圧を記録する',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          _slider(
            '収縮期（上）',
            _sys,
            80,
            190,
            (v) => setState(() => _sys = v),
            unit: 'mmHg',
            alert: _sys >= 140,
          ),
          _slider(
            '拡張期（下）',
            _dia,
            40,
            130,
            (v) => setState(() => _dia = v),
            unit: 'mmHg',
            alert: _dia >= 90,
          ),
          _slider(
            '心拍',
            _pulse,
            40,
            140,
            (v) => setState(() => _pulse = v),
            unit: 'bpm',
            alert: _pulse >= 110,
          ),
          if (alert) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFDEBEE),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: const [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 17,
                    color: Color(0xFFE07C93),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '140/90 以上です。記録すると担当助産師へ自動でお知らせします。',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textBody,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                context.read<CareState>().addVitalQuick(
                  systolic: _sys,
                  diastolic: _dia,
                  pulse: _pulse,
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blushPinkDeep,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: const Text(
                '記録する',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _slider(
    String label,
    int value,
    int min,
    int max,
    ValueChanged<int> onChanged, {
    String unit = '',
    bool alert = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '$value $unit',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: alert
                    ? const Color(0xFFE07C93)
                    : AppColors.blushPinkDeep,
              ),
            ),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          activeColor: alert
              ? const Color(0xFFE07C93)
              : AppColors.blushPinkDeep,
          inactiveColor: AppColors.line,
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }
}

class _TempSheet extends StatefulWidget {
  const _TempSheet();
  @override
  State<_TempSheet> createState() => _TempSheetState();
}

class _TempSheetState extends State<_TempSheet> {
  double _temp = 36.6;
  double _weight = 58.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 22,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            '体温・体重を記録する',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text(
                '体温',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                '${_temp.toStringAsFixed(1)} ℃',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _temp >= 38
                      ? const Color(0xFFE07C93)
                      : AppColors.blushPinkDeep,
                ),
              ),
            ],
          ),
          Slider(
            value: _temp,
            min: 35.0,
            max: 40.0,
            divisions: 50,
            activeColor: _temp >= 38
                ? const Color(0xFFE07C93)
                : AppColors.blushPinkDeep,
            inactiveColor: AppColors.line,
            onChanged: (v) => setState(() => _temp = v),
          ),
          Row(
            children: [
              const Text(
                '体重',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                '${_weight.toStringAsFixed(1)} kg',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.blushPinkDeep,
                ),
              ),
            ],
          ),
          Slider(
            value: _weight,
            min: 38,
            max: 100,
            divisions: 124,
            activeColor: AppColors.blushPinkDeep,
            inactiveColor: AppColors.line,
            onChanged: (v) => setState(() => _weight = v),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                context.read<CareState>().addVitalQuick(
                  temperature: _temp,
                  weight: _weight,
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blushPinkDeep,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: const Text(
                '記録する',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
