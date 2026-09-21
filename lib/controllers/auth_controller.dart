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

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }

  Future<void> loadFromStorage() async {
    _setLoading(true);

    try {
      final saved = await DBService.getConfig('current_user');

      if (saved is String && saved.isNotEmpty) {
        final storedUser = await DBService.getUser(saved);

        if (storedUser != null) {
          _user = Map<String, dynamic>.from(storedUser);
          notifyListeners();
        }
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> login(
    String username,
    String password, {
    bool persist = false,
  }) async {
    _setLoading(true);

    try {
      if (username.isEmpty || password.isEmpty) {
        return false;
      }

      final loggedUser = await DBService.login(username, password);

      if (loggedUser == null) {
        return false;
      }

      _user = Map<String, dynamic>.from(loggedUser);

      if (persist) {
        await DBService.putConfig('current_user', username);
      }

      notifyListeners();
      return true;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout({bool clearPersist = true}) async {
    _user = null;

    if (clearPersist) {
      try {
        await DBService.deleteConfig('current_user');
      } catch (_) {
        // La sesión local ya fue eliminada; no bloquear el logout.
      }
    }

    notifyListeners();
  }

  String? get role => _user?['role']?.toString();

  bool get isAdmin => role == 'admin';

  bool get isSeller => role == 'seller';

  bool get isStorekeeper => role == 'storekeeper';

  bool get isGuest => role == 'guest';

  bool get isSupervisor => role == 'supervisor';
}