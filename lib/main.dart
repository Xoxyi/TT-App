import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/app_state.dart';
import 'data/store.dart';
import 'screens/home_shell.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.s1,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  Store store;
  var persistent = true;
  try {
    store = await openStore();
  } catch (e) {
    // If on-device storage fails, still open the app (without saving).
    debugPrint('Storage unavailable: $e');
    store = MemoryStore();
    persistent = false;
  }
  final state = await AppState.load(store, persistent: persistent);
  runApp(PiciulinApp(state: state));
  // Fetch the latest FITeT results in the background.
  state.syncFitet();
}

class PiciulinApp extends StatelessWidget {
  const PiciulinApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      notifier: state,
      child: MaterialApp(
        title: 'TT Piciulin',
        debugShowCheckedModeBanner: false,
        theme: buildDarkTheme(),
        home: const HomeShell(),
      ),
    );
  }
}
