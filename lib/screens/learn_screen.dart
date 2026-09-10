import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/care_state.dart';
import '../theme/app_theme.dart';
import '../ops/ui/ops_ui.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import 'article_screen.dart';
import 'breast_care_screen.dart';
import 'epds_screen.dart';
import 'health_screen.dart';
import 'notification_screen.dart';
import 'online_visit_screen.dart';

/// ---------------------------------------------------------------------------
/// 「学ぶ・そなえる」（§5 の5カテゴリを増やさないための置き場）
///
/// §5 が定める家族トップのカテゴリは5つだけです。そこへ読みものや
/// セルフチェックを足すと「1画面1テーマ」（§25）が崩れ、
/// 予約という主目的が埋もれます。
///
/// いっぽうで、からだの記録・こころのセルフチェック・母乳の観察・
/// オンライン面談・読みものは家族にとって価値があるため、
/// 予約導線とは別のタブにまとめて残しました。
///
/// ここには「予約を確定させるボタン」を置きません。
/// 予約は必ず Matching Engine（§12）を通します。
/// ---------------------------------------------------------------------------
class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final care = context.watch<CareState>();
    final unread = care.unreadCount;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: warmList([
            _header(context, unread),
            const SizedBox(height: 20),

            const SectionTitle('からだと、こころ', subtitle: '気になったときだけ、のぞいてください'),
            const SizedBox(height: 12),
            _tile(
              context,
              title: 'からだの記録',
              sub: '体温・血圧・体重などをまとめて見返せます',
              icon: Icons.favorite_outline_rounded,
              color: AppColors.blushPinkDeep,
              onTap: () =>
                  Navigator.push(context, warmRoute(const HealthScreen())),
            ),
            const SizedBox(height: 10),
            _tile(
              context,
              title: 'こころのセルフチェック',
              sub: '10問・約2分。結果は自動で誰かに送られたりしません',
              icon: Icons.self_improvement_outlined,
              color: AppColors.lavender,
              onTap: () =>
                  Navigator.push(context, warmRoute(const EpdsScreen())),
            ),
            const SizedBox(height: 10),
            _tile(
              context,
              title: '母乳・授乳の観察',
              sub: 'そのまま母乳外来のご予約にも進めます',
              icon: Icons.water_drop_outlined,
              color: AppColors.mauve,
              onTap: () =>
                  Navigator.push(context, warmRoute(const BreastCareScreen())),
            ),

            const SizedBox(height: 24),
            const SectionTitle('オンラインで話す', subtitle: '外に出なくても、顔を見て相談できます'),
            const SizedBox(height: 12),
            _tile(
              context,
              title: 'オンライン面談',
              sub: '助産師とビデオでお話しします',
              icon: Icons.videocam_outlined,
              color: AppColors.sageDeep,
              onTap: () =>
                  Navigator.push(context, warmRoute(const OnlineVisitScreen())),
            ),

            const SizedBox(height: 24),
            const SectionTitle('読みもの', subtitle: '夜中に読んでも、だいじょうぶな短さです'),
            const SizedBox(height: 12),
            _tile(
              context,
              title: '記事をさがす',
              sub: '授乳・睡眠・気持ちのゆらぎなど',
              icon: Icons.menu_book_outlined,
              color: AppColors.mauve,
              onTap: () =>
                  Navigator.push(context, warmRoute(const ArticleListScreen())),
            ),

            const SizedBox(height: 22),
            const InfoNote(
              title: 'ここに予約のボタンはありません',
              text:
                  'ご予約は「ホーム」からお願いします。'
                  'ご利用条件や空き状況をきちんと確認したうえでご案内するため、'
                  '入口をひとつにまとめています。',
              icon: Icons.info_outline_rounded,
              color: AppColors.lavender,
            ),
          ]),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, int unread) => SoftCard(
    color: AppColors.cardLavender,
    child: Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '学ぶ・そなえる',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'いま必要なものだけ選んでください。\nぜんぶ見なくても大丈夫です。',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.45,
                  color: AppColors.textBody,
                ),
              ),
            ],
          ),
        ),
        Pressable(
          radius: BorderRadius.circular(14),
          onTap: () =>
              Navigator.push(context, warmRoute(const NotificationScreen())),
          child: Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.notifications_none_rounded,
                  size: 22,
                  color: AppColors.mauve,
                ),
                if (unread > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97A7A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$unread',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _tile(
    BuildContext context, {
    required String title,
    required String sub,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: '$title。$sub',
      child: SoftCard(
        onTap: onTap,
        color: AppColors.surface,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 21, color: color),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    sub,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
