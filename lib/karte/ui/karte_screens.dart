import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../learning/ui/learning_widgets.dart';
import '../../ops/ops_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_nav.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../karte_models.dart';
import '../karte_store.dart';
import 'karte_visit_screen.dart';

const String kKarteNotice =
    '紙の「すいな法乳房ケア 乳房ケアカルテ」を画面にしたものです。'
    '記録はすべて下書きの扱いで、確定・署名・印刷の機能はまだありません。'
    '保存先はこの端末（このブラウザ）の中だけで、暗号化・ほかの端末との共有・'
    'バックアップはありません。実在の方の情報を入れる前に、施設の運用ルールを確かめてください。';

InputDecoration _nameDeco(String label) => InputDecoration(
  isDense: true,
  counterText: '',
  labelText: label,
  labelStyle: const TextStyle(fontSize: 13, color: AppColors.textBody),
  filled: true,
  fillColor: Colors.white,
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.sm),
    borderSide: const BorderSide(color: Color(0xFFCBD8CF)),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.sm),
    borderSide: const BorderSide(color: Color(0xFFCBD8CF)),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.sm),
    borderSide: const BorderSide(color: kLearnTeal, width: 1.6),
  ),
);

Future<bool> _confirmDelete(
  BuildContext context,
  String title,
  String body,
) async {
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
          child: const Text('削除する', style: TextStyle(color: kLearnWarn)),
        ),
      ],
    ),
  );
  return ok == true;
}

// =============================================================================
// 一覧
// =============================================================================
class KarteListScreen extends StatefulWidget {
  /// 会話の下書きから持ち込むとき。カルテを選ぶと、記録の画面を開く。
  final KartePrefill? prefill;
  const KarteListScreen({super.key, this.prefill});

  @override
  State<KarteListScreen> createState() => _KarteListScreenState();
}

class _KarteListScreenState extends State<KarteListScreen> {
  final _mother = TextEditingController();
  final _child = TextEditingController();
  String? _message;

  bool get _picking => widget.prefill != null;

  @override
  void dispose() {
    _mother.dispose();
    _child.dispose();
    super.dispose();
  }

  Future<void> _open(Karte k) async {
    if (!_picking) {
      await Navigator.push(
        context,
        warmRoute<void>(KarteDetailScreen(karteId: k.id)),
      );
      return;
    }
    final saved = await Navigator.push<bool>(
      context,
      warmRoute<bool>(KarteVisitScreen(karteId: k.id, prefill: widget.prefill)),
    );
    if (saved == true && mounted) {
      Navigator.pushReplacement(
        context,
        warmRoute<void>(KarteDetailScreen(karteId: k.id)),
      );
    }
  }

