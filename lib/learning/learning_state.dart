/// 助産の学習室 — 演習の状態。
///
/// 入力（初答・理由・次の一言・別課題の回答・検索語）は **この画面のメモリだけ** に置く。
/// 端末にも保存せず、どこにも送らない。学習室を閉じると消える。
/// 実際の母子の相談・予約・カルテ（OpsState / CareState）とは互いに参照しない。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'card_selector.dart';
import 'learning_models.dart';
import 'learning_search.dart';

/// 参考例の扱い。初期値は保留。
enum CardChoice { hold, adopt, skip }

extension CardChoiceX on CardChoice {
  /// 振り返りに残す短い呼び名。
  String get label => switch (this) {
    CardChoice.hold => '保留',
    CardChoice.adopt => '採用',
    CardChoice.skip => '見送り',
  };

  /// 選ぶときの言い方。
  String get optionLabel => switch (this) {
    CardChoice.hold => '保留',
    CardChoice.adopt => '自分の問いに取り入れる',
    CardChoice.skip => '今回は見送る',
  };
}

/// 演習の4段階。
abstract final class ExerciseStep {
  static const int firstAnswer = 0;
  static const int compare = 1;
  static const int transfer = 2;
  static const int review = 3;
  static const List<String> names = ['最初の問い', '参考例と比較', '別の事例', '振り返り'];
}

/// 1ケース分の演習の記録（メモリのみ）。
class ExerciseSession {
  int step = ExerciseStep.firstAnswer;
  String first = '';
  String why = '';
  int focusIndex = 0;
  List<String> rank = const [];
  final Map<String, CardChoice> chosen = {};
  String rewrite = '';
  String transfer = '';

  /// 候補をどう並べたか（画面に表示する）。
  String method = '';

  /// 別課題を一度中断したか。中断後は「再練習」として扱う。
  bool revisited = false;

  /// 教材を照合している最中か。
  bool matching = false;

  CardChoice choiceFor(String cardId) => chosen[cardId] ?? CardChoice.hold;

  bool get hasInput =>
      first.trim().isNotEmpty ||
      why.trim().isNotEmpty ||
      rewrite.trim().isNotEmpty ||
      transfer.trim().isNotEmpty;
}

class LearningState extends ChangeNotifier {
  static const List<String> tabs = ['ケース演習', '知識を探す', '能力マップ', '文献台帳'];
  static const int exerciseTab = 0;
  static const int searchTab = 1;

  static const String methodEmergency = '緊急連携の固定演習 · 監修前の作例';
  static const String methodOnDevice = '端末内検索で初答と観点に近い順 · 監修前の作例';
  static const String methodModelHeld = '施設内モデルは候補を保留';
  static const String methodUnverified = '接続・検証が成立せず、候補を保留';
  static String methodModel(String model) => '施設内モデルによる選択 · $model';

  LearningKb? _kb;
  LearningIndex? _index;
  String? loadError;

  int tab = exerciseTab;
  String caseId = kStartCaseId;
  String searchQuery = '';
  String sourceQuery = '';

  final Map<String, ExerciseSession> _sessions = {};
  CardSelector? _selector;
  bool _disposed = false;
  bool _hadInput = false;

  LearningState({LearningKb? kb, CardSelector? selector})
    : _selector = selector {
    if (kb != null) _adopt(kb);
  }

  void _adopt(LearningKb kb) {
    _kb = kb;
    _index = LearningIndex(kb);
  }

  bool get ready => _kb != null;
  LearningKb get kb => _kb!;
  LearningIndex get index => _index!;

  /// 同梱の教材を読み込み、参照を検査する。
  Future<void> load() async {
    if (ready) return;
    try {
      _adopt(LearningKb.parse(await rootBundle.loadString(kLearningKbAsset)));
      loadError = null;
    } on LearningDataError catch (e) {
      loadError = e.message;
    } catch (_) {
      loadError = '教材を読み込めませんでした';
    }
    _notify();
  }

  // ---------------------------------------------------------------- 演習

  LearningCase get currentCase => kb.cases[caseId]!;

  ExerciseSession sessionOf(String id) =>
      _sessions.putIfAbsent(id, ExerciseSession.new);

  ExerciseSession get session => sessionOf(caseId);

  /// 別課題に取り組んでいる間は、他のケース・他のタブを開けない。
  bool get locked =>
      tab == exerciseTab && session.step == ExerciseStep.transfer;

  /// 書きかけの入力があるか（閉じる前の確認に使う）。
  bool get hasInput => _sessions.values.any((s) => s.hasInput);

  bool canOpenTab(int i) => i == tab || !locked;

  bool canOpenCase(String id) => id == caseId || !locked;

  void openTab(int i) {
    if (i < 0 || i >= tabs.length || i == tab || !canOpenTab(i)) return;
    tab = i;
    _notify();
  }

  void openCase(String id) {
    if (!kb.cases.containsKey(id) || id == caseId || !canOpenCase(id)) return;
    caseId = id;
    _notify();
  }

