import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../learning_models.dart';
import '../learning_state.dart';
import 'learning_widgets.dart';

/// ケース演習：最初の問い → 参考例と比較 → 別の事例 → 振り返り。
class ExercisePane extends StatefulWidget {
  const ExercisePane({super.key});

  @override
  State<ExercisePane> createState() => _ExercisePaneState();
}

class _ExercisePaneState extends State<ExercisePane> {
  final _scroll = ScrollController();
  String? _shown;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<LearningState>();
    final c = st.currentCase;
    final s = st.session;
    final panelKey = '${c.id}/${s.step}/${identityHashCode(s)}';

    // 段階やケースが変わったら、先頭から読めるようにする。
    if (_shown != null && _shown != panelKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(0);
      });
    }
    _shown = panelKey;

    return SingleChildScrollView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CasePicker(current: c, locked: st.locked),
          const SizedBox(height: 12),
          SoftCard(
            child: _StepPanel(key: ValueKey(panelKey), kase: c, session: s),
          ),
          const LearningFooter(),
        ],
      ),
    );
  }
}

class _CasePicker extends StatelessWidget {
  final LearningCase current;
  final bool locked;
  const _CasePicker({required this.current, required this.locked});

  void _open(BuildContext context) {
    final st = context.read<LearningState>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheet).size.height * 0.8,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              const LearnHeading('ケースを選ぶ', size: 16),
              const SizedBox(height: 4),
              const Text('すべて架空の事例です。', style: kLearnSmall),
              const SizedBox(height: 8),
              for (final k in st.kb.cases.values)
                _CaseRow(
                  kase: k,
                  selected: k.id == st.caseId,
                  onTap: () {
                    st.openCase(k.id);
                    Navigator.of(sheet).pop();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !locked,
      label: 'ケースを選ぶ。いまは「${current.title}」',
      child: SoftCard(
        padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
        onTap: locked ? null : () => _open(context),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(current.phase, style: kLearnSmall),
                  const SizedBox(height: 2),
                  Text(
                    current.title,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (locked)
              const Icon(
                Icons.lock_outline_rounded,
                size: 18,
                color: AppColors.textMuted,
              )
            else
              const Text(
                'ケースを選ぶ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: kLearnTeal,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CaseRow extends StatelessWidget {
  final LearningCase kase;
  final bool selected;
  final VoidCallback onTap;
  const _CaseRow({
    required this.kase,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
            decoration: BoxDecoration(
              color: selected ? kLearnPale : Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: selected ? kLearnTeal : const Color(0xFFCBD8CF),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(kase.phase, style: kLearnSmall),
                const SizedBox(height: 2),
                Text(
                  kase.title,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepPanel extends StatefulWidget {
  final LearningCase kase;
  final ExerciseSession session;
  const _StepPanel({super.key, required this.kase, required this.session});

  @override
  State<_StepPanel> createState() => _StepPanelState();
}

class _StepPanelState extends State<_StepPanel> {
  late final _first = TextEditingController(text: widget.session.first);
  late final _why = TextEditingController(text: widget.session.why);
  late final _rewrite = TextEditingController(text: widget.session.rewrite);
  late final _transfer = TextEditingController(text: widget.session.transfer);
  String? _message;

  @override
  void dispose() {
    _first.dispose();
    _why.dispose();
    _rewrite.dispose();
    _transfer.dispose();
    super.dispose();
  }

  LearningState get _st => context.read<LearningState>();

  void _edited(void Function() write) {
    write();
    _st.noteEdited();
  }

  Future<void> _submitFirst() async {
    FocusScope.of(context).unfocus();
    final message = await _st.submitFirst();
    if (mounted) setState(() => _message = message);
  }

  void _submit(String? Function() action) {
    FocusScope.of(context).unfocus();
    final message = action();
    if (mounted) setState(() => _message = message);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.kase;
    final s = widget.session;
    final step = s.step;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LearnFlag('${step + 1} / 4　${ExerciseStep.names[step]}'),
        const SizedBox(height: 10),
        LearnHeading(step == ExerciseStep.transfer ? '別の事例で考える' : c.title),
        const SizedBox(height: 12),
        if (step <= ExerciseStep.compare) ...[
          LearnSpot(c.scene),
          const SizedBox(height: 12),
          if (c.isEmergency) ...[
            const LearnWarn(
              '急な変化が現実に起きた際は、ただちに施設の緊急手順で人へ連絡します。'
              'ここでは架空演習の連携を振り返ります。',
            ),
            const SizedBox(height: 12),
          ],
        ],
        ...switch (step) {
          ExerciseStep.firstAnswer => _firstAnswer(c, s),
          ExerciseStep.compare => _compare(s),
          ExerciseStep.transfer => _transferStep(c, s),
          _ => _review(c, s),
        },
      ],
    );
  }

  Widget _status() {
    final text = widget.session.matching ? '教材を照合しています。' : _message;
    return Semantics(
      liveRegion: true,
      child: text == null
          ? const SizedBox(height: 12)
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: kLearnWarn,
                ),
              ),
            ),
    );
  }

  List<Widget> _firstAnswer(LearningCase c, ExerciseSession s) {
    final busy = s.matching;
    return [
      LearnField(
        label: '本人や指導者に、最初に何を確かめますか。',
        controller: _first,
        enabled: !busy,
        onChanged: (v) => _edited(() => s.first = v),
      ),
      const SizedBox(height: 14),
      LearnField(
        label: 'その問いを選んだ理由',
        controller: _why,
        enabled: !busy,
        onChanged: (v) => _edited(() => s.why = v),
      ),
      const SizedBox(height: 14),
      const Text(
        '比較したい観点',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
      ),
      const SizedBox(height: 4),
      Wrap(
        spacing: 8,
        children: [
          for (var i = 0; i < c.focus.length; i++)
            ChoiceChip(
              label: Text(c.focus[i]),
              selected: s.focusIndex == i,
              onSelected: busy ? null : (_) => _st.setFocus(i),
              selectedColor: kLearnPale,
              backgroundColor: Colors.white,
              checkmarkColor: kLearnTeal,
              side: BorderSide(
                color: s.focusIndex == i ? kLearnTeal : const Color(0xFFCBD8CF),
              ),
              labelStyle: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: s.focusIndex == i ? kLearnTeal : AppColors.textBody,
              ),
            ),
        ],
      ),
      _status(),
      LearnPrimaryButton(
        label: '自分の問いを残して、参考例を見る',
        onTap: busy ? null : _submitFirst,
      ),
    ];
  }

  List<Widget> _compare(ExerciseSession s) {
    final cards = _st.kb.cards;
    return [
      LearnNote('最初の問い　${s.first}\n理由　${s.why}'),
      const SizedBox(height: 8),
      Text(s.method, style: kLearnSmall),
      const SizedBox(height: 12),
      if (s.rank.isEmpty) ...[
        const LearnWarn('適用できる候補を確かめられませんでした。保留のまま、自分の言葉で次へ進めます。'),
        const SizedBox(height: 12),
      ],
      for (final id in s.rank) ...[
        _ReferenceTile(card: cards[id]!, choice: s.choiceFor(id)),
        const SizedBox(height: 12),
      ],
      LearnField(
        label: '比べたあと、次にかける一言とその理由',
        controller: _rewrite,
        onChanged: (v) => _edited(() => s.rewrite = v),
      ),
      _status(),
      LearnPrimaryButton(
        label: '参考例を閉じて、別の事例へ',
        onTap: () => _submit(_st.submitRewrite),
      ),
    ];
  }

  List<Widget> _transferStep(LearningCase c, ExerciseSession s) {
    return [
      LearnSpot(c.transfer),
      const SizedBox(height: 8),
      const Text('この課題は自分の力で考えます。回答を確定するか、中断すると他の教材を開けます。', style: kLearnSmall),
      const SizedBox(height: 14),
      LearnField(
        label: 'この事例での問いと理由',
        controller: _transfer,
        onChanged: (v) => _edited(() => s.transfer = v),
      ),
      _status(),
      LearnPrimaryButton(
        label: '回答を確定して振り返る',
        onTap: () => _submit(_st.submitTransfer),
      ),
      const SizedBox(height: 8),
      LearnSecondaryButton(label: '中断して比較に戻る', onTap: _st.suspendTransfer),
    ];
  }

  List<Widget> _review(LearningCase c, ExerciseSession s) {
    Widget pair(String label, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LearnHeading(label, size: 13.5),
          const SizedBox(height: 4),
          Text(text, style: kLearnBody),
        ],
      ),
    );

    return [
      if (s.revisited) ...[
        const LearnNote('別課題を一度中断しています。初見時の独力評価には使わず、再練習として振り返ります。'),
        const SizedBox(height: 12),
      ],
      pair('最初の問い', s.first),
      pair('その理由', s.why),
      pair('比べたあとの一言', s.rewrite),
      pair('別の事例での回答', s.transfer),
      const LearnHeading('指導者と振り返る観点', size: 13.5),
      const SizedBox(height: 6),
      LearnSpot(c.rubric),
      const SizedBox(height: 8),
      Text('候補の扱い　${_st.handlingSummary()}', style: kLearnSmall),
      const SizedBox(height: 16),
      LearnSecondaryButton(label: 'このケースを最初から', onTap: _st.restartCase),
    ];
  }
}

/// 参考例（問い・理由・確認したい条件・原資料）と、その扱い。
class _ReferenceTile extends StatelessWidget {
  final LearningCard card;
  final CardChoice choice;
  const _ReferenceTile({required this.card, required this.choice});

  @override
  Widget build(BuildContext context) {
    final st = context.read<LearningState>();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: const Color(0xFFCBD8CF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LearnHeading(card.question, size: 14.5),
          const SizedBox(height: 6),
          Text(card.why, style: kLearnBody),
          const SizedBox(height: 6),
          Text('確認したい条件　${card.stop}', style: kLearnSmall),
          const SizedBox(height: 4),
          SourceLinks(card.refs),
          const SizedBox(height: 8),
          const Text(
            'この事例では',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final option in CardChoice.values)
                ChoiceChip(
                  label: Text(option.optionLabel),
                  selected: choice == option,
                  onSelected: (_) => st.choose(card.id, option),
                  selectedColor: kLearnPale,
                  backgroundColor: Colors.white,
                  checkmarkColor: kLearnTeal,
                  side: BorderSide(
                    color: choice == option
                        ? kLearnTeal
                        : const Color(0xFFCBD8CF),
                  ),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: choice == option ? kLearnTeal : AppColors.textBody,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
