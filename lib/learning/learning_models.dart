/// 助産の学習室（教育試作 0.2）— 教材データのモデルと検証。
///
/// 編集原本は `assets/learning/kb.json`（配布キットの `data/教材データ.json` と同一）。
/// ここでは読み込みと、キット同梱 `教材を反映.py` の `validate()` と同じ参照検査を行う。
/// Flutter に依存しない（検索・検証を画面から切り離してテストするため）。
library;

import 'dart:convert';

/// アセットの場所。
const String kLearningKbAsset = 'assets/learning/kb.json';

/// 最初に開くケース。
const String kStartCaseId = 'C01';

/// 緊急連携ケース。提示順を固定し、モデルを呼び出さない。
const String kEmergencyCaseId = 'C08';

class LearningDataError implements Exception {
  final String message;
  const LearningDataError(this.message);

  @override
  String toString() => message;
}

/// 出典（B＝原稿の参照URL / K＝研究課題 / A＝追加資料 / M＝MAMOA既存設計）。
class LearningSource {
  final String id;
  final String title;
  final String kind;
  final String finding;
  final String use;
  final String url;

  LearningSource({
    required this.id,
    required this.title,
    required this.kind,
    required this.finding,
    required this.use,
    required this.url,
  });

  /// 文献台帳の絞り込み対象（ID・題名・種類・知見・用途・URL）。
  late final String haystack = '$id $title $kind $finding $use $url'
      .toLowerCase();
}

/// ICM 2024 の能力項目に付けた、MAMOA 独自の索引。
class Competency {
  final String code;
  final String page;
  final String group;
  final String dom;
  final String theme;
  final String task;
  final List<String> refs;

  const Competency({
    required this.code,
    required this.page,
    required this.group,
    required this.dom,
    required this.theme,
    required this.task,
    required this.refs,
  });
}

/// 国内実務の学習領域と基礎ノート。
class FoundationNote {
  final String label;
  final String topics;
  final List<String> codes;
  final String task;
  final List<String> refs;
  final String concept;
  final String selfQuestion;
  final String selfAnswer;

  const FoundationNote({
    required this.label,
    required this.topics,
    required this.codes,
    required this.task,
    required this.refs,
    required this.concept,
    required this.selfQuestion,
    required this.selfAnswer,
  });
}

/// 教材作例（カード）。
class LearningCard {
  final String id;
  final String title;
  final String tags;
  final List<String> codes;
  final String question;
  final String why;
  final String example;
  final String stop;
  final List<String> refs;
  final String status;

  const LearningCard({
    required this.id,
    required this.title,
    required this.tags,
    required this.codes,
    required this.question,
    required this.why,
    required this.example,
    required this.stop,
    required this.refs,
    required this.status,
  });
}

/// 架空ケースと、その別課題。
class LearningCase {
  final String id;
  final String title;
  final String phase;
  final String scene;
  final List<String> focus;
  final List<String> cards;
  final String transfer;
  final String rubric;
  final List<String> focusReference;

  const LearningCase({
    required this.id,
    required this.title,
    required this.phase,
    required this.scene,
    required this.focus,
    required this.cards,
    required this.transfer,
    required this.rubric,
    required this.focusReference,
  });

  bool get isEmergency => id == kEmergencyCaseId;
}

class LearningKb {
  final String version;
  final Map<String, LearningSource> sources;
  final List<Competency> competencies;
  final List<FoundationNote> notes;
  final Map<String, LearningCard> cards;
  final Map<String, LearningCase> cases;

  LearningKb({
    required this.version,
    required this.sources,
    required this.competencies,
    required this.notes,
    required this.cards,
    required this.cases,
  });

