import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class HomeScreen extends StatelessWidget {
  final void Function(int tab) onNavigate;
  const HomeScreen({super.key, required this.onNavigate});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 5) return 'おつかれさまです';
    if (h < 11) return 'おはようございます';
    if (h < 18) return 'こんにちは';
    return 'こんばんは';
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final today = state.today;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF1F4), AppColors.cream],
          stops: [0, 0.4],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            _topBar(context, state),
            const SizedBox(height: 18),
            _todayWord(),
            const SizedBox(height: 22),
            const Text('今日の記録サマリー',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark)),
            const SizedBox(height: 12),
            _recordSummary(context, today),
            const SizedBox(height: 22),
            _soraMessage(context),
            const SizedBox(height: 22),
            _quickActions(context),
          ],
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context, AppState state) {
    return Row(
      children: [
        const MamoaLogo(size: 38),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_greeting()}、${state.motherName}',
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark)),
              const SizedBox(height: 2),
              const Text('今日も、あなたを応援しています。',
                  style:
                      TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
            ],
          ),
        ),
        _bell(context),
      ],
    );
  }

  Widget _bell(BuildContext context) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('新しいお知らせはありません')),
        );
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: AppShadows.card,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.notifications_none_rounded,
                color: AppColors.mauve, size: 22),
            Positioned(
              top: 11,
              right: 12,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    color: AppColors.blushPinkDeep, shape: BoxShape.circle),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _todayWord() {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      shadow: AppShadows.soft,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              width: 92,
              height: 92,
              color: AppColors.cardPink,
              padding: const EdgeInsets.all(6),
              child: Image.asset('assets/images/mascot.png', fit: BoxFit.contain),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('今日のひとこと',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.blushPinkDeep,
                        fontWeight: FontWeight.w700)),
                SizedBox(height: 8),
                Text('よくここまで\nがんばってるよ。',
                    style: TextStyle(
                        fontSize: 17,
                        height: 1.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark)),
                SizedBox(height: 6),
                Text('— MOAより 🌸',
                    style:
                        TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _recordSummary(BuildContext context, DailyRecord today) {
    return Row(
      children: [
        Expanded(
          child: _summaryTile(
            context,
            label: '授乳',
            value: today.feedingCount > 0 ? '${today.feedingCount}' : '—',
            unit: '回',
            color: AppColors.cardPink,
            icon: Icons.local_cafe_outlined,
            iconColor: AppColors.blushPinkDeep,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryTile(
            context,
            label: '睡眠',
            value: today.sleepHours > 0
                ? today.sleepHours.toStringAsFixed(1)
                : '—',
            unit: '時間',
            color: AppColors.cardLavender,
            icon: Icons.nightlight_round,
            iconColor: AppColors.lavender,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryTile(
            context,
            label: '気分',
            value: today.mood?.emoji ?? '—',
            unit: today.mood?.label ?? '未記録',
            color: AppColors.cardSage,
            icon: Icons.favorite_border_rounded,
            iconColor: AppColors.sageDeep,
            isEmoji: today.mood != null,
          ),
        ),
      ],
    );
  }

  Widget _summaryTile(
    BuildContext context, {
    required String label,
    required String value,
    required String unit,
    required Color color,
    required IconData icon,
    required Color iconColor,
    bool isEmoji = false,
  }) {
    return GestureDetector(
      onTap: () => onNavigate(4),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textBody,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: isEmoji ? 22 : 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark)),
            const SizedBox(height: 2),
            Text(unit,
                style: const TextStyle(
                    fontSize: 10.5, color: AppColors.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _soraMessage(BuildContext context) {
    return SoftCard(
      onTap: () => onNavigate(1),
      color: const Color(0xFFFDF3F6),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.blushPink, AppColors.lavender],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MOAからのメッセージ',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.blushPinkDeep)),
                SizedBox(height: 5),
                Text('夜間の授乳、おつかれさまです。何か気になることがあれば、いつでも聞いてくださいね。',
                    style: TextStyle(
                        fontSize: 12.5,
                        height: 1.5,
                        color: AppColors.textBody)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }

  Widget _quickActions(BuildContext context) {
    final actions = [
      (_QA('MOAに相談', Icons.chat_bubble_outline_rounded, AppColors.blushPink, 1)),
      (_QA('ケアを予約', Icons.calendar_today_outlined, AppColors.sageDeep, 2)),
      (_QA('つながり広場', Icons.groups_outlined, AppColors.lavender, 3)),
      (_QA('ジャーナル', Icons.menu_book_outlined, AppColors.mauve, 4)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('できること',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark)),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final a in actions) ...[
              Expanded(
                child: GestureDetector(
                  onTap: () => onNavigate(a.tab),
                  child: Column(
                    children: [
                      Container(
                        height: 58,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          boxShadow: AppShadows.card,
                        ),
                        child: Icon(a.icon, color: a.color, size: 24),
                      ),
                      const SizedBox(height: 7),
                      Text(a.label,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textBody,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              if (a != actions.last) const SizedBox(width: 10),
            ],
          ],
        ),
      ],
    );
  }
}

class _QA {
  final String label;
  final IconData icon;
  final Color color;
  final int tab;
  _QA(this.label, this.icon, this.color, this.tab);
}
