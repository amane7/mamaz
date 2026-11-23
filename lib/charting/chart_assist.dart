/// 会話からカルテの下書き（試作）— 下書きづくりと「確かめたい点」の検出。
///
/// ここで行うのは次の2つだけ:
///   1. 会話の発言を、言い換えずにそのまま、話者つきで下書きの欄に振り分ける。
///   2. 会話に「無いもの・あいまいなもの」を決まった手掛かり語で見つけ、
///      助産師に確かめる問いの候補（学習室の教材ID）を挙げる。
///
/// 言語モデルは使っていない。端末内の語句の照合だけで動く。
/// 病状・緊急度・薬の可否は判定しない。空いた欄を推測で埋めない。
/// 手掛かり語は開発時に置いた仮のもので、臨床の監修は受けていない。
/// Flutter に依存しない。
library;

import 'package:unorm_dart/unorm_dart.dart' as unorm;

import '../learning/learning_search.dart' show LearningIndex;
import 'conversation.dart';

/// 下書きの欄。発言は言い換えずに載せるので、欄は「どの話題で出た発言か」の目印にとどまる。
enum ChartSection {
  wish,
  words,
  feeding,
  baby,
  fromFamily,
  medication,
  followUp,
  unknownSpeaker,
}

extension ChartSectionX on ChartSection {
  String get label => switch (this) {
    ChartSection.wish => 'ご本人の希望として出た言葉',
    ChartSection.words => 'ご本人の言葉',
    ChartSection.feeding => '授乳について出た話',
    ChartSection.baby => 'お子さんについて出た話',
    ChartSection.fromFamily => 'ご家族から聞いたこと',
    ChartSection.medication => '薬について出た話',
    ChartSection.followUp => '連携・次回',
    ChartSection.unknownSpeaker => '話者が分からない発言',
  };
}

/// 下書きの1行。発言をそのまま載せ、誰の何番目の発言かを残す。
class DraftEntry {
  final ChartSection section;
  final String text;
  final Speaker speaker;
  final int line;
  const DraftEntry(this.section, this.text, this.speaker, this.line);
}

/// 確かめたい点の種類。それぞれ学習室の教材1枚に対応する。
enum GapKind {
  ownWish,
  childIdentity,
  feedingWish,
  shortReply,
  hearsay,
  handoff,
  companion,
  medication,
}

extension GapKindX on GapKind {
  String get label => switch (this) {
    GapKind.ownWish => '本人の希望',
    GapKind.childIdentity => '児の識別',
    GapKind.feedingWish => '授乳の希望',
    GapKind.shortReply => '観察と推測',
    GapKind.hearsay => '情報の出所',
    GapKind.handoff => '引継ぎ',
    GapKind.companion => '同席と話しやすさ',
    GapKind.medication => '薬の確認',
  };

  /// 問い・理由・出典を引く教材。
  String get cardId => switch (this) {
    GapKind.ownWish => 'L01',
    GapKind.childIdentity => 'L02',
    GapKind.feedingWish => 'L03',
    GapKind.shortReply => 'L04',
    GapKind.hearsay => 'L05',
    GapKind.handoff => 'L06',
    GapKind.companion => 'L07',
    GapKind.medication => 'L17',
  };
}

class ClarifyingQuestion {
  final GapKind kind;

  /// 会話のどこを見て挙げたか（会話についての事実だけを書く）。
  final String reason;

  /// 手掛かりになった発言の番号。
  final List<int> lines;

  const ClarifyingQuestion(this.kind, this.reason, this.lines);

  String get cardId => kind.cardId;
}

class AssistResult {
  /// 差し迫った状況を示す語句があった。問いも下書きも出さず、人につなぐ案内だけにする。
  final bool stopped;
  final List<DraftEntry> draft;
  final List<ClarifyingQuestion> questions;

  const AssistResult({
    required this.stopped,
    required this.draft,
    required this.questions,
  });
}

String _n(String s) => unorm.nfkc(s).toLowerCase();

