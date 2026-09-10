/// AI助産師「MOA」のトリアージエンジン（Step3 / フェーズ3実装）。
///
/// 本番では助産師の知見をRAG化したLLM（GPT-4 / Claude 3.5）に接続する想定。
/// ここでは同じ振る舞い（レッドフラグ→エスカレーション、カテゴリ分類、
/// 信頼度スコア、根拠の提示、母親コンテキストを踏まえた個別化、
/// 助産師への引き継ぎサマリー生成）をルールベース＋RAG風の
/// ナレッジ参照で実装している。
library;

enum TriageLevel {
  emergency, // 救急受診をすすめる
  urgent, // 助産師へ即エスカレーション
  consult, // 受診・相談をすすめる
  selfCare, // セルフケアで対応可
}

enum TriageCategory {
  breast('母乳・乳房'),
  mental('こころ'),
  body('からだ'),
  baby('赤ちゃん'),
  sleep('睡眠・休息'),
  booking('予約・制度'),
  other('その他');

  const TriageCategory(this.label);
  final String label;
}

/// AIが参照した根拠（RAGで引いた助産師ナレッジ／ガイドライン）。
class KnowledgeSource {
  final String title;
  final String detail;
  const KnowledgeSource(this.title, this.detail);
}

/// 母親の状況（アプリ内の記録から生成）。
/// AIはこれを踏まえて「あなた向けの」回答を返す。
class MotherContext {
  final String motherName;
  final int? postpartumWeeks;
  final int? latestEpds;
  final int? systolic;
  final int? diastolic;
  final double? temperature;
  final String? breastRisk; // low / mid / high
  final int todayFeedCount;
  final double? sleepHours;
  final bool hasUpcomingBooking;
  final String? nextBookingLabel;

  const MotherContext({
    this.motherName = 'ママ',
    this.postpartumWeeks,
    this.latestEpds,
    this.systolic,
    this.diastolic,
    this.temperature,
    this.breastRisk,
    this.todayFeedCount = 0,
    this.sleepHours,
    this.hasUpcomingBooking = false,
    this.nextBookingLabel,
  });

  bool get bpConcern =>
      (systolic != null && systolic! >= 140) ||
      (diastolic != null && diastolic! >= 90);
  bool get epdsConcern => latestEpds != null && latestEpds! >= 9;
  bool get breastConcern => breastRisk == 'high' || breastRisk == 'mid';
}

class TriageResult {
  final TriageLevel level;
  final TriageCategory category;
  final String reply;
  final double confidence; // 0.0-1.0
  final String? escalationReason;
  final List<String> quickReplies;
  final String? suggestAction; // 'booking' / 'epds' / 'vitals' / 'breast'

  /// 回答の根拠（透明性要件）
  final List<KnowledgeSource> sources;

  /// さらに絞り込むための追加質問（マルチターン）
  final String? followUp;

  /// 助産師へ引き継ぐときの要約
  final String? handoffSummary;

  const TriageResult({
    required this.level,
    required this.category,
    required this.reply,
    required this.confidence,
    this.escalationReason,
    this.quickReplies = const [],
    this.suggestAction,
    this.sources = const [],
    this.followUp,
    this.handoffSummary,
  });

  bool get needsEscalation =>
      level == TriageLevel.emergency || level == TriageLevel.urgent;

  String get levelLabel => switch (level) {
    TriageLevel.emergency => '緊急：すぐに受診・相談を',
    TriageLevel.urgent => '要注意：助産師へ接続しました',
    TriageLevel.consult => '相談推奨：早めのケアを',
    TriageLevel.selfCare => 'セルフケアで対応できます',
  };
}

class AiMidwife {
  AiMidwife._();

  // ---- レッドフラグ（母体） ----
  static const _emergencyKeys = [
    '死にたい',
    '消えたい',
    '自分を傷つけ',
    '自殺',
    '赤ちゃんを傷つけ',
    '意識',
    '呼吸ができ',
    '息ができ',
    'けいれん',
    '大量出血',
    '血の塊',
  ];

