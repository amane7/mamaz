import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'main_scaffold.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _start() {
    final state = context.read<AppState>();
    if (_nameController.text.trim().isNotEmpty) {
      state.setMotherName(_nameController.text.trim());
    }
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, a, __) => FadeTransition(
            opacity: a, child: const MainScaffold()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFDEFF3), AppColors.cream, Color(0xFFF3EEF9)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const Spacer(flex: 2),
                const MamoaWordmark(logoSize: 48, fontSize: 30),
                const SizedBox(height: 28),
                Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.cream,
                    boxShadow: AppShadows.soft,
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Image.asset('assets/images/mascot.png',
                      fit: BoxFit.contain),
                ),
                const SizedBox(height: 28),
                const Text('産後の不安に、\n温もりが届く。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 24,
                        height: 1.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark)),
                const SizedBox(height: 12),
                const Text('助産師の手のぬくもりを、24時間そばに。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13.5,
                        color: AppColors.textBody,
                        height: 1.5)),
                const Spacer(flex: 2),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: AppShadows.card,
                  ),
                  child: TextField(
                    controller: _nameController,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15),
                    decoration: const InputDecoration(
                      hintText: 'お名前・ニックネーム（任意）',
                      hintStyle: TextStyle(
                          color: AppColors.textMuted, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _start,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blushPinkDeep,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28)),
                    ),
                    child: const Text('はじめる',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('24時間いつでも寄り添う・医学的根拠に基づく情報・プライバシーに配慮',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 10.5, color: AppColors.textMuted)),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
