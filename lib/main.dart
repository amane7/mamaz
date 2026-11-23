import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'charting/insight_store.dart';
import 'karte/karte_store.dart';
import 'ops/ops_state.dart';
import 'ops/ui/ops_home.dart';
import 'services/app_state.dart';
import 'services/care_state.dart';
import 'theme/app_theme.dart';
import 'widgets/app_nav.dart';
import 'screens/onboarding_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ja');
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  final appState = AppState();
  await appState.init();

  final careState = CareState();
  await careState.init();

  // ナビゲーション層から事業設計画面を開けるように注入する
  // （widgets → ops/ui の循環参照を避けるため）
  businessDesignPage = () => const BusinessDesignScreen();

  // 乳房ケアカルテ（下書き）。この端末の中だけに保存する。
  final karteStore = await KarteStore.openOnDevice();

  runApp(
    MamoaApp(appState: appState, careState: careState, karteStore: karteStore),
  );
}

class MamoaApp extends StatelessWidget {
  final AppState appState;
  final CareState careState;
  final KarteStore karteStore;
  const MamoaApp({
    super.key,
    required this.appState,
    required this.careState,
    required this.karteStore,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appState),
        ChangeNotifierProvider.value(value: careState),
        ChangeNotifierProvider(create: (_) => OpsState()),
        // 記録づくりで残した気づきを、学習室へ渡す（メモリのみ）。
        ChangeNotifierProvider(create: (_) => InsightStore()),
        ChangeNotifierProvider.value(value: karteStore),
      ],
      child: MaterialApp(
        title: 'MAMOA',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const OnboardingScreen(),
      ),
    );
  }
}
