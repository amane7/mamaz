import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ops/ops_state.dart';
import '../theme/app_theme.dart';
import 'motion.dart';

/// ---------------------------------------------------------------------------
/// MAMOA Navigation System
///
/// 「いま、どこにいるか」と「どうやって帰るか」を、
/// アプリのどの画面でも同じ形・同じ場所で示すための共通部品。
///
/// 設計原則
///  1. 帰り道は必ず画面の右上・同じ位置にある（探さなくていい）
///  2. もどる（1つ前）と メニュー（全体画面）を分けて提示する
///  3. 全体画面に戻るときは、タブも先頭に戻して「まっさら」にする
/// ---------------------------------------------------------------------------

/// 「全体画面にもどる」ときに、各ルートシェルのタブを先頭へ戻すための合図。
class HomeSignal {
  HomeSignal._();
  static final ValueNotifier<int> tick = ValueNotifier<int>(0);
  static void fire() => tick.value++;
}

/// どの画面からでも、いまのロールの「メインメニュー（全体画面）」へ戻る。
void goHome(BuildContext context) {
  AppMotion.softTap();
  HomeSignal.fire();
  Navigator.of(context).popUntil((r) => r.isFirst);
}

// =============================================================================
// ロールの見た目（色・アイコン・呼び名）
// =============================================================================
class RoleSkin {
  final String label;
  final String short;
  final String caption;
  final IconData icon;
  final Color color;

  const RoleSkin({
    required this.label,
    required this.short,
    required this.caption,
    required this.icon,
    required this.color,
  });

  Color get tint => color.withValues(alpha: 0.12);
}

RoleSkin roleSkin(OpsRole r) => switch (r) {
  OpsRole.family => const RoleSkin(
    label: '利用者（ご家族）',
    short: 'ご家族',
    caption: 'ケアを受ける・予約する',
    icon: Icons.family_restroom_rounded,
    color: AppColors.blushPinkDeep,
  ),
  OpsRole.midwife => const RoleSkin(
    label: '助産師',
    short: '助産師',
    caption: '今日のケア・専門判断・OK／NG時間',
    icon: Icons.medical_services_outlined,
    color: AppColors.lavender,
  ),
  OpsRole.admin => const RoleSkin(
    label: '管理者',
    short: '管理者',
    caption: '例外キュー・カレンダー・マスタ・監査',
    icon: Icons.admin_panel_settings_outlined,
    color: AppColors.mauve,
  ),
};

// =============================================================================
// メニュー（全体画面）へ戻るボタン
// =============================================================================
class HomeButton extends StatelessWidget {
  /// 押したときに確認したい場合の文言（nullなら即もどる）
  final String? confirm;
  final String label;

  const HomeButton({super.key, this.confirm, this.label = 'メニュー'});

