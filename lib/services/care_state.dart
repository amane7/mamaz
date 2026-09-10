import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/facility.dart';
import 'ai_midwife.dart';
import 'seed_data.dart';

/// MAMOA の拡張ケア機能（予約・問診・RPM・母乳ケア・カルテ・通知）の状態。
///
/// AppState と分離して管理し、main.dart で MultiProvider として提供する。
class CareState extends ChangeNotifier {
  static const _uuid = Uuid();

  late Box _bookingBox;
  late Box _intakeBox;
  late Box _vitalBox;
  late Box _feedBox;
  late Box _breastBox;
  late Box _recordBox;
  late Box _prefsBox;

  final List<Booking> _bookings = [];
  final List<IntakeForm> _intakes = [];
  final List<VitalReading> _vitals = [];
  final List<FeedingLog> _feeds = [];
  final List<BreastCheck> _breastChecks = [];
  final List<CareRecord> _careRecords = [];
  final List<AppNotification> _notifications = [];
  final List<Escalation> _escalations = [];
  final List<Invoice> _invoices = [];
  late List<WearableDevice> _devices;

  // 自治体産後ケア事業の利用回数
  int subsidyDayCareLimit = 4;
  int subsidyStayLimit = 7;
  int subsidyVisitLimit = 3;
  String municipality = '世田谷区';

  bool midwifeMode = false; // 助産師モード

  /// 出産日（産後週数の算出に使用）
  DateTime? birthDate;

  /// オンライン面談（MamaWell型）の予定
  final List<OnlineVisit> _visits = [];

  // ---------------- init ----------------
  Future<void> init() async {
    _bookingBox = await Hive.openBox('bookings');
    _intakeBox = await Hive.openBox('intakes');
    _vitalBox = await Hive.openBox('vitals');
    _feedBox = await Hive.openBox('feeds');
    _breastBox = await Hive.openBox('breastChecks');
    _recordBox = await Hive.openBox('careRecords');
    _prefsBox = await Hive.openBox('carePrefs');

    municipality =
        _prefsBox.get('municipality', defaultValue: '世田谷区') as String;

    final bd = _prefsBox.get('birthDate');
    if (bd is String) {
      birthDate = DateTime.tryParse(bd);
    }
    // 初回起動時は「産後3週」相当をデモ値として設定
    birthDate ??= DateTime.now().subtract(const Duration(days: 22));

    for (final v in _bookingBox.values) {
      _bookings.add(Booking.fromMap(Map<String, dynamic>.from(v as Map)));
    }
    for (final v in _intakeBox.values) {
      _intakes.add(IntakeForm.fromMap(Map<String, dynamic>.from(v as Map)));
    }
    for (final v in _vitalBox.values) {
      _vitals.add(VitalReading.fromMap(Map<String, dynamic>.from(v as Map)));
    }
    for (final v in _feedBox.values) {
      _feeds.add(FeedingLog.fromMap(Map<String, dynamic>.from(v as Map)));
    }
    for (final v in _breastBox.values) {
      _breastChecks.add(
        BreastCheck.fromMap(Map<String, dynamic>.from(v as Map)),
      );
    }
    for (final v in _recordBox.values) {
      _careRecords.add(CareRecord.fromMap(Map<String, dynamic>.from(v as Map)));
    }

    _devices = seedDevices();

    if (_vitals.isEmpty) _seedVitals();
    if (_feeds.isEmpty) _seedFeeds();
    if (_careRecords.isEmpty) _seedCareRecords();
    _seedNotifications();
    _seedInvoices();
    _seedVisits();

    notifyListeners();
  }

  // ---------------- 産後週数（Step3の個別化の基礎） ----------------
  void setBirthDate(DateTime d) {
    birthDate = d;
    _prefsBox.put('birthDate', d.toIso8601String());
    notifyListeners();
  }

  int get postpartumDays => birthDate == null
      ? 0
      : DateTime.now().difference(birthDate!).inDays.clamp(0, 100000);

  int get postpartumWeeks => (postpartumDays / 7).floor();

  String get postpartumLabel {
    if (birthDate == null) return '産後';
    final d = postpartumDays;
    if (d < 7) return '産後$d日目';
    final m = (d / 30.4).floor();
    if (m >= 2) return '産後$mヶ月';
    return '産後$postpartumWeeks週目';
  }

  /// 産後の時期に応じた、そのときに一番役立つひとこと。
  String get stageMessage {
    final d = postpartumDays;
    if (d <= 7) {
      return 'いまはとにかく横になる時期です。'
          '身体は出産という大仕事の直後。家事は後回しにして大丈夫です。';
    }
    if (d <= 21) {
      return 'ホルモンの変化で涙が出やすい時期です。'
          '気分の波は「弱さ」ではなく、からだの自然な反応です。';
    }
    if (d <= 42) {
      return '身体の回復が進む一方、血圧が新たに上がることもある時期。'
          '週に数回の測定をおすすめします。';
    }
    if (d <= 90) {
      return '授乳のリズムが少し整ってくる頃。'
          '「自分のための30分」を予定として入れてみませんか。';
    }
    return 'ここまで育ててこられたこと、本当にすごいことです。'
        '無理なく、続けられるペースを一緒に探しましょう。';
  }

