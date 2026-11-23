import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../charting/chart_assist.dart';
import '../../charting/insight_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../learning_state.dart';
import 'learning_widgets.dart';

/// 現場の気づき：記録づくりの途中で、助産師が自分で残した覚え書き。
class InsightsPane extends StatelessWidget {
  const InsightsPane({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<InsightStore>();
    final st = context.read<LearningState>();
    final notes = store.notes;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      children: [
        const LearnHeading('現場の気づき'),
        const SizedBox(height: 6),
        const Text(
          '記録づくりの途中で、助産師が自分で「残す」を選んだ覚え書きです。'
          '会話や下書き、お名前は含みません。監修前で、教材ではありません。'
          'この試作ではアプリを閉じると消えます。',
          style: kLearnBody,
        ),
        const SizedBox(height: 12),
        if (notes.isEmpty)
          const LearnNote(
            'まだ気づきはありません。「会話からカルテの下書き」で問いを見たときに、'
            '自分ならどう扱うかを残せます。',
          ),
        for (final n in notes) ...[
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    LearnFlag(n.stance.label),
                    Text(
                      '${InsightNote.status} · ${_time(n.at)}',
                      style: kLearnSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (n.kind != null) ...[
                  Text('問いの種類　${n.kind!.label}', style: kLearnSmall),
                  const SizedBox(height: 4),
                ],
                Text(
                  n.text,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.7,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    if (n.kind != null)
                      LearnChipButton(
                        label: '教材 ${n.kind!.cardId} を開く',
                        onTap: () => st.openCardInSearch(n.kind!.cardId),
                      ),
                    LearnChipButton(
                      label: '取り消す',
                      onTap: () => store.remove(n.id),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        // 学習室共通のフッターは「学習室を閉じると消える」と書いてあり、
        // 気づきの持ち方（アプリを閉じるまで残る）と食い違うので、ここでは使わない。
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 18, 4, 8),
          child: Text(
            '気づきは助産師が自分で書いた覚え書きです。学習室を閉じても残り、'
            'アプリを閉じると消えます。教材への反映や共有は、この試作では行いません。',
            style: kLearnSmall,
          ),
        ),
      ],
    );
  }

  static String _time(DateTime t) =>
      '${t.month}/${t.day} ${t.hour}:${t.minute.toString().padLeft(2, '0')}';
}
