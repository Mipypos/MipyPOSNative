// lib/native_bridge.dart
import 'package:flutter/services.dart';
import 'services/db_service.dart';

class NativeBridge {
  static const MethodChannel _channel = MethodChannel('com.mipypos.app/logic');

  static void setup() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'getProductsCount':
          try {
            return (await DBService.getProducts()).length;
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
