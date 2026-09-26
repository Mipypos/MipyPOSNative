// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'services/db_service.dart';
import 'services/license_service.dart';
import 'native_bridge.dart';
import 'core/session_manager.dart';
import 'controllers/cart_controller.dart';
import 'controllers/auth_controller.dart';
import 'screens/login_screen.dart';
import 'screens/home_shell.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await DBService.init();
  await LicenseService.init();
  await LicenseService.ensureDemoModeIfNoLicense();

  try {
    NativeBridge.setup();
  } catch (error) {
    debugPrint('Warning: NativeBridge.setup() failed: $error');
  }

  final auth = AuthController();
  final sessionManager = SessionManager();
  try {
    await sessionManager.loadSession();
  } catch (error) {
    debugPrint('Warning: sessionManager.loadSession() failed: $error');
  }

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
    if (details.stack != null) debugPrint(details.stack.toString());
  };

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>.value(value: auth),
        ChangeNotifierProvider<SessionManager>.value(value: sessionManager),
        ChangeNotifierProvider(create: (_) => CartController()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MiPyPOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routes: {
        '/': (context) => const LoginScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeShell(),
      },
      initialRoute: '/',
    );
  }
}
