// ============================================================================
// 永続化の抽象（§28 レイヤ分離 / §26 将来の差し替え前提）
//
// UI も Booking Engine も、この抽象より下（Hive / API / LINE）を知らない。
// 実装を LocalOpsRepository → ApiOpsRepository に差し替えても、
// 判定ロジックと画面は一切変更しなくてよい状態を作るのが目的。
// ============================================================================

import '../ops_models.dart';

/// マスタ（管理者が編集し、家族・助産師は読むだけ）
///
/// §24 の「管理者が編集できるマスタ」に対応。取得は同期・保存は非同期にして、
/// 画面は即時に描画しつつ、保存だけを I/O に委ねられるようにする。
abstract class MasterRepository {
  List<MunicipalityProgram> loadPrograms();
  List<Municipality> loadMunicipalities();
  List<ServiceDef> loadServices();
  List<OpsFacility> loadFacilities();
  List<OpsResource> loadResources();
  List<SkillDef> loadSkills();
  List<MidwifeSkill> loadMidwifeSkills();
  List<CancelPolicy> loadCancelPolicies();
  List<TermsDoc> loadTerms();
  List<OpsStaff> loadStaff();

  /// 種別ごとに丸ごと保存する（部分更新は上位で組み立てる）。
  Future<void> saveMasters(MasterSnapshot snapshot);
}

/// 予約・可用性・通知・監査など、日々増える運用データ
abstract class OperationRepository {
  List<OpsBooking> loadBookings();
  List<StaffAvailability> loadAvailability();
  Set<String> loadAvailabilityDayOverrides();
  List<StaffBlock> loadBlocks();
  List<BookingResource> loadResourceAllocations();
  List<OpsNotification> loadNotifications();
  List<OpsTask> loadTasks();
  List<AuditEntry> loadAuditLog();
  List<WaitEntry> loadWaitlist();

  Future<void> saveOperations(OperationSnapshot snapshot);
}

/// 実装側に渡す「今の全マスタ」。差分計算を実装に押し付けない。
class MasterSnapshot {
  final List<MunicipalityProgram> programs;
  final List<Municipality> municipalities;
  final List<ServiceDef> services;
  final List<OpsFacility> facilities;
  final List<OpsResource> resources;
  final List<SkillDef> skills;
  final List<MidwifeSkill> midwifeSkills;
  final List<CancelPolicy> cancelPolicies;
  final List<TermsDoc> terms;
  final List<OpsStaff> staff;

  const MasterSnapshot({
    required this.programs,
    required this.municipalities,
    required this.services,
    required this.facilities,
    required this.resources,
    required this.skills,
    required this.midwifeSkills,
    required this.cancelPolicies,
    required this.terms,
    required this.staff,
  });
}

class OperationSnapshot {
  final List<OpsBooking> bookings;
  final List<StaffAvailability> availability;
  final Set<String> availabilityDayOverrides;
  final List<StaffBlock> blocks;
  final List<BookingResource> resourceAllocations;
  final List<OpsNotification> notifications;
  final List<OpsTask> tasks;
  final List<AuditEntry> auditLog;
  final List<WaitEntry> waitlist;

  const OperationSnapshot({
    required this.bookings,
    required this.availability,
    required this.availabilityDayOverrides,
    required this.blocks,
    required this.resourceAllocations,
    required this.notifications,
    required this.tasks,
    required this.auditLog,
    required this.waitlist,
  });
}

/// 両方をまとめて扱う窓口。State はこれ1つだけを持てばよい。
abstract class OpsRepository implements MasterRepository, OperationRepository {
  /// 起動時の準備（Hive の open / API の疎通確認など）
  Future<void> init();

  /// 開発用：初期データに戻す
  Future<void> reset();
}
