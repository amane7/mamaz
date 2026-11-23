/// 会話の下書き（試作）を、乳房ケアカルテの記録へ持ち込む形に直す。
///
/// 発言は言い換えずに S）へ、「次回確かめること」は P）へ入れる。
/// 回数・体重などの欄は、会話から読み取って埋めない。
library;

import '../charting/chart_assist.dart';
import '../charting/chart_assist_state.dart';
import '../charting/conversation.dart';
import '../learning/learning_models.dart';
import 'karte_models.dart';

/// 持ち込める内容が無いとき（会話が開かれていない・人につなぐ会話）は null。
KartePrefill? prefillFromAssist(
  ChartAssistState assist,
  Map<String, LearningCard> cards,
) {
  final c = assist.conversation;
  final result = assist.result;
  if (c == null || result == null || result.stopped) return null;

  final s = StringBuffer();
  for (final section in ChartSection.values) {
    final entries = assist.entriesIn(section);
    if (entries.isEmpty) continue;
    s.writeln('【${section.label}】');
    for (final e in entries) {
      s.writeln('${e.speaker.label}「${e.text}」');
    }
  }
  if (assist.confirmed.isNotEmpty) {
    s.writeln('【助産師が確かめたこと】');
    for (final q in assist.confirmed) {
      s.writeln('${q.kind.label}：${assist.answerOf(q.kind)}');
    }
  }

  final p = StringBuffer();
  if (assist.nextChecks.isNotEmpty) {
    p.writeln('【次回、ご本人に確かめること】');
    for (final q in assist.nextChecks) {
      p.writeln(cards[q.cardId]?.question ?? q.kind.label);
    }
  }

  return KartePrefill(
    s: s.toString().trim(),
    p: p.toString().trim(),
    openPoints: [
      for (final q in assist.unresolved) '${q.kind.label}：${q.reason}',
    ],
    source: conversationSourceLabel(c),
  );
}

String conversationSourceLabel(Conversation c) =>
    c.sample ? '架空の会話例「${c.title}」' : '画面で書いた会話';
