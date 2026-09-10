import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/facility.dart';
import '../services/care_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import '../widgets/app_nav.dart';

/// 通知センター（LINE / プッシュ通知の履歴）
class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final care = context.watch<CareState>();
    final list = care.notifications;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('お知らせ'),
        actions: [
          TextButton(
            onPressed: care.unreadCount == 0
                ? null
                : () => context.read<CareState>().markAllRead(),
            child: Text(
              'すべて既読',
              style: TextStyle(
                fontSize: 12.5,
                color: care.unreadCount == 0
                    ? AppColors.textMuted
                    : AppColors.blushPinkDeep,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          HomeButton(),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: list.isEmpty
            ? const Padding(
                padding: EdgeInsets.fromLTRB(24, 60, 24, 24),
                child: WarmEmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: 'お知らせはまだありません',
                  message: '予約のリマインドや、助産師からのご連絡は\nここに届きます。見逃しても大丈夫です。',
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                itemCount: list.length,
                itemBuilder: (context, i) => FadeSlideIn(
                  delay: Duration(milliseconds: 40 + (i < 10 ? i : 10) * 50),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 11),
                    child: _tile(context, list[i]),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _tile(BuildContext context, AppNotification n) {
    return SoftCard(
      color: n.read ? Colors.white : const Color(0xFFFFFAFB),
      border: n.read
          ? null
          : Border.all(color: AppColors.blushPink.withValues(alpha: 0.5)),
      onTap: () => context.read<CareState>().markRead(n.id),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: n.kind.color.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(n.kind.icon, size: 19, color: AppColors.mauve),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        n.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: n.read
                              ? FontWeight.w600
                              : FontWeight.w800,
                          height: 1.4,
                        ),
                      ),
                    ),
                    if (!n.read)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.blushPinkDeep,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  n.body,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textBody,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TagChip(
                      n.channel,
                      color: n.channel == 'LINE'
                          ? AppColors.cardSage
                          : AppColors.cardLavender,
                      textColor: n.channel == 'LINE'
                          ? const Color(0xFF6FB57E)
                          : AppColors.lavender,
                    ),
                    const Spacer(),
                    Text(
                      _ago(n.time),
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'たった今';
    if (d.inMinutes < 60) return '${d.inMinutes}分前';
    if (d.inHours < 24) return '${d.inHours}時間前';
    if (d.inDays < 7) return '${d.inDays}日前';
    return DateFormat('M月d日').format(t);
  }
}
