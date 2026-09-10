// ============================================================================
// ローカル実装（§30 実データは扱わない・匿名モックのみ）
//
// 現段階では seed（メモリ）を正とし、保存呼び出しは受け取って保持するだけ。
// Hive / API へ差し替えるときは、このクラスと同じ interface を満たす別実装を
// 作って main.dart の1行を変えるだけで済む形にしてある。
// ============================================================================

import '../ops_models.dart';
import '../ops_seed.dart';
import 'ops_repository.dart';

class LocalOpsRepository implements OpsRepository {
  MasterSnapshot? _masters;
  OperationSnapshot? _ops;

  bool _ready = false;
  bool get isReady => _ready;

  @override
  Future<void> init() async {
    _ready = true;
  }

  @override
  Future<void> reset() async {
    _masters = null;
    _ops = null;
  }

  // --- マスタ ---------------------------------------------------------------

  @override
  List<MunicipalityProgram> loadPrograms() =>
      _masters?.programs ?? [...seedMunicipalities];

  @override
  List<Municipality> loadMunicipalities() =>
      _masters?.municipalities ?? [...seedMunicipalityMasters];

  @override
  List<ServiceDef> loadServices() => _masters?.services ?? [...seedServices];

  @override
  List<OpsFacility> loadFacilities() =>
      _masters?.facilities ?? [...seedOpsFacilities];

  @override
  List<OpsResource> loadResources() =>
      _masters?.resources ?? [...seedResources];

  @override
  List<SkillDef> loadSkills() => _masters?.skills ?? [...seedSkills];

  @override
  List<MidwifeSkill> loadMidwifeSkills() =>
      _masters?.midwifeSkills ?? [...seedMidwifeSkills];

  @override
  List<CancelPolicy> loadCancelPolicies() =>
      _masters?.cancelPolicies ?? [...seedCancelPolicies];

  @override
  List<TermsDoc> loadTerms() => _masters?.terms ?? [...seedTerms];

  @override
  List<OpsStaff> loadStaff() => _masters?.staff ?? [...seedStaff];

  @override
  Future<void> saveMasters(MasterSnapshot snapshot) async {
    _masters = snapshot;
  }

  // --- 運用データ -----------------------------------------------------------

  @override
  List<OpsBooking> loadBookings() => _ops?.bookings ?? [];

  @override
  List<StaffAvailability> loadAvailability() =>
      _ops?.availability ?? seedAvailability();

  @override
  Set<String> loadAvailabilityDayOverrides() =>
      _ops?.availabilityDayOverrides ?? <String>{};

  @override
  List<StaffBlock> loadBlocks() => _ops?.blocks ?? seedBlocks();

  @override
  List<BookingResource> loadResourceAllocations() =>
      _ops?.resourceAllocations ?? [];

  @override
  List<OpsNotification> loadNotifications() => _ops?.notifications ?? [];

  @override
  List<OpsTask> loadTasks() => _ops?.tasks ?? [];

  @override
  List<AuditEntry> loadAuditLog() => _ops?.auditLog ?? [];

  @override
  List<WaitEntry> loadWaitlist() => _ops?.waitlist ?? [];

  @override
  Future<void> saveOperations(OperationSnapshot snapshot) async {
    _ops = snapshot;
  }
}
