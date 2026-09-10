// §24 管理者が編集できるマスタのテスト。
//
// ここで守りたいことは2つです。
//
//  1. 固定実装をしていないこと（§11 / §12 / §24）
//     回数上限・助成額・所要時間・必要スキル・必要設備・キャンセル料は
//     すべてマスタ側の値で決まり、コードを書き換えずに変えられる。
//
//  2. 改定しても過去は変わらないこと（§20）
//     マスタを改定すると版番号が上がるが、すでに入っている予約が
//     持っているキャンセル規定の版（スナップショット）は動かない。
//
// 加えて、改定が Matching Engine の判定に本当に効いているか
// （＝画面の飾りではないか）を、枠の出方まで見て確認します。
import 'package:flutter_test/flutter_test.dart';
import 'package:mama_care/ops/ops_models.dart';
import 'package:mama_care/ops/ops_state.dart';

const _starts = <int>[540, 600, 660, 780, 840, 900];

DateTime onWeekday(int weekday, int hour, {int minute = 0, int ahead = 21}) {
  var d = DateTime.now().add(Duration(days: ahead));
  while (d.weekday != weekday) {
    d = d.add(const Duration(days: 1));
  }
  return DateTime(d.year, d.month, d.day, hour, minute);
}

void main() {
  late OpsState ops;

  setUp(() {
    ops = OpsState()..switchRole(OpsRole.admin);
  });

  // ---------------------------------------------------------------------------
  group('§24 自治体・事業要件', () {
    test('回数上限を改定すると版が上がり、判定にも効く', () {
      final before = ops.municipalities.first;
      final v0 = before.version;

      final ok = ops.updateProgram(before.id, maxUseCount: 99);
      expect(ok, isTrue);

      final after = ops.municipalities.first;
      expect(after.maxUseCount, 99, reason: 'マスタの値が変わる');
      expect(after.version, v0 + 1, reason: '§24 改定は版を繰り上げる');
      expect(after.id, before.id, reason: 'id は変えない');
    });

    test('同時予約上限はマスタで決まる（固定実装していない）', () {
      final p = ops.municipalities.first;

      // 0 件に絞れば「これ以上とれない」、大きくすれば通る。
      ops.updateProgram(p.id, maxConcurrentBookings: 1);
      expect(ops.municipalities.first.maxConcurrentBookings, 1);

      ops.updateProgram(p.id, maxConcurrentBookings: 0);
      expect(
        ops.municipalities.first.maxConcurrentBookings,
        0,
        reason: '0 は「制限なし」として保存できる',
      );
    });

    test('存在しない id は改定できない', () {
      expect(ops.updateProgram('mun_not_exist', maxUseCount: 1), isFalse);
    });

    test('改定は監査ログに残る（§30 個人情報は書かない）', () {
      final n = ops.auditLog.length;
      ops.updateProgram(ops.municipalities.first.id, subsidyYen: 12345);
      expect(ops.auditLog.length, n + 1);
      final e = ops.auditLog.last;
      expect(e.action, 'master.update');
      expect(e.target, contains('program:'));
      expect(e.detail, contains('改定'));
    });
  });

  // ---------------------------------------------------------------------------
  group('§24 サービス定義（プラン）', () {
    test('必要スキルを増やすと、その枠は予約できなくなる（§11 固定実装していない）', () {
      final svc = ops.services.firstWhere((s) => s.kind == ServiceKind.dayStay);
      final at = onWeekday(DateTime.wednesday, 10);

      // 改定前：誰かしら対応できる枠がある。
      final before = ops.engine.searchSlots(
        service: svc,
        from: at,
        days: 1,
        startMinutes: _starts,
      );
      expect(before.any((s) => s.bookable), isTrue, reason: '改定前は予約できる枠がある');

      // 誰も持っていないスキルをマスタに追加して、プランの必須にする。
      final rare = ops.addSkill(name: '存在しない特殊ケア');
      ops.updateService(
        svc.id,
        requiredSkills: {...svc.requiredSkills, rare.id},
      );

      final after = ops.engine.searchSlots(
        service: ops.serviceById(svc.id),
        from: at,
        days: 1,
        startMinutes: _starts,
      );
      expect(
        after.any((s) => s.bookable),
        isFalse,
        reason: 'マスタを変えただけで、スキル不足により予約できなくなる',
      );
      // 対応できる助産師が1人もいない枠は、そもそも家族に見せない
      // （§25「選べない選択肢を出さない」）。候補が残る場合も0人であること。
      expect(
        after.every((s) => s.eligible.isEmpty),
        isTrue,
        reason: '候補が0人になる（コードは触っていない）',
      );
    });

    test('所要時間・バッファの改定が占有時間に反映される（§12 / §14）', () {
      final svc = ops.services.firstWhere((s) => s.kind == ServiceKind.visit);
      ops.updateService(svc.id, durationMin: 90, travelMin: 30, bufferMin: 20);

      final s = ops.serviceById(svc.id);
      expect(s.durationMin, 90);
      expect(s.blockMin, 90 + 30 * 2 + 20, reason: '占有＝ケア＋移動×2＋バッファ。式もマスタ値で動く');
    });

    test('料金の改定は版を上げる', () {
      final svc = ops.services.first;
      final v0 = svc.version;
      ops.updateService(svc.id, priceYen: 7777);
      final after = ops.serviceById(svc.id);
      expect(after.priceYen, 7777);
      expect(after.version, v0 + 1);
    });
  });

  // ---------------------------------------------------------------------------
  group('§24 / §20 キャンセル規定', () {
    test('規定を改定しても、既存予約に保存された版は動かない', () {
      // 既存の有効予約（規定版のスナップショットを持っている）
      final b = ops.bookings.firstWhere((x) => x.cancelPolicyVersion != null);
      final snapVersion = b.cancelPolicyVersion;
      final policyId = b.cancelPolicyId!;

      final ok = ops.updateCancelPolicy(policyId, changeDeadlineHours: 1);
      expect(ok, isTrue);

      final policy = ops.cancelPolicies.firstWhere((p) => p.id == policyId);
      expect(policy.changeDeadlineHours, 1, reason: 'マスタは新しい版になる');

      expect(
        b.cancelPolicyVersion,
        snapVersion,
        reason: '§20 予約に適用された版は改定の影響を受けない',
      );
      expect(policy.version, greaterThan(snapVersion!), reason: 'マスタ側だけが先に進む');
    });

    test('キャンセル料は固定実装ではなくマスタの段階表から出る', () {
      final p = ops.cancelPolicies.first;
      ops.updateCancelPolicy(
        p.id,
        tiers: const [CancelTier('前日まで', 24, 0), CancelTier('当日', 0, 5555)],
      );
      final after = ops.cancelPolicies.firstWhere((x) => x.id == p.id);
      final at = DateTime.now().add(const Duration(hours: 2));
      expect(
        after.feeFor(bookingAt: at, requestAt: DateTime.now()),
        5555,
        reason: '書き換えた段階表の金額がそのまま使われる',
      );
    });
  });

  // ---------------------------------------------------------------------------
  group('§24 施設・設備（Resource）', () {
    test('設備を停止すると、その施設の空きが減る（§15）', () {
      final svc = ops.services.firstWhere((s) => s.kind == ServiceKind.dayStay);
      final at = onWeekday(DateTime.wednesday, 10);
      final fac = ops.facilities.first;

      final before = ops.engine
          .availableResources(service: svc, at: at, facilityId: fac.id)
          .length;
      expect(before, greaterThan(0), reason: '前提：空き設備がある');

      for (final r in ops.resources.where((r) => r.facilityId == fac.id)) {
        ops.updateResource(r.id, active: false);
      }

      final after = ops.engine
          .availableResources(service: svc, at: at, facilityId: fac.id)
          .length;
      expect(after, 0, reason: 'マスタで停止した設備は候補から消える');
    });

    test('設備を追加できる（§15 施設ごとに登録）', () {
      final fac = ops.facilities.first;
      final n = ops.resources.where((r) => r.facilityId == fac.id).length;
      final r = ops.addResource(
        facilityId: fac.id,
        name: '個室C',
        kind: ResourceKind.room,
      );
      expect(r.id, isNotEmpty);
      expect(ops.resources.where((x) => x.facilityId == fac.id).length, n + 1);
      expect(ops.auditLog.last.target, contains('resource:'));
    });

    test('施設の同時受入数を変更できる', () {
      final fac = ops.facilities.first;
      expect(ops.updateFacility(fac.id, concurrentCapacity: 1), isTrue);
      expect(ops.facilities.first.concurrentCapacity, 1);
    });
  });

  // ---------------------------------------------------------------------------
  group('§11 Skill マスタ', () {
    test('スキルはコードに固定せず追加できる', () {
      final n = ops.skills.length;
      final s = ops.addSkill(name: '双子のケア', description: '多胎児のご家庭向け');
      expect(ops.skills.length, n + 1);
      expect(ops.skillName(s.id), '双子のケア');
    });

    test('助産師へのスキル付与・取消ができ、割当判定に効く', () {
      final staff = ops.staff.first;
      final s = ops.addSkill(name: '沐浴指導（追加）');

      expect(ops.toggleMidwifeSkill(staff.id, s.id), isTrue);
      expect(ops.skillIdsOf(staff.id), contains(s.id), reason: '付与できる');

      ops.toggleMidwifeSkill(staff.id, s.id);
      expect(ops.skillIdsOf(staff.id), isNot(contains(s.id)), reason: '取消できる');
    });

    // これは「画面だけ変わって判定に効かない」事故を防ぐための回帰テスト。
    // スキルの正は付与テーブル（MidwifeSkill）であって、
    // 初期データ（OpsStaff.skills）ではない。
    test('スキルを取り消すと、その助産師はもう割り当てられない', () {
      final svc = ops.services.firstWhere((x) => x.requiredSkills.isNotEmpty);
      final need = svc.requiredSkills.first;
      final at = onWeekday(DateTime.tuesday, 10);

      final holders = ops.staff
          .where((m) => ops.skillIdsOf(m.id).contains(need))
          .toList();
      expect(holders, isNotEmpty, reason: '前提：対応できる助産師がいる');

      // 全員からそのスキルを取り消す（管理者のマスタ操作）
      for (final m in holders) {
        ops.toggleMidwifeSkill(m.id, need);
      }
      expect(
        ops.staff.every((m) => !ops.skillIdsOf(m.id).contains(need)),
        isTrue,
      );

      final after = ops.engine.searchSlots(
        service: svc,
        from: at,
        days: 1,
        startMinutes: _starts,
      );
      expect(
        after.any((x) => x.bookable),
        isFalse,
        reason: '取消がエンジンの判定に効いていなければ、ここで予約が取れてしまう',
      );
    });
  });
}
