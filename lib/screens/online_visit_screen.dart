import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/facility.dart';
import '../services/care_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import '../widgets/app_nav.dart';

/// オンライン面談（MamaWell型・Step3）
/// 助産師と顔を見て話す定期フォローの予約・履歴画面。
class OnlineVisitScreen extends StatefulWidget {
  const OnlineVisitScreen({super.key});

  @override
  State<OnlineVisitScreen> createState() => _OnlineVisitScreenState();
}

class _OnlineVisitScreenState extends State<OnlineVisitScreen> {
  static const _topics = [
    _Topic(
      '母乳のこと',
      '出方・痛み・卒乳など',
      Icons.water_drop_outlined,
      AppColors.cardPink,
      AppColors.blushPinkDeep,
    ),
    _Topic(
      'こころのこと',
      'つらさ・不安・眠れない',
      Icons.favorite_border_rounded,
      AppColors.cardLavender,
      AppColors.lavender,
    ),
    _Topic(
      'からだの回復',
      '血圧・傷・悪露・体調',
      Icons.monitor_heart_outlined,
      AppColors.cardSage,
      Color(0xFF6FB57E),
    ),
    _Topic(
      '赤ちゃんのこと',
      '体重・寝ない・泣きやまない',
      Icons.child_care_outlined,
      AppColors.cardCream,
      AppColors.mauve,
    ),
    _Topic(
      '話をきいてほしい',
      'まとまらなくても大丈夫です',
      Icons.chat_bubble_outline_rounded,
      AppColors.cardPink,
      AppColors.mauve,
    ),
  ];

  int _topicIndex = 0;
  int _dayOffset = 1;
  int _slotIndex = 1;

  static const _slots = ['10:00', '11:00', '14:00', '15:00', '20:00', '21:00'];