  static const _urgentKeys = [
    '38度',
    '38℃',
    '39度',
    '高熱',
    '出血が止まらない',
    'ナプキンがいっぱい',
    '血圧が高',
    '140',
    '目がちらつ',
    '激しい頭痛',
    'ひどい頭痛',
    'みぞおち',
    '傷が化膿',
    '膿',
    '胸が痛',
    '足が痛くて腫れ',
    'ぐったり',
    'ミルクを飲まない',
    '母乳を飲まない',
  ];

  static const _breastUrgent = ['乳腺炎', '赤く腫れ', '熱をもって', '熱感', 'しこりが痛', '白斑'];

  static const _mentalKeys = [
    'つらい',
    'しんどい',
    '涙',
    '泣け',
    '不安',
    '孤独',
    'ひとり',
    '疲れ',
    'イライラ',
    '限界',
    'かわいく思えない',
    '自信がない',
    '眠れない',
  ];

  static const _breastKeys = [
    '母乳',
    '授乳',
    'おっぱい',
    '乳房',
    '乳首',
    '乳頭',
    '搾乳',
    'しこり',
    '張',
    'ミルク',
    '混合',
    '卒乳',
    '断乳',
  ];

  static const _bodyKeys = [
    '血圧',
    '悪露',
    '傷',
    '会陰',
    '帝王切開',
    '腰痛',
    '尿漏れ',
    '体重',
    '発熱',
    '頭痛',
    'めまい',
    '浮腫',
    'むくみ',
  ];

  static const _babyKeys = [
    '赤ちゃん',
    '体重',
    '発育',
    '便',
    'うんち',
    '吐き戻し',
    '沐浴',
    '寝ない',
    '夜泣き',
    '泣き',
    '湿疹',
    'おむつ',
  ];

  static const _sleepKeys = ['睡眠', '眠', '寝不足', '仮眠', '夜間'];

  static const _bookingKeys = [
    '予約',
    '通所',
    '宿泊',
    '訪問',
    '助成',
    'クーポン',
    '料金',
    'いくら',
    '自治体',
    '産後ケア事業',
  ];

  static const _thanksKeys = ['ありがとう', 'ありがと', '助かり', '安心した'];

  static bool _has(String s, List<String> keys) =>
      keys.any((k) => s.contains(k));

  // -------------------------------------------------------------------------
  // RAG風ナレッジ（助産師監修の根拠ドキュメント）
  // -------------------------------------------------------------------------
  static const _srcMastitis = KnowledgeSource(
    '乳腺炎の初期対応（助産師監修ナレッジ）',
    '授乳・搾乳を継続し、乳汁の流れを保つことが最優先。'
        '発熱38℃以上・24時間で改善しない硬結は受診の目安。',
  );
  static const _srcLatch = KnowledgeSource(
    'ラッチオン（深い含ませ方）ガイド',
    '乳頭痛の多くは浅飲みが原因。唇が外にめくれ、'
        'あごが乳房に触れ、鼻が空いている状態が目安。',
  );
  static const _srcSupply = KnowledgeSource(
    '母乳分泌のメカニズム',
    '分泌量は「授乳・搾乳の頻度（1日8〜12回）」と'
        '「乳房を空にすること」に最も影響される。',
  );
  static const _srcEpds = KnowledgeSource(
    'EPDS（エジンバラ産後うつ病自己評価票）',
    '30点満点。9点以上で要注意、13点以上で高リスク。'
        '項目10（自傷念慮）が1点以上のときは点数に関わらず即対応。',
  );
  static const _srcBlues = KnowledgeSource(
    '産後のホルモン変動とマタニティブルーズ',
    '産後3〜10日に約半数が経験する生理的反応。'
        '2週間以上続く場合は産後うつの評価が必要。',
  );
  static const _srcHypertension = KnowledgeSource(
    '産後高血圧・産後子癇前症',
    '産後6週までは新規に発症しうる。140/90 mmHg以上、'
        '強い頭痛・視野異常・みぞおちの痛みは緊急受診の対象。',
  );
  static const _srcLochia = KnowledgeSource(
    '産後の身体的回復のめやす',
    '悪露は約4〜6週で終了。1時間でナプキンがいっぱいになる出血、'
        '悪臭・発熱は感染や後期出血のサイン。',
  );
  static const _srcSleep = KnowledgeSource(
    '産後の睡眠マネジメント',
    '断片睡眠は「まとめて寝る」より「短時間の確保」が現実的。'
        '1回の授乳を家族に任せる設計が回復に有効。',
  );
  static const _srcBabyWeight = KnowledgeSource(
    '新生児の発育・哺乳のめやす',
    '体重増加は1日25〜30g前後、排尿は1日6回以上が目安。'
        '生後3ヶ月未満の37.5℃以上は受診対象。',
  );
  static const _srcMunicipal = KnowledgeSource(
    '自治体 産後ケア事業（母子保健法第17条の2）',
    '通所・宿泊・訪問の3類型。自治体ごとに利用回数と'
        '自己負担額が設定され、市区町村への申請で助成が受けられる。',
  );

