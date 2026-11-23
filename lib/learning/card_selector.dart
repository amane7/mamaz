/// 助産の学習室 — 施設内モデルの任意接続（教材選択API）。
///
/// 配布キットの構成図どおり、学習室は「同じ端末の別プロセス」である教材選択APIに
/// **ケース番号と観点の番号だけ** を送る。学習者の初答・理由・検索語は送らない。
/// 返ってきた候補IDは、そのケースで許可された候補と照合し、
/// 形式不正・範囲外・重複・接続失敗はすべて「保留」として扱う。
/// モデルが書いた文章を画面に出す経路はない（表示するのは登録済み教材だけ）。
///
/// Flutter に依存しない。
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

/// 候補選定の結果。[verified] が false のときは候補を保留する。
class SelectionResult {
  final bool verified;
  final List<String> ids;
  final String model;

  const SelectionResult.verified(this.ids, this.model) : verified = true;
  const SelectionResult.held() : verified = false, ids = const [], model = '';
}

abstract class CardSelector {
  /// [allowed] はそのケースで提示を許可された教材ID。
  Future<SelectionResult> select({
    required String caseId,
    required int focusIndex,
    required List<String> allowed,
  });
}

/// 同じ端末で動く教材選択API（キットの `serve_local.py` と同じ `/mode`・`/rank`）。
class LocalSelectionApi implements CardSelector {
  /// 接続先は同じ端末に限る。
  static const String host = '127.0.0.1';
  static const int defaultPort = 8765;
  static const int _maxBody = 4096;
  static const int _maxModelName = 120;
  static final RegExp _control = RegExp(r'[\x00-\x1f\x7f]');

  final int port;
  final Duration timeout;
  final http.Client _client;

  LocalSelectionApi({
    required this.port,
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  }) : assert(validPort(port)),
       _client = client ?? http.Client();

  static bool validPort(int port) => port >= 1 && port <= 65535;

  Uri _uri(String path) =>
      Uri(scheme: 'http', host: host, port: port, path: path);

  /// 教材選択APIが施設内モデルを使う設定で動いているか。
  Future<bool> usesLocalModel() async {
    try {
      final r = await _client.get(_uri('/mode')).timeout(timeout);
      if (r.statusCode != 200 || r.bodyBytes.length > _maxBody) return false;
      final body = jsonDecode(utf8.decode(r.bodyBytes));
      return body is Map && body['mode'] == 'local_model';
    } catch (_) {
      return false;
    }
  }

  @override
  Future<SelectionResult> select({
    required String caseId,
    required int focusIndex,
    required List<String> allowed,
  }) async {
    try {
      final r = await _client
          .post(
            _uri('/rank'),
            headers: const {'Content-Type': 'application/json'},
            // 送るのはこの2項目だけ。
            body: jsonEncode({'case_id': caseId, 'focus': focusIndex}),
          )
          .timeout(timeout);
      if (r.statusCode != 200 || r.bodyBytes.length > _maxBody) {
        return const SelectionResult.held();
      }
      return checkResponse(jsonDecode(utf8.decode(r.bodyBytes)), allowed);
    } catch (_) {
      return const SelectionResult.held();
    }
  }

  /// 応答の検査。候補IDは許可された範囲・重複なし、モデル名は表示できる文字列であること。
  static SelectionResult checkResponse(Object? body, List<String> allowed) {
    if (body is! Map) return const SelectionResult.held();
    final ids = body['ids'];
    final model = body['model'];
    if (ids is! List || ids.length > allowed.length) {
      return const SelectionResult.held();
    }
    final seen = <String>{};
    for (final id in ids) {
      if (id is! String || !allowed.contains(id) || !seen.add(id)) {
        return const SelectionResult.held();
      }
    }
    if (model is! String ||
        model.isEmpty ||
        model.length > _maxModelName ||
        _control.hasMatch(model)) {
      return const SelectionResult.held();
    }
    return SelectionResult.verified(List<String>.unmodifiable(seen), model);
  }

  void close() => _client.close();
}