final _medication = RegExp(r'薬|くすり|服用|処方|錠|痛み止め|サプリ');
final _feeding = RegExp(r'授乳|母乳|ミルク|おっぱい|哺乳|搾乳|飲ん|飲み|飲め|飲ま');
final _babyTopic = RegExp(
  r'赤ちゃん|子ども|こども|お子|上の子|下の子|この子|体重|グラム|\d\s*g|おむつ|うんち|おしっこ',
);
final _childObservation = RegExp(
  r'飲ん|飲み|飲め|飲ま|体重|グラム|\d\s*g|泣|おむつ|うんち|おしっこ|寝て|寝た|寝ま|寝な|眠って|眠ら',
);
final _self = RegExp(r'私|わたし|自分');
final _followUp = RegExp(r'連携|紹介|相談先|引き継|引継|申し送|次回|退所後|訪問');
final _handoff = RegExp(r'連携|紹介|相談先|引き継|引継|申し送');
final _handoffDetail = RegExp(r'いつまで|\d+\s*日|来週|明日|今週|担当は|が担当');
final _multiples = RegExp(r'双子|ふたご|三つ子|多胎|二人とも|ふたりとも|お二人');
final _childId = RegExp(
  r'上の子|下の子|第[一二三123]子|兄|姉|弟|妹|一人目|二人目|ひとりめ|ふたりめ'
  r'|二人とも|ふたりとも|どちらも|両方|(ちゃん|くん|君)(は|が|も|の)',
);
final _reportedState = RegExp(r'飲ん|飲み|飲め|飲ま|寝|眠|食べ|泣|体重|元気|疲|つら|痛|起き');
final _quoted = RegExp(r'って言って|と言って|と聞い|らしい');
final _familyRequest = RegExp(r'てほしい|て欲しい|させたい|してあげて|お願い|指導');
final _wish = RegExp(r'たい|ほしい|欲しい|希望');
final _notWish = RegExp(r'みたい|だいたい|いったい|ぜったい|重たい|冷たい|かたい|眠たい|ねむたい|ありがたい|めでたい');
final _shortReply = RegExp(r'大丈夫|だいじょうぶ|平気|特にな|とくにな|なんでもな');
final _punctuation = RegExp(r'[\s、。．，,.!！?？「」…・]');

bool _hasWish(String t) => _wish.hasMatch(t.replaceAll(_notWish, ''));

