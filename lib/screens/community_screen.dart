import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  int _filter = 0; // 0:すべて 1:フォロー 2:マイグループ

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 60) return '${diff.inMinutes}分前';
    if (diff.inHours < 24) return '${diff.inHours}時間前';
    return '${diff.inDays}日前';
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final posts = state.posts;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('つながり広場'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(54),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  _filterChip(['すべて', 'フォロー', 'マイグループ'][i], i),
                  if (i < 2) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
          children: [
            _intro(),
            const SizedBox(height: 16),
            for (final p in posts) _postCard(context, p, state),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCompose(context),
        backgroundColor: AppColors.blushPinkDeep,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.edit_outlined, size: 18),
        label: const Text('投稿する',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _filterChip(String label, int i) {
    final sel = _filter == i;
    return GestureDetector(
      onTap: () => setState(() => _filter = i),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? AppColors.blushPink : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: sel ? AppColors.blushPink : AppColors.line),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: sel ? Colors.white : AppColors.textBody)),
      ),
    );
  }

  Widget _intro() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFFF7EDF7), Color(0xFFFDEFF3)]),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: const [
          Icon(Icons.groups_rounded, color: AppColors.lavender, size: 26),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'ママ同士で、やさしくつながる場所。\n同じ月齢のママと匿名でつながれます。助産師がそっと見守っています。',
              style: TextStyle(
                  fontSize: 12, color: AppColors.textBody, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _postCard(BuildContext context, CommunityPost p, AppState state) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: SoftCard(
        color: Colors.white,
        border: p.isMidwife
            ? Border.all(color: AppColors.blushPink.withValues(alpha: 0.5))
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: p.isMidwife
                        ? const LinearGradient(
                            colors: [AppColors.blushPink, AppColors.lavender])
                        : null,
                    color: p.isMidwife ? null : AppColors.cardPink,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    p.isMidwife ? Icons.auto_awesome : Icons.face_retouching_natural,
                    size: 20,
                    color: p.isMidwife ? Colors.white : AppColors.blushPinkDeep,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(p.authorName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700)),
                          ),
                          if (p.isMidwife) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.verified_rounded,
                                size: 14, color: AppColors.blushPinkDeep),
                          ],
                        ],
                      ),
                      Text('${p.babyMonth} ・ ${_timeAgo(p.time)}',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(p.text,
                style: const TextStyle(
                    fontSize: 13.5, height: 1.6, color: AppColors.textDark)),
            const SizedBox(height: 14),
            Row(
              children: [
                _actionBtn(
                  icon: p.liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  label: '${p.likes}',
                  color: p.liked ? AppColors.blushPinkDeep : AppColors.textMuted,
                  onTap: () => state.toggleLike(p.id),
                ),
                const SizedBox(width: 20),
                _actionBtn(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: '${p.comments}',
                  color: AppColors.textMuted,
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('コメント機能は近日公開予定です')),
                  ),
                ),
                const Spacer(),
                Icon(Icons.bookmark_border_rounded,
                    size: 18, color: AppColors.textMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12.5, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _openCompose(BuildContext context) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
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
              const Text('気持ちをシェアする',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text('匿名で投稿されます。やさしい言葉でつながりましょう。',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: AppShadows.card,
                ),
                child: TextField(
                  controller: controller,
                  minLines: 4,
                  maxLines: 7,
                  autofocus: true,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                  decoration: const InputDecoration(
                    hintText: '今日のできごとや、気持ちを書いてみましょう…',
                    hintStyle: TextStyle(
                        color: AppColors.textMuted, fontSize: 13.5),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    if (controller.text.trim().isEmpty) return;
                    context.read<AppState>().addPost(controller.text.trim());
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blushPinkDeep,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25)),
                  ),
                  child: const Text('投稿する',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
