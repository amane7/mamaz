import 'package:flutter/material.dart';

import 'models.dart';

/// 予約プラン種別（産後ケア事業の区分に準拠）
enum PlanKind {
  dayCare('通所型', '日中お預かり＋ケア', Icons.wb_sunny_outlined, Color(0xFFF8C8D6)),
  stay('宿泊型', '1泊〜のショートステイ', Icons.night_shelter_outlined, Color(0xFFC9BEE6)),
  visit('訪問型', '助産師がご自宅へ', Icons.directions_walk_rounded, Color(0xFFB7D0B5)),
  breastClinic(
    '母乳外来',
    '乳房・母乳ケア相談',
    Icons.water_drop_outlined,
    Color(0xFFF6D9A8),
  ),
  online('オンライン相談', 'ビデオ通話で相談', Icons.videocam_outlined, Color(0xFFB0E0E6));

  const PlanKind(this.label, this.desc, this.icon, this.color);
  final String label;
  final String desc;
  final IconData icon;
  final Color color;
}

/// 施設のケアプラン（料金・時間）
class CarePlan {
  final String id;
  final PlanKind kind;
  final String name;
  final int hours; // 0 = 宿泊(1泊) 扱い
  final int price; // 自己負担前の総額(円)
  final int subsidy; // 自治体助成額(円)

  const CarePlan({
    required this.id,
    required this.kind,
    required this.name,
    required this.hours,
    required this.price,
    this.subsidy = 0,
  });

  int get payAmount => (price - subsidy).clamp(0, price);

  String get durationLabel =>
      kind == PlanKind.stay ? '1泊2日' : (hours > 0 ? '$hours時間' : '30分');
}

/// 助産院・産後ケア施設
class Facility {
  final String id;
  final String name;
  final String area;
  final String address;
  final String tel;
  final double rating;
  final int reviewCount;
  final double distanceKm;
  final List<PlanKind> kinds;
  final List<String> features;
  final String midwifeName;
  final String comment;
  final bool subsidyAvailable; // 自治体産後ケア事業の対象
  final List<CarePlan> plans;

  const Facility({
    required this.id,
    required this.name,
    required this.area,
    required this.address,
    required this.tel,
    required this.rating,
    required this.reviewCount,
    required this.distanceKm,
    required this.kinds,
    required this.features,
    required this.midwifeName,
    required this.comment,
    required this.plans,
    this.subsidyAvailable = false,
  });
}

/// 予約枠（30分刻み）
class TimeSlot {
  final String time; // 'HH:mm'
  final bool available;
  const TimeSlot(this.time, this.available);
}

/// 決済方法
enum PayMethod {
  card('クレジットカード', Icons.credit_card_rounded),
  paypay('PayPay', Icons.qr_code_rounded),
  coupon('自治体クーポン利用', Icons.confirmation_number_outlined),
  onsite('当日 現地でお支払い', Icons.storefront_outlined);