  /// メイン判定
  ///
  /// [ctx] にアプリ内の記録（EPDS・血圧・乳房リスク等）を渡すと、
  /// 回答が個別化され、必要に応じて記録に基づく注意喚起が加わる。
  static TriageResult analyze(
    String input,
    String motherName, {
    MotherContext? ctx,
  }) {
    final s = input.trim();
    final c = ctx ?? MotherContext(motherName: motherName);
    final name = c.motherName.isEmpty ? motherName : c.motherName;
    final weeks = c.postpartumWeeks;

    // 0) お礼・ポジティブな締め
    if (_has(s, _thanksKeys) && s.length <= 20) {
      return TriageResult(
        level: TriageLevel.selfCare,
        category: TriageCategory.other,
        confidence: 0.95,
        reply:
            'こちらこそ、話してくださってありがとうございます。\n\n'
            '$nameが今日ここに来てくれたこと、それ自体がもう十分がんばっている証です。\n\n'
            'また眠れない夜も、ふと不安になった昼も、いつでも呼んでください。'
            '何時でも、何度でも、ここにいます。',
        quickReplies: ['また相談したい', '記録をつける', 'ケアを予約する'],
      );
    }

    // 1) 救急レベル
    if (_has(s, _emergencyKeys)) {
      return TriageResult(
        level: TriageLevel.emergency,
        category: _category(s),
        confidence: 0.98,
        escalationReason: '緊急性の高い表現を検知',
        reply:
            'いま、とてもつらい気持ちを言葉にしてくださって、ありがとうございます。'
            '$name、ひとりで抱えないでください。\n\n'
            'すぐに助産師におつなぎしました。担当助産師から折り返しご連絡します。\n\n'
            '今すぐ誰かと話したいときは、こちらもご利用ください。\n'
            '・よりそいホットライン 0120-279-338（24時間・無料）\n'
            '・こころの健康相談統一ダイヤル 0570-064-556\n\n'
            '強い症状や危険を感じるときは、迷わず 119 / 産科へご連絡ください。\n\n'
            'あなたがいなくなって良い理由は、どこにもありません。'
            'ここにいてくれて、ありがとう。',
        quickReplies: ['助産師と話したい', 'いまの気持ちを聞いてほしい'],
        sources: const [_srcEpds],
        handoffSummary:
            '【最優先】AI相談で緊急性の高い表現を検知。'
            '発話「$s」。${c.latestEpds != null ? '直近EPDS ${c.latestEpds}点。' : ''}'
            '即時の電話連絡が必要。',
      );
    }

    // 2) 母体の危険サイン
    if (_has(s, _urgentKeys)) {
      final bpNote = c.bpConcern
          ? '\n\n記録を確認したところ、直近の血圧が ${c.systolic}/${c.diastolic} mmHg でした。'
                'この値は注意が必要な範囲です。助産師にも共有しています。'
          : '';
      return TriageResult(
        level: TriageLevel.urgent,
        category: _category(s),
        confidence: 0.93,
        escalationReason: '産後の危険サイン（発熱・出血・血圧・頭痛など）を検知',
        reply:
            'お知らせありがとうございます。その症状は、産後に注意が必要なサインに当てはまります。'
            'ご自分で「大丈夫かな」と迷いながら伝えてくださったこと、とても大切な判断でした。\n\n'
            '担当助産師におつなぎしました。内容を確認して順次ご連絡します。$bpNote\n\n'
            '次のような場合は、待たずに産科・救急へご連絡ください。\n'
            '・38℃以上の発熱が続く\n'
            '・1時間でナプキンがいっぱいになる出血\n'
            '・薬が効かない強い頭痛、目のちらつき\n'
            '・血圧 140/90 mmHg 以上\n\n'
            'よければ「緊急時問診票」で状態を教えてください。助産師がすぐに確認できます。',
        quickReplies: ['緊急時問診票を書く', '血圧を記録する', '助産師と話したい'],
        suggestAction: 'vitals',
        sources: const [_srcHypertension, _srcLochia],
        followUp: 'いつからその症状が続いていますか？（何日前から／今日だけ）',
        handoffSummary:
            '産後の危険サインを検知。発話「$s」。'
            '${c.bpConcern ? '直近血圧 ${c.systolic}/${c.diastolic}。' : ''}'
            '${weeks != null ? '産後$weeks週。' : ''}要確認。',
      );
    }

    // 3) 乳腺炎の疑い
    if (_has(s, _breastUrgent)) {
      final riskNote = c.breastRisk == 'high'
          ? '\n\n乳房セルフチェックでも高リスクの判定が出ています。'
                '早めに母乳外来で診てもらうことを強くおすすめします。'
          : '';
      return TriageResult(
        level: TriageLevel.consult,
        category: TriageCategory.breast,
        confidence: 0.9,
        escalationReason: '乳腺炎の疑い',
        reply:
            '痛い中、伝えてくださってありがとうございます。'
            '乳房の赤み・熱感・強い痛みは、乳腺炎に進みかけているサインかもしれません。'
            '早めのケアで軽くすむことが多いので、我慢しないでくださいね。$riskNote\n\n'
            '【いまできること】\n'
            '① 授乳・搾乳を止めない（つまりを流す方向へ）\n'
            '② 痛む側から、あるいは脇抱きで角度を変えて飲ませる\n'
            '③ 授乳後に保冷剤をタオル越しに10分ほど当てる\n'
            '④ 水分と休息をとる\n\n'
            '38℃以上の発熱、しこりが24時間改善しない場合は母乳外来の受診をおすすめします。'
            '助産師に状況を共有しました。',
        quickReplies: ['母乳外来を予約する', '乳房セルフチェックをする', '助産師と話したい'],
        suggestAction: 'breast',
        sources: const [_srcMastitis, _srcLatch],
        followUp: '発熱はありますか？（ある／ない／測っていない）',
        handoffSummary:
            '乳腺炎の疑い。発話「$s」。'
            '${c.breastRisk != null ? '乳房セルフチェック：${c.breastRisk}。' : ''}'
            '母乳外来の枠確保を検討。',
      );
    }

    // 4) こころ
    if (_has(s, _mentalKeys)) {
      final heavy =
          s.contains('限界') ||
          s.contains('かわいく思えない') ||
          s.contains('ずっと') ||
          s.contains('毎日') ||
          c.epdsConcern;
      final epdsNote = c.epdsConcern
          ? '\n\n前回のこころのセルフチェックは ${c.latestEpds}点でした。'
                'このスコアは「支えが必要な状態」を示すもので、$nameの弱さの証明ではありません。'
          : '';
      final sleepNote = (c.sleepHours != null && c.sleepHours! < 5)
          ? '\n\n記録では睡眠が ${c.sleepHours!.toStringAsFixed(1)}時間。'
                'これだけ眠れない状態が続けば、誰でも心は削れます。'
          : '';
      return TriageResult(
        level: heavy ? TriageLevel.consult : TriageLevel.selfCare,
        category: TriageCategory.mental,
        confidence: heavy ? 0.86 : 0.78,
        escalationReason: heavy ? 'こころの負担が大きい可能性' : null,
        reply:
            'ここまで、本当によくがんばってこられましたね。$nameのつらさは、'
            'がんばりが足りないからではありません。産後はホルモンが大きく変化して、'
            '誰にでも気分の落ち込みが起こります。$epdsNote$sleepNote\n\n'
            '【いま、少しだけ試せること】\n'
            '・4秒吸って、8秒吐く呼吸を3回\n'
            '・赤ちゃんが眠っている間、家事より先に横になる\n'
            '・「できなかったこと」より「できたこと」を1つ数える\n\n'
            '${heavy ? 'よければ、こころのセルフチェック（EPDS）で今の状態を見てみませんか。9点以上のときは、そのまま助産師へおつなぎします。ひとりで判断しなくて大丈夫です。' : 'もう少し、今の気持ちを聞かせてもらえますか。うまく言葉にならなくても大丈夫です。'}',
        quickReplies: ['こころのセルフチェックをする', '助産師と話したい', 'もう少し話を聞いて'],
        suggestAction: 'epds',
        sources: const [_srcBlues, _srcEpds],
        followUp: 'その気持ちは、いつ頃から続いていますか？（数日／2週間以上）',
        handoffSummary: heavy
            ? 'こころの負担が大きい可能性。発話「$s」。'
                  '${c.latestEpds != null ? '直近EPDS ${c.latestEpds}点。' : 'EPDS未実施。'}'
                  '${weeks != null ? '産後$weeks週。' : ''}オンライン面談の提案を推奨。'
            : null,
      );
    }

    // 5) 母乳・授乳
    if (_has(s, _breastKeys)) {
      final feedNote = c.todayFeedCount > 0
          ? '\n\n今日はここまで ${c.todayFeedCount}回の授乳を記録されています。'
                '${c.todayFeedCount < 8 ? '分泌を保つには1日8〜12回が目安なので、あと少し回数を増やせると安心です。' : '十分な回数です。よくがんばっています。'}'
          : '';
      return TriageResult(
        level: TriageLevel.selfCare,
        category: TriageCategory.breast,
        confidence: 0.88,
        reply:
            '授乳のこと、一緒に見ていきましょう。ママズケアの助産師がよくお伝えしている内容です。$feedNote\n\n'
            '【張って痛いとき】\n'
            '授乳前に少し温めて、乳輪を柔らかくしてから浅く搾ります。'
            '飲ませたあとに冷やすと落ち着きます。\n\n'
            '【出が少ないと感じるとき】\n'
            '回数（1日8〜12回）と「深く含ませる」ことが量に一番効きます。'
            '水分・休息も母乳をつくる材料です。\n\n'
            '【痛いとき】\n'
            '多くは浅飲みが原因です。赤ちゃんの唇が外にめくれ、あごが乳房に触れているかを見てください。\n\n'
            '姿勢の図解は「母乳ケア」から確認できます。しこり・赤み・白斑があるときは母乳外来へ。\n\n'
            'どんな飲ませ方でも、$nameが赤ちゃんを育てていることに変わりはありません。',
        quickReplies: ['授乳姿勢のガイドを見る', '母乳外来を予約する', '母乳量を記録する'],
        suggestAction: 'breast',
        sources: const [_srcLatch, _srcSupply],
        followUp: '痛み・しこり・赤みはありますか？（ある／ない）',
      );
    }

    // 6) 睡眠
    if (_has(s, _sleepKeys)) {
      final bookNote = c.hasUpcomingBooking && c.nextBookingLabel != null
          ? '\n\n${c.nextBookingLabel} のご予約が入っています。'
                'その日は「眠ること」を目的にしてしまって大丈夫です。'
          : '';
      return TriageResult(
        level: TriageLevel.selfCare,
        category: TriageCategory.sleep,
        confidence: 0.85,
        reply:
            '夜間の授乳、本当におつかれさまです。産後の睡眠不足は「体力」ではなく「仕組み」で補うのがコツです。$bookNote\n\n'
            '① 授乳グッズを1カ所にまとめる（立ち上がる回数を減らす）\n'
            '② 明かりは暖色の間接照明に\n'
            '③ 日中の20分仮眠を「予定」として入れる\n'
            '④ 1回だけでも搾乳を家族に任せる日をつくる\n\n'
            'それでも眠れない日が続くときは、通所・宿泊ケアで「眠ること」を目的に頼ってください。'
            'それは立派なケアの使い方で、甘えではありません。',
        quickReplies: ['宿泊ケアを予約する', '通所ケアを予約する', '睡眠を記録する'],
        suggestAction: 'booking',
        sources: const [_srcSleep],
      );
    }

    // 7) 赤ちゃん
    if (_has(s, _babyKeys)) {
      return TriageResult(
        level: TriageLevel.selfCare,
        category: TriageCategory.baby,
        confidence: 0.8,
        reply:
            '赤ちゃんのことですね。心配になる気持ち、とてもよくわかります。判断のめやすをお伝えします。\n\n'
            '【落ち着いて様子を見てよいサイン】\n'
            '・体重が1日25〜30g前後増えている\n'
            '・おしっこが1日6回以上出ている\n'
            '・泣いたあと、抱っこで落ち着く\n\n'
            '【早めに受診したいサイン】\n'
            '・ぐったりして飲まない\n'
            '・38℃以上の発熱（生後3ヶ月未満は37.5℃以上）\n'
            '・呼吸が速い、顔色が悪い\n\n'
            '気になる様子があれば、遠慮なく詳しく教えてください。助産師にもおつなぎできます。',
        quickReplies: ['助産師と話したい', 'オンライン相談を予約する'],
        sources: const [_srcBabyWeight],
        followUp: '赤ちゃんの機嫌と哺乳はいかがですか？（いつもどおり／少ない）',
      );
    }

    // 8) 予約・制度
    //
    // 要件再定義：AIは最終的な対象可否や金額を決めない。
    // 制度案内・一般的なFAQ・必要情報の聞き取り・人への引継ぎに限定する。
    if (_has(s, _bookingKeys)) {
      final asksEligibility = _has(s, const ['対象', '使える', '受けられる', '該当', '条件']);
      final asksFee = _has(s, const ['料金', 'いくら', '金額', '費用', '円']);
      final scope = asksEligibility
          ? '対象になるかどうかの最終判断は、お住まいの自治体とスタッフが確認します。'
                'ここでは「申請の流れ」と「目安」だけお伝えできます。\n\n'
          : asksFee
          ? '料金は自治体・回数・課税区分・クーポンで変わるため、ここでの金額は概算です。'
                '確定はスタッフ確認後になります。\n\n'
          : '';
      return TriageResult(
        level: TriageLevel.selfCare,
        category: TriageCategory.booking,
        confidence: 0.9,
        reply:
            '$scopeご案内します。MAMOAでは次のケアを予約できます。\n\n'
            '・通所型（日中の休息＋ケア）\n'
            '・宿泊型（1泊〜のショートステイ）\n'
            '・訪問型（助産師がご自宅へ）\n'
            '・母乳外来（乳房・授乳の相談・自費）\n\n'
            '自治体の産後ケア事業を使う場合は、先に自治体への申請と決定通知・利用券が必要です。'
            '「自治体の制度・申請」で、お住まいの自治体ごとの流れ・申請先・料金の目安を確認できます。\n\n'
            'お住まいの自治体・お子さまの月齢・利用回数を教えていただければ、必要な手続きを整理して'
            'スタッフにお引き継ぎします。',
        quickReplies: ['自治体の制度・申請を見る', '産後ケアを利用する', 'スタッフに引き継ぐ'],
        suggestAction: 'booking',
        sources: const [_srcMunicipal],
        handoffSummary: '制度・料金に関するご質問。対象可否・最終金額はスタッフ確認が必要。',
      );
    }

    // 9) からだ
    if (_has(s, _bodyKeys)) {
      final bpNote = c.bpConcern
          ? '\n\n直近の記録では血圧が ${c.systolic}/${c.diastolic} mmHg でした。'
                '140/90 を超えているため、助産師にもお知らせが届いています。'
          : '';
      return TriageResult(
        level: TriageLevel.consult,
        category: TriageCategory.body,
        confidence: 0.76,
        reply:
            'お体のこと、教えてくださってありがとうございます。'
            '${weeks != null ? '産後$weeks週' : '産後6週間まで'}は回復の途中なので、'
            '「これくらいで相談していいのかな」と思うことこそ聞いてほしい時期です。$bpNote\n\n'
            '特に血圧は、産後にはじめて上がることがあります。'
            '「健康管理」に記録すると、140/90 を超えた時点で助産師へ自動でお知らせが飛びます。\n\n'
            '症状の続く期間や強さを教えていただけますか？内容によっては助産師へおつなぎします。',
        quickReplies: ['血圧を記録する', '助産師と話したい'],
        suggestAction: 'vitals',
        sources: const [_srcHypertension, _srcLochia],
        followUp: 'その症状の強さは10段階でどのくらいですか？',
      );
    }

    // 10) 分類できない → 信頼度が低いのでエスカレーション候補
    return TriageResult(
      level: TriageLevel.selfCare,
      category: TriageCategory.other,
      confidence: 0.42,
      reply:
          'お話してくれてありがとうございます。$nameのペースで大丈夫です。\n\n'
          'もう少し詳しく教えていただけますか？（いつから／どんなときに／どれくらい）\n\n'
          'わたしの理解が足りないと感じたときは、遠慮なく「助産師と話したい」とお伝えください。'
          'すぐに人の助産師へおつなぎします。うまく説明できないことも、'
          '「うまく言えない」とだけ伝えてもらえれば十分です。',
      quickReplies: ['助産師と話したい', '母乳のこと', 'こころのこと', '赤ちゃんのこと'],
      followUp: 'いちばん困っているのは、からだ・こころ・赤ちゃん・母乳のどれに近いですか？',
    );
  }

