import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../learning/learning_models.dart';
import '../../learning/learning_state.dart';
import '../../learning/ui/learning_widgets.dart';
import '../../ops/ops_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_nav.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../chart_assist.dart';
import '../chart_assist_state.dart';
import '../conversation.dart';
import '../insight_store.dart';

/// 会話からカルテの下書き（試作）。
///
/// 文字になった会話から、発言をそのまま欄に分けた下書きを作り、
/// 会話に無かったこと・あいまいなことを「確かめたい点」として助産師に挙げる。
/// 音声の録音・文字起こしは未接続。カルテや予約の記録には書き込まない。
class ChartAssistScreen extends StatelessWidget {
  /// テスト用：教材を直接渡す。
  final LearningKb? kb;
  const ChartAssistScreen({super.key, this.kb});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 問い・理由・出典は学習室の教材から引く。
        ChangeNotifierProvider<LearningState>(
          create: (_) {
            final s = LearningState(kb: kb);
            if (!s.ready) s.load();
            return s;
          },
        ),
        ChangeNotifierProvider<ChartAssistState>(
          create: (_) => ChartAssistState(),
        ),
      ],
      child: const _ChartAssistView(),
    );
  }
}

const String _prototypeNotice =
    '試作です。音声の録音と文字起こしは、まだつないでいません。'
    '言語モデルも使っていません。決まった語句の照合で、候補を挙げます。'
    '会話は架空の例か、ここで書いた文章で試します。'
    '下書きは画面のメモリだけに置き、カルテや予約の記録には書き込みません。';

class _ChartAssistView extends StatelessWidget {
  const _ChartAssistView();

  @override
  Widget build(BuildContext context) {
    final role = context.watch<OpsState>().role;
    final kbState = context.watch<LearningState>();
    final assist = context.watch<ChartAssistState>();

    if (role == OpsRole.family) {
      return const Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppTopBar(title: '会話からカルテの下書き'),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: WarmEmptyState(
              icon: Icons.edit_note_rounded,
              title: '専門職向けの画面です',
              message: '記録づくりの試作は、助産師・運営スタッフ向けの画面です。',
              color: AppColors.sageDeep,
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: !assist.isOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) assist.close();
      },
      child: Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppTopBar(
          title: '会話からカルテの下書き',
          subtitle: '試作 · 音声は未接続 · 端末内で動作',
          confirmLeave: assist.isOpen ? '下書きは保存されません。閉じると消えます。' : null,
        ),
        body: SafeArea(
          top: false,
          child: !kbState.ready
              ? Center(
                  child: kbState.loadError == null
                      ? const CircularProgressIndicator(color: kLearnTeal)
                      : Padding(
                          padding: const EdgeInsets.all(24),
                          child: LearnWarn(
                            '問いの教材を読み込めませんでした（${kbState.loadError}）。',
                          ),
                        ),
                )
              : assist.isOpen
              ? const _WorkPane()
              : const _StartPane(),
        ),
      ),
    );
  }
}

// =============================================================================
// はじめ：会話を選ぶ・書く
// =============================================================================
class _StartPane extends StatefulWidget {
  const _StartPane();

  @override
  State<_StartPane> createState() => _StartPaneState();
}

class _StartPaneState extends State<_StartPane> {
  final _input = TextEditingController();
  String? _message;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _openTyped() {
    FocusScope.of(context).unfocus();
    final message = context.read<ChartAssistState>().open(
      parseConversation(_input.text),
    );
    if (mounted) setState(() => _message = message);
  }

