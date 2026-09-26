import 'dart:io';
import 'package:hive/hive.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'db_service.dart';

class LicenseService {
  static Box? _license;

  static Future<void> init() async => _license = await Hive.openBox('license');

  static Future<String> getDeviceIdentifier() async {
    final info = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final android = await info.androidInfo;
      return '${android.model}_${android.id}'.toUpperCase().replaceAll(' ', '');
    }
    if (Platform.isIOS) {
      final ios = await info.iosInfo;
      return ios.identifierForVendor ?? 'IOS_DEVICE';
    }
    return 'GENERIC_DEVICE';
  }

  static String? getLicenseCode() => _license?.get('code')?.toString();

  static Future<bool> validateLicense(String code) async {
    return code.trim().toUpperCase() == 'PRO-MIPY-${await getDeviceIdentifier()}';
  }

  static Future<void> activatePro(String code) async {
    if (await validateLicense(code)) {
      await _license?.put('code', code);
      await DBService.setAppMode('pro');
    }
  }

  static bool isProActive() => getLicenseCode()?.startsWith('PRO-MIPY-') ?? false;

  static Future<void> ensureDemoModeIfNoLicense() async {
    if (isProActive()) {
      await DBService.setAppMode('pro');
    } else {
      await _license?.put('code', '');
      await DBService.setAppMode('demo');
    }
  }
}