  Future<void> _create() async {
    FocusScope.of(context).unfocus();
    final r = await context.read<KarteStore>().create(
      motherName: _mother.text,
      childName: _child.text,
    );
    if (!mounted) return;
    if (r.karte == null) {
      setState(() => _message = r.error);
      return;
    }
    setState(() => _message = null);
    _mother.clear();
    _child.clear();
    await _open(r.karte!);
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<OpsState>().role;
    if (role == OpsRole.family) {
      return const Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppTopBar(title: '乳房ケアカルテ'),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: WarmEmptyState(
              icon: Icons.assignment_outlined,
              title: '専門職向けの画面です',
              message: '乳房ケアカルテは、助産師・運営スタッフ向けの画面です。',
              color: AppColors.sageDeep,
            ),
          ),
        ),
      );
    }

    final store = context.watch<KarteStore>();
    final kartes = store.kartes;
    final sampleSource = widget.prefill?.source.startsWith('架空') ?? false;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppTopBar(
        title: '乳房ケアカルテ',
        subtitle: store.onDevice ? '下書き · この端末に保存' : '下書き · 保存先を開けず、閉じると消えます',
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          children: [
            if (_picking) ...[
              const LearnHeading('どのカルテの下書きに入れますか'),
              const SizedBox(height: 6),
              const Text(
                'カルテを選ぶと、会話の下書きを入れた記録の画面が開きます。'
                '「下書きとして保存」を押すまでは、カルテには入りません。',
                style: kLearnBody,
              ),
              if (sampleSource) ...[
                const SizedBox(height: 10),
                const LearnWarn('持ち込むのは架空の会話例です。実在の方のカルテには入れないでください。'),
              ],
            ] else ...[
              const LearnHeading('乳房ケアカルテ'),
              const SizedBox(height: 6),
              const LearnWarn(kKarteNotice),
            ],
            if (!store.onDevice) ...[
              const SizedBox(height: 10),
              const LearnWarn('端末の保存先を開けませんでした。いまはアプリを閉じると記録が消えます。'),
            ],
            if (store.unreadable > 0) ...[
              const SizedBox(height: 10),
              LearnWarn(
                '読み込めなかったカルテが${store.unreadable}件あります。'
                '内容は消さずに残してあります。',
              ),
            ],
            const SizedBox(height: 16),
            LearnHeading('カルテ　${kartes.length}件', size: 15.5),
            const SizedBox(height: 8),
            if (kartes.isEmpty) const LearnNote('まだカルテはありません。下で氏名を書いて作れます。'),
            for (final k in kartes) ...[
              _KarteTile(karte: k, onTap: () => _open(k)),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 8),
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const LearnHeading('新しいカルテを作る', size: 15),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey('karte_new_mother'),
                    controller: _mother,
                    maxLength: kKarteNameMax,
                    decoration: _nameDeco('氏名'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey('karte_new_child'),
                    controller: _child,
                    maxLength: kKarteNameMax,
                    decoration: _nameDeco('お子様名前'),
                  ),
                  const SizedBox(height: 10),
                  if (_message != null) ...[
                    LearnWarn(_message!),
                    const SizedBox(height: 10),
                  ],
                  LearnPrimaryButton(
                    label: _picking ? 'カルテを作って、下書きを入れる' : 'カルテを作る',
                    onTap: _create,
                  ),
                ],
              ),
            ),
            if (_picking)
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 16, 4, 8),
                child: Text(kKarteNotice, style: kLearnSmall),
              ),
          ],
        ),
      ),
    );
  }
}

