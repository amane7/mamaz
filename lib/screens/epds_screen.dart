import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/facility.dart';
import '../services/care_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import 'online_visit_screen.dart';
import '../widgets/app_nav.dart';

/// EPDS（エジンバラ産後うつ病自己評価票）10項目スクリーニング
class EpdsScreen extends StatefulWidget {
  const EpdsScreen({super.key});

  @override
  State<EpdsScreen> createState() => _EpdsScreenState();
}

class _EpdsScreenState extends State<EpdsScreen> {
  final Map<int, int> _scores = {}; // index -> 0..3
  bool _started = false;

  int get _total => _scores.values.fold(0, (a, b) => a + b);
  bool get _complete => _scores.length == epdsQuestions.length;
  bool get _selfHarm => (_scores[9] ?? 0) >= 1;

  @override
  Widget build(BuildContext context) {
    final care = context.watch<CareState>();

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('こころのセルフチェック'),
        actions: const [HomeButton(), SizedBox(width: 8)],
      ),
      body: SafeArea(
        top: false,
        child: _started ? _questionnaire() : _intro(care),
      ),
    );
  }

  // ---------------- イントロ・履歴 ----------------
  Widget _intro(CareState care) {
    final history = care.epdsHistory;
    final latest = care.latestEpds;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        if (care.epdsDue) ...[
          FadeSlideIn(child: _dueCard(care)),
          const SizedBox(height: 16),
        ],
        FadeSlideIn(
          delay: const Duration(milliseconds: 60),
          child: SoftCard(
            color: Colors.white,
            shadow: AppShadows.soft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(
                        color: AppColors.cardLavender,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite_border_rounded,
                        color: AppColors.lavender,
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'EPDS 産後うつスクリーニング',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            '10項目・約2分',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'エジンバラ産後うつ病自己評価票（EPDS）は、世界中で使われているこころの状態のセルフチェックです。'
                  '「過去7日間」のご自身に一番近いものを選んでください。\n\n'
                  '点数は良い・悪いを決めるものではありません。9点以上のときは、MAMOAから助産師へおつなぎします。',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textBody,
                    height: 1.7,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (latest != null)
          FadeSlideIn(
            delay: const Duration(milliseconds: 120),
            child: _latestCard(latest, history.first.submittedAt, care),
          ),
        if (latest != null) const SizedBox(height: 16),
        if (history.length > 1) ...[
          const SectionTitle('スコアの推移', subtitle: 'あなたの変化を、そっと見守っています'),
          const SizedBox(height: 12),
          FadeSlideIn(
            delay: const Duration(milliseconds: 180),
            child: _historyChart(history),
          ),
          const SizedBox(height: 16),
        ],
        FadeSlideIn(
          delay: const Duration(milliseconds: 240),
          child: _milestoneCard(care),
        ),
        const SizedBox(height: 16),
        Pressable(
          onTap: () => setState(() => _started = true),
          child: Container(
            width: double.infinity,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.blushPinkDeep, AppColors.blushPink],
              ),
              borderRadius: BorderRadius.circular(27),
              boxShadow: AppShadows.soft,
            ),
            child: const Text(
              'チェックをはじめる',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: AppColors.cardCream,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: const [
              Icon(
                Icons.info_outline_rounded,
                size: 17,
                color: AppColors.mauve,
              ),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'このチェックは診断ではありません。結果にかかわらず、つらいときはいつでも助産師・医師にご相談ください。',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textBody,
                    height: 1.55,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 定期スクリーニングのおすすめカード（Step3）
  Widget _dueCard(CareState care) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF6EFFA), Color(0xFFFDF0F4)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          FloatingBob(
            child: Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.event_available_rounded,
                color: AppColors.lavender,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '今日、チェックしてみませんか',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                Text(
                  care.epdsDueMessage,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textBody,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 推奨タイミングのロードマップ
  Widget _milestoneCard(CareState care) {
    final days = care.postpartumDays;
    return SoftCard(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.timeline_rounded,
                size: 17,
                color: AppColors.mauve,
              ),
              const SizedBox(width: 7),
              const Text(
                'おすすめの実施タイミング',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                care.postpartumLabel,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final m in CareState.epdsMilestoneDays) ...[
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: days >= m
                              ? AppColors.sageDeep
                              : AppColors.cardPink,
                        ),
                        child: Icon(
                          days >= m
                              ? Icons.check_rounded
                              : Icons.circle_outlined,
                          size: 13,
                          color: days >= m
                              ? Colors.white
                              : AppColors.blushPinkDeep,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        m < 30
                            ? '${(m / 7).round()}週'
                            : '${(m / 30).round()}ヶ月',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: days >= m
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: days >= m
                              ? AppColors.textDark
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (care.nextEpdsMilestone != null) ...[
            const SizedBox(height: 11),
            Text(
              '次のめやすは産後${care.nextEpdsMilestone! < 30 ? '${(care.nextEpdsMilestone! / 7).round()}週' : '${(care.nextEpdsMilestone! / 30).round()}ヶ月'}'
              '（あと${care.nextEpdsMilestone! - days}日）。忘れていても、こちらからお声がけします。',
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.textMuted,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _latestCard(int score, DateTime at, CareState care) {
    final color = score >= 13
        ? const Color(0xFFE89AA8)
        : score >= 9
        ? const Color(0xFFF1B07A)
        : const Color(0xFF8FC79A);
    final delta = care.epdsDelta;
    return SoftCard(
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              GentleRing(
                progress: score / 30,
                size: 72,
                stroke: 7,
                color: color,
                center: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedCountText(
                      score,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    Text('/30', style: TextStyle(fontSize: 9, color: color)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '前回のスコア',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      CareState.epdsJudgement(score),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      DateFormat('yyyy年M月d日 HH:mm', 'ja').format(at),
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
          if (delta != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: delta <= 0 ? AppColors.cardSage : AppColors.cardCream,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    delta < 0
                        ? Icons.trending_down_rounded
                        : delta == 0
                        ? Icons.trending_flat_rounded
                        : Icons.trending_up_rounded,
                    size: 17,
                    color: delta <= 0
                        ? AppColors.sageDeep
                        : const Color(0xFFE8A468),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      delta < 0
                          ? '前回より${delta.abs()}点やわらいでいます。あなたが続けてきたことが、ちゃんと効いています。'
                          : delta == 0
                          ? '前回と同じスコアです。横ばいも、踏みとどまれている証拠です。'
                          : '前回より$delta点上がっています。ひとりで持たずに、頼ってください。',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textBody,
                        height: 1.55,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _historyChart(List<IntakeForm> history) {
    final items = history.reversed.toList();
    return SoftCard(
      color: Colors.white,
      child: Column(
        children: [
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: items.map((e) {
                final s = e.epdsScore ?? 0;
                final h = (s / 30 * 88).clamp(6.0, 88.0);
                final color = s >= 13
                    ? const Color(0xFFE89AA8)
                    : s >= 9
                    ? const Color(0xFFF1B07A)
                    : const Color(0xFF8FC79A);
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '$s',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: h,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        DateFormat('M/d').format(e.submittedAt),
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              _Legend(Color(0xFF8FC79A), '0-8'),
              SizedBox(width: 12),
              _Legend(Color(0xFFF1B07A), '9-12'),
              SizedBox(width: 12),
              _Legend(Color(0xFFE89AA8), '13以上'),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- 質問 ----------------
  Widget _questionnaire() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    '${_scores.length} / ${epdsQuestions.length} 項目',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.blushPinkDeep,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    '過去7日間のご自身について',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(
                    begin: 0,
                    end: _scores.length / epdsQuestions.length,
                  ),
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => LinearProgressIndicator(
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
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            itemCount: epdsQuestions.length,
            itemBuilder: (context, i) => FadeSlideIn(
              delay: Duration(milliseconds: 40 * i),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _epdsQuestion(i, epdsQuestions[i]),
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE9B9C6).withValues(alpha: 0.2),
                blurRadius: 18,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _complete ? _finish : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blushPinkDeep,
                  disabledBackgroundColor: AppColors.line,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                child: Text(
                  _complete
                      ? '結果を見る'
                      : 'あと${epdsQuestions.length - _scores.length}項目',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _epdsQuestion(int i, EpdsQuestion q) {
    return SoftCard(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _scores.containsKey(i)
                      ? AppColors.blushPinkDeep
                      : AppColors.cardPink,
                  shape: BoxShape.circle,
                ),
                child: _scores.containsKey(i)
                    ? const Icon(
                        Icons.check_rounded,
                        size: 13,
                        color: Colors.white,
                      )
                    : Text(
                        '${i + 1}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.blushPinkDeep,
                        ),
                      ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  q.text,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var c = 0; c < q.choices.length; c++)
            Pressable(
              scale: 0.98,
              onTap: () => setState(() => _scores[i] = c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                margin: const EdgeInsets.only(bottom: 7),
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: _scores[i] == c ? AppColors.cardPink : AppColors.cream,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _scores[i] == c
                        ? AppColors.blushPinkDeep
                        : AppColors.line,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _scores[i] == c
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 17,
                      color: _scores[i] == c
                          ? AppColors.blushPinkDeep
                          : AppColors.textMuted,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        q.choices[c],
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          fontWeight: _scores[i] == c
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------- 結果 ----------------
  void _finish() {
    final care = context.read<CareState>();
    final answers = <String, String>{};
    for (var i = 0; i < epdsQuestions.length; i++) {
      answers['Q${i + 1} ${epdsQuestions[i].text}'] =
          '${epdsQuestions[i].choices[_scores[i]!]}（${_scores[i]}点）';
    }
    answers['合計'] = '$_total点';
    care.submitIntake(
      IntakeKind.postpartum,
      answers,
      epdsScore: _total,
      signed: true,
    );

    if (_selfHarm) {
      care.addEscalation(
        reason: '自傷念慮に関する項目に該当',
        detail: 'Q10（自分自身を傷つけるという考え）に該当があります。至急、助産師・専門機関への接続が必要です。',
        severity: 'high',
      );
    }

    final score = _total;
    final high = score >= 13 || _selfHarm;
    final mid = score >= 9;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0xFF5C5350).withValues(alpha: 0.3),
      builder: (dialogCtx) {
        if (!mid) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (dialogCtx.mounted) Celebration.show(dialogCtx, count: 20);
          });
        }
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: FadeSlideIn(
            offsetY: 22,
            scale: true,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GentleRing(
                      progress: score / 30,
                      size: 96,
                      stroke: 9,
                      color: high
                          ? const Color(0xFFE89AA8)
                          : mid
                          ? const Color(0xFFF1B07A)
                          : const Color(0xFF6FB57E),
                      center: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedCountText(
                            score,
                            duration: const Duration(milliseconds: 900),
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: high
                                  ? const Color(0xFFE89AA8)
                                  : mid
                                  ? const Color(0xFFF1B07A)
                                  : const Color(0xFF6FB57E),
                            ),
                          ),
                          const Text(
                            '/ 30点',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      CareState.epdsJudgement(score),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      high
                          ? 'ここまで、本当によくがんばってこられました。今のつらさは「がんばりが足りないから」では決してありません。\n\n担当助産師におつなぎしました。公式LINEからご連絡します。強い気持ちの落ち込みが続くときは、産科・心療内科の受診もご検討ください。'
                          : mid
                          ? 'ひとりで抱えなくて大丈夫です。助産師とお話しできる場を用意しました。オンライン相談なら、赤ちゃんと一緒のままご参加いただけます。'
                          : '今は落ち着いた状態のようです。ここまで自分を守ってこられたこと、すごいことです。\n\n産後は変化が大きい時期なので、月に1回のふりかえりをおすすめします。時期が来たら、こちらからお声がけしますね。',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textBody,
                        height: 1.7,
                      ),
                    ),
                    if (_selfHarm) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDEBEE),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Column(
                          children: [
                            Text(
                              '今すぐ話せる窓口',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'よりそいホットライン 0120-279-338（24時間）\nこころの健康相談統一ダイヤル 0570-064-556',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textBody,
                                height: 1.7,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    if (mid)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(dialogCtx);
                            Navigator.pop(context);
                            // §1 「Human when it matters.」
                            // ここは予約エンジンではなく、
                            // 直接人につなぐ場面です。
                            Navigator.push(
                              context,
                              warmRoute(const OnlineVisitScreen()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.blushPinkDeep,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: const Text(
                            '助産師のオンライン相談を予約する',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(dialogCtx);
                        Navigator.pop(context);
                      },
                      child: const Text(
                        '閉じる',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend(this.color, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
        ),
      ],
    );
  }
}