  Future<void> _tap(BuildContext context) async {
    if (confirm != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          title: const Text(
            'メニューにもどりますか？',
            style: TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          content: Text(
            confirm!,
            style: const TextStyle(
              fontSize: 13,
              height: 1.6,
              color: AppColors.textBody,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'このまま続ける',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.blushPinkDeep,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('メニューへ'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    if (context.mounted) goHome(context);
  }

  @override
  Widget build(BuildContext context) {
    // 積み上がった画面が無い＝すでに全体画面なので、出さない。
    if (!Navigator.of(context).canPop()) return const SizedBox.shrink();
    final skin = roleSkin(context.watch<OpsState>().role);
    return Semantics(
      button: true,
      label: 'メニュー（全体画面）にもどる',
      child: Tooltip(
        message: 'メニュー（全体画面）にもどる',
        child: Pressable(
          radius: BorderRadius.circular(22),
          onTap: () => _tap(context),
          child: Padding(
            // タップ領域を 48px 以上確保する（WCAG 2.2 AA）
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: skin.tint,
                borderRadius: BorderRadius.circular(19),
                border: Border.all(color: skin.color.withValues(alpha: 0.28)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.grid_view_rounded, size: 15, color: skin.color),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: skin.color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 1つ前にもどる丸ボタン（AppBar の leading）
class BackChip extends StatelessWidget {
  final VoidCallback? onTap;
  const BackChip({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '前の画面にもどる',
      child: Tooltip(
        message: '前の画面にもどる',
        child: Pressable(
          radius: BorderRadius.circular(24),
          onTap: onTap ?? () => Navigator.of(context).maybePop(),
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                size: 19,
                color: AppColors.textDark,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 共通トップバー
// 押せるときだけ「もどる」と「メニュー」を出す（タブ画面では出さない）
// =============================================================================
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final String? confirmLeave;
  final Color background;
  final bool showHome;

  const AppTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.onBack,
    this.confirmLeave,
    this.background = AppColors.surface,
    this.showHome = true,
  });

  @override
  Size get preferredSize => Size.fromHeight(subtitle == null ? 56 : 64);

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return AppBar(
      backgroundColor: background,
      surfaceTintColor: background,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      toolbarHeight: preferredSize.height,
      leadingWidth: canPop ? 52 : 0,
      titleSpacing: canPop ? 2 : 18,
      leading: canPop ? BackChip(onTap: onBack) : null,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.textMuted,
              ),
            ),
        ],
      ),
      actions: [
        ...actions,
        if (canPop && showHome) HomeButton(confirm: confirmLeave),
        const SizedBox(width: 8),
      ],
    );
  }
}

// =============================================================================
// ロールリボン（ルート画面の最上部）
// 「いま、どのロールで見ているか」を常に示し、その場で切り替えられる。
// 下部CTAと重ならないので、操作の邪魔になりません。
// =============================================================================
class RoleRibbon extends StatelessWidget {
  const RoleRibbon({super.key});

  @override
  Widget build(BuildContext context) {
    final ops = context.watch<OpsState>();
    final skin = roleSkin(ops.role);
    final name = ops.role == OpsRole.midwife ? ops.currentStaff.name : null;

    return Material(
      color: skin.tint,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 42,
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(skin.icon, size: 15, color: skin.color),
              const SizedBox(width: 7),
              Expanded(
                child: RichText(
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textBody,
                    ),
                    children: [
                      TextSpan(
                        text: name == null ? skin.short : '$name さん',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: skin.color,
                        ),
                      ),
                      TextSpan(text: name == null ? 'として利用中' : '（助産師）として利用中'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: '入る立場を切り替える',
                child: Pressable(
                  radius: BorderRadius.circular(20),
                  onTap: () => showRoleSwitchSheet(context),
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.swap_horiz_rounded,
                            size: 14,
                            color: skin.color,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '切替',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: skin.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 画面末尾に置く「メニューにもどる」カード
// 長い画面をスクロールし切った人が、迷わず帰れるようにするための出口。
// =============================================================================
class ReturnHomeCard extends StatelessWidget {
  final String label;
  const ReturnHomeCard({super.key, this.label = 'メニュー（全体画面）にもどる'});

  @override
  Widget build(BuildContext context) {
    if (!Navigator.of(context).canPop()) return const SizedBox.shrink();
    final skin = roleSkin(context.watch<OpsState>().role);
    return Semantics(
      button: true,
      label: label,
      child: Pressable(
        radius: BorderRadius.circular(AppRadius.md),
        onTap: () => goHome(context),
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: skin.tint,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: skin.color.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.grid_view_rounded, size: 17, color: skin.color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: skin.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// ロール切替シート
// =============================================================================
void showRoleSwitchSheet(BuildContext context) {
  final ops = context.read<OpsState>();
  final nav = Navigator.of(context);

  void apply(OpsRole r) {
    // §37/§42 権限がなければ switchRole は false を返して切り替わらない。
    // 黙って何も起きないと «壊れている» と思われるため、理由を伝える。
    // 権限の付与は入口（はじめる画面）の招待コード／承認申請で行う。
    if (!ops.canSwitchTo(r)) {
      nav.pop();
      showWarmToast(context, '${r.label}の画面には、招待コードまたは管理者の承認が必要です');
      return;
    }
    nav.pop();
    nav.popUntil((route) => route.isFirst);
    HomeSignal.fire();
    ops.switchRole(r);
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              '入る立場を切り替える',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '同じデータを、3つの立場から確認できます。',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 14),
            for (final r in OpsRole.values) ...[
              RolePickCard(
                role: r,
                selected: ops.role == r,
                onTap: () => apply(r),
              ),
              const SizedBox(height: 9),
            ],
            const SizedBox(height: 4),
            Semantics(
              button: true,
              child: Pressable(
                radius: BorderRadius.circular(AppRadius.md),
                onTap: () {
                  nav.pop();
                  nav.push(warmRoute(businessDesignPage()));
                },
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.cardSage,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.insights_rounded,
                        size: 17,
                        color: AppColors.sageDeep,
                      ),
                      SizedBox(width: 8),
                      Text(
                        '事業設計を見る',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.sageDeep,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 事業設計画面のビルダー。
/// （ops/ui 側から注入することで、widgets → ops/ui の循環参照を避ける）
late Widget Function() businessDesignPage;

// =============================================================================
// ロール選択カード（オンボーディング／切替シート共用）
// =============================================================================
class RolePickCard extends StatelessWidget {
  final OpsRole role;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

  const RolePickCard({
    super.key,
    required this.role,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final skin = roleSkin(role);
    return Semantics(
      button: true,
      selected: selected,
      label: '${skin.label}、${skin.caption}',
      child: Pressable(
        radius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.quick,
          curve: AppMotion.gentle,
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: selected ? skin.tint : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? skin.color : AppColors.line,
              width: selected ? 1.8 : 1,
            ),
            boxShadow: selected ? AppShadows.card : null,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: AppMotion.quick,
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? skin.color
                      : skin.color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  skin.icon,
                  size: 21,
                  color: selected ? Colors.white : skin.color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      skin.label,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      skin.caption,
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.4,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing ??
                  AnimatedSwitcher(
                    duration: AppMotion.quick,
                    child: selected
                        ? Icon(
                            Icons.check_circle_rounded,
                            key: const ValueKey('on'),
                            size: 22,
                            color: skin.color,
                          )
                        : const Icon(
                            Icons.radio_button_unchecked_rounded,
                            key: ValueKey('off'),
                            size: 22,
                            color: AppColors.line,
                          ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
