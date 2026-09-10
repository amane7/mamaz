import '../ops_models.dart';

// ---------------------------------------------------------------------------
// §12 / §15 Resource ルール（Pure Function）
//
// 「助産師は空いているが部屋が無い」を正しく判定するための層。
// 施設単位の粗い定員ではなく、Resource（個室・ベッド・座席・沐浴設備）
// 単位の排他で判定する。ここに UI 依存も State 依存も持ち込まない。
// ---------------------------------------------------------------------------

/// 指定施設で、指定サービス種別に使えるリソース（有効なものだけ）。
List<OpsResource> resourcesFor({
  required Iterable<OpsResource> resources,
  required String facilityId,
  ServiceKind? kind,
  ResourceKind? resourceKind,
  bool overnight = false,
}) => resources
    .where(
      (r) =>
          r.active &&
          r.facilityId == facilityId &&
          (kind == null || r.supports(kind)) &&
          (resourceKind == null || r.kind == resourceKind) &&
          (!overnight || r.overnightCapable),
    )
    .toList();

/// そのリソースが [from, to) の間に何件占有されているか。
int resourceUsage({
  required Iterable<BookingResource> allocations,
  required String resourceId,
  required DateTime from,
  required DateTime to,
  String? excludeBookingId,
}) => allocations
    .where(
      (a) =>
          a.resourceId == resourceId &&
          a.bookingId != excludeBookingId &&
          a.overlapsWith(from, to),
    )
    .length;

/// そのリソースが [from, to) に空いているか（capacity を考慮）。
bool resourceFree({
  required OpsResource resource,
  required Iterable<BookingResource> allocations,
  required DateTime from,
  required DateTime to,
  String? excludeBookingId,
}) {
  if (!resource.active) return false;
  final used = resourceUsage(
    allocations: allocations,
    resourceId: resource.id,
    from: from,
    to: to,
    excludeBookingId: excludeBookingId,
  );
  return used < resource.capacity;
}

/// 空いているリソース一覧（家族には「1つでもあれば予約可」を返すために使う）。
List<OpsResource> freeResources({
  required Iterable<OpsResource> resources,
  required Iterable<BookingResource> allocations,
  required String facilityId,
  required ServiceKind kind,
  required DateTime from,
  required DateTime to,
  ResourceKind? resourceKind,
  Set<ResourceKind> requiredKinds = const {},
  bool overnight = false,
  String? excludeBookingId,
}) =>
    resourcesFor(
          resources: resources,
          facilityId: facilityId,
          kind: kind,
          resourceKind: resourceKind,
          overnight: overnight,
        )
        .where((r) => requiredKinds.isEmpty || requiredKinds.contains(r.kind))
        .where(
          (r) => resourceFree(
            resource: r,
            allocations: allocations,
            from: from,
            to: to,
            excludeBookingId: excludeBookingId,
          ),
        )
        .toList();

/// このサービスに「必須のリソース」が存在し、かつ空いているか。
///
/// リソースが未登録の施設では従来通り施設定員だけで判定する（後方互換）。
/// 登録されている施設では、Resource 単位の排他が有効になる。
bool resourceAvailable({
  required Iterable<OpsResource> resources,
  required Iterable<BookingResource> allocations,
  required String facilityId,
  required ServiceKind kind,
  required DateTime from,
  required DateTime to,
  Set<ResourceKind> requiredKinds = const {},
  String? excludeBookingId,
}) {
  final pool = resourcesFor(
    resources: resources,
    facilityId: facilityId,
    kind: kind,
    overnight: kind == ServiceKind.stay,
  );
  // 施設にリソース定義が無い＝この層では判定しない（施設定員で判定）
  if (pool.isEmpty) return true;

  bool free(OpsResource r) => resourceFree(
    resource: r,
    allocations: allocations,
    from: from,
    to: to,
    excludeBookingId: excludeBookingId,
  );

  // プランが必要とする設備種別は、それぞれ1つ以上空いていること。
  if (requiredKinds.isNotEmpty) {
    for (final k in requiredKinds) {
      final ofKind = pool.where((r) => r.kind == k);
      if (ofKind.isEmpty) continue; // その設備を持たない施設は従来動作
      if (!ofKind.any(free)) return false;
    }
    return true;
  }

  return pool.any(free);
}

// ---------------------------------------------------------------------------
// 施設定員（Resource 未登録施設のフォールバック）
// ---------------------------------------------------------------------------

/// 施設の同時利用件数（既存予約ベース）。
int facilityConcurrentUse({
  required Iterable<OpsBooking> bookings,
  required String facilityId,
  required DateTime day,
  required int startMin,
  required int endMin,
  String? excludeBookingId,
}) => bookings
    .where(
      (b) =>
          b.facilityId == facilityId &&
          b.state.isActive &&
          b.id != excludeBookingId &&
          dayOf(b.at) == dayOf(day) &&
          minOfDay(b.at) < endMin &&
          startMin < minOfDay(b.at) + b.durationMin,
    )
    .length;

/// 施設に同時受入の余地があるか。
bool facilityHasCapacity({
  required OpsFacility facility,
  required Iterable<OpsBooking> bookings,
  required DateTime day,
  required int startMin,
  required int endMin,
  String? excludeBookingId,
}) =>
    facilityConcurrentUse(
      bookings: bookings,
      facilityId: facility.id,
      day: day,
      startMin: startMin,
      endMin: endMin,
      excludeBookingId: excludeBookingId,
    ) <
    facility.concurrentCapacity;
