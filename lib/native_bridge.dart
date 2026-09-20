// lib/native_bridge.dart
import 'package:flutter/services.dart';
import 'services/db_service.dart';

class NativeBridge {
  static const MethodChannel _channel =
      MethodChannel('com.mipypos.app/logic');

  /// Debe llamarse temprano desde `main()` después de inicializar servicios.
  static void setup() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'getProductsCount':
          try {
            final products = await DBService.getProducts();
            return products.length;
          } catch (_) {
            return 0;
          }
        case 'ping':
          return 'pong';
        default:
          throw PlatformException(
            code: 'NOT_IMPLEMENTED',
            message: 'Method not implemented: ${call.method}',
          );
      }
    });
  }
}
