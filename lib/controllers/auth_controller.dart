import 'package:flutter/foundation.dart';

import '../services/db_service.dart';

class AuthController extends ChangeNotifier {
  Map<String, dynamic>? _user;
  bool _loading = false;

  AuthController();

  Map<String, dynamic>? get user => _user;

  bool get isLoading => _loading;

  bool get isLoggedIn => _user != null;

  String? get role => _user?['role']?.toString();

  bool get isAdmin => role == 'admin';

  bool get isSeller => role == 'seller';

  bool get isStorekeeper => role == 'storekeeper';

  bool get isGuest => role == 'guest';

  bool get isSupervisor => role == 'supervisor';

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }

  Future<void> loadFromStorage() async {
    _setLoading(true);

    try {
      final savedUser = await DBService.getConfig('current_user');

      if (savedUser is! String || savedUser.isEmpty) {
        return;
      }

      final storedUser = await DBService.getUser(savedUser);

      if (storedUser == null) {
        return;
      }

      _user = Map<String, dynamic>.from(storedUser);
      notifyListeners();
    } catch (error) {
      debugPrint('Error loading stored user: $error');
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
      final normalizedUsername = username.trim();

      if (normalizedUsername.isEmpty || password.isEmpty) {
        return false;
      }

      final loggedUser = await DBService.login(
        normalizedUsername,
        password,
      );

      if (loggedUser == null) {
        return false;
      }

      _user = Map<String, dynamic>.from(loggedUser);

      if (persist) {
        await DBService.putConfig(
          'current_user',
          normalizedUsername,
        );
      }

      notifyListeners();
      return true;
    } catch (error) {
      debugPrint('Login error: $error');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout({
    bool clearPersist = true,
  }) async {
    _user = null;

    if (clearPersist) {
      try {
        await DBService.deleteConfig('current_user');
      } catch (error) {
        debugPrint('Error clearing stored user: $error');
      }
    }

    notifyListeners();
  }
}