/// 乳房ケアカルテ — 紙の様式「すいな法乳房ケア 乳房ケアカルテ」を画面にしたもの。
///
/// 項目の名前・選択肢・金額は、紙の様式に書いてあるとおりに持つ。
/// 様式に無い判断（リスク判定・自動計算・要約）は入れない。
/// 記録はすべて「下書き」の扱いで、確定や署名の機能はまだ無い。
library;

import 'dart:math' as math;

/// 文字で書く欄のキー。
class KF {
  static const no = 'no';
  static const staff = 'staff';
  static const trainee = 'trainee';
  static const ageYears = 'ageYears';
  static const ageMonths = 'ageMonths';
  static const ageDays = 'ageDays';
  static const weightG = 'weightG';
  static const gainPerDay = 'gainPerDay';
  static const weaningDay = 'weaningDay';
  static const breastPerDay = 'breastPerDay';
  static const breastDay = 'breastDay';
  static const breastNight = 'breastNight';
  static const intervalFrom = 'intervalFrom';
  static const intervalTo = 'intervalTo';
  static const formulaPerDay = 'formulaPerDay';
  static const formulaFrom = 'formulaFrom';
  static const formulaTo = 'formulaTo';
  static const expressedPerDay = 'expressedPerDay';
  static const expressedFrom = 'expressedFrom';
  static const expressedTo = 'expressedTo';
  static const solidsPerDay = 'solidsPerDay';
  static const solidsNote = 'solidsNote';
  static const stoolPerDay = 'stoolPerDay';
  static const urinePerDay = 'urinePerDay';
  static const development = 'development';
  static const s = 's';
  static const oNote = 'oNote';
  static const pumpPerDay = 'pumpPerDay';
  static const nippleOther = 'nippleOther';
  static const painOther = 'painOther';
  static const posture = 'posture';
  static const support = 'support';
  static const p = 'p';
  static const diagnosis = 'diagnosis';
  static const feeOther = 'feeOther';

  /// 長い文章を書く欄（ほかは短い欄）。
  static const long = {
    development,
    s,
    oNote,
    posture,
    support,
    p,
    diagnosis,
    solidsNote,
  };

  static const all = [
    no, staff, trainee, ageYears, ageMonths, ageDays, weightG, gainPerDay,
    weaningDay, breastPerDay, breastDay, breastNight, intervalFrom,
    intervalTo, formulaPerDay, formulaFrom, formulaTo, expressedPerDay,
    expressedFrom, expressedTo, solidsPerDay, solidsNote, stoolPerDay,
    urinePerDay, development, s, oNote, pumpPerDay, nippleOther, painOther,
    posture, support, p, diagnosis, feeOther, //
  ];
}

const int kKarteShortMax = 40;
const int kKarteLongMax = 2000;
const int kKarteNameMax = 40;

/// 選ぶ欄（紙の □ と「・」区切りの選択肢）。
class KarteChoice {
  final List<String> options;

  /// 複数に印を付けられるか。
  final bool multi;
  const KarteChoice(this.options, {this.multi = false});
}

/// 選ぶ欄のキー。
class KP {
  static const place = 'place';
  static const weaning = 'weaning';
  static const stool = 'stool';
  static const breastShape = 'breastShape';
  static const nippleShield = 'nippleShield';
  static const pumpType = 'pumpType';
  static const nippleState = 'nippleState';
  static const pain = 'pain';
  static const payMethod = 'payMethod';
  static const fees = 'fees';
}

/// 「その他（　）」に印を付けたことを表す値。
const String kFeeOtherId = 'other';

const Map<String, KarteChoice> kKarteChoices = {
  // 紙では □ が6つ並ぶ。場所と種別が重なることがあるので、複数に印を付けられる。
  KP.place: KarteChoice(['宝塚', '西宮', '名古屋', '浦和', '訪問', '産後ケア'], multi: true),
  KP.weaning: KarteChoice(['卒乳', '断乳']),
  KP.stool: KarteChoice(['硬', '普通', '軟']),
  KP.breastShape: KarteChoice(['Ⅰ型', 'Ⅱa型', 'Ⅱb型', 'Ⅲ型']),
  KP.nippleShield: KarteChoice(['ニップル使用']),
  KP.pumpType: KarteChoice(['手動', '電動'], multi: true),
  KP.nippleState: KarteChoice(['白斑', '亀裂', '発赤'], multi: true),
  KP.pain: KarteChoice(['乳輪', '乳頭', '乳房'], multi: true),
  KP.payMethod: KarteChoice(['カード', 'PayPay', '現金']),
  KP.fees: KarteChoice([
    'first',
    'single',
    'ticket',
    'rentalTowel',
    'careTowel',
    kFeeOtherId,
  ], multi: true),
};