  const PayMethod(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// 拡張版の予約（施設・プラン・決済つき）
class Booking {
  final String id;
  final String facilityId;
  final String facilityName;
  final PlanKind kind;
  final String planName;
  final DateTime dateTime;
  final int hours;
  final int amount;
  final PayMethod payMethod;
  String status; // 申込 / 確定 / 完了 / キャンセル
  bool intakeDone; // 問診票の提出済み
  String? recordId; // カルテID

  Booking({
    required this.id,
    required this.facilityId,
    required this.facilityName,
    required this.kind,
    required this.planName,
    required this.dateTime,
    required this.hours,
    required this.amount,
    required this.payMethod,
    this.status = '確定',
    this.intakeDone = false,
    this.recordId,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'facilityId': facilityId,
    'facilityName': facilityName,
    'kind': kind.index,
    'planName': planName,
    'dateTime': dateTime.toIso8601String(),
    'hours': hours,
    'amount': amount,
    'payMethod': payMethod.index,
    'status': status,
    'intakeDone': intakeDone,
    'recordId': recordId,
  };

  factory Booking.fromMap(Map map) => Booking(
    id: map['id'] as String,
    facilityId: (map['facilityId'] ?? '') as String,
    facilityName: (map['facilityName'] ?? '') as String,
    kind: PlanKind.values[(map['kind'] ?? 0) as int],
    planName: (map['planName'] ?? '') as String,
    dateTime: DateTime.parse(map['dateTime'] as String),
    hours: (map['hours'] ?? 0) as int,
    amount: (map['amount'] ?? 0) as int,
    payMethod: PayMethod.values[(map['payMethod'] ?? 0) as int],
    status: (map['status'] ?? '確定') as String,
    intakeDone: (map['intakeDone'] ?? false) as bool,
    recordId: map['recordId'] as String?,
  );
}

/// 問診票の種別
enum IntakeKind {
  first('初回問診票', '9項目のご状況アンケート', Icons.assignment_outlined),
  postpartum('産後経過問診（EPDS）', 'こころの状態のセルフチェック', Icons.favorite_border_rounded),
  breast('母乳ケア問診票', '乳房・授乳のお悩み', Icons.water_drop_outlined),
  urgent('緊急時問診票', '受診の目安を確認', Icons.emergency_outlined);

  const IntakeKind(this.label, this.desc, this.icon);
  final String label;
  final String desc;
  final IconData icon;
}

/// 提出済み問診票
class IntakeForm {
  final String id;
  final IntakeKind kind;
  final DateTime submittedAt;
  final Map<String, String> answers;
  final int? epdsScore;
  final bool signed; // 電子同意

  IntakeForm({
    required this.id,
    required this.kind,
    required this.submittedAt,
    required this.answers,
    this.epdsScore,
    this.signed = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'kind': kind.index,
    'submittedAt': submittedAt.toIso8601String(),
    'answers': answers,
    'epdsScore': epdsScore,
    'signed': signed,
  };

  factory IntakeForm.fromMap(Map map) => IntakeForm(
    id: map['id'] as String,
    kind: IntakeKind.values[map['kind'] as int],
    submittedAt: DateTime.parse(map['submittedAt'] as String),
    answers: Map<String, String>.from(map['answers'] as Map),
    epdsScore: map['epdsScore'] as int?,
    signed: (map['signed'] ?? false) as bool,
  );
}

/// バイタル測定（ウェアラブル / 手入力）
class VitalReading {
  final String id;
  final DateTime time;
  final int? systolic; // 収縮期血圧
  final int? diastolic; // 拡張期血圧
  final int? pulse;
  final double? temperature;
  final double? weight;
  final double? sleepHours;
  final int? steps;
  final String source; // 手入力 / Withings / Apple Watch など

  VitalReading({
    required this.id,
    required this.time,
    this.systolic,
    this.diastolic,
    this.pulse,
    this.temperature,
    this.weight,
    this.sleepHours,
    this.steps,
    this.source = '手入力',
  });

  /// 産後子癇前症リスク：140/90 以上
  bool get bpAlert =>
      (systolic != null && systolic! >= 140) ||
      (diastolic != null && diastolic! >= 90);

  bool get feverAlert => temperature != null && temperature! >= 38.0;

  bool get pulseAlert => pulse != null && (pulse! >= 110 || pulse! <= 45);

  bool get hasAlert => bpAlert || feverAlert || pulseAlert;

  Map<String, dynamic> toMap() => {
    'id': id,
    'time': time.toIso8601String(),
    'systolic': systolic,
    'diastolic': diastolic,
    'pulse': pulse,
    'temperature': temperature,
    'weight': weight,
    'sleepHours': sleepHours,
    'steps': steps,
    'source': source,
  };

  factory VitalReading.fromMap(Map map) => VitalReading(
    id: map['id'] as String,
    time: DateTime.parse(map['time'] as String),
    systolic: map['systolic'] as int?,
    diastolic: map['diastolic'] as int?,
    pulse: map['pulse'] as int?,
    temperature: (map['temperature'] as num?)?.toDouble(),
    weight: (map['weight'] as num?)?.toDouble(),
    sleepHours: (map['sleepHours'] as num?)?.toDouble(),
    steps: map['steps'] as int?,
    source: (map['source'] ?? '手入力') as String,
  );
}

/// 連携デバイス
class WearableDevice {
  final String id;
  final String name;
  final String vendor;
  final IconData icon;
  bool connected;
  final List<String> metrics;

  WearableDevice({
    required this.id,
    required this.name,
    required this.vendor,
    required this.icon,
    required this.metrics,
    this.connected = false,
  });
}

/// 授乳（母乳）記録
enum FeedSide {
  left('左'),
  right('右'),
  both('両側'),
  bottle('ミルク');

  const FeedSide(this.label);
  final String label;
}

class FeedingLog {
  final String id;
  final DateTime start;
  final int minutes;
  final FeedSide side;
  final int? amountMl; // 搾乳量 or ミルク量
  final String? memo;
  final String source; // 手入力 / 搾乳器連携

  FeedingLog({
    required this.id,
    required this.start,
    required this.minutes,
    required this.side,
    this.amountMl,
    this.memo,
    this.source = '手入力',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'start': start.toIso8601String(),
    'minutes': minutes,
    'side': side.index,
    'amountMl': amountMl,
    'memo': memo,
    'source': source,
  };

  factory FeedingLog.fromMap(Map map) => FeedingLog(
    id: map['id'] as String,
    start: DateTime.parse(map['start'] as String),
    minutes: (map['minutes'] ?? 0) as int,
    side: FeedSide.values[(map['side'] ?? 0) as int],
    amountMl: map['amountMl'] as int?,
    memo: map['memo'] as String?,
    source: (map['source'] ?? '手入力') as String,
  );
}

/// 乳房セルフ観察記録
class BreastCheck {
  final String id;
  final DateTime date;
  final List<String> symptoms; // しこり / 赤み / 痛み / 熱感 ...
  final int painLevel; // 0-5
  final String? memo;

  BreastCheck({
    required this.id,
    required this.date,
    required this.symptoms,
    this.painLevel = 0,
    this.memo,
  });

  /// 乳腺炎リスク判定
  String get risk {
    final s = symptoms;
    final hot = s.contains('熱感') || s.contains('発熱');
    final red = s.contains('赤み');
    final lump = s.contains('しこり');
    if ((hot && red) || painLevel >= 4) return 'high';
    if (lump || red || painLevel >= 2) return 'mid';
    return 'low';
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'date': date.toIso8601String(),
    'symptoms': symptoms,
    'painLevel': painLevel,
    'memo': memo,
  };

  factory BreastCheck.fromMap(Map map) => BreastCheck(
    id: map['id'] as String,
    date: DateTime.parse(map['date'] as String),
    symptoms: List<String>.from(map['symptoms'] as List),
    painLevel: (map['painLevel'] ?? 0) as int,
    memo: map['memo'] as String?,
  );
}

/// 電子カルテ（SOAP形式・母乳ケア特化）
class CareRecord {
  final String id;
  final String motherName;
  final String facilityName;
  final DateTime date;
  final PlanKind kind;
  final String subjective; // S
  final String objective; // O
  final String assessment; // A
  final String plan; // P
  final String? breastNote; // 乳房・母乳ケア所見
  final String recorder; // 記録者（助産師）

  CareRecord({
    required this.id,
    required this.motherName,
    required this.facilityName,
    required this.date,
    required this.kind,
    required this.subjective,
    required this.objective,
    required this.assessment,
    required this.plan,
    this.breastNote,
    required this.recorder,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'motherName': motherName,
    'facilityName': facilityName,
    'date': date.toIso8601String(),
    'kind': kind.index,
    'subjective': subjective,
    'objective': objective,
    'assessment': assessment,
    'plan': plan,
    'breastNote': breastNote,
    'recorder': recorder,
  };

  factory CareRecord.fromMap(Map map) => CareRecord(
    id: map['id'] as String,
    motherName: (map['motherName'] ?? '') as String,
    facilityName: (map['facilityName'] ?? '') as String,
    date: DateTime.parse(map['date'] as String),
    kind: PlanKind.values[(map['kind'] ?? 0) as int],
    subjective: (map['subjective'] ?? '') as String,
    objective: (map['objective'] ?? '') as String,
    assessment: (map['assessment'] ?? '') as String,
    plan: (map['plan'] ?? '') as String,
    breastNote: map['breastNote'] as String?,
    recorder: (map['recorder'] ?? '') as String,
  );
}

/// 通知
enum NotifyKind {
  reminder('リマインド', Icons.alarm_rounded, Color(0xFFF8C8D6)),
  booking('予約', Icons.event_available_rounded, Color(0xFFB7D0B5)),
  alert('健康アラート', Icons.warning_amber_rounded, Color(0xFFF6D9A8)),
  midwife('助産師より', Icons.volunteer_activism_outlined, Color(0xFFC9BEE6)),
  info('お知らせ', Icons.campaign_outlined, Color(0xFFB0E0E6));

  const NotifyKind(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

class AppNotification {
  final String id;
  final NotifyKind kind;
  final String title;
  final String body;
  final DateTime time;
  bool read;
  final String channel; // LINE / プッシュ

  AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.time,
    this.read = false,
    this.channel = 'プッシュ',
  });
}

/// AI→助産師エスカレーション
class Escalation {
  final String id;
  final DateTime time;
  final String reason;
  final String detail;
  final String severity; // high / mid
  String status; // 受付 / 対応中 / 完了
  final String midwife;

  Escalation({
    required this.id,
    required this.time,
    required this.reason,
    required this.detail,
    required this.severity,
    this.status = '受付',
    this.midwife = '助産師 みなみ',
  });
}

/// 助産師側：報酬・請求
class Invoice {
  final String id;
  final String month; // 'yyyy-MM'
  final String payer; // 自治体名 / 自費
  final int cases;
  final int amount;
  String status; // 未請求 / 請求済 / 入金済

  Invoice({
    required this.id,
    required this.month,
    required this.payer,
    required this.cases,
    required this.amount,
    this.status = '未請求',
  });
}

/// 記事（おすすめコラム）
class Article {
  final String id;
  final String title;
  final String category;
  final String readMin;
  final String body;
  final Color color;
  final IconData icon;

  const Article({
    required this.id,
    required this.title,
    required this.category,
    required this.readMin,
    required this.body,
    required this.color,
    required this.icon,
  });
}

/// EPDS 質問（エジンバラ産後うつ病自己評価票 10項目）
class EpdsQuestion {
  final String text;
  final List<String> choices; // 0→3点の順
  final bool reversed; // 選択肢の並びが逆（点数昇順）

  const EpdsQuestion(this.text, this.choices, {this.reversed = false});
}

const epdsQuestions = <EpdsQuestion>[
  EpdsQuestion('笑うことができたし、物事の面白い面もわかった', [
    'いつもと同様にできた',
    'あまりできなかった',
    '明らかにできなかった',
    'まったくできなかった',
  ]),
  EpdsQuestion('物事を楽しみにして待った', [
    'いつもと同様にできた',
    'あまりできなかった',
    '明らかにできなかった',
    'ほとんどできなかった',
  ]),
  EpdsQuestion('物事がうまくいかない時、自分を不必要に責めた', [
    'はい、たいていそうだった',
    'はい、時々そうだった',
    'いいえ、あまり度々ではない',
    'いいえ、そうではなかった',
  ]),
  EpdsQuestion('はっきりした理由もないのに不安になったり、心配した', [
    'いいえ、そうではなかった',
    'ほとんどそうではなかった',
    'はい、時々あった',
    'はい、しょっちゅうあった',
  ]),
  EpdsQuestion('はっきりした理由もないのに恐怖に襲われた', [
    'いいえ、そうではなかった',
    'いいえ、あまりなかった',
    'はい、時々あった',
    'はい、しょっちゅうあった',
  ]),
  EpdsQuestion('することがたくさんあって大変だった', [
    'いいえ、いつもうまく対処できた',
    'いいえ、たいていうまく対処した',
    'はい、いつものようにはうまく対処できなかった',
    'はい、ほとんど対処できなかった',
  ]),
  EpdsQuestion('不幸なので、眠りにくかった', [
    'いいえ、そうではなかった',
    'いいえ、あまりなかった',
    'はい、時々あった',
    'はい、ほとんどいつもそうだった',
  ]),
  EpdsQuestion('悲しくなったり、惨めになった', [
    'いいえ、そうではなかった',
    'いいえ、あまり度々ではない',
    'はい、かなりしばしば',
    'はい、たいていそうだった',
  ]),
  EpdsQuestion('不幸なので、泣けてきた', [
    'いいえ、そうではなかった',
    'ほんの時々あった',
    'はい、かなりしばしば',
    'はい、たいていそうだった',
  ]),
  EpdsQuestion('自分自身を傷つけるという考えが浮かんできた', [
    'まったくなかった',
    'めったになかった',
    '時々そうだった',
    'はい、かなりしばしば',
  ]),
];

/// 初回問診（9項目）
const firstIntakeQuestions = <String, List<String>>{
  '出産方法': ['自然分娩', '帝王切開', '吸引・鉗子分娩'],
  '産後の経過週数': ['産後1週以内', '産後2〜4週', '産後1〜2ヶ月', '産後3ヶ月以降'],
  '赤ちゃんの授乳方法': ['母乳のみ', '母乳＋ミルク', 'ミルクのみ'],
  '母乳・乳房の状態': ['問題なし', '出が少ない', '張り・痛みがある', 'しこりがある'],
  '睡眠時間（1日）': ['6時間以上', '4〜6時間', '2〜4時間', '2時間未満'],
  '日中の主な育児者': ['自分ひとり', '家族と分担', '里帰り中', 'その他'],
  '身体の回復': ['順調', '傷が痛む', '悪露が続く', '腰痛・肩の痛み'],
  'こころの状態': ['落ち着いている', 'ときどき不安', 'ずっと不安', '涙が出る'],
  '今回ご相談したいこと': ['母乳・授乳', '赤ちゃんの体重・発育', '自分の休息', 'こころのケア', '沐浴・お世話'],
};

/// 授乳姿勢ガイド
class LatchGuide {
  final String name;
  final String point;
  final String detail;
  final IconData icon;
  final Color color;
  const LatchGuide(this.name, this.point, this.detail, this.icon, this.color);
}

const latchGuides = <LatchGuide>[
  LatchGuide(
    '横抱き（基本）',
    'おっぱいと赤ちゃんの口が一直線',
    '赤ちゃんの耳・肩・腰が一直線になるように。ママの腕とクッションで赤ちゃんの高さを乳首の位置に合わせます。深く含ませると痛みが軽くなります。',
    Icons.child_care_rounded,
    Color(0xFFF8C8D6),
  ),
  LatchGuide(
    '交差横抱き',
    '浅飲み・新生児さんに',
    '飲ませる側と反対の手で赤ちゃんの後頭部を支えます。頭のコントロールがしやすく、深く含ませたい時に有効です。',
    Icons.compare_arrows_rounded,
    Color(0xFFC9BEE6),
  ),
  LatchGuide(
    '脇抱き（フットボール）',
    '帝王切開後・乳房外側のしこりに',
    '赤ちゃんを脇に抱えるように。傷にお腹が当たらず、乳房の外側〜下側のつまりを飲み取りやすい姿勢です。',
    Icons.sports_rugby_rounded,
    Color(0xFFB7D0B5),
  ),
  LatchGuide(
    '添い乳',
    '夜間授乳の負担を減らす',
    'ママも横になり、赤ちゃんと向き合います。寝落ちに注意し、周囲に柔らかい物を置きすぎないようにしましょう。',
    Icons.bedtime_outlined,
    Color(0xFFF6D9A8),
  ),
];

/// 参考: 既存の CareType → PlanKind 変換
PlanKind planKindFromCareType(CareType t) {
  switch (t) {
    case CareType.breast:
      return PlanKind.breastClinic;
    case CareType.visit:
      return PlanKind.visit;
    case CareType.online:
      return PlanKind.online;
    case CareType.house:
      return PlanKind.stay;
  }
}

/// オンライン面談（MamaWell型の定期フォロー・Step3）
class OnlineVisit {
  final String id;
  final DateTime at;
  final String topic;
  final String midwife;
  String status; // 予約済 / 完了 / キャンセル
  String? note;

  OnlineVisit({
    required this.id,
    required this.at,
    required this.topic,
    required this.midwife,
    this.status = '予約済',
    this.note,
  });
}

/// RPM 週次レポート（Step3：助産師への定期レポート）
class RpmReport {
  final DateTime from;
  final DateTime to;
  final int measurements;
  final double? avgSystolic;
  final double? avgDiastolic;
  final double? avgPulse;
  final double? avgSleep;
  final double? avgSteps;
  final int alertCount;
  final double feedPerDay;
  final List<String> findings;

  const RpmReport({
    required this.from,
    required this.to,
    required this.measurements,
    this.avgSystolic,
    this.avgDiastolic,
    this.avgPulse,
    this.avgSleep,
    this.avgSteps,
    required this.alertCount,
    required this.feedPerDay,
    required this.findings,
  });

  /// 総合コンディション（0.0〜1.0／高いほど良好）
  double get conditionScore {
    double s = 1.0;
    if (avgSystolic != null && avgSystolic! >= 135) s -= 0.25;
    if (avgSystolic != null && avgSystolic! >= 145) s -= 0.15;
    if (alertCount > 0) s -= 0.10 * alertCount.clamp(0, 3);
    if (avgSleep != null && avgSleep! < 5) s -= 0.15;
    if (feedPerDay > 0 && feedPerDay < 8) s -= 0.05;
    return s.clamp(0.0, 1.0);
  }

  String get conditionLabel {
    final s = conditionScore;
    if (s >= 0.85) return 'とても順調です';
    if (s >= 0.6) return 'おおむね順調です';
    if (s >= 0.4) return '少し気をつけたい状態です';
    return '助産師のサポートをおすすめします';
  }
}
