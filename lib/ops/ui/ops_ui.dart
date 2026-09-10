// ============================================================================
// v2.1 共通UIコンポーネント
// UX原則: 一画面ひとテーマ / 片手操作 / 大きなタップ領域 / 途中離脱耐性
// アクセシビリティ: WCAG 2.2 AA を目標（コントラスト・タップ44px以上・明示ラベル）
// ============================================================================

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/motion.dart';
import '../ops_models.dart';

/// 最小タップ領域 44×44（WCAG 2.2 Target Size）
const double kMinTap = 48;

// ---------------------------------------------------------------------------
// 状態バッジ
// ---------------------------------------------------------------------------
class StateBadge extends StatelessWidget {
  final BookingState state;
  final bool showCode;
  const StateBadge(this.state, {super.key, this.showCode = false});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '予約状態 ${state.label}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: state.color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: state.color.withValues(alpha: 0.32)),
        ),
        child: Text(
          showCode ? '${state.label}・${state.code}' : state.label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: state.color,
          ),
        ),
      ),
    );
  }
}

/// 料金の三状態表示（見込／確認中／確定）— 誤認防止（§8.4）
class FeeChip extends StatelessWidget {
  final int yen;
  final FeeState state;
  final String? prefix;
  const FeeChip({
    super.key,
    required this.yen,
    required this.state,
    this.prefix,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${prefix ?? '料金'} ${state.label} $yen円',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: state.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: state.color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: state.color,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                state.label,
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              '¥${_comma(yen)}',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: state.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _comma(int v) {
  final s = v.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

String yen(int v) => '¥${_comma(v)}';

// ---------------------------------------------------------------------------
// 理由コードチップ（管理者・助産師向け）
// ---------------------------------------------------------------------------
class ReasonChip extends StatelessWidget {
  final ReasonCode code;
  final bool overdue;
  const ReasonChip(this.code, {super.key, this.overdue = false});

  @override
  Widget build(BuildContext context) {
    final c = code == ReasonCode.redFlag
        ? const Color(0xFFD2705E)
        : (overdue ? const Color(0xFFE0A83C) : AppColors.mauve);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (code == ReasonCode.redFlag)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(
                Icons.priority_high_rounded,
                size: 12,
                color: Color(0xFFD2705E),
              ),
            ),
          Text(
            '${code.code} ${code.label}',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ステップ進捗（家族向けウィザード / 途中離脱耐性を可視化）
// ---------------------------------------------------------------------------
class StepProgress extends StatelessWidget {
  final int current; // 1-based
  final int total;
  final String label;
  const StepProgress({
    super.key,
    required this.current,
    required this.total,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$total ステップ中 $current ステップ目、$label',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'STEP $current / $total',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: AppColors.blushPinkDeep,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textBody,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SmoothValue(
            value: current / total,
            duration: const Duration(milliseconds: 520),
            builder: (v) => ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: v,
                minHeight: 6,
                backgroundColor: AppColors.line,
                valueColor: const AlwaysStoppedAnimation(
                  AppColors.blushPinkDeep,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 選択肢タイル（大きなタップ領域・単一/複数選択）
// ---------------------------------------------------------------------------
class ChoiceTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final Color color;
  final Widget? trailing;
  final bool multi;

  const ChoiceTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    required this.selected,
    required this.onTap,
    this.color = AppColors.blushPinkDeep,
    this.trailing,
    this.multi = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$title${subtitle == null ? '' : '、$subtitle'}',
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minHeight: kMinTap + 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.10) : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? color : AppColors.line,
              width: selected ? 1.8 : 1,
            ),
            boxShadow: selected ? null : AppShadows.card,
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: selected ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? AppColors.textDark
                            : AppColors.textBody,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textMuted,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else
                AnimatedScale(
                  duration: const Duration(milliseconds: 220),
                  scale: selected ? 1 : 0.75,
                  child: Icon(
                    multi
                        ? (selected
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded)
                        : (selected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded),
                    size: 22,
                    color: selected ? color : AppColors.textMuted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 主ボタン（親指の届く位置に固定するフッター用）
// ---------------------------------------------------------------------------
class PrimaryBar extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final String? note;
  final IconData? icon;
  final Color color;

  const PrimaryBar({
    super.key,
    required this.label,
    this.onTap,
    this.secondaryLabel,
    this.onSecondary,
    this.note,
    this.icon,
    this.color = AppColors.blushPinkDeep,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppColors.line)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE9B9C6).withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (note != null) ...[
              Text(
                note!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 9),
            ],
            Row(
              children: [
                if (secondaryLabel != null) ...[
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: onSecondary,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textBody,
                          side: const BorderSide(color: AppColors.line),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                        child: Text(
                          secondaryLabel!,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: enabled ? color : AppColors.line,
                        foregroundColor: enabled
                            ? Colors.white
                            : AppColors.textMuted,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (icon != null) ...[
                            const SizedBox(width: 7),
                            Icon(icon, size: 18),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 情報バナー（安全境界・注意の明示）
// ---------------------------------------------------------------------------
class InfoNote extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  final String? title;
  const InfoNote({
    super.key,
    required this.text,
    this.icon = Icons.info_outline_rounded,
    this.color = AppColors.lavender,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 11.8,
                    color: AppColors.textBody,
                    height: 1.65,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 業務画面用のコンパクトな指標カード
// ---------------------------------------------------------------------------
class MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;
  final bool alert;

  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.sub,
    this.color = AppColors.blushPinkDeep,
    this.icon = Icons.insights_rounded,
    this.onTap,
    this.alert = false,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: alert ? const Color(0xFFD2705E) : AppColors.line,
            width: alert ? 1.6 : 1,
          ),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 15, color: color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
                color: alert ? const Color(0xFFD2705E) : AppColors.textDark,
                height: 1.1,
              ),
            ),
            if (sub != null) ...[
              const SizedBox(height: 4),
              Text(
                sub!,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// KPI 達成バー
// ---------------------------------------------------------------------------
class KpiBar extends StatelessWidget {
  final String label;
  final String valueText;
  final double progress; // 0..1（達成度）
  final String target;
  final bool achieved;
  const KpiBar({
    super.key,
    required this.label,
    required this.valueText,
    required this.progress,
    required this.target,
    required this.achieved,
  });

  @override
  Widget build(BuildContext context) {
    final c = achieved ? const Color(0xFF6FB57E) : const Color(0xFFE0A83C);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                achieved
                    ? Icons.check_circle_rounded
                    : Icons.trending_up_rounded,
                size: 15,
                color: c,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              Text(
                valueText,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: c,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SmoothValue(
            value: progress.clamp(0.0, 1.0),
            builder: (v) => ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: v,
                minHeight: 5,
                backgroundColor: AppColors.line,
                valueColor: AlwaysStoppedAnimation(c),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '目標：$target',
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// セクション見出し（業務画面用・コンパクト）
// ---------------------------------------------------------------------------
class OpsSection extends StatelessWidget {
  final String title;
  final String? note;
  final String? spec; // 要件ID（トレーサビリティ）
  final Widget? action;
  const OpsSection({
    super.key,
    required this.title,
    this.note,
    this.spec,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    if (spec != null) ...[
                      const SizedBox(width: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.cardLavender,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          spec!,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppColors.lavender,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (note != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    note!,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textMuted,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 日時フォーマット
// ---------------------------------------------------------------------------
const _wd = ['月', '火', '水', '木', '金', '土', '日'];

String fmtDateTime(DateTime d) =>
    '${d.month}月${d.day}日(${_wd[d.weekday - 1]}) ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String fmtDate(DateTime d) => '${d.month}月${d.day}日(${_wd[d.weekday - 1]})';

String fmtTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String weekdayLabel(int weekday) => _wd[weekday - 1];

/// エリアコードを人が読む言葉にする（§25 ふだんの言葉で書く）。
///
/// 画面に 'area_midori' のような内部コードを出してしまわないための共通変換。
/// 未知のコードはそのまま返し、消えてしまわないようにする。
String areaLabel(String code) => switch (code) {
  'area_sakura' => '名古屋市',
  'area_midori' => '長久手市',
  'area_hinata' => '瀬戸市',
  _ => code,
};

String fmtRange(DateTime d, int minutes) {
  final e = d.add(Duration(minutes: minutes));
  return '${fmtTime(d)}〜${fmtTime(e)}';
}

String relativeDay(DateTime d) {
  final diff = dayOf(d).difference(dayOf(DateTime.now())).inDays;
  if (diff == 0) return '今日';
  if (diff == 1) return 'あした';
  if (diff == 2) return 'あさって';
  if (diff < 0) return '${-diff}日前';
  return '$diff日後';
}
