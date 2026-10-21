import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class BiometricRegistryService {
  static final Set<String> _registeredUsers = {};
  static bool _isLoaded = false;

  static File _getFile() {
    final dir = Directory.systemTemp;
    return File('${dir.path}/app_biometric_registry_tranvanluong.json');
  }

  static Future<void> load() async {
    if (_isLoaded) return;
    try {
      final file = _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> list = jsonDecode(content);
        for (var item in list) {
          _registeredUsers.add(item.toString().trim().toLowerCase());
        }
      }
    } catch (e) {
      debugPrint('BiometricRegistryService load error: $e');
    }
    _isLoaded = true;
  }

  // Kiểm tra tài khoản đã đăng ký vân tay chưa
  static Future<bool> isFingerprintRegistered(String? usernameOrEmail) async {
    await load();
    if (usernameOrEmail != null && usernameOrEmail.trim().isNotEmpty) {
      final key = usernameOrEmail.trim().toLowerCase();
      return _registeredUsers.contains('${key}_fingerprint') ||
          _registeredUsers.contains(key) ||
          _registeredUsers.contains('fingerprint_enabled');
    }
    return _registeredUsers.contains('fingerprint_enabled') || _registeredUsers.contains('global_biometric_enabled');
  }

  // Kiểm tra tài khoản đã đăng ký Face ID chưa
  static Future<bool> isFaceRegistered(String? usernameOrEmail) async {
    await load();
    if (usernameOrEmail != null && usernameOrEmail.trim().isNotEmpty) {
      final key = usernameOrEmail.trim().toLowerCase();
      return _registeredUsers.contains('${key}_face') ||
          _registeredUsers.contains(key) ||
          _registeredUsers.contains('face_enabled');
    }
    return _registeredUsers.contains('face_enabled') || _registeredUsers.contains('global_biometric_enabled');
  }

  // Kiểm tra tài khoản này (hoặc trên máy) đã đăng ký Face ID / Vân tay chưa (chung)
  static Future<bool> isRegistered(String? usernameOrEmail) async {
    await load();
    if (usernameOrEmail != null && usernameOrEmail.trim().isNotEmpty) {
      final key = usernameOrEmail.trim().toLowerCase();
      return _registeredUsers.contains(key) ||
          _registeredUsers.contains('${key}_fingerprint') ||
          _registeredUsers.contains('${key}_face');
    }
    return _registeredUsers.isNotEmpty;
  }

  // Đăng ký riêng Vân tay
  static Future<void> registerFingerprint(String? usernameOrEmail) async {
    await load();
    if (usernameOrEmail != null && usernameOrEmail.trim().isNotEmpty) {
      final key = usernameOrEmail.trim().toLowerCase();
      _registeredUsers.add(key);
      _registeredUsers.add('${key}_fingerprint');
    }
    _registeredUsers.add('fingerprint_enabled');
    _registeredUsers.add('global_biometric_enabled');
    await _save();
  }

  // Đăng ký riêng Face ID
  static Future<void> registerFace(String? usernameOrEmail) async {
    await load();
    if (usernameOrEmail != null && usernameOrEmail.trim().isNotEmpty) {
      final key = usernameOrEmail.trim().toLowerCase();
      _registeredUsers.add(key);
      _registeredUsers.add('${key}_face');
    }
    _registeredUsers.add('face_enabled');
    _registeredUsers.add('global_biometric_enabled');
    await _save();
  }

  // Đăng ký cả hai (Face ID & Vân tay)
  static Future<void> register(String? usernameOrEmail) async {
    await registerFingerprint(usernameOrEmail);
    await registerFace(usernameOrEmail);
  }

  static Future<void> _save() async {
    try {
      final file = _getFile();
      await file.writeAsString(jsonEncode(_registeredUsers.toList()));
    } catch (e) {
      debugPrint('BiometricRegistryService save error: $e');
    }
  }

  // Lấy email/tên người dùng đã đăng ký gần nhất nếu có
  static Future<String?> getLatestRegisteredUser() async {
    await load();
    for (var u in _registeredUsers) {
      if (!u.contains('_enabled') && !u.endsWith('_face') && !u.endsWith('_fingerprint')) {
        return u;
      }
    }
    return null;
  }
}