  void setFocus(int i) {
    final s = session;
    if (s.step != ExerciseStep.firstAnswer || s.matching) return;
    if (i < 0 || i >= currentCase.focus.length || i == s.focusIndex) return;
    s.focusIndex = i;
    _notify();
  }

  /// 「自分の問いを残して、参考例を見る」。入力が足りなければ理由を返す。
  Future<String?> submitFirst() async {
    final c = currentCase;
    final s = sessionOf(c.id);
    if (s.step != ExerciseStep.firstAnswer || s.matching) return null;
    if (s.first.trim().isEmpty || s.why.trim().isEmpty) {
      return '問いと理由をそれぞれ入力してください。';
    }
    s.matching = true;
    _notify();

    var ids = c.cards;
    var method = methodEmergency;
    if (!c.isEmergency) {
      final selector = _selector;
      if (selector == null) {
        ids = index.personalOrder(
          c,
          focusIndex: s.focusIndex,
          first: s.first,
          why: s.why,
        );
        method = methodOnDevice;
      } else {
        // 送るのはケース番号と観点の番号だけ。初答・理由は渡さない。
        var r = const SelectionResult.held();
        try {
          r = await selector.select(
            caseId: c.id,
            focusIndex: s.focusIndex,
            allowed: List<String>.unmodifiable(c.cards),
          );
        } catch (_) {}
        // 接続口の実装に関わらず、ここでも候補の範囲と重複を確かめる。
        final ok =
            r.verified &&
            r.model.isNotEmpty &&
            r.ids.length <= c.cards.length &&
            r.ids.toSet().length == r.ids.length &&
            r.ids.every(c.cards.contains);
        if (!ok) {
          ids = const [];
          method = methodUnverified;
        } else {
          ids = r.ids;
          method = ids.isEmpty ? methodModelHeld : methodModel(r.model);
        }
      }
    }

    s.matching = false;
    if (identical(_sessions[c.id], s)) {
      s.rank = List<String>.unmodifiable(ids);
      s.method = method;
      s.step = ExerciseStep.compare;
    }
    _notify();
    return null;
  }

  void choose(String cardId, CardChoice choice) {
    final s = session;
    if (s.step != ExerciseStep.compare || !s.rank.contains(cardId)) return;
    s.chosen[cardId] = choice;
    _notify();
  }

  /// 「参考例を閉じて、別の事例へ」。全候補が保留のままでも進める。
  String? submitRewrite() {
    final s = session;
    if (s.step != ExerciseStep.compare) return null;
    if (s.rewrite.trim().isEmpty) return '次の一言と理由を入力してください。';
    s.step = ExerciseStep.transfer;
    _notify();
    return null;
  }

  /// 「回答を確定して振り返る」。
  String? submitTransfer() {
    final s = session;
    if (s.step != ExerciseStep.transfer) return null;
    if (s.transfer.trim().isEmpty) return 'この事例での回答を入力してください。';
    s.step = ExerciseStep.review;
    _notify();
    return null;
  }

  /// 「中断して比較に戻る」。以後は再練習として扱う。
  void suspendTransfer() {
    final s = session;
    if (s.step != ExerciseStep.transfer) return;
    s.revisited = true;
    s.transfer = '';
    s.step = ExerciseStep.compare;
    _notify();
  }

  /// 「このケースを最初から」。
  void restartCase() {
    _sessions.remove(caseId);
    _notify();
  }

  /// 振り返りに残す「候補の扱い」。
  String handlingSummary() {
    final s = session;
    if (s.rank.isEmpty) return '全保留';
    return s.rank
        .map((id) => '${kb.cards[id]!.title}（${s.choiceFor(id).label}）')
        .join('、');
  }

  // ---------------------------------------------------------------- 検索

  void search(String query) {
    searchQuery = query.trim();
    _notify();
  }

  /// 能力マップから教材を開く（知識検索にIDを入れて表示）。
  void openCardInSearch(String cardId) {
    if (locked) return;
    searchQuery = cardId;
    tab = searchTab;
    _notify();
  }

  void filterSources(String query) {
    sourceQuery = query.trim();
    _notify();
  }

  // ---------------------------------------------------------------- 任意接続

  bool get modelConnected => _selector != null;

  String get modeLabel =>
      modelConnected ? '教育用試作 · 端末内のモデル選択を使用' : '教育用試作 · 端末内で動作';

  /// 同じ端末の教材選択APIが施設内モデルを使う設定のときだけ、接続を有効にする。
  Future<bool> connect(LocalSelectionApi api) async {
    final ok = await api.usesLocalModel();
    if (_disposed || !ok) {
      api.close();
      return false;
    }
    _closeSelector();
    _selector = api;
    _notify();
    return true;
  }

  void disconnect() {
    if (_selector == null) return;
    _closeSelector();
    _notify();
  }

  void _closeSelector() {
    final s = _selector;
    if (s is LocalSelectionApi) s.close();
    _selector = null;
  }

  /// 入力欄の編集を知らせる。書きかけの有無が変わったときだけ画面を更新する。
  void noteEdited() {
    if (hasInput != _hadInput) _notify();
  }

  void _notify() {
    _hadInput = hasInput;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _closeSelector();
    _sessions.clear();
    super.dispose();
  }
}
