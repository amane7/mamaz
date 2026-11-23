import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../learning_models.dart';
import '../learning_state.dart';
import 'learning_widgets.dart';

/// 文献台帳：出典名・用語・ID（B04、K01 など）で絞り込む。
class SourcesPane extends StatefulWidget {
  const SourcesPane({super.key});

  @override
  State<SourcesPane> createState() => _SourcesPaneState();
}

class _SourcesPaneState extends State<SourcesPane> {
  late final TextEditingController _input = TextEditingController(
    text: context.read<LearningState>().sourceQuery,
  );

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<LearningState>();
    final found = st.index.filterSources(st.sourceQuery);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      itemCount: found.length + 2,
      itemBuilder: (context, i) {
        if (i == 0) return _header(st, found.length);
        if (i == found.length + 1) return const LearningFooter();
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _SourceTile(found[i - 1]),
        );
      },
    );
  }

  Widget _header(LearningState st, int count) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LearnHeading('文献台帳'),
        const SizedBox(height: 6),
        const Text(
          '添付の出典B01–B37、科研費K01・K02、補足資料A、既存設計Mを区別しています。'
          '判読できた範囲と学習への用途を表示します。',
          style: kLearnBody,
        ),
        const SizedBox(height: 12),
        Semantics(
          label: '文献を絞り込む',
          child: TextField(
            controller: _input,
            maxLength: 80,
            onChanged: st.filterSources,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 14, color: AppColors.textDark),
            decoration: InputDecoration(
              isDense: true,
              counterText: '',
              hintText: '例　分母、身体知、B04',
              hintStyle: const TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 20,
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
                borderSide: const BorderSide(color: kLearnTeal, width: 1.6),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Semantics(liveRegion: true, child: Text('$count件', style: kLearnSmall)),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _SourceTile extends StatelessWidget {
  final LearningSource source;
  const _SourceTile(this.source);

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: EdgeInsets.zero,
      radius: AppRadius.md,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey('learn-source-${source.id}'),
          title: Text(
            '${source.id}　${source.title}',
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          iconColor: kLearnTeal,
          collapsedIconColor: kLearnTeal,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          expandedAlignment: Alignment.topLeft,
          children: [
            Text(source.kind, style: kLearnSmall),
            const SizedBox(height: 6),
            Text(source.finding, style: kLearnBody),
            const SizedBox(height: 6),
            Text('この資料から使えること　${source.use}', style: kLearnBody),
            const SizedBox(height: 4),
            SourceLinks([source.id]),
          ],
        ),
      ),
    );
  }
}
