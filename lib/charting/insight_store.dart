/// 仕事の中で残した「気づき」— 記録づくりと学習室をつなぐ、ただ一つの受け渡し口。
///
/// 残るのは、助産師が自分で「残す」を押した文章と、問いの種類だけ。
/// 会話の文面・下書き・お名前は受け取らない。
/// 気づきは監修前の覚え書きで、教材ではない。本人がいつでも取り消せる。
/// この試作ではメモリにだけ置き、アプリを閉じると消える。
library;

import 'package:flutter/foundation.dart';

import 'chart_assist.dart';

/// その問いを、自分ならどう扱うか。
enum InsightStance { always, depends, notHere, missing }

extension InsightStanceX on InsightStance {
  String get label => switch (this) {
    InsightStance.always => 'いつも確かめる',
    InsightStance.depends => '場面による',
    InsightStance.notHere => 'この場面では確かめない',
    InsightStance.missing => '候補に無かった観点',
  };
}

class InsightNote {
  final int id;
  final DateTime at;
  final InsightStance stance;

  /// どの種類の問いについての気づきか（候補に無かった観点のときは null）。
  final GapKind? kind;
  final String text;

  const InsightNote({
    required this.id,
    required this.at,
    required this.stance,
    required this.kind,
    required this.text,
  });

  static const String status = '監修前の覚え書き';
}

class InsightStore extends ChangeNotifier {
  static const int maxLength = 400;

  final List<InsightNote> _notes = [];
  int _seq = 0;

  /// 新しい順。
  List<InsightNote> get notes => List.unmodifiable(_notes.reversed);

  /// 気づきを残す。残せないときは理由を返す。
  String? add({
    required InsightStance stance,
    required String text,
    GapKind? kind,
  }) {
    final body = text.trim();
    if (body.isEmpty) return '気づきを書いてから残してください。';
    if (body.length > maxLength) return '気づきは$maxLength文字までにしてください。';
    _notes.add(
      InsightNote(
        id: ++_seq,
        at: DateTime.now(),
        stance: stance,
        kind: kind,
        text: body,
      ),
    );
    notifyListeners();
    return null;
  }

  void remove(int id) {
    final before = _notes.length;
    _notes.removeWhere((n) => n.id == id);
    if (_notes.length != before) notifyListeners();
  }
}
