import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/facility.dart';
import '../ops/ops_models.dart';
import '../ops/ui/booking_wizard_screen.dart';
import '../services/care_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import 'intake_form_screen.dart';
import '../widgets/app_nav.dart';

/// 母乳ケア特化画面：授乳タイマー・記録・搾乳量・乳房セルフ観察・授乳姿勢ガイド
class BreastCareScreen extends StatefulWidget {
  const BreastCareScreen({super.key});

  @override
  State<BreastCareScreen> createState() => _BreastCareScreenState();
}

class _BreastCareScreenState extends State<BreastCareScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('母乳ケア'),
        bottom: TabBar(
          controller: _tab,
          labelColor: AppColors.blushPinkDeep,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.blushPinkDeep,
          indicatorWeight: 2.6,
          labelStyle: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
          tabs: const [
            Tab(text: '授乳記録'),
            Tab(text: '乳房ケア'),
            Tab(text: '姿勢ガイド'),
          ],
        ),
        actions: const [HomeButton(), SizedBox(width: 8)],
      ),
      body: SafeArea(
        top: false,
        child: TabBarView(
          controller: _tab,
          children: const [_FeedingTab(), _BreastTab(), _LatchTab()],
        ),
      ),
    );
  }
}

// ==================== 授乳記録タブ ====================
class _FeedingTab extends StatefulWidget {
  const _FeedingTab();
  @override
  State<_FeedingTab> createState() => _FeedingTabState();
}

