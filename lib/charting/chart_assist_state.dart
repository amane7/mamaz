/// 会話からカルテの下書き（試作）— 画面の状態。
///
/// 会話・下書き・回答は画面のメモリだけに置く。保存も送信もしない。
/// 予約やカルテの記録（OpsState / CareState）には書き込まない。
library;

import 'package:flutter/foundation.dart';

import 'chart_assist.dart';
import 'conversation.dart';

/// 問いの扱い。
enum Resolution { confirmed, askNext, notNeeded }

extension ResolutionX on Resolution {
  String get label => switch (this) {
    Resolution.confirmed => '確認済みとして下書きに入れた',
    Resolution.askNext => '次回、ご本人に確かめる',
    Resolution.notNeeded => '今回は確かめない',
  };
}

class ChartAssistState extends ChangeNotifier {
  Conversation? conversation;
  AssistResult? result;

  final Map<GapKind, Resolution> _resolutions = {};
  final Map<GapKind, String> _answers = {};

  bool get isOpen => conversation != null;

  /// 会話を読み込む。読めないときは理由を返す。
  String? open(Conversation c) {
    if (c.lines.isEmpty) return '会話を1行以上書いてください。';
    conversation = c;
    result = analyzeConversation(c);
    _resolutions.clear();
    _answers.clear();
    notifyListeners();
    return null;
  }

  void close() {
    conversation = null;
    result = null;
    _resolutions.clear();
    _answers.clear();
    notifyListeners();
  }

  List<ClarifyingQuestion> get questions => result?.questions ?? const [];

  Resolution? resolutionOf(GapKind k) => _resolutions[k];
  String answerOf(GapKind k) => _answers[k] ?? '';

  /// 問いの扱いを決める。確認済みにするには、確かめた内容が要る。
  String? resolve(GapKind kind, Resolution r, {String answer = ''}) {
    if (!questions.any((q) => q.kind == kind)) return null;
    final body = answer.trim();
    if (r == Resolution.confirmed && body.isEmpty) {
      return '確認できている内容を書いてください。分からなければ「次回、ご本人に確かめる」を選べます。';
    }
    _resolutions[kind] = r;
    if (r == Resolution.confirmed) {
      _answers[kind] = body;
    } else {
      _answers.remove(kind);
    }
    notifyListeners();
    return null;
  }

  void reopen(GapKind kind) {
    if (_resolutions.remove(kind) == null) return;
    _answers.remove(kind);
    notifyListeners();
  }

  List<ClarifyingQuestion> _with(Resolution? r) => [
    for (final q in questions)
      if (_resolutions[q.kind] == r) q,
  ];

  /// 助産師が確かめた内容つきで下書きに入れた問い。
  List<ClarifyingQuestion> get confirmed => _with(Resolution.confirmed);

  /// 次回、ご本人に確かめる問い。
  List<ClarifyingQuestion> get nextChecks => _with(Resolution.askNext);

  /// まだ扱いを決めていない問い（下書きでは「未確認」として残る）。
  List<ClarifyingQuestion> get unresolved => _with(null);

  List<DraftEntry> entriesIn(ChartSection s) => [
    for (final e in result?.draft ?? const <DraftEntry>[])
      if (e.section == s) e,
  ];
}
