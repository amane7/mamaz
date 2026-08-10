import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';

/// Central app state backed by Hive local storage.
class AppState extends ChangeNotifier {
  static const _uuid = Uuid();

  late Box _recordBox;
  late Box _chatBox;
  late Box _reservationBox;
  late Box _prefsBox;

  final Map<String, DailyRecord> _records = {};
  final List<ChatMessage> _messages = [];
  final List<Reservation> _reservations = [];
  late List<CommunityPost> _posts;

  String motherName = 'ママ';

  // ---- init ----
  Future<void> init() async {
    await Hive.initFlutter();
    _recordBox = await Hive.openBox('records');
    _chatBox = await Hive.openBox('chat');
    _reservationBox = await Hive.openBox('reservations');
    _prefsBox = await Hive.openBox('prefs');

    motherName = _prefsBox.get('motherName', defaultValue: 'ママ') as String;

    // load records
    for (final v in _recordBox.values) {
      final r = DailyRecord.fromMap(Map<String, dynamic>.from(v as Map));
      _records[r.dateKey] = r;
    }
    // load chat
    for (final v in _chatBox.values) {
      _messages.add(ChatMessage.fromMap(Map<String, dynamic>.from(v as Map)));
    }
    if (_messages.isEmpty) {
      _seedChat();
    }
    // load reservations
    for (final v in _reservationBox.values) {
      _reservations
          .add(Reservation.fromMap(Map<String, dynamic>.from(v as Map)));
    }
    _seedCommunity();

    // seed a little record data so journal/home look alive on first run
    if (_records.isEmpty) {
      _seedRecords();
    }
    notifyListeners();
  }

  // ---- mother name ----
  void setMotherName(String name) {
    motherName = name.trim().isEmpty ? 'ママ' : name.trim();
    _prefsBox.put('motherName', motherName);
    notifyListeners();
  }

