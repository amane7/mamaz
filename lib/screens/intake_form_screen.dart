import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/facility.dart';
import '../services/care_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/app_nav.dart';

/// 問診票（初回9項目 / 母乳ケア / 緊急時）＋電子同意
class IntakeFormScreen extends StatefulWidget {
  final IntakeKind kind;
  final String? bookingId;
  final String motherName;
  const IntakeFormScreen({
    super.key,
    required this.kind,
    this.bookingId,
    this.motherName = 'ママ',
  });

  @override
  State<IntakeFormScreen> createState() => _IntakeFormScreenState();
}

class _IntakeFormScreenState extends State<IntakeFormScreen> {
  final Map<String, String> _answers = {};
  final _freeText = TextEditingController();
  bool _signed = false;

  Map<String, List<String>> get _questions {
    switch (widget.kind) {
      case IntakeKind.breast:
        return const {
          '授乳方法': ['母乳のみ', '母乳＋ミルク', 'ミルクのみ', '搾乳のみ'],
          '母乳の量の実感': ['足りている', 'やや少ない', 'とても少ない', '多すぎる'],
          '乳房の状態': ['問題なし', '張って痛い', 'しこりがある', '赤み・熱感がある'],
          '乳頭の状態': ['問題なし', '切れて痛い', '白斑がある', '形が飲みにくい'],
          '1日の授乳回数': ['6回以下', '7〜9回', '10〜12回', '13回以上'],
          '痛みの強さ': ['なし', '弱い', '中くらい', '強い'],
          '発熱': ['なし', '37℃台', '38℃以上'],
          'これまでの乳腺炎': ['なし', '1回', '2回以上'],
          '今回のご希望': ['乳房ケア（マッサージ）', '授乳姿勢の指導', '母乳量を増やしたい', '卒乳・断乳の相談'],
        };
      case IntakeKind.urgent:
        return const {
          '出血の量': ['ほぼなし', '生理程度', '生理より多い', 'ナプキンが1時間でいっぱい'],
          '体温': ['37℃未満', '37℃台', '38℃以上'],
          '頭痛': ['なし', '軽い', '強い（薬が効かない）'],
          '目の見えにくさ・ちらつき': ['なし', 'ときどき', '継続してある'],
          'みぞおち・右上腹部の痛み': ['なし', '軽い', '強い'],
          '傷の痛み・赤み': ['なし', '軽い', '赤く腫れている', '膿が出る'],
          '呼吸のしにくさ・胸の痛み': ['なし', '軽い', 'ある'],
          '赤ちゃんの様子': ['変わりなし', '飲みが悪い', '元気がない・ぐったり'],
          '今すぐ相談したいこと': ['自分の体', '赤ちゃんの体', 'こころの状態'],
        };
      default:
        return firstIntakeQuestions;
    }
  }

  @override
  void dispose() {
    _freeText.dispose();
    super.dispose();
  }

  bool get _complete => _answers.length >= _questions.length && _signed;

  /// 緊急時問診の危険サイン判定
  bool get _hasRedFlag {
    if (widget.kind == IntakeKind.urgent) {
      return _answers['出血の量'] == 'ナプキンが1時間でいっぱい' ||
          _answers['体温'] == '38℃以上' ||
          _answers['頭痛'] == '強い（薬が効かない）' ||
          _answers['目の見えにくさ・ちらつき'] == '継続してある' ||
          _answers['みぞおち・右上腹部の痛み'] == '強い' ||
          _answers['呼吸のしにくさ・胸の痛み'] == 'ある' ||
          _answers['赤ちゃんの様子'] == '元気がない・ぐったり';
    }
    if (widget.kind == IntakeKind.breast) {
      return _answers['乳房の状態'] == '赤み・熱感がある' ||
          _answers['発熱'] == '38℃以上' ||
          _answers['痛みの強さ'] == '強い';
    }
    return _answers['こころの状態'] == 'ずっと不安' || _answers['こころの状態'] == '涙が出る';
  }

