import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'chat_screen.dart';
import 'reservation_screen.dart';
import 'community_screen.dart';
import 'journal_screen.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _index = 0;

  void _navigate(int i) => setState(() => _index = i);

  late final List<Widget> _pages = [
    HomeScreen(onNavigate: _navigate),
    const ChatScreen(),
    const ReservationScreen(),
    const CommunityScreen(),
    const JournalScreen(),
  ];

  static const _items = [
    _NavItem('ホーム', Icons.home_outlined, Icons.home_rounded),
    _NavItem('MOA相談', Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded),
    _NavItem('予約', Icons.calendar_today_outlined, Icons.calendar_today_rounded),
    _NavItem('つながり', Icons.groups_outlined, Icons.groups_rounded),
    _NavItem('ジャーナル', Icons.menu_book_outlined, Icons.menu_book_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _navigate(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 5),
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
                        Text(item.label,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected
                                    ? AppColors.blushPinkDeep
                                    : AppColors.textMuted)),
                      ],
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