  /// AIに渡す母親コンテキスト（Step3の個別化）
  MotherContext motherContext(String motherName) {
    final v = latestVital;
    final bc = breastChecks.isEmpty ? null : breastChecks.first;
    final nb = nextBooking;
    return MotherContext(
      motherName: motherName,
      postpartumWeeks: birthDate == null ? null : postpartumWeeks,
      latestEpds: latestEpds,
      systolic: v?.systolic,
      diastolic: v?.diastolic,
      temperature: v?.temperature,
      breastRisk: bc?.risk,
      todayFeedCount: todayFeedCount,
      sleepHours: v?.sleepHours,
      hasUpcomingBooking: nb != null,
      nextBookingLabel: nb == null
          ? null
          : '${_fmt(nb.dateTime)}の${nb.kind.label}',
    );
  }

  // ---------------- 施設 ----------------
  List<Facility> get facilities => seedFacilities;

  List<Article> get articles => seedArticles;

  Facility facilityById(String id) => seedFacilities.firstWhere(
    (f) => f.id == id,
    orElse: () => seedFacilities.first,
  );

  /// 施設検索（キーワード・種別・助成対象・並び替え）
  List<Facility> searchFacilities({
    String keyword = '',
    PlanKind? kind,
    bool subsidyOnly = false,
    String sort = 'distance', // distance / rating / price
  }) {
    var list = seedFacilities.where((f) {
      if (kind != null && !f.kinds.contains(kind)) return false;
      if (subsidyOnly && !f.subsidyAvailable) return false;
      if (keyword.trim().isEmpty) return true;
      final k = keyword.trim();
      return f.name.contains(k) ||
          f.area.contains(k) ||
          f.features.any((e) => e.contains(k)) ||
          f.midwifeName.contains(k);
    }).toList();

    switch (sort) {
      case 'rating':
        list.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'price':
        list.sort((a, b) => _minPay(a).compareTo(_minPay(b)));
        break;
      default:
        list.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    }
    return list;
  }

  int _minPay(Facility f) =>
      f.plans.map((p) => p.payAmount).reduce((a, b) => a < b ? a : b);

  /// 施設・日付から30分刻みの空き枠を生成（ダブルブッキング防止込み）
  List<TimeSlot> slotsFor(Facility f, DateTime day, PlanKind kind) {
    if (kind == PlanKind.stay) {
      return const [TimeSlot('14:00', true), TimeSlot('15:00', true)];
    }
    final base = <String>[
      '09:00',
      '09:30',
      '10:00',
      '10:30',
      '11:00',
      '11:30',
      '13:00',
      '13:30',
      '14:00',
      '14:30',
      '15:00',
      '15:30',
      '16:00',
      '16:30',
    ];
    if (kind == PlanKind.online) {
      base.addAll(['18:00', '18:30', '19:00', '19:30', '20:00']);
    }
    // 施設ID+日付をシードに擬似的な空き状況を作る（毎回同じ結果になる）
    final seed = f.id.hashCode ^ (day.year * 10000 + day.month * 100 + day.day);
    final rnd = Random(seed);
    final booked = _bookings
        .where(
          (b) =>
              b.facilityId == f.id &&
              b.status != 'キャンセル' &&
              b.dateTime.year == day.year &&
              b.dateTime.month == day.month &&
              b.dateTime.day == day.day,
        )
        .map(
          (b) =>
              '${b.dateTime.hour.toString().padLeft(2, '0')}:${b.dateTime.minute.toString().padLeft(2, '0')}',
        )
        .toSet();

    return base.map((t) {
      if (booked.contains(t)) return TimeSlot(t, false);
      final ok = rnd.nextDouble() > 0.28;
      return TimeSlot(t, ok);
    }).toList();
  }

  bool hasAvailability(Facility f, DateTime day, PlanKind kind) =>
      slotsFor(f, day, kind).any((s) => s.available);

  /// 直近で空きのある日
  DateTime? nextAvailableDay(Facility f, PlanKind? kind) {
    final k = kind ?? f.kinds.first;
    for (var i = 1; i <= 14; i++) {
      final d = DateTime.now().add(Duration(days: i));
      if (hasAvailability(f, d, k)) return d;
    }
    return null;
  }

  // ---------------- 予約 ----------------
  List<Booking> get bookings {
    final l = List<Booking>.from(_bookings);
    l.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return l;
  }

  List<Booking> get upcomingBookings => bookings
      .where((b) => b.dateTime.isAfter(DateTime.now()) && b.status != 'キャンセル')
      .toList();

  List<Booking> get pastBookings => bookings
      .where((b) => !b.dateTime.isAfter(DateTime.now()))
      .toList()
      .reversed
      .toList();