  @override
  Widget build(BuildContext context) {
    final entries = _questions.entries.toList();

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: Text(widget.kind.label),
        actions: const [HomeButton(), SizedBox(width: 8)],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _progressBar(entries.length),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                children: [
                  _intro(),
                  const SizedBox(height: 18),
                  for (var i = 0; i < entries.length; i++) ...[
                    _question(i + 1, entries[i].key, entries[i].value),
                    const SizedBox(height: 16),
                  ],
                  _freeTextCard(),
                  const SizedBox(height: 16),
                  _consentCard(),
                ],
              ),
            ),
            _submitBar(),
          ],
        ),
      ),
    );
  }

  Widget _progressBar(int total) {
    final p = total == 0 ? 0.0 : _answers.length / total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '${_answers.length} / $total 項目',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.blushPinkDeep,
                ),
              ),
              const Spacer(),
              Text(
                p >= 1 ? '入力完了' : 'あと${total - _answers.length}項目',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: p,
              minHeight: 6,
              backgroundColor: AppColors.line,
              valueColor: const AlwaysStoppedAnimation(AppColors.blushPinkDeep),
            ),
          ),
        ],
      ),
    );
  }

  Widget _intro() {
    final color = widget.kind == IntakeKind.urgent
        ? AppColors.cardCream
        : AppColors.cardPink;
    return SoftCard(
      color: color,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(widget.kind.icon, size: 21, color: AppColors.mauve),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.kind.desc,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.kind == IntakeKind.urgent
                      ? '当てはまるものを選んでください。危険なサインがある場合は、すぐに助産師へおつなぎします。'
                      : '事前にご記入いただくと、当日は説明を省いてケアの時間にあてられます。回答は担当助産師のみが閲覧します。',
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

  Widget _question(int no, String q, List<String> choices) {
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
                  color: _answers.containsKey(q)
                      ? AppColors.blushPinkDeep
                      : AppColors.cardPink,
                  shape: BoxShape.circle,
                ),
                child: _answers.containsKey(q)
                    ? const Icon(
                        Icons.check_rounded,
                        size: 13,
                        color: Colors.white,
                      )
                    : Text(
                        '$no',
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
                  q,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: choices.map((c) {
              final sel = _answers[q] == c;
              return GestureDetector(
                onTap: () => setState(() => _answers[q] = c),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.blushPinkDeep : AppColors.cream,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel ? AppColors.blushPinkDeep : AppColors.line,
                    ),
                  ),
                  child: Text(
                    c,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: sel ? Colors.white : AppColors.textBody,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _freeTextCard() {
    return SoftCard(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'その他、伝えておきたいこと（任意）',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(16),
            ),
            child: TextField(
              controller: _freeText,
              minLines: 3,
              maxLines: 6,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                hintText: '例：夜間の授乳がつらいので、日中に眠れる時間がほしいです。',
                hintStyle: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textMuted,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _consentCard() {
    return GestureDetector(
      onTap: () => setState(() => _signed = !_signed),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: _signed ? AppColors.cardSage : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: _signed ? const Color(0xFF6FB57E) : AppColors.line,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _signed ? Icons.verified_rounded : Icons.draw_outlined,
              size: 21,
              color: _signed ? const Color(0xFF6FB57E) : AppColors.textMuted,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _signed ? '電子同意済み（${widget.motherName}）' : '電子同意書に署名する',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    '記入内容を担当助産師・提携施設と共有すること、および産後ケアのために利用することに同意します。（電子署名法準拠）',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textBody,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _submitBar() {
    return Container(
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
            onPressed: _complete ? _submit : null,
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
              _signed ? '問診票を提出する' : '同意にチェックしてください',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    final care = context.read<CareState>();
    final answers = Map<String, String>.from(_answers);
    if (_freeText.text.trim().isNotEmpty) {
      answers['その他'] = _freeText.text.trim();
    }
    care.submitIntake(widget.kind, answers, signed: _signed);
    if (widget.bookingId != null) {
      care.markIntakeDone(widget.bookingId!);
    }
    if (_hasRedFlag) {
      care.addEscalation(
        reason: '${widget.kind.label}で注意サインを検知',
        detail: '問診票の回答に、早めの対応が望ましい項目が含まれています。助産師が内容を確認します。',
        severity: widget.kind == IntakeKind.urgent ? 'high' : 'mid',
      );
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: _hasRedFlag ? AppColors.cardCream : AppColors.cardSage,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _hasRedFlag ? Icons.support_agent_rounded : Icons.check_rounded,
                size: 32,
                color: _hasRedFlag ? AppColors.mauve : const Color(0xFF6FB57E),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _hasRedFlag ? '助産師におつなぎします' : '問診票を提出しました',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              _hasRedFlag
                  ? '早めの対応が望ましい内容が含まれていました。担当助産師が内容を確認し、公式LINEでご連絡します。\n\n強い症状があるときは、迷わず産科・救急へご相談ください。'
                  : '担当助産師が事前に内容を確認します。当日はケアの時間をたっぷり使えます。',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textBody,
                height: 1.6,
              ),
            ),
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                Navigator.pop(context);
              },
              child: const Text(
                'OK',
                style: TextStyle(
                  color: AppColors.blushPinkDeep,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