  @override
  Widget build(BuildContext context) {
    final assist = context.read<ChartAssistState>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      children: [
        const LearnHeading('会話からカルテの下書き'),
        const SizedBox(height: 6),
        const Text(
          '会話の発言をそのまま欄に分けて下書きを作り、会話の中に見つからなかったこと・あいまいなことを'
          '「確かめたい点」として挙げます。確かめて、答えを書くのは助産師です。',
          style: kLearnBody,
        ),
        const SizedBox(height: 10),
        const LearnWarn(_prototypeNotice),
        const SizedBox(height: 18),
        const LearnHeading('架空の会話例', size: 15),
        const SizedBox(height: 8),
        for (final c in kSampleConversations) ...[
          Semantics(
            button: true,
            child: SoftCard(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              onTap: () => assist.open(c),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.setting, style: kLearnSmall),
                        const SizedBox(height: 2),
                        Text(
                          c.title,
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
                  const Icon(Icons.chevron_right_rounded, color: kLearnTeal),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 12),
        const LearnHeading('会話を書いて試す', size: 15),
        const SizedBox(height: 4),
        const Text(
          '「母：」「家族：」「助産師：」で行を始めます。'
          '実在の方のお名前や相談内容は入れないでください。',
          style: kLearnSmall,
        ),
        const SizedBox(height: 8),
        Semantics(
          label: '会話の文章',
          child: TextField(
            controller: _input,
            minLines: 5,
            maxLines: 12,
            maxLength: 4000,
            keyboardType: TextInputType.multiline,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: AppColors.textDark,
            ),
            decoration: InputDecoration(
              isDense: true,
              counterText: '',
              hintText: '母：今日は少し眠りたいです。\n家族：授乳の練習をしてほしいんです。',
              hintStyle: const TextStyle(
                fontSize: 13,
                height: 1.6,
                color: AppColors.textMuted,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(12),
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
        _Status(_message),
        LearnPrimaryButton(label: '下書きを作る', onTap: _openTyped),
      ],
    );
  }
}

class _Status extends StatelessWidget {
  final String? text;
  const _Status(this.text);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: text == null
          ? const SizedBox(height: 12)
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                text!,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  fontWeight: FontWeight.w700,
                  color: kLearnWarn,
                ),
              ),
            ),
    );
  }
}

// =============================================================================
// 作業：会話・確かめたい点・下書き
// =============================================================================
class _WorkPane extends StatelessWidget {
  const _WorkPane();

  @override
  Widget build(BuildContext context) {
    final assist = context.watch<ChartAssistState>();
    final c = assist.conversation!;
    final stopped = assist.result!.stopped;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      children: [
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LearnFlag(c.sample ? '架空の会話例' : '書いて試した会話'),
              const SizedBox(height: 8),
              LearnHeading(c.title, size: 15.5),
              const SizedBox(height: 2),
              Text(c.setting, style: kLearnSmall),
              const SizedBox(height: 10),
              for (var i = 0; i < c.lines.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${i + 1}　${c.lines[i].speaker.label}　${c.lines[i].text}',
                    style: kLearnBody,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (stopped)
          const LearnWarn(
            'この会話には、差し迫った危険・薬の量・診断に関わる言葉が含まれています。'
            'この画面では問いも下書きも出しません。担当の医療者へ、'
            '差し迫った危険があるときは施設の緊急手順・救急要請につないでください。',
          )
        else ...[
          LearnHeading('確かめたい点　${assist.questions.length}件', size: 16),
          const SizedBox(height: 4),
          const Text(
            '挙げているのは問いの候補です。手掛かりの発言が会話に出てきた順に並べ、'
            '優先順位は付けていません。問いと理由は、学習室の教材（監修前の作例）から引いています。',
            style: kLearnSmall,
          ),
          const SizedBox(height: 10),
          if (assist.questions.isEmpty)
            const LearnNote(
              'この会話からは、確かめたい点の候補を挙げられませんでした。'
              '挙がらないことは、確認が要らないことを意味しません。',
            ),
          for (final q in assist.questions) ...[
            _QuestionCard(key: ValueKey(q.kind), question: q),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 2),
          const _MissingViewCard(),
          const SizedBox(height: 18),
          const LearnHeading('下書き', size: 16),
          const SizedBox(height: 4),
          const Text(
            '発言はそのまま載せています。要約や言い換えはしていません。'
            '欄は話題の目印です。空いた欄を推測で埋めることはしません。',
            style: kLearnSmall,
          ),
          const SizedBox(height: 10),
          const _DraftCard(),
        ],
        const SizedBox(height: 16),
        LearnSecondaryButton(label: 'ほかの会話で試す', onTap: assist.close),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 18, 4, 8),
          child: Text(_prototypeNotice, style: kLearnSmall),
        ),
      ],
    );
  }
}

/// 確かめたい点の1件。問いは常に見せ、理由・出典・扱いは開いて見る。
class _QuestionCard extends StatefulWidget {
  final ClarifyingQuestion question;
  const _QuestionCard({super.key, required this.question});

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  final _answer = TextEditingController();
  final _insight = TextEditingController();
  InsightStance _stance = InsightStance.depends;
  bool _open = false;
  bool _insightOpen = false;
  String? _message;
  String? _insightMessage;

