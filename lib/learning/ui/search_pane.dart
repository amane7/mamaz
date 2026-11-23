import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../learning_search.dart';
import '../learning_state.dart';
import 'learning_widgets.dart';

/// 知識を探す：学びたい言葉から、端末内で関連する教材と基礎ノートを探す。
class SearchPane extends StatefulWidget {
  const SearchPane({super.key});

  @override
  State<SearchPane> createState() => _SearchPaneState();
}

class _SearchPaneState extends State<SearchPane> {
  static const _presets = ['双子の記録', '暗黙知・実地指導', 'プロラクチン・射乳', '胎盤の働き'];

  late final TextEditingController _input = TextEditingController(
    text: context.read<LearningState>().searchQuery,
  );

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _go([String? preset]) {
    if (preset != null) _input.text = preset;
    FocusScope.of(context).unfocus();
    context.read<LearningState>().search(_input.text);
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<LearningState>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      children: [
        const LearnHeading('知識を探す'),
        const SizedBox(height: 6),
        const Text(
          '学びたい言葉や質問から、端末内で関連する教材を探します。病名・緊急度・薬量の判定には使えません。',
          style: kLearnBody,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Semantics(
                label: '学びたいテーマ',
                child: TextField(
                  controller: _input,
                  maxLength: 160,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _go(),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textDark,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    counterText: '',
                    hintText: '例　双子の体重の記録をどう確かめる？',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      borderSide: const BorderSide(color: Color(0xFFCBD8CF)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      borderSide: const BorderSide(
                        color: kLearnTeal,
                        width: 1.6,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _go,
              style: FilledButton.styleFrom(
                backgroundColor: kLearnTeal,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('教材を探す'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            for (final p in _presets)
              LearnChipButton(label: p, onTap: () => _go(p)),
          ],
        ),
        const SizedBox(height: 14),
        ..._results(st),
        const LearningFooter(),
      ],
    );
  }

  List<Widget> _results(LearningState st) {
    final q = st.searchQuery;
    if (q.isEmpty) {
      return const [Text('学びたいテーマを入力するか、例を選んでください。', style: kLearnBody)];
    }
    if (LearningIndex.asksAboutRealCare(q)) {
      return const [
        LearnWarn(
          'この画面は架空事例を学ぶ場所です。実際の母子については担当の医療者へ、'
          '差し迫った危険があるときは施設の緊急手順・救急要請につないでください。',
        ),
      ];
    }
    final ids = st.index.rankCards(q);
    final notes = st.index.matchNotes(q);
    if (ids.isEmpty && notes.isEmpty) {
      return const [LearnWarn('該当する教材を特定できません。能力マップで原典を探すか、指導者に確認してください。')];
    }
    return [
      if (ids.isNotEmpty) ...[
        Align(
          alignment: Alignment.centerLeft,
          child: LearnFlag('教材カード · ${ids.length}件'),
        ),
        const SizedBox(height: 10),
      ],
      for (final id in ids) ...[
        () {
          final d = st.kb.cards[id]!;
          return SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${d.id} · ${d.status}', style: kLearnSmall),
                const SizedBox(height: 2),
                LearnHeading(d.title, size: 16),
                const SizedBox(height: 10),
                LearnSpot(d.question),
                const SizedBox(height: 10),
                Text(d.why, style: kLearnBody),
                const SizedBox(height: 6),
                Text('例　${d.example}', style: kLearnBody),
                const SizedBox(height: 6),
                Text(d.stop, style: kLearnSmall),
                const SizedBox(height: 4),
                SourceLinks(d.refs),
              ],
            ),
          );
        }(),
        const SizedBox(height: 12),
      ],
      if (notes.isNotEmpty) ...[
        const SizedBox(height: 4),
        const LearnHeading('関連する基礎ノート', size: 16),
        const SizedBox(height: 10),
      ],
      for (final n in notes) ...[
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LearnHeading(n.label, size: 14.5),
              const SizedBox(height: 8),
              NoteContent(n, key: ValueKey('search-note-${n.label}')),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    ];
  }
}
