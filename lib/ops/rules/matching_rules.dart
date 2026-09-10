import '../ops_models.dart';
import 'availability_rules.dart';

// ---------------------------------------------------------------------------
// §12 条件⑨〜⑮ マッチングルール（Pure Function）
//
// 助産師1名 × 1枠 の可否を、State も UI も参照せずに判定する。
// MatchingEngine.evaluate() はこの層に委譲するだけにしていく。
// ---------------------------------------------------------------------------

/// 予約が実際に「占有」する時間。
///
/// 訪問は 前予約 → 移動 → ケア → 移動 → 次予約 の順に並ぶため、
/// ケア時間の前後に移動時間、さらに後ろにバッファを積む。
class Occupancy {
  /// ケア本体の開始・終了
  final int careStart;
  final int careEnd;

  /// 移動を含む開始・終了（OK時間に収まっている必要がある範囲）
  final int travelStart;
  final int travelEnd;

  /// 移動＋バッファを含む占有全体（他予約と重ねてはいけない範囲）
  final int blockStart;
  final int blockEnd;

  const Occupancy({
    required this.careStart,
    required this.careEnd,
    required this.travelStart,
    required this.travelEnd,
    required this.blockStart,
    required this.blockEnd,
  });
}

/// §14 移動時間・§12 バッファを反映した占有区間を求める。
Occupancy occupancyOf({
  required ServiceDef service,
  required int startMin,
  required int bufferMin,
}) {
  final careEnd = startMin + service.durationMin;
  final travel = service.kind == ServiceKind.visit ? service.travelMin : 0;
  return Occupancy(
    careStart: startMin,
    careEnd: careEnd,
    travelStart: startMin - travel,
    travelEnd: careEnd + travel,
    blockStart: startMin - travel,
    blockEnd: careEnd + travel + bufferMin,
  );
}

// ---------------------------------------------------------------------------
// ⑨ Skill
// ---------------------------------------------------------------------------

/// 必要スキルを満たすか。スキルIDはマスタ（SkillDef）由来で、コードに固定しない。
bool skillSatisfied({
  required Set<String> requiredSkills,
  required Set<String> staffSkills,
}) => requiredSkills.every(staffSkills.contains);

/// 不足しているスキルID（管理者の「必要条件 vs 候補」比較表示に使う）。
List<String> missingSkills({
  required Set<String> requiredSkills,
  required Set<String> staffSkills,
}) => requiredSkills.where((s) => !staffSkills.contains(s)).toList();

// ---------------------------------------------------------------------------
// ⑩ 対応サービス・地域・施設
// ---------------------------------------------------------------------------

bool serviceSupported(OpsStaff s, ServiceDef service) =>
    s.services.contains(service.kind);

bool areaSupported(OpsStaff s, ServiceDef service, String? areaCode) {
  if (service.kind != ServiceKind.visit) return true;
  if (areaCode == null) return true;
  return s.areas.contains(areaCode);
}

bool facilitySupported(OpsStaff s, ServiceDef service, String? facilityId) {
  if (service.kind == ServiceKind.visit) return true;
  if (facilityId == null) return true;
  return s.facilityIds.contains(facilityId);
}

// ---------------------------------------------------------------------------
// ⑪⑫ OK / NG（NGは絶対優先）
// ---------------------------------------------------------------------------

/// OK未登録の日＝原則予約不可（空欄は「OK」ではない）。
bool okRegistered(Iterable<StaffAvailability> avail) => hasOkRegistered(avail);

/// 移動込みのケア時間がOK区間に完全に収まるか。
bool withinOk(Iterable<StaffAvailability> avail, Occupancy o) =>
    containedInOk(avail, TimeRange(o.travelStart, o.travelEnd));

/// NGと1分でも重なれば不可。バッファ込みの占有全体で見る。
bool blockedByNg(Iterable<StaffAvailability> avail, Occupancy o) =>
    overlapsNg(avail, TimeRange(o.blockStart, o.blockEnd));

// ---------------------------------------------------------------------------
// ⑬ 休暇・研修
// ---------------------------------------------------------------------------

bool blockedByBlocks({
  required Iterable<StaffBlock> blocks,
  required String staffId,
  required DateTime day,
  required Occupancy o,
}) => overlapsBlocks(blocks, staffId, day, TimeRange(o.blockStart, o.blockEnd));

// ---------------------------------------------------------------------------
// ⑭ 既存予約の重複・バッファ
// ---------------------------------------------------------------------------

class BookingConflict {
  /// ケア時間そのものが重なっている（絶対に不可）
  final bool hardOverlap;

  /// 移動・バッファの範囲で衝突している
  final bool bufferOverlap;

  /// その日の合計ケア時間（分）
  final int loadMin;

  /// 前後の予約との詰まり具合（小さいほど移動効率が良い）
  final int travelPenaltyMin;

  /// その日の件数
  final int count;

  const BookingConflict({
    required this.hardOverlap,
    required this.bufferOverlap,
    required this.loadMin,
    required this.travelPenaltyMin,
    required this.count,
  });
}

/// その日の既存予約と、候補枠との関係をまとめて評価する。
BookingConflict evaluateBookings({
  required Iterable<OpsBooking> sameDayBookings,
  required Occupancy o,
  required int bufferMin,
}) {
  var hard = false;
  var soft = false;
  var loadMin = 0;
  var penalty = 0;
  var count = 0;

  for (final b in sameDayBookings) {
    count++;
    final bs = minOfDay(b.at);
    final be = bs + b.durationMin;
    loadMin += b.durationMin;

    if (overlapsRange(o.careStart, o.careEnd, bs, be)) {
      hard = true;
    } else if (overlapsRange(
      o.blockStart,
      o.blockEnd,
      bs - bufferMin,
      be + bufferMin,
    )) {
      soft = true;
    }

    final gap = bs >= o.careEnd ? bs - o.careEnd : o.careStart - be;
    if (gap >= 0) penalty += gap > 240 ? 0 : (gap < 30 ? 30 - gap : 0);
  }

  return BookingConflict(
    hardOverlap: hard,
    bufferOverlap: soft,
    loadMin: loadMin,
    travelPenaltyMin: penalty,
    count: count,
  );
}

// ---------------------------------------------------------------------------
// ⑮ 1日上限・連続対応上限
// ---------------------------------------------------------------------------

bool dailyCapExceeded({
  required int loadMin,
  required int addMin,
  required int dailyMaxMin,
}) => loadMin + addMin > dailyMaxMin;

bool consecutiveExceeded({required int count, required int consecutiveMax}) =>
    count + 1 > consecutiveMax;

// ---------------------------------------------------------------------------
// 優先順位スコア（負荷平準化 > 移動効率 > 継続性）
// ---------------------------------------------------------------------------

double assignmentScore({
  required int loadMin,
  required int dailyMaxMin,
  required int travelPenaltyMin,
  required bool continuity,
}) {
  final loadRatio = dailyMaxMin == 0 ? 1.0 : loadMin / dailyMaxMin;
  final travelBonus = travelPenaltyMin == 0
      ? 20
      : (20 - travelPenaltyMin.clamp(0, 20));
  return (1.0 - loadRatio) * 60 + travelBonus + (continuity ? 25 : 0);
}