/// お会計の項目。金額は紙の様式の表記による。
class KarteFee {
  final String id;
  final String label;
  final int yen;
  const KarteFee(this.id, this.label, this.yen);
}

const List<KarteFee> kKarteFees = [
  KarteFee('first', '初診料', 1000),
  // 紙の表記は「1回5.500円」。5,500円として扱っている。
  KarteFee('single', '1回', 5500),
  KarteFee('ticket', 'チケット', 14850),
  KarteFee('rentalTowel', 'レンタルタオル', 350),
  KarteFee('careTowel', 'ケアタオル', 250),
];

String formatYen(int yen) {
  final s = yen.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

/// 乳房図（時計の文字盤の円）に置いた印。
///
/// x は図の右向き、y は図の下向きを正とし、円のふちが 1。
/// 紙と同じく、向かって左の円が「右」、向かって右の円が「左」。
class BreastMark {
  /// 'R'（右の乳房）か 'L'（左の乳房）。
  final String side;
  final double x;
  final double y;
  const BreastMark(this.side, this.x, this.y);

  double get distance => math.sqrt(x * x + y * y);

  /// 文字盤の何時の方向か（12, 1, …, 11）。
  int get hour {
    final deg = math.atan2(x, -y) * 180 / math.pi; // 12時が0、時計回り
    final h = ((deg < 0 ? deg + 360 : deg) / 30).round() % 12;
    return h == 0 ? 12 : h;
  }

  /// 図に置いた位置を、そのまま言葉にしたもの（所見の解釈ではない）。
  String get where {
    final name = side == 'R' ? '右' : '左';
    if (distance < 0.2) return '$name　中心付近';
    return '$name　$hour時の方向・${distance < 0.6 ? '中心寄り' : 'ふち寄り'}';
  }

  Map<String, dynamic> toJson() => {'side': side, 'x': x, 'y': y};

  static BreastMark? fromJson(Object? v) {
    if (v is! Map) return null;
    final side = v['side'];
    final x = v['x'], y = v['y'];
    if ((side != 'R' && side != 'L') || x is! num || y is! num) return null;
    return BreastMark(side as String, x.toDouble(), y.toDouble());
  }
}

/// 1回分の記録（紙の1枠）。
class KarteVisit {
  final String id;
  final DateTime date;
  final Map<String, String> text;
  final Map<String, List<String>> picks;
  final List<BreastMark> marks;

  /// 会話から作った下書きのときの出どころ（手で書いた記録は空）。
  final String source;

  /// 会話から作ったとき、まだ確かめていない点（紙の様式には無い欄）。
  final List<String> openPoints;
  final DateTime updatedAt;

  const KarteVisit._({
    required this.id,
    required this.date,
    required this.text,
    required this.picks,
    required this.marks,
    required this.source,
    required this.openPoints,
    required this.updatedAt,
  });

  /// 入力を整えて作る。空の欄は持たず、様式に無い選択肢は捨てる。
  factory KarteVisit.build({
    required String id,
    required DateTime date,
    Map<String, String> text = const {},
    Map<String, Iterable<String>> picks = const {},
    List<BreastMark> marks = const [],
    String source = '',
    List<String> openPoints = const [],
    DateTime? updatedAt,
  }) {
    final t = <String, String>{};
    for (final k in KF.all) {
      var v = (text[k] ?? '').trim();
      if (v.isEmpty) continue;
      final max = KF.long.contains(k) ? kKarteLongMax : kKarteShortMax;
      if (v.length > max) v = v.substring(0, max);
      t[k] = v;
    }
    final p = <String, List<String>>{};
    kKarteChoices.forEach((k, choice) {
      final chosen = (picks[k] ?? const <String>[]).toSet();
      final kept = [
        for (final o in choice.options)
          if (chosen.contains(o)) o,
      ];
      if (kept.isEmpty) return;
      p[k] = choice.multi ? kept : [kept.first];
    });
    return KarteVisit._(
      id: id,
      date: DateTime(date.year, date.month, date.day),
      text: Map.unmodifiable(t),
      picks: Map.unmodifiable(p),
      marks: List.unmodifiable(marks),
      source: source.trim(),
      openPoints: List.unmodifiable([
        for (final o in openPoints)
          if (o.trim().isNotEmpty) o.trim(),
      ]),
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  String t(String key) => text[key] ?? '';
  List<String> p(String key) => picks[key] ?? const [];
  bool has(String key, String option) => p(key).contains(option);

  /// 印を付けた金額の合計。「その他」は金額が決まっていないので含めない。
  int get feeTotal {
    final chosen = p(KP.fees);
    return [
      for (final f in kKarteFees)
        if (chosen.contains(f.id)) f.yen,
    ].fold(0, (a, b) => a + b);
  }

  String get dateLabel =>
      '${date.year}年${date.month}月${date.day}日（${weekdayLabel(date)}）';

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'text': text,
    'picks': picks,
    'marks': [for (final m in marks) m.toJson()],
    'source': source,
    'openPoints': openPoints,
    'updatedAt': updatedAt.toIso8601String(),
  };

  static KarteVisit? fromJson(Object? v) {
    if (v is! Map) return null;
    final id = v['id'];
    final date = DateTime.tryParse('${v['date']}');
    if (id is! String || id.isEmpty || date == null) return null;
    final text = <String, String>{};
    if (v['text'] is Map) {
      (v['text'] as Map).forEach((k, val) {
        if (k is String && val is String) text[k] = val;
      });
    }
    final picks = <String, List<String>>{};
    if (v['picks'] is Map) {
      (v['picks'] as Map).forEach((k, val) {
        if (k is String && val is List) {
          picks[k] = [
            for (final o in val)
              if (o is String) o,
          ];
        }
      });
    }
    return KarteVisit.build(
      id: id,
      date: date,
      text: text,
      picks: picks,
      marks: [
        if (v['marks'] is List)
          for (final m in v['marks'] as List)
            if (BreastMark.fromJson(m) != null) BreastMark.fromJson(m)!,
      ],
      source: v['source'] is String ? v['source'] as String : '',
      openPoints: [
        if (v['openPoints'] is List)
          for (final o in v['openPoints'] as List)
            if (o is String) o,
      ],
      updatedAt: DateTime.tryParse('${v['updatedAt']}') ?? date,
    );
  }
}

String weekdayLabel(DateTime d) => '月火水木金土日'[d.weekday - 1];

/// お一人分のカルテ（紙の1冊）。
class Karte {
  final String id;

  /// 氏名。
  final String motherName;

  /// お子様名前。
  final String childName;
  final DateTime createdAt;

  /// 日付の古い順。
  final List<KarteVisit> visits;

  Karte({
    required this.id,
    required this.motherName,
    required this.childName,
    required this.createdAt,
    List<KarteVisit> visits = const [],
  }) : visits = List.unmodifiable(
         [...visits]..sort((a, b) {
           final d = a.date.compareTo(b.date);
           return d != 0 ? d : a.updatedAt.compareTo(b.updatedAt);
         }),
       );

  Karte copyWith({
    String? motherName,
    String? childName,
    List<KarteVisit>? visits,
  }) => Karte(
    id: id,
    motherName: motherName ?? this.motherName,
    childName: childName ?? this.childName,
    createdAt: createdAt,
    visits: visits ?? this.visits,
  );

  DateTime get updatedAt => visits.fold(
    createdAt,
    (latest, v) => v.updatedAt.isAfter(latest) ? v.updatedAt : latest,
  );

  /// 次の記録に振る番号（紙の「No.（ ）」）。
  String get nextNo {
    var max = 0;
    for (final v in visits) {
      final n = int.tryParse(v.t(KF.no));
      if (n != null && n > max) max = n;
    }
    return '${math.max(max, visits.length) + 1}';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'motherName': motherName,
    'childName': childName,
    'createdAt': createdAt.toIso8601String(),
    'visits': [for (final v in visits) v.toJson()],
  };

  static Karte? fromJson(Object? v) {
    if (v is! Map) return null;
    final id = v['id'], name = v['motherName'];
    final created = DateTime.tryParse('${v['createdAt']}');
    if (id is! String || id.isEmpty || name is! String || created == null) {
      return null;
    }
    return Karte(
      id: id,
      motherName: name,
      childName: v['childName'] is String ? v['childName'] as String : '',
      createdAt: created,
      visits: [
        if (v['visits'] is List)
          for (final x in v['visits'] as List)
            if (KarteVisit.fromJson(x) != null) KarteVisit.fromJson(x)!,
      ],
    );
  }
}

/// 会話の下書きから、カルテの記録へ持ち込む内容。
class KartePrefill {
  /// S）に入れる文章（発言そのまま）。
  final String s;

  /// P）に入れる文章（次回、確かめること）。
  final String p;

  /// まだ確かめていない点。
  final List<String> openPoints;

  /// 出どころ（架空の会話例か、画面で書いた会話か）。
  final String source;

  const KartePrefill({
    required this.s,
    required this.p,
    required this.openPoints,
    required this.source,
  });
}