  @override
  void dispose() {
    _answer.dispose();
    _insight.dispose();
    super.dispose();
  }

  void _resolve(Resolution r) {
    FocusScope.of(context).unfocus();
    final message = context.read<ChartAssistState>().resolve(
      widget.question.kind,
      r,
      answer: _answer.text,
    );
    setState(() => _message = message);
  }

  void _saveInsight() {
    FocusScope.of(context).unfocus();
    final message = context.read<InsightStore>().add(
      stance: _stance,
      kind: widget.question.kind,
      text: _insight.text,
    );
    setState(() {
      _insightMessage = message;
      if (message == null) {
        _insight.clear();
        _insightOpen = false;
      }
    });
    if (message == null) {
      showWarmToast(
        context,
        '気づきを残しました（学習室の「現場の気づき」）',
        icon: Icons.lightbulb_outline_rounded,
        color: kLearnTeal,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final assist = context.watch<ChartAssistState>();
    final card = context.read<LearningState>().kb.cards[q.cardId]!;
    final resolution = assist.resolutionOf(q.kind);
    final lines = q.lines.isEmpty
        ? '（手掛かりの発言はありません）'
        : q.lines.map((i) => '${i + 1}').join('、');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: const Color(0xFFCBD8CF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              LearnFlag(q.kind.label),
              const SizedBox(width: 8),
              Expanded(child: Text('教材 ${card.id} · 監修前', style: kLearnSmall)),
            ],
          ),
          const SizedBox(height: 8),
          Text(q.reason, style: kLearnBody),
          Text('手掛かりにした発言　$lines', style: kLearnSmall),
          const SizedBox(height: 10),
          LearnSpot(card.question),
          if (resolution != null) ...[
            const SizedBox(height: 8),
            LearnNote(
              resolution == Resolution.confirmed
                  ? '${resolution.label}\n${assist.answerOf(q.kind)}'
                  : resolution.label,
            ),
          ],
          const SizedBox(height: 4),
          Semantics(
            expanded: _open,
            child: LearnChipButton(
              label: _open ? 'とじる' : '理由・出典を見て、扱いを決める',
              onTap: () => setState(() => _open = !_open),
            ),
          ),
          if (_open) ...[
            const SizedBox(height: 6),
            Text(card.why, style: kLearnBody),
            const SizedBox(height: 4),
            Text('確認したい条件　${card.stop}', style: kLearnSmall),
            const SizedBox(height: 2),
            SourceLinks(card.refs),
            const SizedBox(height: 10),
            if (resolution == null) ...[
              LearnField(
                label: '確認できていること（ご本人から聞いた内容）',
                controller: _answer,
                onChanged: (_) {},
              ),
              _Status(_message),
              LearnPrimaryButton(
                label: '確認済みとして下書きに入れる',
                onTap: () => _resolve(Resolution.confirmed),
              ),
              const SizedBox(height: 8),
              LearnSecondaryButton(
                label: '次回、ご本人に確かめる',
                onTap: () => _resolve(Resolution.askNext),
              ),
              const SizedBox(height: 8),
              LearnSecondaryButton(
                label: '今回は確かめない',
                onTap: () => _resolve(Resolution.notNeeded),
              ),
            ] else
              LearnChipButton(
                label: '扱いを選び直す',
                onTap: () => assist.reopen(q.kind),
              ),
            const Divider(height: 22, color: AppColors.line),
            if (!_insightOpen)
              LearnChipButton(
                label: 'この問いについて、気づきを残す',
                onTap: () => setState(() => _insightOpen = true),
              )
            else ...[
              const Text(
                'あなたなら、この問いをどう扱いますか',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final s in const [
                    InsightStance.always,
                    InsightStance.depends,
                    InsightStance.notHere,
                  ])
                    ChoiceChip(
                      label: Text(s.label),
                      selected: _stance == s,
                      onSelected: (_) => setState(() => _stance = s),
                      selectedColor: kLearnPale,
                      backgroundColor: Colors.white,
                      checkmarkColor: kLearnTeal,
                      side: BorderSide(
                        color: _stance == s
                            ? kLearnTeal
                            : const Color(0xFFCBD8CF),
                      ),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _stance == s ? kLearnTeal : AppColors.textBody,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              LearnField(
                label: 'どんな時に確かめる／確かめないか、その理由',
                controller: _insight,
                onChanged: (_) {},
              ),
              const SizedBox(height: 4),
              const Text(
                '残るのはこの文章と問いの種類だけです。会話や下書きは残しません。'
                'お名前や個別の事情は書かないでください。',
                style: kLearnSmall,
              ),
              _Status(_insightMessage),
              LearnSecondaryButton(label: '気づきを残す', onTap: _saveInsight),
            ],
          ],
        ],
      ),
    );
  }
}

