// lib/controllers/auth_controller.dart
import 'package:flutter/foundation.dart';
import '../services/db_service.dart';

class AuthController extends ChangeNotifier {
  Map<String, dynamic>? _user;
  bool _loading = false;

  AuthController();

  Map<String, dynamic>? get user => _user;
  bool get isLoading => _loading;
  bool get isLoggedIn => _user != null;

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  /// Carga la sesión desde almacenamiento persistente si existe.
  Future<void> loadFromStorage() async {
    _setLoading(true);
    try {
      final saved = await DBService.getConfig('current_user');
      if (saved != null && saved is String) {
        final u = await DBService.getUser(saved);
        if (u != null) {
          _user = Map<String, dynamic>.from(u);
          notifyListeners();
        }
      }
    } catch (_) {
      // No bloquear la app si no hay persistencia
    } finally {
      _setLoading(false);
    }
  }

  /// login(username, password, {persist:false})
  Future<bool> login(String username, String password, {bool persist = false}) async {
    _setLoading(true);
    try {
      if (username.isEmpty || password.isEmpty) {
        return false;
      }

      final u = await DBService.login(username, password);
      if (u != null) {
        _user = Map<String, dynamic>.from(u);
        if (persist) {
          await DBService.putConfig('current_user', username);
        }
        notifyListeners();
        return true;
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Cierra sesión y elimina persistencia
  Future<void> logout({bool clearPersist = true}) async {
    _user = null;
    if (clearPersist) {
      try {
        await DBService.deleteConfig('current_user');
      } catch (_) {}
    }
    notifyListeners();
  }

  bool get isAdmin => _user?['role'] == 'admin';
  bool get isSeller => _user?['role'] == 'seller';
  bool get isStorekeeper => _user?['role'] == 'storekeeper';
  bool get isGuest => _user?['role'] == 'guest';

  // Added to match checks in UI. Returns true if the user's role is 'supervisor'.
  bool get isSupervisor => _user?['role'] == 'supervisor';
}
