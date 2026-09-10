import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/motion.dart';
import 'ops_ui.dart';

/// ---------------------------------------------------------------------------
/// §24 マスタ編集のための共通部品
///
/// 管理者は毎日この画面を触るわけではありません。ひさしぶりに開いて
/// 「どこを押せば直せるか」がすぐ分かることを優先しています。
///
///  ・数値はキーボードを出さず ＋／− で変える（誤入力を作らない）
///  ・変更したものは色で分かる（保存前に気づける）
///  ・保存するまで反映されない（§25 入力を失わない・取り消せる）
/// ---------------------------------------------------------------------------

/// ＋／− で数を変える行。単位と刻みを指定できる。
class NumberStepperRow extends StatelessWidget {
  final String label;
  final String? hint;
  final int value;
  final int min;
  final int max;
  final int step;
  final String unit;
  final bool changed;
  final ValueChanged<int> onChanged;

  const NumberStepperRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    this.min = 0,
    this.max = 999999,
    this.step = 1,
    this.unit = '',
    this.changed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: changed
                        ? AppColors.blushPinkDeep
                        : AppColors.textDark,
                  ),
                ),
                if (hint != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    hint!,
                    style: const TextStyle(
                      fontSize: 10.5,
                      height: 1.3,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          _round(
            icon: Icons.remove_rounded,
            enabled: value > min,
            onTap: () => onChanged((value - step).clamp(min, max)),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 74),
            alignment: Alignment.center,
            child: Text(
              '$value$unit',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: changed ? AppColors.blushPinkDeep : AppColors.textDark,
              ),
            ),
          ),
          _round(
            icon: Icons.add_rounded,
            enabled: value < max,
            onTap: () => onChanged((value + step).clamp(min, max)),
          ),
        ],
      ),
    );
  }

  Widget _round({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.32,
      child: Pressable(
        radius: BorderRadius.circular(13),
        onTap: enabled ? onTap : null,
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.cardPink,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, size: 19, color: AppColors.blushPinkDeep),
        ),
      ),
    );
  }
}

/// はい／いいえの切り替え行。
class ToggleRow extends StatelessWidget {
  final String label;
  final String? hint;
  final bool value;
  final bool changed;
  final ValueChanged<bool> onChanged;

  const ToggleRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    this.changed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: changed
                        ? AppColors.blushPinkDeep
                        : AppColors.textDark,
                  ),
                ),
                if (hint != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    hint!,
                    style: const TextStyle(
                      fontSize: 10.5,
                      height: 1.3,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.blushPinkDeep,
            activeTrackColor: AppColors.cardPink,
          ),
        ],
      ),
    );
  }
}

/// 編集シートの共通の器。
///
/// 「改定すると版が上がる」ことを必ず画面に書きます（§20 の説明責任）。
Future<T?> showMasterEditSheet<T>({
  required BuildContext context,
  required String title,
  required String subtitle,
  required Widget Function(BuildContext, void Function(void Function())) body,
  required String Function() saveLabel,
  required bool Function() canSave,
  required VoidCallback onSave,
  String? versionNote,
  String noteTitle = '保存すると新しい版になります',

  /// その場で保存される編集（スキルの付与など）では、
  /// 「やめる」を出すと取り消せるように見えてしまうので閉じるだけにする。
  bool singleAction = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => StatefulBuilder(
      builder: (ctx, setSheetState) => DraggableScrollableSheet(
        initialChildSize: 0.78,
        maxChildSize: 0.95,
        minChildSize: 0.45,
        expand: false,
        builder: (_, scroll) => Container(
          decoration: const BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl),
            ),
          ),
          child: Column(
            children: [
              // つまみ
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.4,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.line),
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                  children: [
                    body(ctx, setSheetState),
                    if (versionNote != null) ...[
                      const SizedBox(height: 16),
                      InfoNote(
                        title: noteTitle,
                        text: versionNote,
                        icon: Icons.history_edu_outlined,
                        color: AppColors.lavender,
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      if (!singleAction) ...[
                        Expanded(
                          child: Pressable(
                            radius: BorderRadius.circular(AppRadius.lg),
                            onTap: () => Navigator.pop(sheetCtx),
                            child: Container(
                              height: kMinTap,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.lg,
                                ),
                                border: Border.all(color: AppColors.line),
                              ),
                              child: const Text(
                                'やめる',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textBody,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        flex: 2,
                        child: Opacity(
                          opacity: (singleAction || canSave()) ? 1 : 0.4,
                          child: Pressable(
                            radius: BorderRadius.circular(AppRadius.lg),
                            onTap: singleAction
                                ? () => Navigator.pop(sheetCtx)
                                : canSave()
                                ? () {
                                    onSave();
                                    Navigator.pop(sheetCtx);
                                  }
                                : null,
                            child: Container(
                              height: kMinTap,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.blushPinkDeep,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.lg,
                                ),
                                boxShadow: AppShadows.soft,
                              ),
                              child: Text(
                                saveLabel(),
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
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
        ),
      ),
    ),
  );
}

/// 「編集できます」と分かる見出し行（鉛筆アイコン付き）。
class EditableCardHeader extends StatelessWidget {
  final String title;
  final String? badge;
  const EditableCardHeader({super.key, required this.title, this.badge});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
      ),
      if (badge != null) ...[TagChipCompat(badge!), const SizedBox(width: 8)],
      Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.cardPink,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.edit_outlined,
          size: 15,
          color: AppColors.blushPinkDeep,
        ),
      ),
    ],
  );
}

/// 版ラベル用の小さなチップ（TagChip の引数順を隠す薄いラッパ）。
class TagChipCompat extends StatelessWidget {
  final String text;
  const TagChipCompat(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.cardLavender,
      borderRadius: BorderRadius.circular(9),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.lavender,
      ),
    ),
  );
}
