import 'package:flutter/material.dart';

import '../ops/ui/family_shell.dart';
import '../theme/app_theme.dart';
import '../widgets/app_nav.dart';
import '../widgets/motion.dart';
import 'community_screen.dart';
import 'journal_screen.dart';
import 'learn_screen.dart';
import 'my_record_screen.dart';

/// ---------------------------------------------------------------------------
/// ご家族シェル（§5 家族トップ / §25 家族向け画面の原則）
///
/// 旧UIは「ホーム／AI相談／予約／記録／つながり／マイカルテ」の6タブでしたが、
/// 要件に合わせて4タブへ整理しました。
///
///  ・「AI相談」を常設タブから外しました。
///      §1「Chatless by default, Human when it matters.」に反するためです。
///      相談は §5 の「どれを選べばよいか相談する」から入り、人が受け取ります。
///      AIが利用可否を判定・自動確定することは行いません（§1）。
///
///  ・「予約」タブを外しました。
///      §5 では予約は「産後ケアを利用する」「母乳・授乳の相談をする」という
///      “用件”です。同じ予約に2つの入口があると §2「迷わせない」に反し、
///      さらに旧予約フローは Matching Engine を通らないため
///      条件判定（§12）を素通りしてしまいます。
///
///  ・ホームは [FamilyShell]（OpsState 駆動）に統一しました。
///      これにより §21「前回と同じ内容で予約」が家族トップに出ます。
///
///  ・旧ホームからしか行けなかった読みもの・セルフチェック・オンライン面談は
///      「学ぶ」タブ（[LearnScreen]）へ移して残しました。§5 のトップ5カテゴリを
///      増やさないためです（§25 1画面1テーマ）。
/// ---------------------------------------------------------------------------
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    HomeSignal.tick.addListener(_resetToHome);
  }

  @override
  void dispose() {
    HomeSignal.tick.removeListener(_resetToHome);
    super.dispose();
  }

  /// 「メニューにもどる」と、ホームタブまで戻る。
  void _resetToHome() {
    if (mounted && _index != 0) setState(() => _index = 0);
  }

  void _navigate(int i) {
    AppMotion.softTap();
    setState(() => _index = i);
  }

  static const _pages = <Widget>[
    FamilyShell(),
    JournalScreen(),
    LearnScreen(),
    CommunityScreen(),
    MyRecordScreen(),
  ];

  static const _items = [
    _NavItem('ホーム', Icons.home_outlined, Icons.home_rounded),
    _NavItem('記録', Icons.edit_note_outlined, Icons.edit_note_rounded),
    _NavItem('学ぶ', Icons.menu_book_outlined, Icons.menu_book_rounded),
    _NavItem('つながり', Icons.groups_outlined, Icons.groups_rounded),
    _NavItem(
      'マイカルテ',
      Icons.folder_shared_outlined,
      Icons.folder_shared_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE9B9C6).withValues(alpha: 0.18),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: List.generate(_items.length, (i) {
                final selected = _index == i;
                final item = _items[i];
                return Expanded(
                  child: Semantics(
                    button: true,
                    selected: selected,
                    label: item.label,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _navigate(i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.cardPink
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              selected ? item.activeIcon : item.icon,
                              size: 23,
                              color: selected
                                  ? AppColors.blushPinkDeep
                                  : AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.visible,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: selected
                                  ? AppColors.blushPinkDeep
                                  : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _NavItem(this.label, this.icon, this.activeIcon);
}