class _KarteTile extends StatelessWidget {
  final Karte karte;
  final VoidCallback onTap;
  const _KarteTile({required this.karte, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final last = karte.visits.isEmpty ? null : karte.visits.last;
    return Semantics(
      button: true,
      label: '${karte.motherName} さんのカルテをひらく',
      child: SoftCard(
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    karte.motherName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'お子様名前：'
                    '${karte.childName.isEmpty ? '（未記入）' : karte.childName}',
                    style: kLearnSmall,
                  ),
                  Text(
                    last == null
                        ? '記録はまだありません'
                        : '記録 ${karte.visits.length}件 · 最新 ${last.dateLabel}',
                    style: kLearnSmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: kLearnTeal),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 1冊
// =============================================================================
class KarteDetailScreen extends StatelessWidget {
  final String karteId;
  const KarteDetailScreen({super.key, required this.karteId});

  Future<void> _rename(BuildContext context, Karte k) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _RenameDialog(karte: k),
    );
  }

  Future<void> _delete(BuildContext context, Karte k) async {
    final ok = await _confirmDelete(
      context,
      'このカルテを削除しますか？',
      '${k.motherName} さんのカルテと、記録${k.visits.length}件を削除します。元に戻せません。',
    );
    if (!ok || !context.mounted) return;
    final store = context.read<KarteStore>();
    final nav = Navigator.of(context);
    final err = await store.deleteKarte(k.id);
    if (err == null) {
      nav.pop();
    } else if (context.mounted) {
      showWarmToast(context, err, icon: Icons.error_outline, color: kLearnWarn);
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = context.watch<KarteStore>().byId(karteId);
    if (k == null) {
      return const Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppTopBar(title: '乳房ケアカルテ'),
        body: Center(child: Text('カルテが見つかりません。', style: kLearnBody)),
      );
    }
    final visits = k.visits.reversed.toList();

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: const AppTopBar(title: '乳房ケアカルテ', subtitle: '下書き'),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          children: [
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('すいな法乳房ケア　乳房ケアカルテ', style: kLearnSmall),
                  const SizedBox(height: 6),
                  LearnHeading('氏名：${k.motherName}', size: 17),
                  Text(
                    'お子様名前：${k.childName.isEmpty ? '（未記入）' : k.childName}',
                    style: kLearnBody,
                  ),
                  const SizedBox(height: 6),
                  LearnChipButton(
                    label: '名前をなおす',
                    onTap: () => _rename(context, k),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            LearnPrimaryButton(
              label: '記録を書く',
              onTap: () => Navigator.push(
                context,
                warmRoute<bool>(KarteVisitScreen(karteId: k.id)),
              ),
            ),
            const SizedBox(height: 18),
            LearnHeading('記録　${visits.length}件', size: 15.5),
            const SizedBox(height: 2),
            const Text('日付の新しい順です。押すと開いてなおせます。', style: kLearnSmall),
            const SizedBox(height: 8),
            if (visits.isEmpty) const LearnNote('まだ記録はありません。'),
            for (final v in visits) ...[
              _VisitTile(
                visit: v,
                onTap: () => Navigator.push(
                  context,
                  warmRoute<bool>(
                    KarteVisitScreen(karteId: k.id, visitId: v.id),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 14),
            LearnSecondaryButton(
              label: 'このカルテを削除',
              onTap: () => _delete(context, k),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 16, 4, 8),
              child: Text(kKarteNotice, style: kLearnSmall),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisitTile extends StatelessWidget {
  final KarteVisit visit;
  final VoidCallback onTap;
  const _VisitTile({required this.visit, required this.onTap});

  static String _head(String s) {
    final one = s.replaceAll('\n', ' ');
    return one.length <= 70 ? one : '${one.substring(0, 70)}…';
  }

  @override
  Widget build(BuildContext context) {
    final v = visit;
    final meta = [
      if (v.p(KP.place).isNotEmpty) v.p(KP.place).join('・'),
      if (v.t(KF.staff).isNotEmpty) '担当 ${v.t(KF.staff)}',
      if (v.t(KF.trainee).isNotEmpty) '研修生 ${v.t(KF.trainee)}',
    ];
    return SoftCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const LearnFlag('下書き'),
              Text(
                'No.${v.t(KF.no).isEmpty ? '（　）' : v.t(KF.no)}　${v.dateLabel}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(meta.join(' · '), style: kLearnSmall),
          ],
          if (v.t(KF.s).isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('S）${_head(v.t(KF.s))}', style: kLearnBody),
          ],
          if (v.t(KF.p).isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('P）${_head(v.t(KF.p))}', style: kLearnBody),
          ],
          if (v.source.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('会話の下書きから：${v.source}', style: kLearnSmall),
          ],
          if (v.openPoints.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'まだ確かめていない点 ${v.openPoints.length}件',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: kLearnWarn,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RenameDialog extends StatefulWidget {
  final Karte karte;
  const _RenameDialog({required this.karte});

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _mother = TextEditingController(text: widget.karte.motherName);
  late final _child = TextEditingController(text: widget.karte.childName);
  String? _message;

  @override
  void dispose() {
    _mother.dispose();
    _child.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nav = Navigator.of(context);
    final err = await context.read<KarteStore>().rename(
      widget.karte.id,
      motherName: _mother.text,
      childName: _child.text,
    );
    if (err == null) {
      nav.pop();
    } else if (mounted) {
      setState(() => _message = err);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text(
        '名前をなおす',
        style: TextStyle(
          fontSize: 16.5,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('karte_rename_mother'),
              controller: _mother,
              maxLength: kKarteNameMax,
              decoration: _nameDeco('氏名'),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('karte_rename_child'),
              controller: _child,
              maxLength: kKarteNameMax,
              decoration: _nameDeco('お子様名前'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 10),
              LearnWarn(_message!),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('もどる'),
        ),
        TextButton(
          onPressed: _save,
          child: const Text('保存', style: TextStyle(color: kLearnTeal)),
        ),
      ],
    );
  }
}

/// 助産師の画面に置く入口。
class KarteEntryCard extends StatelessWidget {
  const KarteEntryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '乳房ケアカルテをひらく',
      child: SoftCard(
        color: AppColors.cardCream,
        onTap: () =>
            Navigator.push(context, warmRoute<void>(const KarteListScreen())),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: kLearnTeal,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.assignment_outlined,
                color: Colors.white,
                size: 23,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '乳房ケアカルテ',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    '紙のカルテと同じ欄で記録します。すべて下書きの扱いで、この端末の中だけに保存します。',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.5,
                      color: AppColors.textBody,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: kLearnTeal),
          ],
        ),
      ),
    );
  }
}
