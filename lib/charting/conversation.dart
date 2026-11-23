/// 会話からカルテの下書き（試作）— 会話のモデルと、架空の会話例。
///
/// この試作は音声の録音・文字起こしをつないでいない。扱うのは文字になった会話だけ。
/// 会話例はすべて、この試作のために作った架空の内容で、実在の方の発言ではない。
/// Flutter に依存しない。
library;

enum Speaker { mother, family, midwife, unknown }

extension SpeakerX on Speaker {
  String get label => switch (this) {
    Speaker.mother => 'ご本人',
    Speaker.family => 'ご家族',
    Speaker.midwife => '助産師',
    Speaker.unknown => '話者不明',
  };
}

class Utterance {
  final Speaker speaker;
  final String text;
  const Utterance(this.speaker, this.text);
}

class Conversation {
  final String title;
  final String setting;
  final List<Utterance> lines;

  /// 同梱の架空例か（false は、画面で書いて試した会話）。
  final bool sample;

  const Conversation({
    required this.title,
    required this.setting,
    required this.lines,
    this.sample = true,
  });
}

const int kMaxConversationLines = 60;
const int kMaxUtteranceLength = 300;

final RegExp _prefix = RegExp(
  r'^\s*(母親|母|ママ|本人|家族|夫|パートナー|祖母|祖父|父|助産師|スタッフ|私)\s*[：:]\s*(.+)$',
);

Speaker _speakerOf(String name) => switch (name) {
  '母親' || '母' || 'ママ' || '本人' => Speaker.mother,
  '助産師' || 'スタッフ' || '私' => Speaker.midwife,
  _ => Speaker.family,
};

/// 「母：…」「家族：…」「助産師：…」の形で書かれた文章を会話として読む。
/// 行頭に話者がない行は「話者不明」として残す（話者を推測で埋めない）。
Conversation parseConversation(String raw) {
  final lines = <Utterance>[];
  for (final row in raw.split('\n')) {
    final text = row.trim();
    if (text.isEmpty) continue;
    if (lines.length >= kMaxConversationLines) break;
    final m = _prefix.firstMatch(text);
    final body = (m?.group(2) ?? text).trim();
    final clipped = body.length > kMaxUtteranceLength
        ? body.substring(0, kMaxUtteranceLength)
        : body;
    lines.add(
      Utterance(m == null ? Speaker.unknown : _speakerOf(m.group(1)!), clipped),
    );
  }
  return Conversation(
    title: '書いて試した会話',
    setting: '画面で入力した内容',
    lines: lines,
    sample: false,
  );
}

/// 架空の会話例。
const List<Conversation> kSampleConversations = [
  Conversation(
    title: '初回面談：休みたい本人と、授乳の練習を望む家族',
    setting: '産後ケアの初回面談。ご家族が同席。',
    lines: [
      Utterance(Speaker.midwife, '今日はどんなふうに過ごしたいですか。'),
      Utterance(Speaker.mother, '今日は少し眠りたいです。'),
      Utterance(Speaker.family, '授乳の練習をしてほしいんです。夜、うまく飲めていないみたいで。'),
      Utterance(Speaker.midwife, '夜の授乳で困っていることはありますか。'),
      Utterance(Speaker.mother, '大丈夫です。'),
      Utterance(Speaker.family, '昨日は三回くらい起きて、ミルクも足しました。'),
    ],
  ),
  Conversation(
    title: '双子の記録：手帳は一冊だけ',
    setting: '双子のご家庭。ご家族が同席。',
    lines: [
      Utterance(Speaker.midwife, 'お二人の様子を教えてください。'),
      Utterance(Speaker.family, '昨日はよく飲みました。'),
      Utterance(Speaker.mother, '体重は前に測ったとき2800グラムでした。'),
      Utterance(Speaker.midwife, '手帳はお持ちですか。'),
      Utterance(Speaker.mother, '一冊だけ持ってきました。'),
      Utterance(Speaker.midwife, '次の訪問の担当に連携しておきますね。'),
    ],
  ),
  Conversation(
    title: '薬の質問と、短い返事',
    setting: 'ご本人のみ来所。',
    lines: [
      Utterance(Speaker.midwife, '体調はいかがですか。'),
      Utterance(Speaker.mother, '大丈夫です。'),
      Utterance(Speaker.mother, '授乳中なんですけど、痛み止めの薬は飲んでもいいですか。'),
      Utterance(Speaker.midwife, 'お薬の名前は分かりますか。'),
      Utterance(Speaker.mother, '名前は覚えていなくて。授乳は続けたいです。'),
    ],
  ),
];
