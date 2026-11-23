import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../learning_models.dart';
import '../learning_state.dart';
import 'learning_widgets.dart';

/// 能力マップ：ICM 2024 の37項目と、国内実務14領域の基礎ノート。
class MapPane extends StatelessWidget {
  const MapPane({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<LearningState>();
    final kb = st.kb;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      children: [
        const LearnHeading('助産実践の能力マップ'),
        const SizedBox(height: 6),
        const Text(
          'ICM 2024の37項目と日本助産師会の4領域を照合した開発用の索引です。'
          '各課題と対応付けはMAMOAの案です。正式な能力認定には監督下の実践評価が必要です。',
          style: kLearnBody,
        ),
        const SizedBox(height: 12),
        for (final group in kb.groups) ...[
          _Fold(
            title: '$group　${kb.competenciesIn(group).length}項目',
            children: [
              for (final c in kb.competenciesIn(group)) _CompetencyEntry(c),
            ],
          ),
          const SizedBox(height: 10),
        ],
        _Fold(
          title: '国内実務の学習領域　${kb.notes.length}領域',
          children: [for (final n in kb.notes) _NoteEntry(n)],
        ),
        const LearningFooter(),
      ],
    );
  }
}

class _Fold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Fold({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey('learn-map-$title'),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          iconColor: kLearnTeal,
          collapsedIconColor: kLearnTeal,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          expandedAlignment: Alignment.topLeft,
          children: children,
        ),
      ),
    );
  }
}

class _CompetencyEntry extends StatelessWidget {
  final Competency c;
  const _CompetencyEntry(this.c);

  @override
  Widget build(BuildContext context) {
    final st = context.read<LearningState>();
    final active = st.kb.cardsFor(c.code);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LearnHeading('${c.code}　${c.theme}', size: 14),
          const SizedBox(height: 4),
          Text(c.task, style: kLearnBody),
          const SizedBox(height: 4),
          Text(
            '${c.dom} ／ 原典 p.${c.page} ／ ${active.isNotEmpty ? '関連する教材' : '索引のみ'}',
            style: kLearnSmall,
          ),
          if (active.isNotEmpty)
            Wrap(
              spacing: 8,
              children: [
                for (final card in active)
                  LearnChipButton(
                    label: '${card.id} ${card.title}',
                    onTap: () => st.openCardInSearch(card.id),
                  ),
              ],
            ),
          SourceLinks(c.refs),
        ],
      ),
    );
  }
}

class _NoteEntry extends StatelessWidget {
  final FoundationNote n;
  const _NoteEntry(this.n);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LearnHeading(n.label, size: 14),
          const SizedBox(height: 4),
          Text(n.topics, style: kLearnBody),
          const SizedBox(height: 4),
          Text(n.task, style: kLearnSmall),
          const SizedBox(height: 8),
          NoteContent(n, key: ValueKey('map-note-${n.label}')),
        ],
      ),
    );
  }
}
