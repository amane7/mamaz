import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selected = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final record = state.recordFor(_selected);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: const Text('産後ジャーナル')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            _calendarCard(state),
            const SizedBox(height: 18),
            _selectedDayCard(record),
            const SizedBox(height: 18),
            _trendCard(state),
            const SizedBox(height: 18),
            _epdsCard(state),
          ],
        ),
      ),
    );
  }

  // ---------- Calendar ----------
  Widget _calendarCard(AppState state) {
    final first = DateTime(_month.year, _month.month, 1);
    final startWeekday = first.weekday % 7; // Sun=0
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final weekLabels = ['日', '月', '火', '水', '木', '金', '土'];

    return SoftCard(
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Text(DateFormat('yyyy年 M月', 'ja').format(_month),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              _navBtn(Icons.chevron_left_rounded, () {
                setState(() =>
                    _month = DateTime(_month.year, _month.month - 1));
              }),
              const SizedBox(width: 6),
              _navBtn(Icons.chevron_right_rounded, () {
                setState(() =>
                    _month = DateTime(_month.year, _month.month + 1));
              }),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: weekLabels.asMap().entries.map((e) {
              final isSun = e.key == 0;
              final isSat = e.key == 6;
              return Expanded(
                child: Center(
                  child: Text(e.value,
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isSun
                              ? AppColors.blushPinkDeep
                              : isSat
                                  ? AppColors.lavender
                                  : AppColors.textMuted)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          ...List.generate(6, (week) {
            // skip empty trailing weeks
            if (week * 7 - startWeekday >= daysInMonth) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: List.generate(7, (wd) {
                  final dayNum = week * 7 + wd - startWeekday + 1;
                  if (dayNum < 1 || dayNum > daysInMonth) {
                    return const Expanded(child: SizedBox(height: 40));
                  }
                  final date = DateTime(_month.year, _month.month, dayNum);
                  return Expanded(child: _dayCell(date, state));
                }),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _dayCell(DateTime date, AppState state) {
    final isSelected = date.year == _selected.year &&
        date.month == _selected.month &&
        date.day == _selected.day;
    final today = DateTime.now();
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    final hasData = state.hasRecord(date);
    final mood = state.recordFor(date).mood;

    return GestureDetector(
      onTap: () => setState(() => _selected = date),
      child: Container(
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.blushPink
              : isToday
                  ? AppColors.cardPink
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${date.day}',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSelected || isToday ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : AppColors.textDark)),
            const SizedBox(height: 2),
            if (hasData)
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white
                        : (mood?.color ?? AppColors.blushPink),
                    shape: BoxShape.circle),
              )
            else
              const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
            color: AppColors.cardPink, shape: BoxShape.circle),
        child: Icon(icon, size: 20, color: AppColors.blushPinkDeep),
      ),
    );
  }

  // ---------- Selected day record ----------
  Widget _selectedDayCard(DailyRecord r) {
    final df = DateFormat('M月d日(E)', 'ja');
    return SoftCard(
      color: AppColors.cardCream,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(df.format(_selected),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              const Spacer(),
              GestureDetector(
                onTap: () => _openRecordEditor(r),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.blushPink,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_outlined, size: 14, color: Colors.white),
                      SizedBox(width: 5),
                      Text('記録をつける',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _miniStat('授乳', r.feedingCount > 0 ? '${r.feedingCount}回' : '—',
                  Icons.local_cafe_outlined, AppColors.blushPinkDeep),
              _divider(),
              _miniStat(
                  '睡眠',
                  r.sleepHours > 0
                      ? '${r.sleepHours.toStringAsFixed(1)}h'
                      : '—',
                  Icons.nightlight_round,
                  AppColors.lavender),
              _divider(),
              _miniStat('気分', r.mood?.emoji ?? '—',
                  Icons.favorite_border_rounded, AppColors.sageDeep,
                  isEmoji: r.mood != null),
            ],
          ),
          if (r.note != null && r.note!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14)),
              child: Text(r.note!,
                  style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textBody,
                      height: 1.5)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, IconData icon, Color color,
      {bool isEmoji = false}) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: isEmoji ? 20 : 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark)),
          const SizedBox(height: 2),
          Text(label,
              style:
                  const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 40, color: AppColors.line);

  // ---------- 7-day trend chart ----------
  Widget _trendCard(AppState state) {
    final data = state.recentRecords(7);
    final maxFeed = data.map((e) => e.feedingCount).fold<int>(1, (a, b) => b > a ? b : a);
    return SoftCard(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('体調トレンド（過去7日間）',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('授乳回数と気分の変化',
              style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
          const SizedBox(height: 18),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: data.map((r) {
                final h = (r.feedingCount / maxFeed) * 90;
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(r.mood?.emoji ?? '·',
                          style: const TextStyle(fontSize: 14)),
                      const SizedBox(height: 6),
                      Container(
                        width: 18,
                        height: h.clamp(6, 90),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [AppColors.blushPink, Color(0xFFFAD3DE)],
                          ),
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(DateFormat('E', 'ja').format(r.date),
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.textMuted)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- EPDS ----------
  Widget _epdsCard(AppState state) {
    final latest = state.recentRecords(7).reversed
        .firstWhere((r) => r.epdsScore != null,
            orElse: () => DailyRecord(date: DateTime.now()));
    final score = latest.epdsScore ?? 10;
    final isHigh = score >= 9;

    return SoftCard(
      color: isHigh ? const Color(0xFFFCF1EC) : AppColors.cardSage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.monitor_heart_outlined,
                  size: 20,
                  color: isHigh ? AppColors.mauve : AppColors.sageDeep),
              const SizedBox(width: 8),
              const Text('EPDS 産後うつスクリーニング',
                  style:
                      TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text('$score',
                  style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: isHigh ? AppColors.mauve : AppColors.sageDeep)),
              const Padding(
                padding: EdgeInsets.only(bottom: 6, left: 4),
                child: Text('/ 30',
                    style:
                        TextStyle(fontSize: 13, color: AppColors.textMuted)),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(isHigh ? '見守りが必要' : '安定しています',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color:
                            isHigh ? AppColors.mauve : AppColors.sageDeep)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isHigh
                ? '少しお疲れが見られます。ひとりで抱えこまず、MOAやリアル助産師にいつでも相談してくださいね。'
                : 'こころが穏やかな時間が増えています。この調子で、ご自身のペースを大切に。',
            style: const TextStyle(
                fontSize: 12, color: AppColors.textBody, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ---------- Record editor ----------
  void _openRecordEditor(DailyRecord existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecordEditor(
        date: _selected,
        existing: existing,
      ),
    );
  }
}

class _RecordEditor extends StatefulWidget {
  final DateTime date;
  final DailyRecord existing;
  const _RecordEditor({required this.date, required this.existing});

  @override
  State<_RecordEditor> createState() => _RecordEditorState();
}

class _RecordEditorState extends State<_RecordEditor> {
  late int _feeding;
  late double _sleep;
  Mood? _mood;
  late TextEditingController _note;

  @override
  void initState() {
    super.initState();
    _feeding = widget.existing.feedingCount;
    _sleep = widget.existing.sleepHours;
    _mood = widget.existing.mood;
    _note = TextEditingController(text: widget.existing.note ?? '');
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('M月d日(E)', 'ja');
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
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
                      borderRadius: BorderRadius.circular(3)),
                ),
              ),
              const SizedBox(height: 16),
              Text('${df.format(widget.date)} の記録',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              _label('授乳回数', '$_feeding 回'),
              _stepper(
                value: _feeding,
                onMinus: () => setState(
                    () => _feeding = (_feeding - 1).clamp(0, 30)),
                onPlus: () => setState(
                    () => _feeding = (_feeding + 1).clamp(0, 30)),
              ),
              const SizedBox(height: 18),
              _label('睡眠時間', '${_sleep.toStringAsFixed(1)} 時間'),
              Slider(
                value: _sleep,
                min: 0,
                max: 12,
                divisions: 24,
                activeColor: AppColors.lavender,
                inactiveColor: AppColors.lavenderSoft,
                onChanged: (v) => setState(() => _sleep = v),
              ),
              const SizedBox(height: 8),
              const Text('今日の気分',
                  style:
                      TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: Mood.values.map((m) {
                  final sel = _mood == m;
                  return GestureDetector(
                    onTap: () => setState(() => _mood = m),
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color:
                                sel ? m.color.withValues(alpha: 0.35) : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: sel ? m.color : AppColors.line,
                                width: sel ? 2 : 1),
                          ),
                          child: Center(
                              child: Text(m.emoji,
                                  style: const TextStyle(fontSize: 24))),
                        ),
                        const SizedBox(height: 5),
                        SizedBox(
                          width: 54,
                          child: Text(m.label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 9.5,
                                  color: sel
                                      ? AppColors.textDark
                                      : AppColors.textMuted)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              const Text('今日のひとことメモ',
                  style:
                      TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: AppShadows.card,
                ),
                child: TextField(
                  controller: _note,
                  minLines: 2,
                  maxLines: 4,
                  style: const TextStyle(fontSize: 13.5, height: 1.5),
                  decoration: const InputDecoration(
                    hintText: '気持ちや、気になったことを書いておきましょう。',
                    hintStyle: TextStyle(
                        color: AppColors.textMuted, fontSize: 13),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(14),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blushPinkDeep,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26)),
                  ),
                  child: const Text('記録を保存する',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.blushPinkDeep)),
        ],
      ),
    );
  }

  Widget _stepper({
    required int value,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) {
    return Row(
      children: [
        _circleBtn(Icons.remove_rounded, onMinus),
        Expanded(
          child: Center(
            child: Text('$value',
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800)),
          ),
        ),
        _circleBtn(Icons.add_rounded, onPlus),
      ],
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: AppShadows.card,
        ),
        child: Icon(icon, color: AppColors.blushPinkDeep),
      ),
    );
  }

  void _save() {
    final r = DailyRecord(
      date: widget.date,
      feedingCount: _feeding,
      sleepHours: _sleep,
      mood: _mood,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      epdsScore: widget.existing.epdsScore,
    );
    context.read<AppState>().saveRecord(r);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('記録を保存しました 🌸')),
    );
  }
}