  @override
  Widget build(BuildContext context) {
    final care = context.watch<CareState>();
    final visits = care.visits;
    final upcoming = visits
        .where((v) => v.status == '予約済' && v.at.isAfter(DateTime.now()))
        .toList();
    final past = visits
        .where((v) => v.status != '予約済' || v.at.isBefore(DateTime.now()))
        .toList()
        .reversed
        .toList();

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textDark,
        title: const Text(
          'オンライン面談',
          style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
        ),
        actions: const [HomeButton(), SizedBox(width: 8)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          FadeSlideIn(child: _hero()),
          const SizedBox(height: 20),
          if (upcoming.isNotEmpty) ...[
            const FadeSlideIn(
              delay: Duration(milliseconds: 60),
              child: SectionTitle('予約されている面談', subtitle: '当日は、こちらからリンクをお送りします'),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < upcoming.length; i++)
              FadeSlideIn(
                delay: Duration(milliseconds: 100 + i * 60),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _upcomingCard(care, upcoming[i]),
                ),
              ),
            const SizedBox(height: 12),
          ],
          const FadeSlideIn(
            delay: Duration(milliseconds: 160),
            child: SectionTitle('話したいこと', subtitle: 'ひとつ選ぶだけ。うまく言葉にできなくて大丈夫です'),
          ),
          const SizedBox(height: 12),
          FadeSlideIn(
            delay: const Duration(milliseconds: 200),
            child: _topicPicker(),
          ),
          const SizedBox(height: 22),
          const FadeSlideIn(
            delay: Duration(milliseconds: 240),
            child: SectionTitle('日時を選ぶ', subtitle: '赤ちゃんと一緒のままご参加いただけます'),
          ),
          const SizedBox(height: 12),
          FadeSlideIn(
            delay: const Duration(milliseconds: 280),
            child: _dayPicker(),
          ),
          const SizedBox(height: 12),
          FadeSlideIn(
            delay: const Duration(milliseconds: 320),
            child: _slotPicker(),
          ),
          const SizedBox(height: 20),
          FadeSlideIn(
            delay: const Duration(milliseconds: 360),
            child: _bookButton(care),
          ),
          if (past.isNotEmpty) ...[
            const SizedBox(height: 26),
            const SectionTitle('これまでの面談', subtitle: 'ふりかえりは、次のケアに活かされます'),
            const SizedBox(height: 12),
            for (final v in past)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _pastCard(v),
              ),
          ],
          const SizedBox(height: 20),
          _note(),
        ],
      ),
    );
  }

  // ---------------- Hero ----------------
  Widget _hero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFBC3D6), Color(0xFFD3C4EE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        children: [
          const FloatingBob(
            amplitude: 5,
            child: Icon(
              Icons.video_camera_front_rounded,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '顔を見て、ゆっくり話す時間',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '30分・オンライン。すっぴん・パジャマ・抱っこしたまま、そのままでどうぞ。',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.white,
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

  // ---------------- 予約済み ----------------
  Widget _upcomingCard(CareState care, OnlineVisit v) {
    final df = DateFormat('M月d日(E) HH:mm', 'ja');
    final days = v.at.difference(DateTime.now()).inDays;
    return SoftCard(
      color: Colors.white,
      shadow: AppShadows.soft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const TagChip(
                '予約済',
                color: AppColors.cardSage,
                textColor: Color(0xFF6FB57E),
              ),
              const Spacer(),
              Text(
                days <= 0 ? '本日' : 'あと$days日',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.blushPinkDeep,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            df.format(v.at),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '${v.topic}\n${v.midwife}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textBody,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Pressable(
                  onTap: () => showWarmDialog(
                    context,
                    icon: Icons.videocam_rounded,
                    title: '入室はこちらから',
                    message:
                        '開始10分前になると、公式LINEとアプリの通知でビデオ通話リンクをお送りします。\n\n'
                        '静かな場所でなくても大丈夫です。泣き声も、生活音も、そのままで。',
                    color: AppColors.lavender,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.cardLavender,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Text(
                      '入室方法',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.mauve,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Pressable(
                  onTap: () => showWarmDialog(
                    context,
                    icon: Icons.event_busy_rounded,
                    title: 'この面談をキャンセルしますか',
                    message:
                        '無理な日は、遠慮なく変更してください。'
                        'キャンセル料はかかりません。またいつでもお待ちしています。',
                    primaryLabel: 'やめておく',
                    secondaryLabel: 'キャンセルする',
                    onSecondary: () {
                      care.cancelVisit(v.id);
                      showWarmToast(
                        context,
                        'キャンセルしました。またお待ちしています。',
                        icon: Icons.spa_rounded,
                      );
                    },
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.cardCream,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Text(
                      '日程を変える',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.mauve,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pastCard(OnlineVisit v) {
    final df = DateFormat('yyyy年M月d日 HH:mm', 'ja');
    return SoftCard(
      color: Colors.white,
      shadow: const [],
      border: Border.all(color: AppColors.line),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.cardSage,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 18,
              color: Color(0xFF6FB57E),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  v.topic,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${df.format(v.at)}・${v.status}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textMuted,
                  ),
                ),
                if (v.note != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    v.note!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textBody,
                      height: 1.6,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- ピッカー ----------------
  Widget _topicPicker() {
    return Column(
      children: [
        for (var i = 0; i < _topics.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Pressable(
              scale: 0.98,
              onTap: () => setState(() => _topicIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _topicIndex == i ? _topics[i].bg : Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: _topicIndex == i
                        ? _topics[i].fg.withValues(alpha: 0.55)
                        : AppColors.line,
                    width: _topicIndex == i ? 1.6 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(_topics[i].icon, size: 20, color: _topics[i].fg),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _topics[i].label,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _topics[i].hint,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _topicIndex == i ? 1 : 0,
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 20,
                        color: _topics[i].fg,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _dayPicker() {
    final now = DateTime.now();
    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 14,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final d = now.add(Duration(days: i + 1));
          final sel = _dayOffset == i + 1;
          return Pressable(
            onTap: () => setState(() => _dayOffset = i + 1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 56,
              decoration: BoxDecoration(
                color: sel ? AppColors.blushPinkDeep : Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: sel ? AppShadows.soft : AppShadows.card,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E', 'ja').format(d),
                    style: TextStyle(
                      fontSize: 10,
                      color: sel ? Colors.white70 : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${d.day}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: sel ? Colors.white : AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${d.month}月',
                    style: TextStyle(
                      fontSize: 9,
                      color: sel ? Colors.white70 : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _slotPicker() {
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: [
        for (var i = 0; i < _slots.length; i++)
          Pressable(
            onTap: () => setState(() => _slotIndex = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              decoration: BoxDecoration(
                color: _slotIndex == i ? AppColors.cardPink : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _slotIndex == i
                      ? AppColors.blushPinkDeep
                      : AppColors.line,
                  width: _slotIndex == i ? 1.6 : 1,
                ),
              ),
              child: Text(
                _slots[i],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _slotIndex == i
                      ? AppColors.blushPinkDeep
                      : AppColors.textBody,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _bookButton(CareState care) {
    return Pressable(
      scale: 0.97,
      onTap: () => _book(care),
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.blushPinkDeep, Color(0xFFCBA6DE)],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: AppShadows.soft,
        ),
        child: const Text(
          'この日時で面談を予約する',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  void _book(CareState care) {
    final now = DateTime.now();
    final d = now.add(Duration(days: _dayOffset));
    final hm = _slots[_slotIndex].split(':');
    final at = DateTime(
      d.year,
      d.month,
      d.day,
      int.parse(hm[0]),
      int.parse(hm[1]),
    );
    care.bookVisit(at: at, topic: _topics[_topicIndex].label);
    AppMotion.celebrate();
    showWarmDialog(
      context,
      icon: Icons.favorite_rounded,
      title: 'ご予約をお預かりしました',
      message:
          '${DateFormat('M月d日(E) HH:mm', 'ja').format(at)}\n'
          '${_topics[_topicIndex].label}について、助産師 南田 みなみ がお待ちしています。\n\n'
          '当日までに書き留めておきたいことがあれば、記録にメモしておいてくださいね。'
          '思い出せなくても、こちらから伺います。',
      celebrate: true,
    );
  }

  Widget _note() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSage,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF6FB57E)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'オンライン面談は助産師による「健康相談」です。診断・治療は行いません。'
              '緊急の症状があるときは、産科・救急へご連絡ください。',
              style: TextStyle(
                fontSize: 10.5,
                color: AppColors.textBody,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Topic {
  final String label;
  final String hint;
  final IconData icon;
  final Color bg;
  final Color fg;
  const _Topic(this.label, this.hint, this.icon, this.bg, this.fg);
}