  Booking? get nextBooking =>
      upcomingBookings.isEmpty ? null : upcomingBookings.first;

  Booking createBooking({
    required Facility facility,
    required CarePlan plan,
    required DateTime dateTime,
    required PayMethod payMethod,
    bool useSubsidy = true,
  }) {
    final amount = useSubsidy && facility.subsidyAvailable
        ? plan.payAmount
        : plan.price;
    final b = Booking(
      id: _uuid.v4(),
      facilityId: facility.id,
      facilityName: facility.name,
      kind: plan.kind,
      planName: plan.name,
      dateTime: dateTime,
      hours: plan.hours,
      amount: amount,
      payMethod: payMethod,
      status: plan.kind == PlanKind.visit ? '調整中' : '確定',
    );
    _bookings.add(b);
    _bookingBox.put(b.id, b.toMap());

    if (useSubsidy && facility.subsidyAvailable) {
      switch (plan.kind) {
        case PlanKind.dayCare:
          if (subsidyDayCareLimit > 0) subsidyDayCareLimit--;
          break;
        case PlanKind.stay:
          if (subsidyStayLimit > 0) subsidyStayLimit--;
          break;
        case PlanKind.visit:
          if (subsidyVisitLimit > 0) subsidyVisitLimit--;
          break;
        default:
          break;
      }
    }

    pushNotification(
      NotifyKind.booking,
      '予約が完了しました',
      '${facility.name} / ${plan.name}\n${_fmt(dateTime)}',
      channel: 'LINE',
    );
    pushNotification(
      NotifyKind.reminder,
      '前日リマインドを設定しました',
      '${_fmt(dateTime)} のケアの前日と当日朝に、公式LINEでお知らせします。',
      channel: 'LINE',
    );
    notifyListeners();
    return b;
  }

  void cancelBooking(String id) {
    final b = _bookings.firstWhere((e) => e.id == id);
    b.status = 'キャンセル';
    _bookingBox.put(b.id, b.toMap());
    pushNotification(
      NotifyKind.booking,
      '予約をキャンセルしました',
      '${b.facilityName} / ${_fmt(b.dateTime)}',
    );
    notifyListeners();
  }

  void markIntakeDone(String bookingId) {
    final i = _bookings.indexWhere((e) => e.id == bookingId);
    if (i < 0) return;
    _bookings[i].intakeDone = true;
    _bookingBox.put(_bookings[i].id, _bookings[i].toMap());
    notifyListeners();
  }

  void approveBooking(String id) {
    final b = _bookings.firstWhere((e) => e.id == id);
    b.status = '確定';
    _bookingBox.put(b.id, b.toMap());
    pushNotification(
      NotifyKind.midwife,
      '訪問日程が確定しました',
      '${b.facilityName} の助産師が ${_fmt(b.dateTime)} にうかがいます。',
    );
    notifyListeners();
  }

  String _fmt(DateTime d) =>
      '${d.month}月${d.day}日 ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  // ---------------- 問診票 ----------------
  List<IntakeForm> get intakes {
    final l = List<IntakeForm>.from(_intakes);
    l.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return l;
  }

  IntakeForm? latestIntake(IntakeKind kind) {
    final l = intakes.where((e) => e.kind == kind);
    return l.isEmpty ? null : l.first;
  }

  bool get hasFirstIntake => latestIntake(IntakeKind.first) != null;

  void submitIntake(
    IntakeKind kind,
    Map<String, String> answers, {
    int? epdsScore,
    bool signed = false,
  }) {
    final f = IntakeForm(
      id: _uuid.v4(),
      kind: kind,
      submittedAt: DateTime.now(),
      answers: answers,
      epdsScore: epdsScore,
      signed: signed,
    );
    _intakes.add(f);
    _intakeBox.put(f.id, f.toMap());

    pushNotification(
      NotifyKind.info,
      '${kind.label}を提出しました',
      '助産師が事前に内容を確認し、当日のケアに活かします。',
    );

    if (epdsScore != null && epdsScore >= 9) {
      addEscalation(
        reason: 'EPDS $epdsScore点（9点以上）',
        detail: 'こころの状態のスクリーニングで基準を超えました。助産師による面談をご案内します。',
        severity: epdsScore >= 13 ? 'high' : 'mid',
      );
    }
    notifyListeners();
  }

  /// EPDS スコア履歴（新しい順）
  List<IntakeForm> get epdsHistory =>
      intakes.where((e) => e.epdsScore != null).toList();

  int? get latestEpds =>
      epdsHistory.isEmpty ? null : epdsHistory.first.epdsScore;

  static String epdsJudgement(int score) {
    if (score >= 13) return '高リスク：早めに助産師・医師へご相談ください';
    if (score >= 9) return '要注意：助産師のサポートをおすすめします';
    return '現在は基準内：引き続き様子を見ましょう';
  }

