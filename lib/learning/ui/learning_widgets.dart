import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_theme.dart';
import '../../widgets/motion.dart';
import '../learning_models.dart';
import '../learning_state.dart';

/// 学習室の差し色。業務画面（ピンク／ラベンダー）と見分けがつくよう、配布キットの色を使う。
const Color kLearnTeal = Color(0xFF186958);
const Color kLearnPale = Color(0xFFE5F1EB);
const Color kLearnWarn = Color(0xFFAA503E);

const String kLearningFooter =
    '架空事例を使う専門職向けの演習です。実際の母子の相談は施設の担当者へ。'
    '入力はこの画面のメモリだけに保持し、学習室を閉じると消えます。'
    '出典リンクは選んだときに外部サイトを開きます。';

const TextStyle kLearnBody = TextStyle(
  fontSize: 13.5,
  height: 1.7,
  color: AppColors.textBody,
);

const TextStyle kLearnSmall = TextStyle(
  fontSize: 11.5,
  height: 1.6,
  color: AppColors.textMuted,
);

/// 段階や件数を示す小さな札。
class LearnFlag extends StatelessWidget {
  final String text;
  const LearnFlag(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: kLearnPale,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: kLearnTeal,
        ),
      ),
    );
  }
}

class LearnHeading extends StatelessWidget {
  final String text;
  final double size;
  const LearnHeading(this.text, {super.key, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text,
        style: TextStyle(
          fontSize: size,
          height: 1.45,
          fontWeight: FontWeight.w800,
          color: AppColors.textDark,
        ),
      ),
    );
  }
}

/// 場面・問いなど、いま向き合う文章。
class LearnSpot extends StatelessWidget {
  final String text;
  const LearnSpot(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      decoration: const BoxDecoration(
        color: kLearnPale,
        border: Border(left: BorderSide(color: kLearnTeal, width: 3)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          height: 1.7,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
      ),
    );
  }
}

/// 注意（人につなぐ・保留）。
class LearnWarn extends StatelessWidget {
  final String text;
  const LearnWarn(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kLearnWarn.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: kLearnWarn.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.priority_high_rounded,
              size: 17,
              color: kLearnWarn,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.65,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 自分が書いた文章や補足。
class LearnNote extends StatelessWidget {
  final String text;
  const LearnNote(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardCream,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(text, style: kLearnBody),
    );
  }
}

/// 入力欄。内容はメモリにだけ置く。
class LearnField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool enabled;

  const LearnField({
    super.key,
    required this.label,
    required this.controller,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          onChanged: onChanged,
          enabled: enabled,
          minLines: 3,
          maxLines: 8,
          maxLength: 1000,
          keyboardType: TextInputType.multiline,
          style: const TextStyle(
            fontSize: 14,
            height: 1.6,
            color: AppColors.textDark,
          ),
          decoration: InputDecoration(
            isDense: true,
            counterText: '',
            filled: true,
            fillColor: enabled ? Colors.white : AppColors.cream,
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: const BorderSide(color: AppColors.line),
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
      ],
    );
  }
}

class LearnPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const LearnPrimaryButton({super.key, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: kLearnTeal,
          foregroundColor: Colors.white,
          disabledBackgroundColor: kLearnTeal.withValues(alpha: 0.35),
          disabledForegroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        child: Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}

class LearnSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const LearnSecondaryButton({super.key, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: kLearnTeal,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: Color(0xFFCBD8CF)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          textStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}

/// 小さなボタン（例・関連教材）。
class LearnChipButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const LearnChipButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFFCBD8CF)),
      labelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: kLearnTeal,
      ),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.compact,
    );
  }
}

/// 出典へのリンク。選んだときだけ外部サイトを開く。
class SourceLinks extends StatelessWidget {
  final List<String> ids;
  const SourceLinks(this.ids, {super.key});

  @override
  Widget build(BuildContext context) {
    final sources = context.read<LearningState>().kb.sources;
    return Wrap(
      spacing: 6,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('出典', style: kLearnSmall),
        for (final id in ids)
          if (sources[id] != null) _SourceLink(sources[id]!),
      ],
    );
  }
}

class _SourceLink extends StatelessWidget {
  final LearningSource source;
  const _SourceLink(this.source);

  Future<void> _open(BuildContext context) async {
    final uri = Uri.tryParse(source.url);
    var opened = false;
    if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        opened = false;
      }
    }
    if (!opened && context.mounted) {
      showWarmToast(
        context,
        '外部サイトを開けませんでした（${source.id}）',
        icon: Icons.link_off_rounded,
        color: kLearnWarn,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      label: '${source.id} ${source.title}（外部サイト）',
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
          child: Text(
            '${source.id} ${source.title}',
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
              color: kLearnTeal,
              decoration: TextDecoration.underline,
              decorationColor: kLearnTeal,
            ),
          ),
        ),
      ),
    );
  }
}

/// 基礎ノート。自分の説明を考えてから、説明例を開く。
class NoteContent extends StatefulWidget {
  final FoundationNote note;
  const NoteContent(this.note, {super.key});

  @override
  State<NoteContent> createState() => _NoteContentState();
}

class _NoteContentState extends State<NoteContent> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final n = widget.note;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(n.concept, style: kLearnBody),
        const SizedBox(height: 10),
        LearnSpot(n.selfQuestion),
        const SizedBox(height: 6),
        Semantics(
          expanded: _open,
          child: LearnChipButton(
            label: _open ? '説明例を閉じる' : '自分の説明と比べる',
            onTap: () => setState(() => _open = !_open),
          ),
        ),
        if (_open) ...[const SizedBox(height: 6), LearnNote(n.selfAnswer)],
        const SizedBox(height: 6),
        SourceLinks(n.refs),
      ],
    );
  }
}

/// 画面の最後に置く、学習室の前提。
class LearningFooter extends StatelessWidget {
  const LearningFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(kLearningFooter, style: kLearnSmall),
    );
  }
}
