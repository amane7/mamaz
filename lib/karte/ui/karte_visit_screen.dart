import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../learning/ui/learning_widgets.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_nav.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../karte_models.dart';
import '../karte_store.dart';
import 'breast_diagram.dart';

/// 1回分の記録を書く画面（紙の1枠）。
///
/// 欄の名前と並びは紙の様式に合わせている。保存はすべて「下書き」。
class KarteVisitScreen extends StatefulWidget {
  final String karteId;

  /// 既にある記録を開くとき。
  final String? visitId;

  /// 会話の下書きから持ち込むとき。
  final KartePrefill? prefill;

  const KarteVisitScreen({
    super.key,
    required this.karteId,
    this.visitId,
    this.prefill,
  });

  @override
  State<KarteVisitScreen> createState() => _KarteVisitScreenState();
}

class _KarteVisitScreenState extends State<KarteVisitScreen> {
  final Map<String, TextEditingController> _c = {
    for (final k in KF.all) k: TextEditingController(),
  };
  final _year = TextEditingController();
  final _month = TextEditingController();
  final _day = TextEditingController();
  final Map<String, Set<String>> _picks = {
    for (final k in kKarteChoices.keys) k: <String>{},
  };
  List<BreastMark> _marks = const [];
  List<String> _openPoints = const [];
  String _source = '';
  late final String _visitId;
  bool _isNew = true;
  bool _dirty = false;
  bool _saving = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    final karte = context.read<KarteStore>().byId(widget.karteId);
    KarteVisit? existing;
    for (final v in karte?.visits ?? const <KarteVisit>[]) {
      if (v.id == widget.visitId) existing = v;
    }
    var date = DateTime.now();
    if (existing != null) {
      _isNew = false;
      _visitId = existing.id;
      date = existing.date;
      existing.text.forEach((k, v) => _c[k]?.text = v);
      existing.picks.forEach((k, v) => _picks[k]?.addAll(v));
      _marks = existing.marks;
      _openPoints = existing.openPoints;
      _source = existing.source;
    } else {
      _visitId = KarteStore.newId();
      _c[KF.no]!.text = karte?.nextNo ?? '1';
      final pre = widget.prefill;
      if (pre != null) {
        _c[KF.s]!.text = pre.s;
        _c[KF.p]!.text = pre.p;
        _openPoints = pre.openPoints;
        _source = pre.source;
        _dirty = true; // 持ち込んだ内容は、まだ保存されていない
      }
    }
    _year.text = '${date.year}';
    _month.text = '${date.month}';
    _day.text = '${date.day}';
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    _year.dispose();
    _month.dispose();
    _day.dispose();
    super.dispose();
  }

  void _touch() {
    if (!_dirty || _message != null) {
      setState(() {
        _dirty = true;
        _message = null;
      });
    }
  }

  DateTime? get _date {
    final y = int.tryParse(_year.text.trim());
    final m = int.tryParse(_month.text.trim());
    final d = int.tryParse(_day.text.trim());
    if (y == null || m == null || d == null) return null;
    if (y < 2000 || y > 2100) return null;
    final date = DateTime(y, m, d);
    // 2月30日のような、暦に無い日付を通さない。
    if (date.month != m || date.day != d) return null;
    return date;
  }

  void _toggle(String key, String option) {
    final set = _picks[key]!;
    setState(() {
      if (set.contains(option)) {
        set.remove(option);
      } else {
        if (!kKarteChoices[key]!.multi) set.clear();
        set.add(option);
      }
      _dirty = true;
      _message = null;
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final date = _date;
    if (date == null) {
      setState(() => _message = '日付を確かめてください（年・月・日を数字で）。');
      return;
    }
    setState(() => _saving = true);
    final visit = KarteVisit.build(
      id: _visitId,
      date: date,
      text: {for (final e in _c.entries) e.key: e.value.text},
      picks: _picks,
      marks: _marks,
      source: _source,
      openPoints: _openPoints,
    );
    final err = await context.read<KarteStore>().saveVisit(
      widget.karteId,
      visit,
    );
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _saving = false;
        _message = err;
      });
      return;
    }
    _dirty = false;
    showWarmToast(
      context,
      '下書きとして保存しました',
      icon: Icons.save_outlined,
      color: kLearnTeal,
    );
    Navigator.of(context).pop(true);
  }

  Future<bool> _confirm(String title, String body, String yes) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        content: Text(
          body,
          style: const TextStyle(
            fontSize: 13,
            height: 1.6,
            color: AppColors.textBody,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('もどる'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(yes, style: const TextStyle(color: kLearnWarn)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _leave() async {
    if (await _confirm('保存せずに閉じますか？', '書いた内容は、まだ保存されていません。', '保存せずに閉じる')) {
      if (!mounted) return;
      setState(() => _dirty = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(false);
      });
    }
  }

  Future<void> _delete() async {
    if (!await _confirm('この記録を削除しますか？', '削除すると元に戻せません。', '削除する')) return;
    if (!mounted) return;
    final err = await context.read<KarteStore>().deleteVisit(
      widget.karteId,
      _visitId,
    );
    if (!mounted) return;
    if (err != null) {
      setState(() => _message = err);
      return;
    }
    _dirty = false;
    Navigator.of(context).pop(true);
  }

  // ---------------------------------------------------------------- 部品

  static const _label = TextStyle(
    fontSize: 13,
    height: 1.4,
    color: AppColors.textDark,
  );

  InputDecoration _deco({String? hint}) => InputDecoration(
    isDense: true,
    counterText: '',
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFCBD8CF)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFCBD8CF)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: kLearnTeal, width: 1.6),
    ),
  );

  Widget _t(String s) => Text(s, style: _label);

  /// 短い欄。
  Widget _f(String key, {double w = 56, bool number = true}) => SizedBox(
    width: w,
    child: TextField(
      key: ValueKey('kf_$key'),
      controller: _c[key],
      onChanged: (_) => _touch(),
      maxLength: kKarteShortMax,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      style: const TextStyle(fontSize: 14, color: AppColors.textDark),
      decoration: _deco(),
    ),
  );

  Widget _dateField(TextEditingController c, String key, double w) => SizedBox(
    width: w,
    child: TextField(
      key: ValueKey(key),
      controller: c,
      onChanged: (_) => setState(() {
        _dirty = true;
        _message = null;
      }),
      maxLength: 4,
      keyboardType: TextInputType.number,
      style: const TextStyle(fontSize: 14, color: AppColors.textDark),
      decoration: _deco(),
    ),
  );

  /// 長い欄。
  Widget _long(String key, {int minLines = 3, String? hint}) => TextField(
    key: ValueKey('kf_$key'),
    controller: _c[key],
    onChanged: (_) => _touch(),
    minLines: minLines,
    maxLines: 14,
    maxLength: kKarteLongMax,
    keyboardType: TextInputType.multiline,
    style: const TextStyle(
      fontSize: 14,
      height: 1.6,
      color: AppColors.textDark,
    ),
    decoration: _deco(hint: hint),
  );

  Widget _row(List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    ),
  );

  Widget _choice(String key, {Map<String, String> labels = const {}}) => Wrap(
    spacing: 6,
    runSpacing: 0,
    children: [
      for (final o in kKarteChoices[key]!.options)
        FilterChip(
          key: ValueKey('kp_${key}_$o'),
          label: Text(labels[o] ?? o),
          selected: _picks[key]!.contains(o),
          onSelected: (_) => _toggle(key, o),
          showCheckmark: true,
          checkmarkColor: kLearnTeal,
          backgroundColor: Colors.white,
          selectedColor: kLearnPale,
          side: const BorderSide(color: Color(0xFFCBD8CF)),
          labelStyle: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
          visualDensity: VisualDensity.compact,
        ),
    ],
  );

  Widget _block(String title, List<Widget> children, {String? note}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LearnHeading(title, size: 15),
          if (note != null) ...[
            const SizedBox(height: 2),
            Text(note, style: kLearnSmall),
          ],
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    ),
  );

  Widget _sub(String s) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 4),
    child: Text(
      s,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textDark,
      ),
    ),
  );

  // ---------------------------------------------------------------- 画面

  @override
  Widget build(BuildContext context) {
    final karte = context.watch<KarteStore>().byId(widget.karteId);
    if (karte == null) {
      return const Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppTopBar(title: '乳房ケアカルテ'),
        body: Center(child: Text('カルテが見つかりません。', style: kLearnBody)),
      );
    }
    final date = _date;
    final feeChosen = _picks[KP.fees]!;
    final total = [
      for (final f in kKarteFees)
        if (feeChosen.contains(f.id)) f.yen,
    ].fold(0, (a, b) => a + b);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppTopBar(
          title: _isNew ? '記録を書く' : '記録をなおす',
          subtitle: '乳房ケアカルテ · 下書き',
          confirmLeave: _dirty ? '書いた内容は、まだ保存されていません。' : null,
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const LearnFlag('下書き'),
                  Text(
                    '氏名：${karte.motherName}　お子様名前：'
                    '${karte.childName.isEmpty ? '（未記入）' : karte.childName}',
                    style: kLearnBody,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_source.isNotEmpty || _openPoints.isNotEmpty) ...[
                _FromConversation(
                  source: _source,
                  openPoints: _openPoints,
                  onRemove: (i) => setState(() {
                    _openPoints = [
                      for (var j = 0; j < _openPoints.length; j++)
                        if (j != i) _openPoints[j],
                    ];
                    _dirty = true;
                  }),
                ),
                const SizedBox(height: 12),
              ],
              _block('No.・日付・場所', [
                _row([_t('No.（'), _f(KF.no, w: 52), _t('）')]),
                _row([
                  _dateField(_year, 'kd_year', 66),
                  _t('年'),
                  _dateField(_month, 'kd_month', 46),
                  _t('月'),
                  _dateField(_day, 'kd_day', 46),
                  _t('日（${date == null ? '　' : weekdayLabel(date)}）'),
                ]),
                _choice(KP.place),
                const SizedBox(height: 8),
                _row([_t('担当者名：'), _f(KF.staff, w: 170, number: false)]),
                _row([_t('研修生名：'), _f(KF.trainee, w: 170, number: false)]),
              ]),
              _block('お子さん', [
                _row([
                  _f(KF.ageYears, w: 46),
                  _t('歳'),
                  _f(KF.ageMonths, w: 46),
                  _t('ヶ月'),
                  _f(KF.ageDays, w: 52),
                  _t('日目'),
                ]),
                _row([_t('体重'), _f(KF.weightG, w: 84), _t('g')]),
                _row([_t('増加量'), _f(KF.gainPerDay, w: 70), _t('g/日')]),
                _choice(KP.weaning),
                _row([_f(KF.weaningDay, w: 60), _t('日目')]),
              ]),
              _block('授乳・食事・排泄', [
                _row([
                  _t('母乳'),
                  _f(KF.breastPerDay),
                  _t('回/日（日中'),
                  _f(KF.breastDay),
                  _t('回、夜中'),
                  _f(KF.breastNight),
                  _t('回）'),
                ]),
                _row([
                  _t('間隔'),
                  _f(KF.intervalFrom),
                  _t('時間～'),
                  _f(KF.intervalTo),
                  _t('時間'),
                ]),
                _row([
                  _t('ミルク'),
                  _f(KF.formulaPerDay),
                  _t('回/日（'),
                  _f(KF.formulaFrom),
                  _t('ml～'),
                  _f(KF.formulaTo),
                  _t('ml/回）'),
                ]),
                _row([
                  _t('搾母乳'),
                  _f(KF.expressedPerDay),
                  _t('回/日（'),
                  _f(KF.expressedFrom),
                  _t('ml～'),
                  _f(KF.expressedTo),
                  _t('ml/回）'),
                ]),
                _row([_t('離乳食'), _f(KF.solidsPerDay), _t('回/日')]),
                _long(KF.solidsNote, minLines: 1, hint: '硬さ，形状，補食など'),
                const SizedBox(height: 10),
                _row([_t('便回数'), _f(KF.stoolPerDay), _t('回/日（性状）')]),
                _choice(KP.stool),
                const SizedBox(height: 4),
                _row([_t('尿回数'), _f(KF.urinePerDay), _t('回/日')]),
                _sub('【児の発達】'),
                _long(KF.development, minLines: 2),
              ]),
              _block('S）', [_long(KF.s, minLines: 4)]),
              _block('O）', [
                BreastDiagram(
                  marks: _marks,
                  onChanged: (m) => setState(() {
                    _marks = m;
                    _dirty = true;
                  }),
                ),
                if (_marks.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  for (final m in _marks) Text(m.where, style: kLearnSmall),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: LearnChipButton(
                      label: '印をすべて消す',
                      onTap: () => setState(() {
                        _marks = const [];
                        _dirty = true;
                      }),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                _long(KF.oNote, minLines: 2, hint: '図に書き添えること'),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sub('乳房の形'),
                          _choice(KP.breastShape),
                          _choice(KP.nippleShield),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Image.asset(
                      'assets/karte/breast_shapes.jpg',
                      height: 190,
                      semanticLabel: '紙の様式にある乳房の形の図',
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ],
                ),
                const Text(
                  '図は紙の様式のものです。様式の図は5つ、選択肢は4つで、'
                  'どの図がどの型かは様式に書かれていないため、対応は付けていません。',
                  style: kLearnSmall,
                ),
                const SizedBox(height: 10),
                _row([_t('搾乳 1日'), _f(KF.pumpPerDay), _t('回　搾乳器')]),
                _choice(KP.pumpType),
                _sub('乳頭・乳輪の状態'),
                _choice(KP.nippleState),
                _row([
                  _t('ほか（'),
                  _f(KF.nippleOther, w: 180, number: false),
                  _t('）'),
                ]),
                _sub('疼痛'),
                _choice(KP.pain),
                _row([
                  _t('ほか（'),
                  _f(KF.painOther, w: 180, number: false),
                  _t('）'),
                ]),
                _sub('授乳姿勢'),
                _long(KF.posture, minLines: 1),
                _sub('【家族などのサポート状況】'),
                _long(KF.support, minLines: 2),
              ], note: '円を押すと印を置き、印を押すと消えます。紙と同じく、向かって左の円が「右」です。'),
              _block('P）', [_long(KF.p, minLines: 4)]),
              _block('【乳房診断】', [_long(KF.diagnosis, minLines: 2, hint: '＃１')]),
              _block('お会計', [
                _choice(KP.payMethod),
                const SizedBox(height: 6),
                _choice(
                  KP.fees,
                  labels: {
                    for (final f in kKarteFees)
                      f.id: '${f.label} ${formatYen(f.yen)}円',
                    kFeeOtherId: 'その他',
                  },
                ),
                _row([
                  _t('その他（'),
                  _f(KF.feeOther, w: 190, number: false),
                  _t('）'),
                ]),
                Text(
                  '印を付けた項目の合計　${formatYen(total)}円（「その他」は含みません）',
                  style: kLearnBody,
                ),
                const Text(
                  '紙の様式の「1回5.500円」は、5,500円として扱っています。',
                  style: kLearnSmall,
                ),
              ]),
              if (_message != null) ...[
                LearnWarn(_message!),
                const SizedBox(height: 10),
              ],
              LearnPrimaryButton(
                label: '下書きとして保存',
                onTap: _saving ? null : _save,
              ),
              if (!_isNew) ...[
                const SizedBox(height: 8),
                LearnSecondaryButton(label: 'この記録を削除', onTap: _delete),
              ],
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 16, 4, 8),
                child: Text(
                  '保存した記録はすべて下書きの扱いです。確定・署名・印刷の機能は、まだありません。',
                  style: kLearnSmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 会話の下書きから持ち込んだ記録に付く札。
class _FromConversation extends StatelessWidget {
  final String source;
  final List<String> openPoints;
  final ValueChanged<int> onRemove;
  const _FromConversation({
    required this.source,
    required this.openPoints,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: AppColors.cardCream,
      border: Border.all(color: kLearnWarn.withValues(alpha: 0.35)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LearnHeading('会話の下書きから持ち込んだ記録です', size: 14),
          const SizedBox(height: 4),
          Text(
            '${source.isEmpty ? '' : '出どころ：$source。'}'
            'S）には発言をそのまま、P）には「次回確かめること」を入れてあります。'
            '回数や体重などの欄は、会話から読み取って埋めることをしていません。',
            style: kLearnSmall,
          ),
          if (openPoints.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'まだ確かめていない点',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: kLearnWarn,
              ),
            ),
            for (var i = 0; i < openPoints.length; i++)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(openPoints[i], style: kLearnBody),
                    ),
                  ),
                  TextButton(
                    onPressed: () => onRemove(i),
                    child: const Text(
                      '確かめた',
                      style: TextStyle(fontSize: 12.5, color: kLearnTeal),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}
