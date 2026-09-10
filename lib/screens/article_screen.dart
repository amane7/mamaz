import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/facility.dart';
import '../services/care_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/app_nav.dart';

/// 記事一覧（医学的根拠に基づくコラム）
class ArticleListScreen extends StatelessWidget {
  const ArticleListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final care = context.watch<CareState>();
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('読みもの'),
        actions: const [HomeButton(), SizedBox(width: 8)],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            const Text(
              '助産師が監修した、産後のからだ・こころ・母乳のこと。',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textBody,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 18),
            for (final a in care.articles) ...[
              _card(context, a),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, Article a) {
    return SoftCard(
      color: Colors.white,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ArticleDetailScreen(article: a)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: a.color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(a.icon, size: 24, color: AppColors.mauve),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    TagChip(
                      a.category,
                      color: AppColors.cardPink,
                      textColor: AppColors.blushPinkDeep,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      a.readMin,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  a.title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
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

class ArticleDetailScreen extends StatelessWidget {
  final Article article;
  const ArticleDetailScreen({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: Text(article.category),
        actions: const [HomeButton(), SizedBox(width: 8)],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Container(
              height: 110,
              decoration: BoxDecoration(
                color: article.color,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Center(
                child: Icon(article.icon, size: 50, color: AppColors.mauve),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              article.title,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                height: 1.5,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                TagChip(
                  article.category,
                  color: AppColors.cardPink,
                  textColor: AppColors.blushPinkDeep,
                ),
                const SizedBox(width: 8),
                Text(
                  '${article.readMin}で読めます',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SoftCard(
              color: Colors.white,
              child: Text(
                article.body,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.95,
                  color: AppColors.textDark,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cardSage,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: const [
                  Icon(
                    Icons.verified_outlined,
                    size: 18,
                    color: Color(0xFF6FB57E),
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      '監修：助産師 南田 みなみ（ママズケア 助産院）',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textBody,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
