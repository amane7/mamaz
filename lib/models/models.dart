import 'package:flutter/material.dart';

/// 気分 (mood) levels used across journal & home.
enum Mood {
  great('とても穏やか', '😊', Color(0xFF8FC79A)),
  good('やや穏やか', '🙂', Color(0xFFB7D0B5)),
  soso('ふつう', '😐', Color(0xFFF6D38A)),
  low('やや不安', '😟', Color(0xFFF1B07A)),
  bad('つらい', '😢', Color(0xFFE89AA8));

  const Mood(this.label, this.emoji, this.color);
  final String label;
  final String emoji;
  final Color color;
}

/// A daily care record (授乳・睡眠・気分).
class DailyRecord {
  final DateTime date;
  int feedingCount; // 授乳回数
  double sleepHours; // 睡眠時間
  Mood? mood; // 気分
  String? note; // メモ
  int? epdsScore; // EPDS スコア

  DailyRecord({
    required this.date,
    this.feedingCount = 0,
    this.sleepHours = 0,
    this.mood,
    this.note,
    this.epdsScore,
  });

  String get dateKey =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toMap() => {
        'date': date.toIso8601String(),
        'feedingCount': feedingCount,
        'sleepHours': sleepHours,
        'mood': mood?.index,
        'note': note,
        'epdsScore': epdsScore,
      };

  factory DailyRecord.fromMap(Map map) => DailyRecord(
        date: DateTime.parse(map['date'] as String),
        feedingCount: (map['feedingCount'] ?? 0) as int,
        sleepHours: (map['sleepHours'] ?? 0).toDouble(),
        mood: map['mood'] != null ? Mood.values[map['mood'] as int] : null,
        note: map['note'] as String?,
        epdsScore: map['epdsScore'] as int?,
      );
}

/// Chat message with the cradle fairy "MOA".
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;

  ChatMessage({required this.text, required this.isUser, DateTime? time})
      : time = time ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'text': text,
        'isUser': isUser,
        'time': time.toIso8601String(),
      };

  factory ChatMessage.fromMap(Map map) => ChatMessage(
        text: map['text'] as String,
        isUser: map['isUser'] as bool,
        time: DateTime.parse(map['time'] as String),
      );
}

/// Care service type for reservations.
enum CareType {
  breast('母乳・乳房ケア', '通所 / オンライン', Icons.water_drop_outlined, Color(0xFFF8C8D6)),
  visit('助産師の訪問ケア', '訪問 (LINE調整)', Icons.directions_walk_rounded, Color(0xFFC9BEE6)),
  online('オンライン相談', '30分 / オンライン', Icons.videocam_outlined, Color(0xFFB7D0B5)),
  house('宿泊型 THE HOUSE', '1泊 / 宿泊・日帰り', Icons.night_shelter_outlined, Color(0xFFF6D9A8));

  const CareType(this.title, this.subtitle, this.icon, this.color);
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
}

/// A booked reservation.
class Reservation {
  final String id;
  final CareType type;
  final DateTime dateTime;
  final int durationHours; // ケア時間 (2-6h / 0=30min slot)
  final String status; // 確定 / 調整中

  Reservation({
    required this.id,
    required this.type,
    required this.dateTime,
    this.durationHours = 0,
    this.status = '確定',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.index,
        'dateTime': dateTime.toIso8601String(),
        'durationHours': durationHours,
        'status': status,
      };

  factory Reservation.fromMap(Map map) => Reservation(
        id: map['id'] as String,
        type: CareType.values[map['type'] as int],
        dateTime: DateTime.parse(map['dateTime'] as String),
        durationHours: (map['durationHours'] ?? 0) as int,
        status: (map['status'] ?? '確定') as String,
      );
}

/// A community post in つながり広場.
class CommunityPost {
  final String id;
  final String authorName;
  final String babyMonth; // 月齢
  final String text;
  final DateTime time;
  int likes;
  bool liked;
  int comments;
  final bool isMidwife; // 助産師モデレーター

  CommunityPost({
    required this.id,
    required this.authorName,
    required this.babyMonth,
    required this.text,
    required this.time,
    this.likes = 0,
    this.liked = false,
    this.comments = 0,
    this.isMidwife = false,
  });
}
