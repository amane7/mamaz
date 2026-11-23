/// 助産の学習室 — 端末内の検索と並べ替え。
///
/// 配布キット（`MAMOA_助産の学習室.html`）の処理をそのまま移したもの:
///   文字 2-gram の TF–IDF（対数頻度・逆文書頻度）とコサイン類似度。
///   知識検索は教材カード最大3件・基礎ノート最大2件。一致が弱ければ候補なし。
///   ケース演習は、そのケースの候補の範囲で、初答・理由・観点に近い順に並べる。
///
/// 病名・緊急度・薬量の判定は行わない。Flutter に依存しない。
library;

import 'dart:math' as math;

import 'package:unorm_dart/unorm_dart.dart' as unorm;

import 'learning_models.dart';

final RegExp _separators = RegExp(r'[\s、。・？?！!「」『』()（）・：]');
final RegExp _spaces = RegExp(r'\s+');
final RegExp _cardId = RegExp(r'^L\d+$');
final RegExp _cardIdAnyCase = RegExp(r'^L\d+$', caseSensitive: false);

/// 実際の母子についての相談・緊急・薬量・診断を尋ねる語句。
/// 該当したら検索せず、人につなぐ案内だけを返す。
final RegExp _realCare = RegExp(
  r'息(を|が)?(していな|できな)|呼吸が(止|な)|意識が(ない|な)|出血(が)?止まら|救急車を呼|今すぐどう|何錠|何ミリ|何mg|診断して|死にたい|自殺したい',
);

/// 文字 2-gram の出現回数（出現順を保つ）。1文字だけの語はその1文字を 1 回として数える。
Map<String, int> grams(String source) {
  final text = unorm.nfkc(source).toLowerCase().replaceAll(_separators, ' ');
  final g = <String, int>{};
  for (final t in text.split(_spaces)) {
    if (t.isEmpty) continue;
    if (t.length == 1) g[t] = 1;
    for (var i = 0; i < t.length - 1; i++) {
      final k = t.substring(i, i + 2);
      g[k] = (g[k] ?? 0) + 1;
    }
  }
  return g;
}

class LearningIndex {
  final LearningKb kb;

  /// 知識検索で教材カードを出す下限と件数。
  static const double cardThreshold = .045;
  static const int cardLimit = 3;

  /// 基礎ノートを出す下限と件数。
  static const double noteThreshold = .055;
  static const int noteLimit = 2;

  /// ケース演習で、選んだ観点に対応する教材へ足す重み。
  static const double focusBoost = .14;

  final Map<String, Map<String, int>> _cardGrams = {};
  final Map<String, int> _df = {};
  final List<Map<String, int>> _noteGrams = [];

  LearningIndex(this.kb) {
    for (final d in kb.cards.values) {
      final g = grams(
        [d.title, d.title, d.tags, d.tags, d.question, d.why].join(' '),
      );
      _cardGrams[d.id] = g;
      for (final t in g.keys) {
        _df[t] = (_df[t] ?? 0) + 1;
      }
    }
    for (final n in kb.notes) {
      _noteGrams.add(
        grams(
          [n.label, n.label, n.topics, n.concept, n.selfQuestion].join(' '),
        ),
      );
    }
  }

  double _idf(String k) =>
      math.log(1 + (_cardGrams.length + .5) / ((_df[k] ?? 0) + .5));

  /// コサイン類似度。
  double score(Map<String, int> q, Map<String, int> d) {
    var dot = 0.0, a = 0.0, b = 0.0;
    q.forEach((k, f) {
      final w = (1 + math.log(f)) * _idf(k);
      a += w * w;
      final df = d[k];
      if (df != null) dot += w * (1 + math.log(df)) * _idf(k);
    });
    d.forEach((k, f) {
      final w = (1 + math.log(f)) * _idf(k);
      b += w * w;
    });
    final ab = a * b;
    return dot / math.sqrt(ab == 0 || ab.isNaN ? 1 : ab);
  }

  double cardScore(Map<String, int> q, String cardId) =>
      score(q, _cardGrams[cardId]!);

  double noteScore(Map<String, int> q, int noteIndex) =>
      score(q, _noteGrams[noteIndex]);

  /// 知識検索：教材カードのID（近い順・最大3件）。`L21` のようなIDはその1枚だけを返す。
  List<String> rankCards(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final id = trimmed.toUpperCase();
    if (_cardId.hasMatch(id)) {
      return kb.cards.containsKey(id) ? [id] : const [];
    }
    final x = grams(query);
    final ids = kb.cards.keys.toList();
    final scores = [for (final i in ids) cardScore(x, i)];
    return [
      for (final i in _descending(scores))
        if (scores[i] >= cardThreshold) ids[i],
    ].take(cardLimit).toList();
  }

  /// 知識検索：関連する基礎ノート（近い順・最大2件）。
  List<FoundationNote> matchNotes(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty || _cardIdAnyCase.hasMatch(trimmed)) return const [];
    final x = grams(trimmed);
    final scores = [for (var i = 0; i < kb.notes.length; i++) noteScore(x, i)];
    return [
      for (final i in _descending(scores))
        if (scores[i] >= noteThreshold) kb.notes[i],
    ].take(noteLimit).toList();
  }

  /// ケース演習：そのケースの候補を、初答・理由・選んだ観点に近い順に並べる。
  List<String> personalOrder(
    LearningCase c, {
    required int focusIndex,
    required String first,
    required String why,
  }) {
    final focus = c.focus[focusIndex];
    final preferred = c.focusReference[focusIndex];
    final q = grams([focus, focus, first, why].join(' '));
    final scores = [
      for (final id in c.cards)
        cardScore(q, id) + (id == preferred ? focusBoost : 0),
    ];
    return [for (final i in _descending(scores)) c.cards[i]];
  }

  /// 文献台帳の絞り込み（出典名・用語・ID。大文字小文字を区別しない部分一致）。
  List<LearningSource> filterSources(String query) {
    final q = query.trim().toLowerCase();
    return [
      for (final s in kb.sources.values)
        if (s.haystack.contains(q)) s,
    ];
  }

  /// 実際の母子についての相談・緊急・薬量・診断を尋ねているか。
  ///
  /// 語句はキットと同じ。全角・半角や大文字の違い（「何ｍｇ」「何MG」）で
  /// すり抜けないよう、正規化した文字列でも照合する（キットより広く止める方向のみ）。
  static bool asksAboutRealCare(String query) =>
      _realCare.hasMatch(query) ||
      _realCare.hasMatch(unorm.nfkc(query).toLowerCase());
}

/// 点数の高い順の添字。同点は元の並びを保つ（安定ソート）。
List<int> _descending(List<double> scores) {
  final order = List<int>.generate(scores.length, (i) => i);
  order.sort((x, y) {
    final c = scores[y].compareTo(scores[x]);
    return c != 0 ? c : x.compareTo(y);
  });
  return order;
}