  /// JSON 文字列から読み込み、参照を検査する。不正なら [LearningDataError]。
  factory LearningKb.parse(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const LearningDataError('教材データを JSON として読めません');
    }
    return LearningKb.fromJson(_obj(decoded, '教材データ'));
  }

  factory LearningKb.fromJson(Map<String, dynamic> db) {
    final sources = <String, LearningSource>{};
    _obj(db['sources'], 'sources').forEach((id, v) {
      final m = _obj(v, '出典 $id');
      sources[id] = LearningSource(
        id: id,
        title: _str(m, 'title', '出典 $id'),
        kind: _str(m, 'kind', '出典 $id'),
        finding: _str(m, 'finding', '出典 $id'),
        use: _str(m, 'use', '出典 $id'),
        url: _str(m, 'url', '出典 $id'),
      );
    });

    final competencies = [
      for (final v in _list(db['competencies'], 'competencies'))
        () {
          final m = _obj(v, 'competencies');
          return Competency(
            code: _str(m, 'code', 'competencies'),
            page: _str(m, 'page', 'competencies'),
            group: _str(m, 'group', 'competencies'),
            dom: _str(m, 'dom', 'competencies'),
            theme: _str(m, 'theme', 'competencies'),
            task: _str(m, 'task', 'competencies'),
            refs: _strs(m, 'refs', 'competencies'),
          );
        }(),
    ];

    final notes = [
      for (final v in _list(db['extended'], 'extended'))
        () {
          final m = _obj(v, 'extended');
          return FoundationNote(
            label: _str(m, 'label', 'extended'),
            topics: _str(m, 'topics', 'extended'),
            codes: _strs(m, 'codes', 'extended'),
            task: _str(m, 'task', 'extended'),
            refs: _strs(m, 'refs', 'extended'),
            concept: _str(m, 'concept', 'extended'),
            selfQuestion: _str(m, 'selfQuestion', 'extended'),
            selfAnswer: _str(m, 'selfAnswer', 'extended'),
          );
        }(),
    ];

    final cards = <String, LearningCard>{};
    _obj(db['cards'], 'cards').forEach((key, v) {
      final m = _obj(v, '教材 $key');
      cards[key] = LearningCard(
        id: _str(m, 'id', '教材 $key'),
        title: _str(m, 'title', '教材 $key'),
        tags: _str(m, 'tags', '教材 $key'),
        codes: _strs(m, 'codes', '教材 $key'),
        question: _str(m, 'question', '教材 $key'),
        why: _str(m, 'why', '教材 $key'),
        example: _str(m, 'example', '教材 $key'),
        stop: _str(m, 'stop', '教材 $key'),
        refs: _strs(m, 'refs', '教材 $key'),
        status: _str(m, 'status', '教材 $key'),
      );
    });

    final cases = <String, LearningCase>{};
    _obj(db['cases'], 'cases').forEach((key, v) {
      final m = _obj(v, 'ケース $key');
      cases[key] = LearningCase(
        id: _str(m, 'id', 'ケース $key'),
        title: _str(m, 'title', 'ケース $key'),
        phase: _str(m, 'phase', 'ケース $key'),
        scene: _str(m, 'scene', 'ケース $key'),
        focus: _strs(m, 'focus', 'ケース $key'),
        cards: _strs(m, 'cards', 'ケース $key'),
        transfer: _str(m, 'transfer', 'ケース $key'),
        rubric: _str(m, 'rubric', 'ケース $key'),
        focusReference: _strs(m, 'focusReference', 'ケース $key'),
      );
    });

    final kb = LearningKb(
      version: _str(db, 'version', '教材データ'),
      sources: sources,
      competencies: competencies,
      notes: notes,
      cards: cards,
      cases: cases,
    );
    kb.validate();
    return kb;
  }

  /// キット同梱 `教材を反映.py` の `validate()` と同じ検査。
  /// 加えて、演習が前提にする「観点が1つ以上ある」ことだけ確かめる。
  void validate() {
    final codes = {for (final c in competencies) c.code};
    for (final c in competencies) {
      if (!c.refs.every(sources.containsKey)) {
        throw const LearningDataError('competencies の出典IDが不明です');
      }
    }
    for (final n in notes) {
      if (!n.refs.every(sources.containsKey)) {
        throw const LearningDataError('extended の出典IDが不明です');
      }
    }
    if (cards.isEmpty || cases.isEmpty) {
      throw const LearningDataError('教材/ケースが空です');
    }
    cards.forEach((key, d) {
      if (d.id != key ||
          !d.codes.every(codes.contains) ||
          d.refs.isEmpty ||
          !d.refs.every(sources.containsKey)) {
        throw LearningDataError('教材 $key の参照先が不正です');
      }
    });
    cases.forEach((key, c) {
      if (c.id != key ||
          c.cards.isEmpty ||
          c.cards.toSet().length != c.cards.length ||
          !c.cards.every(cards.containsKey) ||
          c.focus.isEmpty ||
          c.focusReference.length != c.focus.length ||
          !c.focusReference.every(c.cards.contains)) {
        throw LearningDataError('ケース $key の参照先が不正です');
      }
    });
    if (!cases.containsKey(kStartCaseId) ||
        !cases.containsKey(kEmergencyCaseId)) {
      throw const LearningDataError('開始ケースC01と固定の緊急連携ケースC08が必要です');
    }
    for (final s in sources.values) {
      if (!s.url.startsWith('https://') && !s.url.startsWith('http://')) {
        throw const LearningDataError('原資料URLはhttpまたはhttpsを使用します');
      }
    }
  }

  /// 能力マップの見出し（データに現れた順）。
  List<String> get groups {
    final seen = <String>{};
    return [
      for (final c in competencies)
        if (seen.add(c.group)) c.group,
    ];
  }

  List<Competency> competenciesIn(String group) => [
    for (final c in competencies)
      if (c.group == group) c,
  ];

  /// 能力項目に関連付けた教材（データ順）。
  List<LearningCard> cardsFor(String code) => [
    for (final d in cards.values)
      if (d.codes.contains(code)) d,
  ];
}

Map<String, dynamic> _obj(Object? v, String where) {
  if (v is Map<String, dynamic>) return v;
  throw LearningDataError('$where の形式が不正です');
}

List<dynamic> _list(Object? v, String where) {
  if (v is List) return v;
  throw LearningDataError('$where の形式が不正です');
}

String _str(Map<String, dynamic> m, String key, String where) {
  final v = m[key];
  if (v is String) return v;
  throw LearningDataError('$where の $key が不正です');
}

List<String> _strs(Map<String, dynamic> m, String key, String where) {
  final v = m[key];
  if (v is List && v.every((e) => e is String)) return v.cast<String>();
  throw LearningDataError('$where の $key が不正です');
}