class _FeedingTabState extends State<_FeedingTab> {
  Timer? _timer;
  int _seconds = 0;
  bool _running = false;
  FeedSide _side = FeedSide.left;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggle() {
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
    } else {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _seconds++);
      });
      setState(() => _running = true);
    }
  }

  void _save() {
    final minutes = (_seconds / 60).ceil();
    if (minutes < 1) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('1分以上の記録から保存できます')));
      return;
    }
    _timer?.cancel();
    context.read<CareState>().addFeed(minutes: minutes, side: _side);
    setState(() {
      _seconds = 0;
      _running = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$minutes分の授乳を記録しました（${_side.label}）')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final care = context.watch<CareState>();
    final today = care.todayFeeds;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        _summary(care),
        const SizedBox(height: 18),
        _timerCard(),
        const SizedBox(height: 16),
        _manualRow(context),
        const SizedBox(height: 22),
        SectionTitle(
          '今日の授乳（${today.length}回）',
          subtitle: '搾乳器を連携すると搾乳量が自動で入ります',
        ),
        const SizedBox(height: 12),
        if (today.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Text(
              'まだ記録がありません',
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            ),
          )
        else
          for (final f in today) ...[
            _feedTile(context, f),
            const SizedBox(height: 8),
          ],
        const SizedBox(height: 20),
        _pumpCard(context),
      ],
    );
  }

  Widget _summary(CareState care) {
    return SoftCard(
      color: Colors.white,
      shadow: AppShadows.soft,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _stat(
                  '今日の授乳',
                  '${care.todayFeedCount}',
                  '回',
                  AppColors.blushPinkDeep,
                ),
              ),
              Expanded(
                child: _stat(
                  '授乳時間',
                  '${care.todayFeedMinutes}',
                  '分',
                  AppColors.lavender,
                ),
              ),
              Expanded(
                child: _stat(
                  '搾乳量',
                  '${care.todayPumpMl}',
                  'ml',
                  AppColors.sageDeep,
                ),
              ),
            ],
          ),
          const Divider(height: 22, color: AppColors.line),
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 16,
                color: AppColors.mauve,
              ),
              const SizedBox(width: 7),
              Text(
                '最後の授乳：${care.sinceLastFeed}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textBody,
                ),
              ),
              const Spacer(),
              Text(
                care.todayFeedCount >= 8 ? '回数は目安内です' : '目安は1日8〜12回',
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, String unit, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              unit,
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _timerCard() {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return SoftCard(
      color: AppColors.cardPink,
      child: Column(
        children: [
          const Text(
            '授乳タイマー',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.blushPinkDeep,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$m:$s',
            style: const TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: FeedSide.values.map((sd) {
              final sel = _side == sd;
              return GestureDetector(
                onTap: () => setState(() => _side = sd),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.blushPinkDeep : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    sd.label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: sel ? Colors.white : AppColors.textBody,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: _toggle,
                    icon: Icon(
                      _running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 20,
                    ),
                    label: Text(
                      _running ? '一時停止' : '開始',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.blushPinkDeep,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(23),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: _seconds > 0 ? _save : null,
                    icon: const Icon(Icons.check_rounded, size: 20),
                    label: const Text(
                      '記録する',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blushPinkDeep,
                      disabledBackgroundColor: Colors.white54,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(23),
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

  Widget _manualRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const _ManualFeedSheet(),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: AppShadows.card,
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.edit_note_rounded,
                    size: 21,
                    color: AppColors.mauve,
                  ),
                  SizedBox(height: 6),
                  Text(
                    'あとから入力',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.mauve,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () {
              context.read<CareState>().syncPump();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('搾乳器のデータを取り込みました')));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: AppShadows.card,
              ),
              child: const Column(
                children: [
                  Icon(Icons.sync_rounded, size: 21, color: AppColors.sageDeep),
                  SizedBox(height: 6),
                  Text(
                    '搾乳器と同期',
                    style: TextStyle(
                      fontSize: 12,
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
    );
  }

  Widget _feedTile(BuildContext context, FeedingLog f) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.cardPink,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              f.side.label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
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
                  '${DateFormat('HH:mm').format(f.start)}〜・${f.minutes}分'
                  '${f.amountMl != null ? '・${f.amountMl}ml' : ''}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  f.source,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              size: 17,
              color: AppColors.textMuted,
            ),
            onPressed: () => context.read<CareState>().deleteFeed(f.id),
          ),
        ],
      ),
    );
  }

  Widget _pumpCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardLavender,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: const [
          Icon(
            Icons.devices_other_rounded,
            size: 19,
            color: AppColors.lavender,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Willow / Medela / Pigeon の搾乳器と連携すると、搾乳量が自動で記録され、助産師とのカルテにも反映されます。',
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.textBody,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== 乳房ケアタブ ====================
class _BreastTab extends StatefulWidget {
  const _BreastTab();
  @override
  State<_BreastTab> createState() => _BreastTabState();
}

class _BreastTabState extends State<_BreastTab> {
  final _symptoms = <String>{};
  int _pain = 0;
  final _memo = TextEditingController();

  static const _options = [
    'しこり',
    '赤み',
    '痛み',
    '熱感',
    '発熱',
    '白斑',
    '乳頭の傷',
    '張りが強い',
    '出が悪い',
  ];

  @override
  void dispose() {
    _memo.dispose();
    super.dispose();
  }

  String get _risk {
    final hot = _symptoms.contains('熱感') || _symptoms.contains('発熱');
    final red = _symptoms.contains('赤み');
    final lump = _symptoms.contains('しこり');
    if ((hot && red) || _pain >= 4) return 'high';
    if (lump || red || _pain >= 2) return 'mid';
    return 'low';
  }

  @override
  Widget build(BuildContext context) {
    final care = context.watch<CareState>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        const SectionTitle('乳房セルフ観察', subtitle: '気になる症状を選ぶと、乳腺炎のリスクを判定します'),
        const SizedBox(height: 12),
        SoftCard(
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '当てはまる症状',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _options.map((o) {
                  final sel = _symptoms.contains(o);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (sel) {
                        _symptoms.remove(o);
                      } else {
                        _symptoms.add(o);
                      }
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.blushPinkDeep : AppColors.cream,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: sel ? AppColors.blushPinkDeep : AppColors.line,
                        ),
                      ),
                      child: Text(
                        o,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: sel ? Colors.white : AppColors.textBody,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    '痛みの強さ',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$_pain / 5',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.blushPinkDeep,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _pain.toDouble(),
                min: 0,
                max: 5,
                divisions: 5,
                activeColor: AppColors.blushPinkDeep,
                inactiveColor: AppColors.line,
                onChanged: (v) => setState(() => _pain = v.round()),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: _memo,
                  minLines: 2,
                  maxLines: 4,
                  style: const TextStyle(fontSize: 12.5),
                  decoration: const InputDecoration(
                    hintText: 'メモ（例：右の外側上部に3cmほどのしこり）',
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(13),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _riskBox(),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _symptoms.isEmpty && _pain == 0
                      ? null
                      : () {
                          context.read<CareState>().addBreastCheck(
                            _symptoms.toList(),
                            _pain,
                            _memo.text.trim().isEmpty
                                ? null
                                : _memo.text.trim(),
                          );
                          setState(() {
                            _symptoms.clear();
                            _pain = 0;
                            _memo.clear();
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('観察記録を保存しました')),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blushPinkDeep,
                    disabledBackgroundColor: AppColors.line,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    '記録して助産師に共有',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _photoCard(),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _linkCard(
                context,
                '母乳ケア問診票',
                Icons.assignment_outlined,
                AppColors.cardPink,
                AppColors.blushPinkDeep,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const IntakeFormScreen(kind: IntakeKind.breast),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _linkCard(
                context,
                '母乳外来を予約',
                Icons.event_available_outlined,
                AppColors.cardSage,
                const Color(0xFF6FB57E),
                // §7 母乳外来は即時予約。§12 の条件判定を必ず通すため、
                // 旧・施設検索フローではなく Matching Engine 側の
                // 予約ウィザードへ直接つなぐ（用件が決まっているので
                // 目的選択のステップは飛ばす）。
                () => Navigator.push(
                  context,
                  warmRoute(
                    const BookingWizardScreen(
                      presetKind: ServiceKind.breastClinic,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        if (care.breastChecks.isNotEmpty) ...[
          const SectionTitle('観察の履歴'),
          const SizedBox(height: 12),
          for (final c in care.breastChecks.take(6)) ...[
            _checkTile(c),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }

  Widget _riskBox() {
    final (label, msg, color, bg) = switch (_risk) {
      'high' => (
        '乳腺炎の可能性が高いです',
        '早めの受診をおすすめします。授乳・搾乳は止めず、飲ませる角度を変えてみてください。38℃以上の発熱があるときは当日の受診を。',
        const Color(0xFFE07C93),
        const Color(0xFFFDEBEE),
      ),
      'mid' => (
        '乳管閉塞の初期かもしれません',
        '授乳前に温め、痛む側から飲ませてみてください。24時間改善しない場合は母乳外来へ。',
        const Color(0xFFC98A4B),
        AppColors.cardCream,
      ),
      _ => (
        '今は落ち着いた状態です',
        '引き続き、1日8〜12回の授乳と深く含ませることを意識してみてください。',
        const Color(0xFF6FB57E),
        AppColors.cardSage,
      ),
    };
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _risk == 'low'
                    ? Icons.check_circle_outline_rounded
                    : Icons.warning_amber_rounded,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            msg,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textBody,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.cardLavender,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.photo_camera_outlined,
              size: 20,
              color: AppColors.lavender,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '乳房写真の記録（準備中）',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 4),
                Text(
                  '端末内で暗号化して保存し、担当助産師にのみ共有。AIによる乳腺炎の早期検知を予定しています。',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textBody,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _linkCard(
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
        padding: const EdgeInsets.symmetric(vertical: 16),
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

  Widget _checkTile(BreastCheck c) {
    final color = switch (c.risk) {
      'high' => const Color(0xFFE07C93),
      'mid' => const Color(0xFFC98A4B),
      _ => const Color(0xFF6FB57E),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.symptoms.isEmpty ? '症状なし' : c.symptoms.join('・'),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '痛み${c.painLevel}/5・${DateFormat('M月d日 HH:mm').format(c.date)}',
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
}

// ==================== 姿勢ガイドタブ ====================
class _LatchTab extends StatelessWidget {
  const _LatchTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        SoftCard(
          color: AppColors.cardPink,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                '深く含ませる（ラッチオン）の4つのポイント',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 10),
              Text(
                '① 赤ちゃんの唇が外向きにめくれている\n'
                '② あごが乳房に触れている\n'
                '③ 耳・肩・腰が一直線\n'
                '④ 飲むリズムでこめかみが動く',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textBody,
                  height: 1.9,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const SectionTitle('授乳姿勢ガイド', subtitle: '3Dアニメーション版は開発中です'),
        const SizedBox(height: 12),
        for (final g in latchGuides) ...[
          _guideCard(g),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardSage,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: const [
              Icon(
                Icons.view_in_ar_outlined,
                size: 19,
                color: Color(0xFF6FB57E),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '3Dアニメーションによる授乳姿勢ガイド（LatchAid型）を開発中です。乳房の断面と赤ちゃんの口の動きを、角度を変えて確認できるようになります。',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textBody,
                    height: 1.55,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _guideCard(LatchGuide g) {
    return SoftCard(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: g.color.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(g.icon, size: 22, color: AppColors.mauve),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      g.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      g.point,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.blushPinkDeep,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            g.detail,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textBody,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== 手入力シート ====================
class _ManualFeedSheet extends StatefulWidget {
  const _ManualFeedSheet();
  @override
  State<_ManualFeedSheet> createState() => _ManualFeedSheetState();
}

class _ManualFeedSheetState extends State<_ManualFeedSheet> {
  int _minutes = 15;
  int _amount = 0;
  FeedSide _side = FeedSide.both;
  TimeOfDay _time = TimeOfDay.now();

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
            '授乳を記録する',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text(
                '開始時刻',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: _time,
                  );
                  if (t != null) setState(() => _time = t);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.blushPinkDeep,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text(
                '授乳時間',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                '$_minutes 分',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.blushPinkDeep,
                ),
              ),
            ],
          ),
          Slider(
            value: _minutes.toDouble(),
            min: 1,
            max: 60,
            activeColor: AppColors.blushPinkDeep,
            inactiveColor: AppColors.line,
            onChanged: (v) => setState(() => _minutes = v.round()),
          ),
          Row(
            children: [
              const Text(
                '搾乳量・ミルク量',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                _amount == 0 ? '記録しない' : '$_amount ml',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.blushPinkDeep,
                ),
              ),
            ],
          ),
          Slider(
            value: _amount.toDouble(),
            min: 0,
            max: 250,
            divisions: 50,
            activeColor: AppColors.blushPinkDeep,
            inactiveColor: AppColors.line,
            onChanged: (v) => setState(() => _amount = v.round()),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: FeedSide.values.map((sd) {
              final sel = _side == sd;
              return GestureDetector(
                onTap: () => setState(() => _side = sd),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.blushPinkDeep : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    sd.label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: sel ? Colors.white : AppColors.textBody,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                final now = DateTime.now();
                context.read<CareState>().addFeed(
                  minutes: _minutes,
                  side: _side,
                  amountMl: _amount == 0 ? null : _amount,
                  start: DateTime(
                    now.year,
                    now.month,
                    now.day,
                    _time.hour,
                    _time.minute,
                  ),
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
