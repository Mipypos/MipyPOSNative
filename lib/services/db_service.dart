// Restored DBService from main branch to replace placeholder content.
// File copied from main commit to ensure buildability.

// lib/services/db_service.dart
// Servicio central de acceso a datos (Hive). Incluye métodos públicos usados por la app.
// Llamar a `await DBService.init()` desde main() después de `Hive.initFlutter()`.

import 'package:hive/hive.dart';

class DBService {
  DBService._();

  static late Box _users;
  static late Box _products;
  static late Box _sales;
  static late Box _saleItems;
  static late Box _cashSessions;
  static late Box _areas;
  static late Box _movements;
  static late Box _config;

  /// Inicializa las cajas. Llamar desde main() tras Hive.initFlutter().
  static Future<void> init() async {
    // Abrir boxes con nombres simples
    _users = await Hive.openBox('users');
    _products = await Hive.openBox('products');
    _sales = await Hive.openBox('sales');
    _saleItems = await Hive.openBox('sale_items');
    _cashSessions = await Hive.openBox('cash_sessions');
    _areas = await Hive.openBox('areas');
    _movements = await Hive.openBox('movements');
    _config = await Hive.openBox('config');

    // Inicializar modo si no existe
    if (_config.get('app_mode') == null) {
      await _config.put('app_mode', 'demo');
    }

    // Seed users si no existen
    await seedUsers();
  }

