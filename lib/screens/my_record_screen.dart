import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/facility.dart';
import '../services/app_state.dart';
import '../services/care_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import 'epds_screen.dart';
import 'intake_form_screen.dart';
import 'midwife_screen.dart';
import '../widgets/app_nav.dart';

/// マイカルテ：共有されたカルテ・提出した問診票・設定（助産師モード切替）
class MyRecordScreen extends StatelessWidget {
  const MyRecordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final care = context.watch<CareState>();
    final state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('マイカルテ'),
        actions: const [HomeButton(), SizedBox(width: 8)],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: warmList([
            _profileCard(state, care),
            const SizedBox(height: 20),
            const SectionTitle('問診票を書く', subtitle: '事前に提出すると、当日はケアに集中できます'),
            const SizedBox(height: 12),
            _intakeGrid(context, state.motherName),
            const SizedBox(height: 22),
            const SectionTitle(
              '助産師から共有されたカルテ',
              subtitle: 'ケアの内容と、次までに気をつけることを確認できます',
            ),
            const SizedBox(height: 12),
            if (care.careRecords.isEmpty)
              const WarmEmptyState(
                icon: Icons.folder_shared_outlined,
                title: '共有されたカルテはまだありません',
                message: 'ケアをご利用いただくと、助産師が記録した内容を\nここでいつでも見返せるようになります。',
              )
            else
              for (final r in care.careRecords) ...[
                _recordCard(r),
                const SizedBox(height: 12),
              ],
            const SizedBox(height: 22),
            const SectionTitle('提出した問診票', subtitle: '書いてくださったことはすべて引き継がれています'),
            const SizedBox(height: 12),
            if (care.intakes.isEmpty)
              const WarmEmptyState(
                icon: Icons.assignment_outlined,
                title: '提出した問診票はまだありません',
                message: 'すべての項目を埋めなくても大丈夫です。\n書けるところだけでも、十分に伝わります。',
                color: AppColors.sageDeep,
              )
            else
              for (final f in care.intakes.take(8)) ...[
                _intakeTile(f),
                const SizedBox(height: 8),
              ],
            const SizedBox(height: 24),
            _midwifeModeCard(context, care),
            const SizedBox(height: 14),
            _privacyCard(),
          ]),
        ),
      ),
    );
  }

  Widget _profileCard(AppState state, CareState care) {
    return SoftCard(
      color: Colors.white,
      shadow: AppShadows.soft,
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              color: AppColors.cardPink,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              size: 26,
              color: AppColors.blushPinkDeep,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${state.motherName} さん',
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${care.municipality} 在住・産後ケア事業 利用登録済み',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _intakeGrid(BuildContext context, String motherName) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _intakeBtn(
                context,
                IntakeKind.first,
                motherName,
                AppColors.cardPink,
                AppColors.blushPinkDeep,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: _epdsBtn(context)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _intakeBtn(
                context,
                IntakeKind.breast,
                motherName,
                AppColors.cardSage,
                const Color(0xFF6FB57E),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _intakeBtn(
                context,
                IntakeKind.urgent,
                motherName,
                AppColors.cardCream,
                AppColors.mauve,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _intakeBtn(
    BuildContext context,
    IntakeKind k,
    String motherName,
    Color bg,
    Color fg,
  ) {
    return Pressable(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => IntakeFormScreen(kind: k, motherName: motherName),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          children: [
            Icon(k.icon, size: 21, color: fg),
            const SizedBox(height: 8),
            Text(
              k.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _epdsBtn(BuildContext context) {
    return Pressable(
      onTap: () => Navigator.push(context, warmRoute(const EpdsScreen())),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.cardLavender,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.favorite_border_rounded,
              size: 21,
              color: AppColors.lavender,
            ),
            SizedBox(height: 8),
            Text(
              'EPDS こころのチェック',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.lavender,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recordCard(CareRecord r) {
    return SoftCard(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: r.kind.color.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(r.kind.icon, size: 19, color: AppColors.mauve),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.facilityName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${DateFormat('yyyy年M月d日', 'ja').format(r.date)}｜${r.recorder}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          _block('助産師が見た状態', r.objective, AppColors.cardLavender),
          _block('お伝えしたこと', r.assessment, AppColors.cardCream),
          _block('次までに気をつけること', r.plan, AppColors.cardSage),
          if (r.breastNote != null && r.breastNote!.isNotEmpty)
            _block('母乳・乳房のこと', r.breastNote!, AppColors.cardPink),
        ],
      ),
    );
  }

  Widget _block(String label, String body, Color bg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: AppColors.mauve,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            body,
            style: const TextStyle(
              fontSize: 12,
              height: 1.7,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _intakeTile(IntakeForm f) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Icon(f.kind.icon, size: 17, color: AppColors.blushPinkDeep),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f.kind.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('yyyy/M/d HH:mm 提出', 'ja').format(f.submittedAt),
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (f.epdsScore != null)
            TagChip(
              '${f.epdsScore}点',
              color: f.epdsScore! >= 9
                  ? AppColors.cardCream
                  : AppColors.cardSage,
              textColor: f.epdsScore! >= 9
                  ? AppColors.mauve
                  : const Color(0xFF6FB57E),
            ),
        ],
      ),
    );
  }

  Widget _midwifeModeCard(BuildContext context, CareState care) {
    return SoftCard(
      color: AppColors.cardCream,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MidwifeScreen()),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.medical_services_outlined,
              size: 21,
              color: AppColors.mauve,
            ),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '助産師モードを開く',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 4),
                Text(
                  '予約管理・問診票確認・SOAPカルテ・報酬計算・請求書発行',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textBody,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.mauve),
        ],
      ),
    );
  }

  Widget _privacyCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: const [
          Icon(
            Icons.lock_outline_rounded,
            size: 18,
            color: AppColors.textMuted,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'カルテ・問診票は端末内で暗号化して保存し、担当助産師と提携施設のみが閲覧できます（転送時TLS1.3／保存時AES-256）。データの削除はいつでも請求できます。',
              style: TextStyle(
                fontSize: 10.5,
                color: AppColors.textMuted,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
