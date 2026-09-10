import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'ops/ops_state.dart';
import 'ops/ui/admin_console.dart';
import 'ops/ui/midwife_workspace.dart';
import 'screens/main_scaffold.dart';
import 'theme/app_theme.dart';
import 'widgets/app_nav.dart';
import 'widgets/motion.dart';

/// ---------------------------------------------------------------------------
/// ルートシェル
///
/// アプリの「いちばん下の画面」。ここが各ロールの メインメニュー（全体画面）です。
/// どの機能画面からでも `goHome()`（＝popUntil(isFirst)）すると必ずここに戻るため、
/// 迷子になりません。
///
///  利用者（ご家族） → MainScaffold（ホーム／記録／つながり／マイカルテ）
///                     ホームは FamilyShell（§5 トップ5カテゴリ＋§21 リピート）
///  助産師           → MidwifeWorkspace（今日のケア／判断キュー／OK・NG／わたし）
///  管理者           → AdminConsole（ダッシュ／例外／カレンダー／マスタ／記録）
/// ---------------------------------------------------------------------------
class RootShell extends StatelessWidget {
  const RootShell({super.key});

  @override
  Widget build(BuildContext context) {
    final role = context.watch<OpsState>().role;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        children: [
          const RoleRibbon(),
          Expanded(
            // 上部のセーフエリアはリボンが消費済みなので、子には渡さない。
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: AnimatedSwitcher(
                duration: AppMotion.normal,
                switchInCurve: AppMotion.gentle,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.02),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: switch (role) {
                  OpsRole.family => const MainScaffold(key: ValueKey('family')),
                  OpsRole.midwife => const MidwifeWorkspace(
                    key: ValueKey('midwife'),
                  ),
                  OpsRole.admin => const AdminConsole(key: ValueKey('admin')),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