  // ---- EPDS 定期スクリーニング（Step3：産後うつの継続的把握） ----

  /// 推奨実施タイミング（産後日数）：2週・1ヶ月・2ヶ月・3ヶ月・6ヶ月
  static const epdsMilestoneDays = [14, 30, 60, 90, 180];

  DateTime? get lastEpdsDate =>
      epdsHistory.isEmpty ? null : epdsHistory.first.submittedAt;

  int? get daysSinceEpds => lastEpdsDate == null
      ? null
      : DateTime.now().difference(lastEpdsDate!).inDays;

  /// 次に受けるとよいタイミング（産後日数）
  int? get nextEpdsMilestone {
    final d = postpartumDays;
    for (final m in epdsMilestoneDays) {
      if (d < m) return m;
    }
    return null;
  }

  /// いまスクリーニングをおすすめすべきか
  bool get epdsDue {
    if (epdsHistory.isEmpty) return postpartumDays >= 10;
    final since = daysSinceEpds ?? 0;
    if (latestEpds != null && latestEpds! >= 9) return since >= 14; // 要注意なら2週ごと
    return since >= 28; // 通常は月1回
  }

  String get epdsDueMessage {
    if (epdsHistory.isEmpty) {
      return 'はじめてのこころのセルフチェックです。10問・約2分。'
          '「いま」を知ることが、いちばん確かな一歩になります。';
    }
    final since = daysSinceEpds ?? 0;
    if (latestEpds != null && latestEpds! >= 9) {
      return '前回は${latestEpds!}点でした。$since日たちました。'
          'そのあとの変化を、一緒に確かめさせてください。';
    }
    return '前回のチェックから$since日。'
        '月に1回のふりかえりが、変化に早く気づくコツです。';
  }

  /// スコアの推移（古い順、最大6件）
  List<int> get epdsTrend {
    final l = epdsHistory.reversed.map((e) => e.epdsScore!).toList();
    return l.length <= 6 ? l : l.sublist(l.length - 6);
  }

  /// 前回との差（マイナスなら改善）
  int? get epdsDelta {
    final h = epdsHistory;
    if (h.length < 2) return null;
    return h.first.epdsScore! - h[1].epdsScore!;
  }

  /// 定期スクリーニングのリマインド通知を積む
  void scheduleEpdsReminder() {
    if (!epdsDue) return;
    final already = _notifications.any(
      (n) =>
          n.title.contains('こころのセルフチェック') &&
          DateTime.now().difference(n.time).inDays < 3,
    );
    if (already) return;
    pushNotification(
      NotifyKind.reminder,
      'こころのセルフチェックの時期です',
      epdsDueMessage,
      channel: 'LINE',
    );
  }

  // ---------------- バイタル / RPM ----------------
  List<VitalReading> get vitals {
    final l = List<VitalReading>.from(_vitals);
    l.sort((a, b) => b.time.compareTo(a.time));
    return l;
  }

  VitalReading? get latestVital => vitals.isEmpty ? null : vitals.first;

  List<VitalReading> get alertVitals =>
      vitals.where((v) => v.hasAlert).toList();

  List<WearableDevice> get devices => List.unmodifiable(_devices);

  void toggleDevice(String id) {
    final d = _devices.firstWhere((e) => e.id == id);
    d.connected = !d.connected;
    if (d.connected) {
      pushNotification(
        NotifyKind.info,
        '${d.name} を連携しました',
        '${d.metrics.join('・')} のデータが自動で取り込まれます。',
      );
    }
    notifyListeners();
  }

  void addVital(VitalReading v) {
    _vitals.add(v);
    _vitalBox.put(v.id, v.toMap());
    if (v.hasAlert) {
      final reasons = <String>[];
      if (v.bpAlert) reasons.add('血圧 ${v.systolic}/${v.diastolic} mmHg');
      if (v.feverAlert) reasons.add('体温 ${v.temperature}℃');
      if (v.pulseAlert) reasons.add('心拍 ${v.pulse} bpm');
      pushNotification(
        NotifyKind.alert,
        '数値が基準を超えました',
        '${reasons.join(' / ')}\n担当助産師に自動通知しました。',
      );
      addEscalation(
        reason: reasons.join(' / '),
        detail: 'ウェアラブル／手入力の測定値が基準値を超えました。助産師が確認します。',
        severity: v.bpAlert && (v.systolic ?? 0) >= 160 ? 'high' : 'mid',
      );
    }
    notifyListeners();
  }

  void addVitalQuick({
    int? systolic,
    int? diastolic,
    int? pulse,
    double? temperature,
    double? weight,
    String source = '手入力',
  }) {
    addVital(
      VitalReading(
        id: _uuid.v4(),
        time: DateTime.now(),
        systolic: systolic,
        diastolic: diastolic,
        pulse: pulse,
        temperature: temperature,
        weight: weight,
        source: source,
      ),
    );
  }

  // ---- RPM 週次レポート（Step3：助産師への定期レポート） ----