  static TriageCategory _category(String s) {
    if (_has(s, _breastKeys)) return TriageCategory.breast;
    if (_has(s, _mentalKeys)) return TriageCategory.mental;
    if (_has(s, _babyKeys)) return TriageCategory.baby;
    if (_has(s, _sleepKeys)) return TriageCategory.sleep;
    if (_has(s, _bodyKeys)) return TriageCategory.body;
    if (_has(s, _bookingKeys)) return TriageCategory.booking;
    return TriageCategory.other;
  }

  /// 明示的に助産師を希望した場合
  static bool wantsHuman(String s) =>
      s.contains('助産師と話') ||
      s.contains('人と話') ||
      s.contains('人間') ||
      s.contains('助産師につな') ||
      s.contains('助産師さん');

  /// 会話履歴から助産師への引き継ぎサマリーを生成（Step3のhuman-in-the-loop）。
  static String buildHandoff({
    required List<String> userUtterances,
    required MotherContext ctx,
    TriageResult? latest,
  }) {
    final b = StringBuffer();
    b.writeln('■ AI相談サマリー（自動生成）');
    b.writeln(
      '対象：${ctx.motherName}'
      '${ctx.postpartumWeeks != null ? '／産後${ctx.postpartumWeeks}週' : ''}',
    );
    if (latest != null) {
      b.writeln(
        'AI判定：${latest.levelLabel}'
        '（${latest.category.label}・確信度${(latest.confidence * 100).round()}%）',
      );
    }
    final flags = <String>[];
    if (ctx.epdsConcern) flags.add('EPDS ${ctx.latestEpds}点');
    if (ctx.bpConcern) flags.add('血圧 ${ctx.systolic}/${ctx.diastolic}');
    if (ctx.breastRisk == 'high') flags.add('乳房リスク高');
    if (ctx.sleepHours != null && ctx.sleepHours! < 5) {
      flags.add('睡眠 ${ctx.sleepHours!.toStringAsFixed(1)}h');
    }
    if (flags.isNotEmpty) b.writeln('注意点：${flags.join(' / ')}');
    b.writeln('― 主な訴え ―');
    final recent = userUtterances.length > 5
        ? userUtterances.sublist(userUtterances.length - 5)
        : userUtterances;
    for (final u in recent) {
      b.writeln('・$u');
    }
    if (latest?.followUp != null) {
      b.writeln('未確認事項：${latest!.followUp}');
    }
    return b.toString().trim();
  }
}
