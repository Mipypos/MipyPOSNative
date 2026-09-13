// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'services/db_service.dart';
import 'services/license_service.dart';
import 'services/sync_service.dart';
import 'native_bridge.dart';
import 'core/session_manager.dart';
import 'controllers/cart_controller.dart';
import 'controllers/auth_controller.dart';
import 'screens/login_screen.dart';
import 'screens/home_shell.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Hive, DBService y licencia
  await Hive.initFlutter();
  await DBService.init();
  await LicenseService.init();
  await LicenseService.ensureDemoModeIfNoLicense();
  // Configurar puente nativo <-> Dart
  try {
    NativeBridge.setup();
  } catch (e) {
    debugPrint('Warning: NativeBridge.setup() failed: $e');
  }

  // Inicializar Sincronización P2P
  final syncService = SyncService();
  // Si es el dispositivo principal (Admin), iniciamos server
  // Nota: En una implementación real, esto se activaría tras el login del admin
  // Por ahora lo dejamos preparado para el arranque.

  // Crear instancias compartidas
  final auth = AuthController();
  final sessionManager = SessionManager();

  // Cargar la sesión de caja en memoria ANTES de construir la UI.
  // Esto evita que la UI de ventas piense que la caja está cerrada cuando en DB hay una sesión abierta.
  try {
    await sessionManager.loadSession();
  } catch (e) {
    // No detener el arranque por un fallo en carga de sesión; log para debugging.
    debugPrint('Warning: sessionManager.loadSession() failed: $e');
  }

  // Opcional: si quieres restaurar usuario persistente en web/desktop,
  // llama a auth.loadFromStorage() aquí (controlado). Por ahora lo dejamos desactivado.
  // await auth.loadFromStorage();

  // Manejo global de errores para que no queden silenciosos en web/desktop
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