/// 候補に無かった観点を、助産師が自分の言葉で残す。
class _MissingViewCard extends StatefulWidget {
  const _MissingViewCard();

  @override
  State<_MissingViewCard> createState() => _MissingViewCardState();
}

class _MissingViewCardState extends State<_MissingViewCard> {
  final _text = TextEditingController();
  String? _message;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() {
    FocusScope.of(context).unfocus();
    final message = context.read<InsightStore>().add(
      stance: InsightStance.missing,
      text: _text.text,
    );
    setState(() {
      _message = message;
      if (message == null) _text.clear();
    });
    if (message == null) {
      showWarmToast(
        context,
        '気づきを残しました（学習室の「現場の気づき」）',
        icon: Icons.lightbulb_outline_rounded,
        color: kLearnTeal,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: AppColors.cardCream,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LearnHeading('候補に無かった観点', size: 14.5),
          const SizedBox(height: 4),
          const Text(
            'この会話で、あなたなら確かめるのに、上の候補に無かったことはありますか。'
            '語句の照合で見つけられるのは、あらかじめ決めた8種類だけです。',
            style: kLearnSmall,
          ),
          const SizedBox(height: 8),
          LearnField(
            label: '確かめたいことと、その理由',
            controller: _text,
            onChanged: (_) {},
          ),
          _Status(_message),
          LearnSecondaryButton(label: '気づきを残す', onTap: _save),
        ],
      ),
    );
  }
}

class _DraftCard extends StatelessWidget {
  const _DraftCard();

  @override
  Widget build(BuildContext context) {
    final assist = context.watch<ChartAssistState>();
    final cards = context.read<LearningState>().kb.cards;

    Widget block(String title, List<String> rows) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LearnHeading(title, size: 13.5),
          const SizedBox(height: 4),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(r, style: kLearnBody),
            ),
        ],
      ),
    );

    final notNeeded = [
      for (final q in assist.questions)
        if (assist.resolutionOf(q.kind) == Resolution.notNeeded) q,
    ];

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final s in ChartSection.values)
            if (assist.entriesIn(s).isNotEmpty)
              block(s.label, [
                for (final e in assist.entriesIn(s))
                  '「${e.text}」（${e.speaker.label}・発言${e.line + 1}）',
              ]),
          if (assist.confirmed.isNotEmpty)
            block('助産師が確かめたこと', [
              for (final q in assist.confirmed)
                '${q.kind.label}：${assist.answerOf(q.kind)}',
            ]),
          if (assist.nextChecks.isNotEmpty)
            block('次回、ご本人に確かめること', [
              for (final q in assist.nextChecks) cards[q.cardId]!.question,
            ]),
          if (assist.unresolved.isNotEmpty)
            block('未確認のまま', [
              for (final q in assist.unresolved) '${q.kind.label}：${q.reason}',
            ]),
          if (notNeeded.isNotEmpty)
            block('今回は確かめないとしたこと', [for (final q in notNeeded) q.kind.label]),
          const Text('この下書きは保存されません。カルテには書き込みません。', style: kLearnSmall),
        ],
      ),
    );
  }
}

/// 助産師の画面に置く入口。
class ChartAssistEntryCard extends StatelessWidget {
  const ChartAssistEntryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '会話からカルテの下書きをひらく',
      child: SoftCard(
        color: AppColors.cardCream,
        onTap: () =>
            Navigator.push(context, warmRoute(const ChartAssistScreen())),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: kLearnTeal,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.edit_note_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '会話からカルテの下書き',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    '会話の中に見つからなかったことを、問いの候補として挙げます。試作・音声は未接続・架空の会話で試します。',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.5,
                      color: AppColors.textBody,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: kLearnTeal),
          ],
        ),
      ),
    );
  }
}
