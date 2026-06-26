import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class ReservationScreen extends StatelessWidget {
  const ReservationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final upcoming = state.upcomingReservations;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: const Text('予約・オンラインケア')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            const Text('助産師とつながる、いつでもそばにある安心。',
                style: TextStyle(
                    fontSize: 13, color: AppColors.textBody, height: 1.5)),
            const SizedBox(height: 18),
            if (upcoming.isNotEmpty) ...[
              const SectionTitle('予約中のケア'),
              const SizedBox(height: 12),
              for (final r in upcoming) _reservationTile(context, r),
              const SizedBox(height: 22),
            ],
            const SectionTitle('ケアを予約する',
                subtitle: '通所・宿泊・母乳外来・オンライン相談を一元予約'),
            const SizedBox(height: 14),
            for (final c in CareType.values) ...[
              _careCard(context, c),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            _lineNote(),
          ],
        ),
      ),
    );
  }

  Widget _reservationTile(BuildContext context, Reservation r) {
    final df = DateFormat('M月d日(E) HH:mm', 'ja');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        color: Colors.white,
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: r.type.color.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(r.type.icon, color: AppColors.mauve, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.type.title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(
                    df.format(r.dateTime) +
                        (r.durationHours > 0 ? ' ・${r.durationHours}時間' : ''),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TagChip(r.status,
                    color: r.status == '確定'
                        ? AppColors.cardSage
                        : AppColors.cardCream,
                    textColor: r.status == '確定'
                        ? AppColors.sageDeep
                        : AppColors.mauve),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _confirmCancel(context, r),
                  child: const Text('キャンセル',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          decoration: TextDecoration.underline)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmCancel(BuildContext context, Reservation r) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('予約をキャンセルしますか？'),
        content: Text('${r.type.title} の予約をキャンセルします。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('もどる')),
          TextButton(
            onPressed: () {
              context.read<AppState>().cancelReservation(r.id);
              Navigator.pop(context);
            },
            child: const Text('キャンセルする',
                style: TextStyle(color: AppColors.blushPinkDeep)),
          ),
        ],
      ),
    );
  }

  Widget _careCard(BuildContext context, CareType c) {
    return SoftCard(
      color: Colors.white,
      onTap: () => _openBooking(context, c),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: c.color.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(c.icon, color: AppColors.mauve, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.title,
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(c.subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }

  Widget _lineNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSage,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: const [
          Icon(Icons.chat_outlined, color: Color(0xFF6FB57E), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '訪問ケアは当面、公式LINEでの日程調整となります。予約が入ると公式LINEへ通知が届きます。',
              style: TextStyle(
                  fontSize: 11.5, color: AppColors.textBody, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  void _openBooking(BuildContext context, CareType c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BookingSheet(careType: c),
    );
  }
}

class _BookingSheet extends StatefulWidget {
  final CareType careType;
  const _BookingSheet({required this.careType});

  @override
  State<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<_BookingSheet> {
  DateTime _selectedDay = DateTime.now().add(const Duration(days: 1));
  String? _slot;
  int _duration = 2;

  final _slots = const [
    '09:00', '09:30', '10:00', '10:30', '11:00',
    '13:00', '13:30', '14:00', '14:30', '15:00', '15:30'
  ];

  bool get _needsDuration =>
      widget.careType == CareType.house || widget.careType == CareType.breast;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('M月d日(E)', 'ja');
    final days = List.generate(
        10, (i) => DateTime.now().add(Duration(days: i + 1)));

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
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: widget.careType.color.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(widget.careType.icon,
                        color: AppColors.mauve, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(widget.careType.title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text('日付を選ぶ',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              SizedBox(
                height: 76,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: days.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final d = days[i];
                    final sel = d.day == _selectedDay.day &&
                        d.month == _selectedDay.month;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedDay = d),
                      child: Container(
                        width: 58,
                        decoration: BoxDecoration(
                          color: sel ? AppColors.blushPink : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: AppShadows.card,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(DateFormat('E', 'ja').format(d),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: sel
                                        ? Colors.white
                                        : AppColors.textMuted)),
                            const SizedBox(height: 4),
                            Text('${d.day}',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: sel
                                        ? Colors.white
                                        : AppColors.textDark)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (_needsDuration) ...[
                const SizedBox(height: 18),
                const Text('ケア時間を選ぶ',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [2, 3, 4, 5, 6].map((h) {
                    final sel = _duration == h;
                    return ChoiceChip(
                      label: Text('$h時間'),
                      selected: sel,
                      onSelected: (_) => setState(() => _duration = h),
                      selectedColor: AppColors.blushPink,
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                          fontSize: 13,
                          color: sel ? Colors.white : AppColors.textBody,
                          fontWeight: FontWeight.w600),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: const BorderSide(color: AppColors.line)),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 18),
              const Text('時間を選ぶ（30分刻み）',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _slots.map((s) {
                  final sel = _slot == s;
                  return GestureDetector(
                    onTap: () => setState(() => _slot = s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.blushPink : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: AppShadows.card,
                      ),
                      child: Text(s,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color:
                                  sel ? Colors.white : AppColors.textBody)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _slot == null ? null : () => _confirm(df),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blushPinkDeep,
                    disabledBackgroundColor: AppColors.line,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26)),
                  ),
                  child: const Text('この内容で予約する',
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

  void _confirm(DateFormat df) {
    final parts = _slot!.split(':');
    final dt = DateTime(_selectedDay.year, _selectedDay.month,
        _selectedDay.day, int.parse(parts[0]), int.parse(parts[1]));
    context.read<AppState>().addReservation(
        widget.careType, dt, _needsDuration ? _duration : 0,
        status: widget.careType == CareType.visit ? '調整中' : '確定');
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                  color: AppColors.cardSage, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded,
                  color: Color(0xFF6FB57E), size: 34),
            ),
            const SizedBox(height: 16),
            const Text('予約が完了しました',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('${df.format(_selectedDay)} $_slot〜\n公式LINEへ通知が届きます。',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textBody,
                    height: 1.5)),
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK',
                  style: TextStyle(color: AppColors.blushPinkDeep)),
            ),
          ),
        ],
      ),
    );
  }
}
