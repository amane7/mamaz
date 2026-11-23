import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../ops/ops_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_nav.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../card_selector.dart';
import '../learning_models.dart';
import '../learning_state.dart';
import 'exercise_pane.dart';
import 'learning_widgets.dart';
import 'map_pane.dart';
import 'search_pane.dart';
import 'sources_pane.dart';

/// 助産の学習室（教育試作 0.2）。
///
/// 専門職（助産師・管理者）向けの、架空事例による演習の画面。
/// 予約・相談・カルテの画面とは状態を共有しない。入力は画面のメモリだけに置き、閉じると消える。
class LearningRoomScreen extends StatelessWidget {
  /// テスト用：教材を直接渡す。通常は同梱の教材を読み込む。
  final LearningKb? kb;
  const LearningRoomScreen({super.key, this.kb});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LearningState>(
      create: (_) {
        final state = LearningState(kb: kb);
        if (!state.ready) state.load();
        return state;
      },
      child: const _LearningRoomView(),
    );
  }
}

const String _leaveMessage = '書いた内容は保存されません。学習室を閉じると消えます。';

class _LearningRoomView extends StatelessWidget {
  const _LearningRoomView();

  Future<void> _confirmClose(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text(
          '学習室を閉じますか？',
          style: TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        content: const Text(
          _leaveMessage,
          style: TextStyle(
            fontSize: 13,
            height: 1.6,
            color: AppColors.textBody,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'このまま続ける',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kLearnTeal),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<OpsState>().role;
    final st = context.watch<LearningState>();

    // 専門職向け。ご家族の画面からは開けないが、権限が外れた場合もここで止める。
    if (role == OpsRole.family) {
      return const Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppTopBar(title: '助産の学習室'),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: WarmEmptyState(
              icon: Icons.school_outlined,
              title: '専門職向けの画面です',
              message: '助産の学習室は、助産師・運営スタッフが架空事例で学ぶための画面です。',
              color: AppColors.sageDeep,
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: !st.hasInput,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmClose(context);
      },
      child: Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppTopBar(
          title: '助産の学習室',
          subtitle: st.modeLabel,
          confirmLeave: st.hasInput ? _leaveMessage : null,
          actions: [
            IconButton(
              tooltip: '施設内モデルの任意接続',
              icon: Icon(
                st.modelConnected ? Icons.lan_rounded : Icons.lan_outlined,
                size: 21,
                color: st.modelConnected ? kLearnTeal : AppColors.textMuted,
              ),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                backgroundColor: AppColors.surface,
                showDragHandle: true,
                isScrollControlled: true,
                builder: (_) => _ConnectionSheet(state: st),
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: !st.ready
              ? _Loading(error: st.loadError)
              : Column(
                  children: [
                    const _TabRow(),
                    Expanded(
                      child: switch (st.tab) {
                        0 => const ExercisePane(),
                        1 => const SearchPane(),
                        2 => const MapPane(),
                        _ => const SourcesPane(),
                      },
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  final String? error;
  const _Loading({this.error});

  @override
  Widget build(BuildContext context) {
    if (error == null) {
      return const Center(child: CircularProgressIndicator(color: kLearnTeal));
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: WarmEmptyState(
          icon: Icons.error_outline_rounded,
          title: '教材を開けませんでした',
          message: '$error\n教材データの参照先を確認してください。',
          color: kLearnWarn,
        ),
      ),
    );
  }
}

class _TabRow extends StatelessWidget {
  const _TabRow();

  @override
  Widget build(BuildContext context) {
    final st = context.watch<LearningState>();
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
      child: Semantics(
        container: true,
        label: '学習メニュー',
        child: Row(
          children: [
            for (var i = 0; i < LearningState.tabs.length; i++)
              Expanded(
                child: _TabButton(
                  label: LearningState.tabs[i],
                  selected: st.tab == i,
                  enabled: st.canOpenTab(i),
                  onTap: () => st.openTab(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  const _TabButton({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Colors.white
        : enabled
        ? kLearnTeal
        : AppColors.textMuted.withValues(alpha: 0.55);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Semantics(
        button: true,
        selected: selected,
        enabled: enabled,
        child: InkWell(
          onTap: enabled && !selected ? onTap : null,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? kLearnTeal : Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: selected ? kLearnTeal : const Color(0xFFCBD8CF),
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 施設内モデルの任意接続。既定は無効で、通常の演習は端末内だけで動く。
class _ConnectionSheet extends StatefulWidget {
  final LearningState state;
  const _ConnectionSheet({required this.state});

  @override
  State<_ConnectionSheet> createState() => _ConnectionSheetState();
}

class _ConnectionSheetState extends State<_ConnectionSheet> {
  final _port = TextEditingController(text: '${LocalSelectionApi.defaultPort}');
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _port.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final port = int.tryParse(_port.text.trim());
    if (port == null || !LocalSelectionApi.validPort(port)) {
      setState(() => _message = 'ポート番号は 1〜65535 で入力してください。');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    final ok = await widget.state.connect(LocalSelectionApi(port: port));
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = ok ? null : '同じ端末の教材選択APIを確かめられませんでした。端末内の並べ替えのまま使えます。';
    });
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.state;
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            18,
            0,
            18,
            18 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const LearnHeading('施設内モデルの任意接続', size: 16),
              const SizedBox(height: 6),
              Text('いま：${st.modeLabel}', style: kLearnSmall),
              const SizedBox(height: 10),
              const Text(
                '通常の演習は、この端末の中だけで教材を並べます。接続は任意です。\n'
                '施設が同じ端末に配備した「教材選択API」がある場合にかぎり、候補の選定を任せられます。',
                style: kLearnBody,
              ),
              const SizedBox(height: 10),
              const LearnNote(
                '・送るのはケース番号と観点の番号だけです。初答・理由・検索語は送りません。\n'
                '・接続先は同じ端末（127.0.0.1）に限ります。\n'
                '・返ってきた候補IDは、そのケースで許可された教材と照合します。'
                '範囲外・重複・形式不正・接続失敗は、候補を保留します。\n'
                '・モデルが書いた文章は表示しません。表示するのは登録済みの教材だけです。\n'
                '・緊急連携ケースは提示順を固定し、モデルを呼び出しません。',
              ),
              const SizedBox(height: 10),
              const LearnWarn(
                '配布キットの serve_local.py は、キット自身の画面からの要求だけを受け付けます。'
                'このアプリから使うには、施設側でこのアプリを許可した教材選択APIの配備が必要です。',
              ),
              const SizedBox(height: 14),
              if (st.modelConnected)
                LearnSecondaryButton(
                  label: '接続を切る（端末内の並べ替えに戻す）',
                  onTap: st.disconnect,
                )
              else ...[
                const Text(
                  '教材選択APIのポート番号',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _port,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(5),
                  ],
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textDark,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixText: 'http://127.0.0.1:',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      borderSide: const BorderSide(color: Color(0xFFCBD8CF)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      borderSide: const BorderSide(
                        color: kLearnTeal,
                        width: 1.6,
                      ),
                    ),
                  ),
                ),
                Semantics(
                  liveRegion: true,
                  child: _message == null
                      ? const SizedBox(height: 12)
                      : Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            _message!,
                            style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.5,
                              fontWeight: FontWeight.w700,
                              color: kLearnWarn,
                            ),
                          ),
                        ),
                ),
                LearnPrimaryButton(
                  label: _busy ? '確かめています…' : '接続を確かめる',
                  onTap: _busy ? null : _connect,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 助産師・管理者の画面に置く、学習室への入口。
class LearningRoomEntryCard extends StatelessWidget {
  const LearningRoomEntryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '助産の学習室をひらく',
      child: SoftCard(
        color: kLearnPale,
        onTap: () =>
            Navigator.push(context, warmRoute(const LearningRoomScreen())),
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
                Icons.school_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '助産の学習室',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    '架空事例で「最初の問い」を練習する。教育試作 0.2・教材は監修前です。',
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
