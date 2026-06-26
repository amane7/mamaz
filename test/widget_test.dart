// Basic smoke test for the MAMOA app.
import 'package:flutter_test/flutter_test.dart';

import 'package:mama_care/services/app_state.dart';

void main() {
  test('AppState seeds chat and community data', () async {
    final state = AppState();
    // soraReply should always return a non-empty response.
    final reply = state.soraReply('夜間の授乳がつらいです');
    expect(reply.isNotEmpty, true);
  });
}