/// 会話を読んで、下書きと、確かめたい点を返す。
///
/// 理由の文は「語句を見つけられなかった」という事実までしか言わない
/// （言い方が違うだけで、実際には話されていることがある）。
AssistResult analyzeConversation(Conversation c) {
  final texts = [for (final u in c.lines) _n(u.text)];

  if (c.lines.any((u) => LearningIndex.asksAboutRealCare(u.text))) {
    return const AssistResult(stopped: true, draft: [], questions: []);
  }

  bool spoken(int i) => c.lines[i].speaker != Speaker.midwife;
  bool by(int i, Speaker s) => c.lines[i].speaker == s;
  List<int> where(bool Function(int i) test) => [
    for (var i = 0; i < texts.length; i++)
      if (test(i)) i,
  ];

  // ---- 下書き：発言をそのまま、話者つきで欄に置く
  final draft = <DraftEntry>[];
  for (var i = 0; i < texts.length; i++) {
    if (!spoken(i)) continue;
    final t = texts[i];
    if (t.replaceAll(_punctuation, '').length <= 2) continue;
    final ChartSection section;
    if (by(i, Speaker.unknown)) {
      section = ChartSection.unknownSpeaker;
    } else if (by(i, Speaker.family)) {
      section = ChartSection.fromFamily;
    } else if (_medication.hasMatch(t)) {
      section = ChartSection.medication;
    } else if (_hasWish(t)) {
      section = ChartSection.wish;
    } else if (_followUp.hasMatch(t)) {
      section = ChartSection.followUp;
    } else if (_feeding.hasMatch(t)) {
      section = ChartSection.feeding;
    } else if (_babyTopic.hasMatch(t) && !_self.hasMatch(t)) {
      section = ChartSection.baby;
    } else {
      section = ChartSection.words;
    }
    draft.add(DraftEntry(section, c.lines[i].text, c.lines[i].speaker, i));
  }

  // ---- 確かめたい点
  final found = <ClarifyingQuestion>[];
  void add(GapKind kind, String reason, List<int> lines) {
    found.add(ClarifyingQuestion(kind, reason, lines));
  }

  // 本人の希望
  final motherWish = where((i) => by(i, Speaker.mother) && _hasWish(texts[i]));
  final familyRequest = where(
    (i) => by(i, Speaker.family) && _familyRequest.hasMatch(texts[i]),
  );
  if (motherWish.isEmpty) {
    add(GapKind.ownWish, 'ご本人が今日どうしたいかを示す言葉を、会話の中に見つけられませんでした。', familyRequest);
  } else if (familyRequest.isNotEmpty) {
    add(
      GapKind.ownWish,
      'ご家族の要望と、ご本人の希望が、別々の発言として出ています。',
      [...motherWish, ...familyRequest]..sort(),
    );
  }

  // 児の識別（お子さんが二人以上のとき）。ご本人の希望や、ご本人自身の話は除く。
  if (texts.any(_multiples.hasMatch)) {
    final unclear = where((i) {
      if (!spoken(i)) return false;
      final t = texts[i];
      if (!_childObservation.hasMatch(t)) return false;
      if (_medication.hasMatch(t) || _childId.hasMatch(t)) return false;
      if (_self.hasMatch(t)) return false;
      if (by(i, Speaker.mother) && _hasWish(t)) return false;
      return true;
    });
    if (unclear.isNotEmpty) {
      add(
        GapKind.childIdentity,
        'お子さんが二人以上のようですが、どちらのお子さんの話かを示す言葉が見つかりません。',
        unclear,
      );
    }
  }

  // 授乳の希望
  final feedingTalk = where(
    (i) => _feeding.hasMatch(texts[i]) && !_medication.hasMatch(texts[i]),
  );
  final motherFeedingWish = where(
    (i) =>
        by(i, Speaker.mother) &&
        _feeding.hasMatch(texts[i]) &&
        _hasWish(texts[i]),
  );
  if (feedingTalk.isNotEmpty && motherFeedingWish.isEmpty) {
    add(
      GapKind.feedingWish,
      '授乳の話は出ていますが、ご本人がどうしたいかを示す言葉は見つけられませんでした。',
      feedingTalk,
    );
  }

  // 短い返事
  final short = where(
    (i) =>
        by(i, Speaker.mother) &&
        _shortReply.hasMatch(texts[i]) &&
        texts[i].replaceAll(_punctuation, '').length <= 12,
  );
  if (short.isNotEmpty) {
    add(GapKind.shortReply, 'ご本人の返事が、短い言葉だけの箇所があります。', short);
  }

  // 情報の出所
  final hearsay = where(
    (i) =>
        (by(i, Speaker.family) && _reportedState.hasMatch(texts[i])) ||
        (spoken(i) && _quoted.hasMatch(texts[i])),
  );
  if (hearsay.isNotEmpty) {
    add(GapKind.hearsay, 'ご家族が話した様子、または人づての話があります。', hearsay);
  }

  // 引継ぎ
  final handoff = where(
    (i) => _handoff.hasMatch(texts[i]) && !_handoffDetail.hasMatch(texts[i]),
  );
  if (handoff.isNotEmpty) {
    add(
      GapKind.handoff,
      '引継ぎ・連携の話が出ていますが、誰がいつまでに何をするかを示す言葉は見つけられませんでした。',
      handoff,
    );
  }

  // 同席
  final familyLines = where((i) => by(i, Speaker.family));
  final motherLines = where((i) => by(i, Speaker.mother));
  if (familyLines.isNotEmpty && familyLines.length >= motherLines.length) {
    add(GapKind.companion, 'ご家族の発言の数が、ご本人と同じか、それより多くなっています。', familyLines);
  }

  // 薬
  final med = where((i) => spoken(i) && _medication.hasMatch(texts[i]));
  if (med.isNotEmpty) {
    add(GapKind.medication, '薬の話が出ています。分かっていることと未確認のことを分けて残せます。', med);
  }

  // 手掛かりの発言が会話に出てきた順に並べる（優先順位ではない）。
  // 手掛かりの発言がないもの（会話に見つからなかったもの）は最後に置く。
  final order = List<int>.generate(found.length, (i) => i);
  int first(int i) => found[i].lines.isEmpty ? 1 << 30 : found[i].lines.first;
  order.sort((a, b) {
    final c = first(a).compareTo(first(b));
    return c != 0 ? c : a.compareTo(b);
  });

  return AssistResult(
    stopped: false,
    draft: draft,
    questions: [for (final i in order) found[i]],
  );
}