  // -------------------------
  // UTIL: convertir a Map<String, dynamic> de forma segura
  // -------------------------
  static Map<String, dynamic> _toMapSafe(dynamic raw) {
    if (raw == null) return <String, dynamic>{};
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return Map<String, dynamic>.from(raw.map((k, v) => MapEntry(k.toString(), v)));
    }
    // Si es otro tipo (JSObject en web), intentar convertir vía cast dinámico
    try {
      return Map<String, dynamic>.from(raw as Map);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  // -------------------------
  // SEED USERS
  // -------------------------
  static Future<void> seedUsers() async {
    try {
      if (_users.isEmpty) {
        await _users.put('admin', {'user': 'admin', 'pass': '1234', 'role': 'admin'});
        await _users.put('cajero', {'user': 'cajero', 'pass': '1234', 'role': 'seller'});
        await _users.put('almacenero', {'user': 'almacenero', 'pass': '1234', 'role': 'storekeeper'});
        await _users.put('invitado', {'user': 'invitado', 'pass': '1234', 'role': 'guest'});
      }
    } catch (_) {
      // Fallback: abrir temporalmente si init no fue llamada
      final box = await Hive.openBox('users');
      try {
        if (box.isEmpty) {
          await box.put('admin', {'user': 'admin', 'pass': '1234', 'role': 'admin'});
        }
      } finally {
        await box.close();
      }
    }
  }

  static Future<void> clearAll() async {
    try {
      await _users.clear();
      await _products.clear();
      await _sales.clear();
      await _saleItems.clear();
      await _cashSessions.clear();
      await _areas.clear();
      await _movements.clear();
      await _config.clear();
      await _config.put('app_mode', 'demo');
      await seedUsers();
    } catch (_) {
      final usersBox = await Hive.openBox('users');
      final productsBox = await Hive.openBox('products');
      final salesBox = await Hive.openBox('sales');
      final saleItemsBox = await Hive.openBox('sale_items');
      final cashSessionsBox = await Hive.openBox('cash_sessions');
      final areasBox = await Hive.openBox('areas');
      final movementsBox = await Hive.openBox('movements');
      final configBox = await Hive.openBox('config');

      try {
        await usersBox.clear();
        await productsBox.clear();
        await salesBox.clear();
        await saleItemsBox.clear();
        await cashSessionsBox.clear();
        await areasBox.clear();
        await movementsBox.clear();
        await configBox.clear();
        await configBox.put('app_mode', 'demo');
      } finally {
        await usersBox.close();
        await productsBox.close();
        await salesBox.close();
        await saleItemsBox.close();
        await cashSessionsBox.close();
        await areasBox.close();
        await movementsBox.close();
        await configBox.close();
      }
    }
  }

  // -------------------------
  // CONFIG (API pública)
  // -------------------------
  static Future<void> putConfig(String key, dynamic value) async {
    try {
      await _config.put(key, value);
    } catch (_) {
      final box = await Hive.openBox('config');
      try {
        await box.put(key, value);
      } finally {
        await box.close();
      }
    }
  }

  static Future<dynamic> getConfig(String key) async {
    try {
      return _config.get(key);
    } catch (_) {
      final box = await Hive.openBox('config');
      try {
        return box.get(key);
      } finally {
        await box.close();
      }
    }
  }

  static Future<void> deleteConfig(String key) async {
    try {
      await _config.delete(key);
    } catch (_) {
      final box = await Hive.openBox('config');
      try {
        await box.delete(key);
      } finally {
        await box.close();
      }
    }
  }

  static String getAppMode() {
    try {
      final value = _config.get('app_mode', defaultValue: 'demo');
      final mode = value?.toString() ?? 'demo';
      return (mode == 'pro' || mode == 'demo') ? mode : 'demo';
    } catch (_) {
      return 'demo';
    }
  }

  static Future<void> setAppMode(String mode) async {
    await putConfig('app_mode', mode);
  }

  // -------------------------
  // LOGIN
  // -------------------------
  /// Devuelve Map<String,dynamic> del usuario si credenciales coinciden, null si no.
  /// Implementación robusta para Web y Desktop.
  static Future<Map<String, dynamic>?> login(String username, String pass) async {
    try {
      final raw = _users.get(username);
      if (raw == null) return null;
      final map = _toMapSafe(raw);
      final storedPass = map['pass']?.toString() ?? '';
      if (storedPass != pass) return null;
      return map;
    } catch (e) {
      // Fallback seguro: intentar abrir box temporalmente
      try {
        final box = await Hive.openBox('users');
        try {
          final raw = box.get(username);
          if (raw == null) return null;
          final map = _toMapSafe(raw);
          final storedPass = map['pass']?.toString() ?? '';
          if (storedPass != pass) return null;
          return map;
        } finally {
          await box.close();
        }
      } catch (_) {
        return null;
      }
    }
  }

  // -------------------------
  // USERS
  // -------------------------
  static Future<List<Map<String, dynamic>>> getUsers() async {
    final list = <Map<String, dynamic>>[];
    for (var k in _users.keys) {
      final vRaw = _users.get(k);
      final v = _toMapSafe(vRaw);
      list.add(v);
    }
    return list;
  }

  static Future<void> upsertUser(Map<String, dynamic> user) async {
    final key = user['user']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
    await _users.put(key, user);
  }

  static Future<void> deleteUser(String username) async {
    await _users.delete(username);
  }
  /// Devuelve el usuario por username sin validar contraseña (útil para restore local)
  static Future<Map<String, dynamic>?> getUser(String username) async {
    try {
      final raw = _users.get(username);
      if (raw == null) return null;
      return _toMapSafe(raw);
    } catch (_) {
      try {
        final box = await Hive.openBox('users');
        try {
          final raw = box.get(username);
          if (raw == null) return null;
          return _toMapSafe(raw);
        } finally {
          await box.close();
        }
      } catch (_) {
        return null;
      }
    }
  }

  // -------------------------
  // AREAS
  // -------------------------
  static Future<List<Map<String, dynamic>>> getAreas() async {
    final list = <Map<String, dynamic>>[];
    for (var k in _areas.keys) {
      final vRaw = _areas.get(k);
      final v = _toMapSafe(vRaw);
      v['id'] = k;
      list.add(v);
    }
    return list;
  }

  static Future<void> addArea(String name) async {
    final id = _areas.length;
    await _areas.put(id, {'id': id, 'name': name});
  }

  // -------------------------
  // PRODUCTS
  // -------------------------
  static Future<List<Map<String, dynamic>>> getProducts() async {
    final list = <Map<String, dynamic>>[];
    for (var k in _products.keys) {
      final raw = _products.get(k);
      final v = _toMapSafe(raw);
      v['id'] = k;
      // Normalizar tipos
      v['stock'] = (v['stock'] is int) ? v['stock'] as int : int.tryParse('${v['stock']}') ?? 0;
      v['price_cash'] = (v['price_cash'] is num) ? (v['price_cash'] as num).toDouble() : double.tryParse('${v['price_cash']}') ?? 0.0;
      v['price_transfer'] = (v['price_transfer'] is num) ? (v['price_transfer'] as num).toDouble() : double.tryParse('${v['price_transfer']}') ?? 0.0;
      v['subcategory'] = (v['subcategory'] ?? '').toString();
      v['foto'] = (v['foto'] ?? '').toString();
      list.add(v);
    }
    return list;
  }

  static Future<void> insertProduct(Map<String, dynamic> p) async {
    final id = _products.length;
    await _products.put(id, {
      'name': p['name'] ?? 'Producto ${id + 1}',
      'subcategory': (p['subcategory'] ?? '').toString(),
      'stock': (p['stock'] is int ? p['stock'] : int.tryParse('${p['stock']}') ?? 0),
      'price_cash': (p['price_cash'] is num ? (p['price_cash'] as num).toDouble() : double.tryParse('${p['price_cash']}') ?? 0.0),
      'price_transfer': (p['price_transfer'] is num ? (p['price_transfer'] as num).toDouble() : double.tryParse('${p['price_transfer']}') ?? 0.0),
      'foto': (p['foto'] ?? '').toString(),
    });
  }

  static Future<void> upsertProduct(Map<String, dynamic> p) async {
    final name = (p['name'] ?? '').toString();
    if (name.isEmpty) return;

    final existingIndex = _products.keys.firstWhere(
      (key) {
        final raw = _products.get(key);
        final item = _toMapSafe(raw);
        return (item['name'] ?? '').toString() == name;
      },
      orElse: () => null,
    );

    if (existingIndex != null) {
      final current = _toMapSafe(_products.get(existingIndex));
      final updated = <String, dynamic>{
        ...current,
        'name': name,
        'subcategory': (p['subcategory'] ?? current['subcategory'] ?? '').toString(),
        'stock': (p['stock'] is int ? p['stock'] : int.tryParse('${p['stock']}') ?? (current['stock'] ?? 0)),
        'price_cash': (p['price_cash'] is num ? (p['price_cash'] as num).toDouble() : double.tryParse('${p['price_cash']}') ?? (current['price_cash'] ?? 0.0)),
        'price_transfer': (p['price_transfer'] is num ? (p['price_transfer'] as num).toDouble() : double.tryParse('${p['price_transfer']}') ?? (current['price_transfer'] ?? 0.0)),
        'foto': (p['foto'] ?? current['foto'] ?? '').toString(),
      };
      await _products.put(existingIndex, updated);
      return;
    }

    await insertProduct(p);
  }
