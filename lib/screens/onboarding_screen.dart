import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ops/ops_state.dart';
import '../root_shell.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_nav.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';

/// はじめる画面
///
/// ここで「どの立場でアプリに入るか」を先に決めます。
/// 産後ケアは 家族・助産師・運営 の3者で成り立つ仕組みなので、
/// 入口の時点で立場を選べることが、いちばん迷わない設計です。
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameController = TextEditingController();
  OpsRole _role = OpsRole.family;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// §39 スタッフとして入ろうとしたときの流れ。
  ///
  /// «押したら入れてしまう» のがこれまでの問題だった。招待コードか
  /// 管理者承認を通す。コードを持っていない人を追い返さないよう、
  /// 「承認を申請する」も同じ画面に置く（現場では後からコードをもらう）。
  Future<void> _requestStaff(OpsState ops, StaffRoleKind area) async {
    final codeCtl = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0xFF5C5350).withValues(alpha: 0.28),
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(
          '${area.label}としてのご利用',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'スタッフ画面には、ご家族の氏名・問診・カルテなど大切な情報が'
              '含まれます。そのため、招待コードまたは管理者の承認が必要です。\n\n'
              'お手元にコードがない場合は、空欄のままお進みください。'
              '管理者へ承認の申請をお預かりします。',
              style: TextStyle(
                fontSize: 13.5,
                height: 1.6,
                color: AppColors.textBody,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeCtl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '招待コード（お持ちの場合）',
                hintText: '例：MW-2026-01',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('やめる'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('確認する'),
          ),
        ],
      ),
    );
    final code = codeCtl.text;
    codeCtl.dispose();
    if (submitted != true || !mounted) return;

    final decision = ops.requestStaffAccess(
      requested: area,
      code: code,
      name: _nameController.text,
    );
    if (!mounted) return;

    if (decision.isGranted) {
      showWarmToast(context, decision.message);
      AppMotion.celebrate();
      _enter();
      return;
    }
    // §40 通らなかったときも行き止まりにしない。利用者として続けられる。
    await showWarmDialog(
      context,
      icon: decision.outcome == StaffAccessOutcome.pending
          ? Icons.pending_actions_outlined
          : Icons.info_outline_rounded,
      color: AppColors.lavender,
      title: decision.outcome == StaffAccessOutcome.pending
          ? '承認の申請をお預かりしました'
          : 'スタッフとしてのご利用を確認できませんでした',
      message: '${decision.message}\n\nこのまま利用者としてお使いいただけます。',
      primaryLabel: '利用者としてはじめる',
    );
    if (!mounted) return;
    setState(() => _role = OpsRole.family);
    ops.returnToFamily();
    _enter();
  }

  Future<void> _start() async {
    final app = context.read<AppState>();
    final ops = context.read<OpsState>();

    if (_role == OpsRole.family && _nameController.text.trim().isNotEmpty) {
      app.setMotherName(_nameController.text.trim());
    }

    // §37 自己申告では権限を渡さない。承認済みでなければ §39 の流れへ。
    final area = _role == OpsRole.midwife
        ? StaffRoleKind.midwife
        : _role == OpsRole.admin
        ? StaffRoleKind.admin
        : null;
    if (area != null && !ops.canOpenStaffArea(area)) {
      await _requestStaff(ops, area);
      return;
    }

    ops.switchRole(_role);
    AppMotion.celebrate();
    _enter();
  }

  void _enter() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 520),
        pageBuilder: (_, a, __) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.03),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: a, curve: AppMotion.gentle)),
            child: const RootShell(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final skin = roleSkin(_role);
    final family = _role == OpsRole.family;

    return Scaffold(
      body: AnimatedContainer(
        duration: AppMotion.slow,
        curve: AppMotion.gentle,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              skin.color.withValues(alpha: 0.13),
              AppColors.cream,
              const Color(0xFFF3EEF9),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
                  child: Column(
                    children: [
                      const MamoaWordmark(logoSize: 38, fontSize: 25),
                      const SizedBox(height: 14),
                      FloatingBob(
                        amplitude: 4,
                        child: Container(
                          width: 122,
                          height: 122,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.cream,
                            boxShadow: AppShadows.soft,
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Image.asset(
                            'assets/images/mascot.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        '産後の不安に、温もりが届く。',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          height: 1.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 18),

                      // ---- ロール選択 -----------------------------------
                      Row(
                        children: [
                          Container(
                            width: 3,
                            height: 16,
                            decoration: BoxDecoration(
                              color: AppColors.blushPinkDeep,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'どの立場で入りますか？',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(left: 11),
                          child: Text(
                            'あとから画面上部の「切替」でいつでも変えられます。',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...List.generate(OpsRole.values.length, (i) {
                        final r = OpsRole.values[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: FadeSlideIn(
                            delay: Duration(milliseconds: 120 + i * 70),
                            child: RolePickCard(
                              role: r,
                              selected: _role == r,
                              onTap: () {
                                AppMotion.softTap();
                                setState(() => _role = r);
                              },
                            ),
                          ),
                        );
                      }),

                      // ---- 家族のときだけ、お名前 ------------------------
                      AnimatedSize(
                        duration: AppMotion.normal,
                        curve: AppMotion.gentle,
                        child: family
                            ? Container(
                                margin: const EdgeInsets.only(top: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(26),
                                  boxShadow: AppShadows.card,
                                ),
                                child: TextField(
                                  controller: _nameController,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 14.5),
                                  decoration: const InputDecoration(
                                    hintText: 'お名前・ニックネーム（任意）',
                                    hintStyle: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 13.5,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 15,
                                    ),
                                  ),
                                ),
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              // ---- 片手で押せるフッターCTA --------------------------------
              Container(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.86),
                  border: const Border(top: BorderSide(color: AppColors.line)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      button: true,
                      label: '${skin.label}としてはじめる',
                      child: SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _start,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: skin.color,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(27),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(skin.icon, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                '${skin.short}としてはじめる',
                                style: const TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '24時間いつでも寄り添う・医学的根拠に基づく情報・プライバシーに配慮',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