  /// 直近7日のバイタルをまとめた週次レポート
  RpmReport get weeklyReport {
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 7));
    final week = _vitals.where((v) => v.time.isAfter(from)).toList();

    double? avg(Iterable<num?> xs) {
      final l = xs.whereType<num>().toList();
      if (l.isEmpty) return null;
      return l.fold<double>(0, (s, e) => s + e) / l.length;
    }

    final sys = avg(week.map((e) => e.systolic));
    final dia = avg(week.map((e) => e.diastolic));
    final pulse = avg(week.map((e) => e.pulse));
    final sleep = avg(week.map((e) => e.sleepHours));
    final steps = avg(week.map((e) => e.steps));
    final alerts = week.where((v) => v.hasAlert).length;

    final feedWeek = _feeds.where((f) => f.start.isAfter(from)).toList();
    final feedPerDay = feedWeek.isEmpty ? 0.0 : feedWeek.length / 7.0;

    final findings = <String>[];
    if (sys != null && sys >= 135) {
      findings.add(
        '収縮期血圧の平均が ${sys.round()} mmHg と高めです。'
        '産後高血圧の可能性があるため、朝晩の測定をおすすめします。',
      );
    }
    if (alerts > 0) {
      findings.add(
        'この1週間で $alerts 回、基準を超えた測定値がありました。'
        '担当助産師にも共有されています。',
      );
    }
    if (sleep != null && sleep < 5) {
      findings.add(
        '睡眠は平均 ${sleep.toStringAsFixed(1)} 時間。'
        '回復には短時間でも「確保された睡眠」が必要です。'
        '通所・宿泊ケアの活用もご検討ください。',
      );
    }
    if (feedPerDay > 0 && feedPerDay < 8) {
      findings.add(
        '授乳回数は1日あたり ${feedPerDay.toStringAsFixed(1)} 回。'
        '分泌を保つ目安は8〜12回です。',
      );
    }
    if (latestEpds != null && latestEpds! >= 9) {
      findings.add(
        '直近のEPDSは ${latestEpds!}点。'
        'こころのケアを含めた面談をおすすめします。',
      );
    }
    if (findings.isEmpty) {
      findings.add(
        'この1週間、大きな異常はありませんでした。'
        'よくご自分のからだを見てあげられています。',
      );
    }

    return RpmReport(
      from: from,
      to: now,
      measurements: week.length,
      avgSystolic: sys,
      avgDiastolic: dia,
      avgPulse: pulse,
      avgSleep: sleep,
      avgSteps: steps,
      alertCount: alerts,
      feedPerDay: feedPerDay,
      findings: findings,
    );
  }

  /// 週次レポートを助産師へ送信（＝通知＋記録）
  void sendWeeklyReport() {
    final r = weeklyReport;
    pushNotification(
      NotifyKind.info,
      '週次レポートを助産師に送信しました',
      '測定${r.measurements}回・アラート${r.alertCount}回。'
          '${r.findings.first}',
      channel: 'LINE',
    );
  }

  /// 直近7日の血圧推移（収縮期）
  List<double> get bpTrend {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      final same = _vitals.where(
        (v) =>
            v.systolic != null &&
            v.time.year == d.year &&
            v.time.month == d.month &&
            v.time.day == d.day,
      );
      if (same.isEmpty) return 0;
      return same.map((e) => e.systolic!).reduce((a, b) => a + b) / same.length;
    });
  }

  // ---------------- 母乳ケア ----------------
  List<FeedingLog> get feeds {
    final l = List<FeedingLog>.from(_feeds);
    l.sort((a, b) => b.start.compareTo(a.start));
    return l;
  }

  List<FeedingLog> feedsOn(DateTime day) => feeds
      .where(
        (f) =>
            f.start.year == day.year &&
            f.start.month == day.month &&
            f.start.day == day.day,
      )
      .toList();

  List<FeedingLog> get todayFeeds => feedsOn(DateTime.now());

  int get todayFeedCount => todayFeeds.length;

  int get todayFeedMinutes => todayFeeds.fold(0, (s, f) => s + f.minutes);

  int get todayPumpMl => todayFeeds.fold(0, (s, f) => s + (f.amountMl ?? 0));

  FeedingLog? get lastFeed => feeds.isEmpty ? null : feeds.first;

  String get sinceLastFeed {
    final f = lastFeed;
    if (f == null) return '記録なし';
    final diff = DateTime.now().difference(f.start);
    if (diff.inMinutes < 60) return '${diff.inMinutes}分前';
    return '${diff.inHours}時間${diff.inMinutes % 60}分前';
  }

  void addFeed({
    required int minutes,
    required FeedSide side,
    int? amountMl,
    String? memo,
    DateTime? start,
    String source = '手入力',
  }) {
    final f = FeedingLog(
      id: _uuid.v4(),
      start: start ?? DateTime.now().subtract(Duration(minutes: minutes)),
      minutes: minutes,
      side: side,
      amountMl: amountMl,
      memo: memo,
      source: source,
    );
    _feeds.add(f);
    _feedBox.put(f.id, f.toMap());
    notifyListeners();
  }

  void deleteFeed(String id) {
    _feeds.removeWhere((e) => e.id == id);
    _feedBox.delete(id);
    notifyListeners();
  }

  /// 搾乳器連携（デモ：直近の搾乳量を取り込む）
  void syncPump() {
    final rnd = Random();
    for (var i = 0; i < 2; i++) {
      addFeed(
        minutes: 15 + rnd.nextInt(8),
        side: FeedSide.both,
        amountMl: 60 + rnd.nextInt(70),
        start: DateTime.now().subtract(Duration(hours: 3 * (i + 1))),
        source: 'Medela 搾乳器',
      );
    }
    pushNotification(NotifyKind.info, '搾乳器のデータを取り込みました', '搾乳量が母乳記録に自動反映されました。');
  }

  List<BreastCheck> get breastChecks {
    final l = List<BreastCheck>.from(_breastChecks);
    l.sort((a, b) => b.date.compareTo(a.date));
    return l;
  }

  void addBreastCheck(List<String> symptoms, int painLevel, String? memo) {
    final c = BreastCheck(
      id: _uuid.v4(),
      date: DateTime.now(),
      symptoms: symptoms,
      painLevel: painLevel,
      memo: memo,
    );
    _breastChecks.add(c);
    _breastBox.put(c.id, c.toMap());

    if (c.risk == 'high') {
      addEscalation(
        reason: '乳腺炎の疑い（${symptoms.join('・')} / 痛み$painLevel）',
        detail: '発熱を伴う赤み・強い痛みがあります。早めの乳房ケア受診をおすすめします。',
        severity: 'high',
      );
      pushNotification(
        NotifyKind.alert,
        '乳腺炎の可能性があります',
        '母乳外来の受診をおすすめします。助産師に共有しました。',
      );
    }
    notifyListeners();
  }

  List<LatchGuide> get latchGuideList => latchGuides;

  // ---------------- カルテ ----------------
  List<CareRecord> get careRecords {
    final l = List<CareRecord>.from(_careRecords);
    l.sort((a, b) => b.date.compareTo(a.date));
    return l;
  }

  void addCareRecord(CareRecord r) {
    _careRecords.add(r);
    _recordBox.put(r.id, r.toMap());
    pushNotification(
      NotifyKind.midwife,
      'カルテが共有されました',
      '${r.facilityName}｜${r.date.month}月${r.date.day}日のケア記録を確認できます。',
    );
    notifyListeners();
  }

  void createCareRecord({
    required String motherName,
    required String facilityName,
    required PlanKind kind,
    required String subjective,
    required String objective,
    required String assessment,
    required String plan,
    String? breastNote,
    required String recorder,
  }) {
    addCareRecord(
      CareRecord(
        id: _uuid.v4(),
        motherName: motherName,
        facilityName: facilityName,
        date: DateTime.now(),
        kind: kind,
        subjective: subjective,
        objective: objective,
        assessment: assessment,
        plan: plan,
        breastNote: breastNote,
        recorder: recorder,
      ),
    );
  }

  // ---------------- 通知 ----------------
  List<AppNotification> get notifications {
    final l = List<AppNotification>.from(_notifications);
    l.sort((a, b) => b.time.compareTo(a.time));
    return l;
  }

  int get unreadCount => _notifications.where((n) => !n.read).length;

  void pushNotification(
    NotifyKind kind,
    String title,
    String body, {
    String channel = 'プッシュ',
  }) {
    _notifications.insert(
      0,
      AppNotification(
        id: _uuid.v4(),
        kind: kind,
        title: title,
        body: body,
        time: DateTime.now(),
        channel: channel,
      ),
    );
    notifyListeners();
  }

  void markAllRead() {
    for (final n in _notifications) {
      n.read = true;
    }
    notifyListeners();
  }

  void markRead(String id) {
    final n = _notifications.firstWhere((e) => e.id == id);
    n.read = true;
    notifyListeners();
  }

  // ---------------- エスカレーション ----------------
  List<Escalation> get escalations {
    final l = List<Escalation>.from(_escalations);
    l.sort((a, b) => b.time.compareTo(a.time));
    return l;
  }

  Escalation? get activeEscalation {
    final l = escalations.where((e) => e.status != '完了');
    return l.isEmpty ? null : l.first;
  }

  Escalation addEscalation({
    required String reason,
    required String detail,
    String severity = 'mid',
  }) {
    final e = Escalation(
      id: _uuid.v4(),
      time: DateTime.now(),
      reason: reason,
      detail: detail,
      severity: severity,
    );
    _escalations.add(e);
    pushNotification(
      NotifyKind.midwife,
      '助産師におつなぎしました',
      '$reason\n担当助産師が確認し、順次ご連絡します。',
      channel: 'LINE',
    );
    notifyListeners();
    return e;
  }

  void updateEscalation(String id, String status) {
    final e = _escalations.firstWhere((x) => x.id == id);
    e.status = status;
    if (status == '対応中') {
      pushNotification(
        NotifyKind.midwife,
        '${e.midwife}が対応を開始しました',
        'いま担当助産師が内容を確認しています。まもなくご連絡します。',
        channel: 'LINE',
      );
    } else if (status == '完了') {
      pushNotification(
        NotifyKind.midwife,
        '${e.midwife}の対応が完了しました',
        '「${e.reason}」について対応を終えました。'
            'その後の変化があれば、いつでも教えてください。',
        channel: 'LINE',
      );
    }
    notifyListeners();
  }

  /// AI相談から助産師へ引き継ぎ（サマリー付き human-in-the-loop）
  Escalation escalateWithHandoff({
    required String reason,
    required String detail,
    required String handoff,
    String severity = 'mid',
  }) {
    final e = addEscalation(
      reason: reason,
      detail: '$detail\n\n$handoff',
      severity: severity,
    );
    return e;
  }

  // ---------------- オンライン面談（MamaWell型・Step3） ----------------
  List<OnlineVisit> get visits {
    final l = List<OnlineVisit>.from(_visits);
    l.sort((a, b) => a.at.compareTo(b.at));
    return l;
  }

  OnlineVisit? get nextVisit {
    final l = visits.where((v) => v.at.isAfter(DateTime.now()));
    return l.isEmpty ? null : l.first;
  }

  OnlineVisit bookVisit({
    required DateTime at,
    required String topic,
    String midwife = '助産師 南田 みなみ',
  }) {
    final v = OnlineVisit(
      id: _uuid.v4(),
      at: at,
      topic: topic,
      midwife: midwife,
    );
    _visits.add(v);
    pushNotification(
      NotifyKind.booking,
      'オンライン面談を予約しました',
      '${_fmt(at)}／$midwife\nビデオ通話のURLは開始10分前にお送りします。',
      channel: 'LINE',
    );
    notifyListeners();
    return v;
  }

  void cancelVisit(String id) {
    final i = _visits.indexWhere((e) => e.id == id);
    if (i < 0) return;
    _visits[i].status = 'キャンセル';
    pushNotification(
      NotifyKind.booking,
      'オンライン面談をキャンセルしました',
      'またご都合のよいときに、いつでもご予約ください。お待ちしています。',
      channel: 'アプリ',
    );
    notifyListeners();
  }

  void completeVisit(String id, {String? note}) {
    final v = _visits.firstWhere((e) => e.id == id);
    v.status = '完了';
    v.note = note;
    notifyListeners();
  }

  void _seedVisits() {
    if (_visits.isNotEmpty) return;
    final now = DateTime.now();
    _visits.add(
      OnlineVisit(
        id: _uuid.v4(),
        at: DateTime(
          now.year,
          now.month,
          now.day,
          14,
        ).add(const Duration(days: 3)),
        topic: '産後1ヶ月の定期フォロー（こころとからだ）',
        midwife: '助産師 南田 みなみ',
      ),
    );
  }

  // ---------------- 助産師モード ----------------
  void setMidwifeMode(bool v) {
    midwifeMode = v;
    notifyListeners();
  }

  List<Invoice> get invoices => List.unmodifiable(_invoices);

  void updateInvoice(String id, String status) {
    final i = _invoices.firstWhere((e) => e.id == id);
    i.status = status;
    notifyListeners();
  }

  /// 産後ケア事業の報酬計算（単価×件数）
  static const municipalUnitPrice = <PlanKind, int>{
    PlanKind.dayCare: 8000,
    PlanKind.stay: 21000,
    PlanKind.visit: 9500,
    PlanKind.breastClinic: 5000,
    PlanKind.online: 2500,
  };

  Map<PlanKind, int> get monthlyCaseCount {
    final now = DateTime.now();
    final map = <PlanKind, int>{};
    for (final b in _bookings) {
      if (b.status == 'キャンセル') continue;
      if (b.dateTime.year == now.year && b.dateTime.month == now.month) {
        map[b.kind] = (map[b.kind] ?? 0) + 1;
      }
    }
    // デモ用のベース件数を加算（施設運営の実感を出すため）
    const base = {
      PlanKind.dayCare: 12,
      PlanKind.stay: 5,
      PlanKind.visit: 8,
      PlanKind.breastClinic: 21,
      PlanKind.online: 14,
    };
    for (final e in base.entries) {
      map[e.key] = (map[e.key] ?? 0) + e.value;
    }
    return map;
  }

  int get monthlyRevenue => monthlyCaseCount.entries.fold(
    0,
    (s, e) => s + (municipalUnitPrice[e.key] ?? 0) * e.value,
  );

  int get monthlyCases => monthlyCaseCount.values.fold(0, (s, e) => s + e);

  // ---------------- Seeds ----------------
  void _seedVitals() {
    final now = DateTime.now();
    final sys = [118, 122, 126, 131, 128, 142, 124];
    final dia = [74, 78, 80, 84, 82, 91, 79];
    final pul = [78, 82, 85, 88, 84, 96, 80];
    for (var i = 0; i < 7; i++) {
      final t = DateTime(
        now.year,
        now.month,
        now.day,
        8,
      ).subtract(Duration(days: 6 - i));
      final v = VitalReading(
        id: _uuid.v4(),
        time: t,
        systolic: sys[i],
        diastolic: dia[i],
        pulse: pul[i],
        temperature: 36.4 + (i % 3) * 0.2,
        weight: 58.4 - i * 0.15,
        sleepHours: 4.5 + (i % 3) * 0.6,
        steps: 2400 + i * 320,
        source: i.isEven ? 'Withings BPM' : 'Apple Watch',
      );
      _vitals.add(v);
      _vitalBox.put(v.id, v.toMap());
    }
  }

  void _seedFeeds() {
    final now = DateTime.now();
    final hours = [1, 4, 7, 10, 13, 16, 20];
    for (var i = 0; i < hours.length; i++) {
      final t = DateTime(now.year, now.month, now.day, hours[i], 15);
      if (t.isAfter(now)) continue;
      final f = FeedingLog(
        id: _uuid.v4(),
        start: t,
        minutes: 12 + (i % 4) * 3,
        side: FeedSide.values[i % 3],
        amountMl: i.isEven ? null : 70 + i * 8,
      );
      _feeds.add(f);
      _feedBox.put(f.id, f.toMap());
    }
  }

  void _seedCareRecords() {
    final now = DateTime.now();
    final r = CareRecord(
      id: _uuid.v4(),
      motherName: 'ママ',
      facilityName: 'ママズケア 助産院',
      date: now.subtract(const Duration(days: 6)),
      kind: PlanKind.breastClinic,
      subjective: '右乳房の外側にしこりと痛み。夜間授乳で3時間おきに起きている。眠れず疲労感が強い。',
      objective: '体温36.8℃、血圧118/74。右乳房外側上部に硬結あり、発赤軽度。乳頭に亀裂なし。授乳姿勢は横抱きで浅飲み傾向。',
      assessment: '乳管閉塞（初期）。浅飲みによる乳房内の残乳が要因と考えられる。乳腺炎への移行に注意。',
      plan:
          '脇抱きでの授乳を指導。授乳前の温罨法と授乳後の冷却を説明。3日以内に硬結が改善しない、または38℃以上の発熱時は再受診。次回は5日後に経過確認。',
      breastNote: '硬結：右C領域 3cm。マッサージ後に軽減。搾乳量 左70ml / 右50ml。',
      recorder: '助産師 南田 みなみ',
    );
    _careRecords.add(r);
    _recordBox.put(r.id, r.toMap());
  }

  void _seedNotifications() {
    if (_notifications.isNotEmpty) return;
    _notifications.addAll([
      AppNotification(
        id: _uuid.v4(),
        kind: NotifyKind.midwife,
        title: '助産師 みなみさんからメッセージ',
        body: '先日の乳房ケアのその後はいかがですか？しこりが残っていたら早めに教えてくださいね。',
        time: DateTime.now().subtract(const Duration(hours: 3)),
        channel: 'LINE',
      ),
      AppNotification(
        id: _uuid.v4(),
        kind: NotifyKind.info,
        title: '$municipality の産後ケア事業のお知らせ',
        body: '通所ケアの助成回数が4回分ご利用可能です。有効期限は産後4ヶ月までです。',
        time: DateTime.now().subtract(const Duration(days: 1)),
      ),
      AppNotification(
        id: _uuid.v4(),
        kind: NotifyKind.alert,
        title: '血圧が基準を超えました',
        body: '2日前の測定で142/91 mmHg を記録しています。担当助産師に共有済みです。',
        time: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ]);
  }

  void _seedInvoices() {
    if (_invoices.isNotEmpty) return;
    final now = DateTime.now();
    String m(int back) {
      final d = DateTime(now.year, now.month - back);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}';
    }

    _invoices.addAll([
      Invoice(
        id: _uuid.v4(),
        month: m(0),
        payer: '$municipality 産後ケア事業',
        cases: 25,
        amount: 268000,
        status: '未請求',
      ),
      Invoice(
        id: _uuid.v4(),
        month: m(0),
        payer: '自費（母乳外来・オンライン）',
        cases: 35,
        amount: 140000,
        status: '未請求',
      ),
      Invoice(
        id: _uuid.v4(),
        month: m(1),
        payer: '$municipality 産後ケア事業',
        cases: 22,
        amount: 241000,
        status: '入金済',
      ),
      Invoice(
        id: _uuid.v4(),
        month: m(1),
        payer: '川崎市 産後ケア事業',
        cases: 9,
        amount: 96000,
        status: '請求済',
      ),
    ]);
  }
}
