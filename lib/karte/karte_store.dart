/// 乳房ケアカルテの置き場所。
///
/// この端末の中だけに保存する（Hive）。暗号化・ほかの端末との共有・
/// バックアップは無い。予約や家族側の記録（OpsState / CareState）とは
/// つながっていない。
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import 'karte_models.dart';

/// 保存先の抽象。1冊を1つの JSON 文字列として読み書きする。
abstract class KarteStorage {
  Map<String, String> readAll();
  Future<void> write(String id, String json);
  Future<void> remove(String id);
}

/// メモリだけに置く（テスト用・端末に保存できなかったときの代わり）。
class MemoryKarteStorage implements KarteStorage {
  final Map<String, String> data;
  MemoryKarteStorage([Map<String, String>? initial]) : data = {...?initial};

  @override
  Map<String, String> readAll() => {...data};

  @override
  Future<void> write(String id, String json) async => data[id] = json;

  @override
  Future<void> remove(String id) async => data.remove(id);
}

class HiveKarteStorage implements KarteStorage {
  static const boxName = 'breastKarte';
  final Box _box;
  HiveKarteStorage._(this._box);

  static Future<HiveKarteStorage> open() async =>
      HiveKarteStorage._(await Hive.openBox(boxName));

  @override
  Map<String, String> readAll() => {
    for (final k in _box.keys)
      if (k is String && _box.get(k) is String) k: _box.get(k) as String,
  };

  @override
  Future<void> write(String id, String json) => _box.put(id, json);

  @override
  Future<void> remove(String id) => _box.delete(id);
}

class KarteStore extends ChangeNotifier {
  final KarteStorage _storage;

  /// 端末に保存できているか（false のときはアプリを閉じると消える）。
  final bool onDevice;

  final Map<String, Karte> _kartes = {};

  /// 読み込めなかった記録の数（壊れた内容は捨てずに、そのまま残してある）。
  int unreadable = 0;

  KarteStore(KarteStorage storage, {this.onDevice = false})
    : _storage = storage {
    storage.readAll().forEach((id, raw) {
      Karte? k;
      try {
        k = Karte.fromJson(jsonDecode(raw));
      } catch (_) {
        k = null;
      }
      if (k == null || k.id != id) {
        unreadable++;
      } else {
        _kartes[id] = k;
      }
    });
  }

  /// 端末の保存先を開く。開けなければ、メモリだけで動かす。
  static Future<KarteStore> openOnDevice() async {
    try {
      return KarteStore(await HiveKarteStorage.open(), onDevice: true);
    } catch (e) {
      if (kDebugMode) debugPrint('乳房ケアカルテの保存先を開けませんでした: $e');
      return KarteStore(MemoryKarteStorage());
    }
  }

  /// 新しく書いた順。
  List<Karte> get kartes =>
      _kartes.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  Karte? byId(String id) => _kartes[id];

  static String newId() => const Uuid().v4();

  static String? _checkNames(String mother, String child) {
    if (mother.isEmpty) return '氏名を書いてください。';
    if (mother.length > kKarteNameMax || child.length > kKarteNameMax) {
      return '名前は$kKarteNameMax字までにしてください。';
    }
    return null;
  }

  Future<String?> _put(Karte k) async {
    try {
      await _storage.write(k.id, jsonEncode(k.toJson()));
    } catch (e) {
      return '保存できませんでした（$e）。内容は画面に残っています。';
    }
    _kartes[k.id] = k;
    notifyListeners();
    return null;
  }

  /// カルテを作る。作れたら karte、作れなければ error を返す。
  Future<({Karte? karte, String? error})> create({
    required String motherName,
    String childName = '',
  }) async {
    final m = motherName.trim(), c = childName.trim();
    final bad = _checkNames(m, c);
    if (bad != null) return (karte: null, error: bad);
    final k = Karte(
      id: newId(),
      motherName: m,
      childName: c,
      createdAt: DateTime.now(),
    );
    final err = await _put(k);
    return err == null ? (karte: k, error: null) : (karte: null, error: err);
  }

  Future<String?> rename(
    String id, {
    required String motherName,
    required String childName,
  }) async {
    final k = _kartes[id];
    if (k == null) return 'カルテが見つかりません。';
    final m = motherName.trim(), c = childName.trim();
    return _checkNames(m, c) ??
        await _put(k.copyWith(motherName: m, childName: c));
  }

  /// 記録を下書きとして保存する（同じ id があれば置き換える）。
  Future<String?> saveVisit(String karteId, KarteVisit visit) async {
    final k = _kartes[karteId];
    if (k == null) return 'カルテが見つかりません。';
    return _put(
      k.copyWith(
        visits: [
          for (final v in k.visits)
            if (v.id != visit.id) v,
          visit,
        ],
      ),
    );
  }

  Future<String?> deleteVisit(String karteId, String visitId) async {
    final k = _kartes[karteId];
    if (k == null) return 'カルテが見つかりません。';
    return _put(
      k.copyWith(
        visits: [
          for (final v in k.visits)
            if (v.id != visitId) v,
        ],
      ),
    );
  }

  Future<String?> deleteKarte(String id) async {
    if (!_kartes.containsKey(id)) return null;
    try {
      await _storage.remove(id);
    } catch (e) {
      return '削除できませんでした（$e）。';
    }
    _kartes.remove(id);
    notifyListeners();
    return null;
  }
}
