// ============================================================================
// availability_rules.dart
//
// 助産師の「働ける時間（OK）」「働けない時間（NG）」を解釈する純関数群。
// §8 OK/NG時間・NG優先 / §9 NGプライバシー / §10 入力UX の判定根拠。
//
// 設計原則（§28）:
//   - すべて Pure Function（副作用なし・引数だけで結果が決まる）
//   - UI・State に依存しない（import は ops_models のみ）
//   - MatchingEngine はこの層に判定を委譲する
//
// 最重要ルール:
//   NG は OK より優先する。
//   OK 09:00-17:00 / NG 12:00-14:00 なら 予約可能は 09:00-12:00 と 14:00-17:00。
//
// プライバシー（§9）:
//   NG に理由を持たせない。この層も理由を一切参照しない。
// ============================================================================

import '../ops_models.dart';

/// 分単位の閉じた区間 [startMin, endMin)。
/// 予約判定はすべてこの型に正規化してから行う。
class TimeRange {
  final int startMin;
  final int endMin;
  const TimeRange(this.startMin, this.endMin);

  int get durationMin => endMin - startMin;
  bool get isEmpty => endMin <= startMin;

  bool overlaps(TimeRange o) => startMin < o.endMin && o.startMin < endMin;
  bool contains(TimeRange o) => startMin <= o.startMin && o.endMin <= endMin;

  @override
  String toString() => '${hhmm(startMin)}-${hhmm(endMin)}';

  @override
  bool operator ==(Object other) =>
      other is TimeRange &&
      other.startMin == startMin &&
      other.endMin == endMin;

  @override
  int get hashCode => Object.hash(startMin, endMin);
}

/// 区間の重なり判定（最小プリミティブ）。
bool overlapsRange(int aStart, int aEnd, int bStart, int bEnd) =>
    aStart < bEnd && bStart < aEnd;

/// 隣接・重複する区間を1本にまとめる（昇順で返す）。
///
/// 例: [9:00-12:00, 12:00-17:00] → [9:00-17:00]
/// OK時間が複数登録されていても「連続して働ける」ことを正しく扱うために必要。
List<TimeRange> mergeRanges(Iterable<TimeRange> src) {
  final list = src.where((r) => !r.isEmpty).toList()
    ..sort((a, b) => a.startMin.compareTo(b.startMin));
  final out = <TimeRange>[];
  for (final r in list) {
    if (out.isNotEmpty && r.startMin <= out.last.endMin) {
      if (r.endMin > out.last.endMin) {
        out[out.length - 1] = TimeRange(out.last.startMin, r.endMin);
      }
    } else {
      out.add(r);
    }
  }
  return out;
}

/// 区間差集合 base − cuts。NG を OK から引くための演算。
///
/// これが「NGがOKより優先される」ことの数学的な実装。
/// OK 09:00-17:00 − NG 12:00-14:00 = [09:00-12:00, 14:00-17:00]
List<TimeRange> subtractRanges(
  Iterable<TimeRange> base,
  Iterable<TimeRange> cuts,
) {
  var acc = mergeRanges(base);
  for (final cut in mergeRanges(cuts)) {
    final next = <TimeRange>[];
    for (final r in acc) {
      if (!r.overlaps(cut)) {
        next.add(r);
        continue;
      }
      // 前の残り
      if (r.startMin < cut.startMin) {
        next.add(TimeRange(r.startMin, cut.startMin));
      }
      // 後の残り
      if (cut.endMin < r.endMin) {
        next.add(TimeRange(cut.endMin, r.endMin));
      }
    }
    acc = next;
  }
  return acc;
}

// ---------------------------------------------------------------------------
// StaffAvailability の解釈
// ---------------------------------------------------------------------------

/// OK区間だけを取り出してマージする。
List<TimeRange> okRanges(Iterable<StaffAvailability> avail) => mergeRanges(
  avail
      .where((a) => a.kind == AvailKind.ok)
      .map((a) => TimeRange(a.startMin, a.endMin)),
);

/// NG区間だけを取り出してマージする。
List<TimeRange> ngRanges(Iterable<StaffAvailability> avail) => mergeRanges(
  avail
      .where((a) => a.kind == AvailKind.ng)
      .map((a) => TimeRange(a.startMin, a.endMin)),
);

/// OK が1件でも登録されているか。
/// 空欄（OKもNGも未登録）は「原則予約不可」なので、この判定が門番になる。
bool hasOkRegistered(Iterable<StaffAvailability> avail) =>
    avail.any((a) => a.kind == AvailKind.ok);

/// §8 の中核：実際に働ける時間 = OK − NG。
///
/// 家族に見せる空き枠、管理者に見せる稼働可能時間はすべてこれを根拠にする。
List<TimeRange> workableRanges(Iterable<StaffAvailability> avail) =>
    subtractRanges(okRanges(avail), ngRanges(avail));

/// 指定区間が OK 時間に完全に収まっているか（連結OKを許容）。
bool containedInOk(Iterable<StaffAvailability> avail, TimeRange target) =>
    okRanges(avail).any((r) => r.contains(target));

/// 指定区間が NG と1分でも重なるか（重なれば予約不可）。
bool overlapsNg(Iterable<StaffAvailability> avail, TimeRange target) =>
    ngRanges(avail).any((r) => r.overlaps(target));

/// §16 AvailabilityException（休暇・研修など単発の対応不可）と重なるか。
///
/// NG と同様に理由は判定に用いない（プライバシー保護）。
bool overlapsBlocks(
  Iterable<StaffBlock> blocks,
  String staffId,
  DateTime day,
  TimeRange target,
) => blocks
    .where((b) => b.staffId == staffId && dayOf(b.date) == dayOf(day))
    .any((b) => target.overlaps(TimeRange(b.startMin, b.endMin)));

/// 特定日の登録が毎週パターンをどう上書きするかを解決する。
///
/// 解決規則（「一度入れたNGを取り消せること」の根拠）:
///   1. その日が個別設定済みなら、特定日の登録だけを正とする。
///      毎週パターンは一切適用しない → 毎週由来のNGもその日だけ確実に消せる。
///   2. 個別設定が無い日は毎週パターンを土台にし、特定日の登録を重ねる。
///      特定日にOKがあれば毎週OKは置換、毎週NGは安全側で常に残す。
List<StaffAvailability> resolveDayAvailability({
  required Iterable<StaffAvailability> all,
  required String staffId,
  required DateTime day,
  required Set<String> dayOverrides,
}) {
  final specific = all
      .where(
        (a) =>
            a.staffId == staffId &&
            a.date != null &&
            dayOf(a.date!) == dayOf(day),
      )
      .toList();

  if (dayOverrides.contains(availDayKey(staffId, day))) return specific;

  final recurring = all
      .where((a) => a.staffId == staffId && a.weekday == day.weekday)
      .toList();
  if (specific.isEmpty) return recurring;

  final hasSpecificOk = specific.any((a) => a.kind == AvailKind.ok);
  final merged = <StaffAvailability>[...specific];
  if (!hasSpecificOk) {
    merged.addAll(recurring.where((a) => a.kind == AvailKind.ok));
  }
  merged.addAll(recurring.where((a) => a.kind == AvailKind.ng));
  return merged;
}