  // ---------------- Records ----------------
  static String keyFor(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DailyRecord recordFor(DateTime date) {
    final k = keyFor(date);
    return _records[k] ??
        DailyRecord(date: DateTime(date.year, date.month, date.day));
  }

  DailyRecord get today => recordFor(DateTime.now());

  Map<String, DailyRecord> get allRecords => _records;

  bool hasRecord(DateTime date) {
    final r = _records[keyFor(date)];
    if (r == null) return false;
    return r.feedingCount > 0 || r.sleepHours > 0 || r.mood != null;
  }

  void saveRecord(DailyRecord record) {
    _records[record.dateKey] = record;
    _recordBox.put(record.dateKey, record.toMap());
    notifyListeners();
  }

  /// Last [days] of records ending today, ordered oldest->newest.
  List<DailyRecord> recentRecords(int days) {
    final now = DateTime.now();
    return List.generate(days, (i) {
      final d = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: days - 1 - i));
      return recordFor(d);
    });
  }

  // ---------------- Chat ----------------
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  void _seedChat() {
    final intro = ChatMessage(
      text:
          'こんにちは、$motherName。\nわたしはゆりかごの妖精「MOA」です。\n授乳や眠り、こころのことなど、深夜でもいつでもそばにいます。どんな小さなことでも、気軽に話してくださいね。',
      isUser: false,
      time: DateTime.now().subtract(const Duration(minutes: 5)),
    );
    _messages.add(intro);
    _chatBox.add(intro.toMap());
  }

  void addUserMessage(String text) {
    final msg = ChatMessage(text: text, isUser: true);
    _messages.add(msg);
    _chatBox.add(msg.toMap());
    notifyListeners();
  }

  void addSoraMessage(String text) {
    final msg = ChatMessage(text: text, isUser: false);
    _messages.add(msg);
    _chatBox.add(msg.toMap());
    notifyListeners();
  }

  /// Very lightweight rule-based reply for the cradle fairy "MOA".
  /// (本番ではママズケアの知見をRAGで学習したAIに接続)
  String soraReply(String input) {
    if (_match(input, ['つらい', 'しんどい', '泣', '不安', '孤独', '疲れ'])) {
      return 'ここまで本当によくがんばってきましたね。$motherName、ひとりで抱え込まなくて大丈夫です。深呼吸を3回、ゆっくりしてみましょう。よければ今の気持ちをもう少し聞かせてください。必要なときは、すぐに人の助産師へおつなぎします。';
    }
    if (_match(input, ['母乳', '授乳', 'おっぱい', '乳房', '張'])) {
      return '授乳のお悩みですね。乳房が張って痛むときは、温めてから少し搾ってみると楽になることがあります。痛みや赤み、しこりが続く場合は乳房ケアの受診をおすすめします。アプリの「予約」から母乳・乳房ケアを予約できますよ。';
    }
    if (_match(input, ['寝', '睡眠', '眠', '夜泣き', '夜間'])) {
      return '夜間の授乳、おつかれさまです。赤ちゃんが寝ている間は$motherName も一緒に少し横になれるといいですね。短い仮眠でも体は回復します。眠れない日が続くときは、こころのサインかもしれないので一緒に見ていきましょう。';
    }
    if (_match(input, ['予約', '相談したい', 'ケア', '訪問', '宿泊'])) {
      return '承知しました。通所・宿泊・母乳外来・オンライン相談を「予約」タブからご案内できます。訪問ケアは当面LINEでの調整となります。どのケアが気になりますか？';
    }
    if (_match(input, ['ありがとう', 'うれしい', '助か', '安心'])) {
      return 'そう言ってもらえて、わたしもうれしいです。$motherName のペースで大丈夫。いつでもここにいますからね。';
    }
    return 'お話してくれてありがとう。$motherName、あなたのペースで大丈夫ですよ。\nもう少し詳しく教えてもらえますか？授乳・睡眠・気分のことなど、どんなことでも一緒に考えます。';
  }

  bool _match(String input, List<String> keys) =>
      keys.any((k) => input.contains(k));

  // ---------------- Reservations ----------------
  List<Reservation> get reservations {
    final list = List<Reservation>.from(_reservations);
    list.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return list;
  }

  List<Reservation> get upcomingReservations {
    final now = DateTime.now();
    return reservations.where((r) => r.dateTime.isAfter(now)).toList();
  }

  void addReservation(CareType type, DateTime dateTime, int durationHours,
      {String status = '確定'}) {
    final r = Reservation(
      id: _uuid.v4(),
      type: type,
      dateTime: dateTime,
      durationHours: durationHours,
      status: status,
    );
    _reservations.add(r);
    _reservationBox.put(r.id, r.toMap());
    notifyListeners();
  }

  void cancelReservation(String id) {
    _reservations.removeWhere((r) => r.id == id);
    _reservationBox.delete(id);
    notifyListeners();
  }

  // ---------------- Community ----------------
  List<CommunityPost> get posts => List.unmodifiable(_posts);

  void toggleLike(String id) {
    final p = _posts.firstWhere((e) => e.id == id);
    p.liked = !p.liked;
    p.likes += p.liked ? 1 : -1;
    notifyListeners();
  }

  void addPost(String text, {String babyMonth = '生後3ヶ月'}) {
    _posts.insert(
      0,
      CommunityPost(
        id: _uuid.v4(),
        authorName: motherName,
        babyMonth: babyMonth,
        text: text,
        time: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  // ---------------- Seed data ----------------
  void _seedRecords() {
    final now = DateTime.now();
    final moods = [Mood.good, Mood.soso, Mood.great, Mood.low, Mood.good, Mood.good, Mood.soso];
    final feeds = [9, 8, 10, 7, 8, 9, 8];
    final sleep = [5.2, 4.8, 6.1, 4.5, 5.5, 5.8, 5.2];
    for (var i = 0; i < 7; i++) {
      final d = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: 6 - i));
      final r = DailyRecord(
        date: d,
        feedingCount: feeds[i],
        sleepHours: sleep[i],
        mood: moods[i],
        epdsScore: 12 - i % 3,
      );
      _records[r.dateKey] = r;
      _recordBox.put(r.dateKey, r.toMap());
    }
  }

  void _seedCommunity() {
    _posts = [
      CommunityPost(
        id: _uuid.v4(),
        authorName: 'はな',
        babyMonth: '生後2ヶ月',
        text: '今日は久しぶりに、少しの間だけど赤ちゃんが穏やかに眠ってくれました。こんな時間も大切にしたいな。みんなはどんな時にホッとしますか？',
        time: DateTime.now().subtract(const Duration(hours: 2)),
        likes: 24,
        comments: 6,
      ),
      CommunityPost(
        id: _uuid.v4(),
        authorName: 'ゆいママ',
        babyMonth: '生後4ヶ月',
        text: '夜間の授乳が続いて寝不足ぎみです…。同じような方、どうやって乗り越えていますか？アドバイスをもらえたら嬉しいです。',
        time: DateTime.now().subtract(const Duration(hours: 5)),
        likes: 18,
        comments: 9,
      ),
      CommunityPost(
        id: _uuid.v4(),
        authorName: '助産師 みなみ（モデレーター）',
        babyMonth: 'ママズケア',
        text: '夜間授乳がつらいときは、日中に赤ちゃんと一緒に短い仮眠をとるのもおすすめです。無理せず、頼れるものはどんどん頼ってくださいね。いつでもMOAに相談してください🌙',
        time: DateTime.now().subtract(const Duration(hours: 6)),
        likes: 42,
        comments: 3,
        isMidwife: true,
      ),
      CommunityPost(
        id: _uuid.v4(),
        authorName: 'まりこ',
        babyMonth: '生後6ヶ月',
        text: '離乳食が始まりました！上手に食べてくれた時の笑顔に、毎日癒されています☺️',
        time: DateTime.now().subtract(const Duration(hours: 9)),
        likes: 31,
        comments: 5,
      ),
    ];
  }
}
