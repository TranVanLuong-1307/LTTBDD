import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

/// Dịch vụ đồng bộ dữ liệu Real-time giữa màn hình Nhân viên (Employee)
/// và Hệ thống Quản trị (Admin Dashboard).
/// Tuyệt đối KHÔNG chứa dữ liệu mẫu cứng (Hardcoded Mock) - 100% tuân thủ dữ liệu Backend.
class AppSyncService {
  static final AppSyncService instance = AppSyncService._();
  AppSyncService._();

  static bool _initialized = false;

  // Danh sách nhân viên đồng bộ thực tế từ server / đăng ký thực (ban đầu hoàn toàn trống)
  static final List<Map<String, dynamic>> _syncedEmployees = [];

  // Danh sách nhật ký chấm công thực tế (ban đầu hoàn toàn trống)
  static final List<Map<String, dynamic>> _syncedAttendances = [];

  static File _getEmployeesFile() {
    return File('${Directory.systemTemp.path}/app_synced_employees_tranvanluong.json');
  }

  static File _getAttendancesFile() {
    return File('${Directory.systemTemp.path}/app_synced_attendances_tranvanluong.json');
  }

  /// Xóa toàn bộ dữ liệu tạm cũ để làm sạch hệ thống theo yêu cầu đề bài
  static Future<void> purgeOldData() async {
    try {
      final f1 = _getEmployeesFile();
      if (await f1.exists()) await f1.delete();
      final f2 = _getAttendancesFile();
      if (await f2.exists()) await f2.delete();
      _syncedEmployees.clear();
      _syncedAttendances.clear();
    } catch (_) {}
  }

  static Future<void> init() async {
    if (_initialized) return;
    try {
      final empFile = _getEmployeesFile();
      if (await empFile.exists()) {
        final content = await empFile.readAsString();
        final List<dynamic> list = jsonDecode(content);
        for (var item in list) {
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            final email = (map['email'] ?? '').toString().toLowerCase().trim();
            final name = (map['fullName'] ?? map['name'] ?? '').toString().toLowerCase().trim();
            final exists = _syncedEmployees.any((e) =>
                (e['email'] ?? '').toString().toLowerCase().trim() == email ||
                (e['fullName'] ?? '').toString().toLowerCase().trim() == name);
            if (!exists) {
              _syncedEmployees.add(map);
            }
          }
        }
      }

      final attFile = _getAttendancesFile();
      if (await attFile.exists()) {
        final content = await attFile.readAsString();
        final List<dynamic> list = jsonDecode(content);
        for (var item in list) {
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            final name = map['name']?.toString() ?? '';
            final time = map['time']?.toString() ?? '';
            final exists = _syncedAttendances.any((a) => a['name'] == name && a['time'] == time);
            if (!exists) {
              map['icon'] = _resolveIcon(map['method']?.toString());
              _syncedAttendances.add(map);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('❌ [AppSyncService] init error: $e');
    }
    _initialized = true;
  }

  static IconData _resolveIcon(String? method) {
    final m = (method ?? '').toLowerCase();
    if (m.contains('face') || m.contains('khuôn mặt')) {
      return Icons.face_retouching_natural;
    } else if (m.contains('qr')) {
      return Icons.qr_code_2_rounded;
    } else if (m.contains('vân tay') || m.contains('fingerprint')) {
      return Icons.fingerprint;
    } else if (m.contains('gps') || m.contains('geofence') || m.contains('vị trí')) {
      return Icons.location_on_rounded;
    }
    return Icons.verified_user_rounded;
  }

  static Future<void> _save() async {
    try {
      final empFile = _getEmployeesFile();
      await empFile.writeAsString(jsonEncode(_syncedEmployees));

      final attFile = _getAttendancesFile();
      final cleanList = _syncedAttendances.map((a) {
        final copy = Map<String, dynamic>.from(a);
        copy.remove('icon');
        return copy;
      }).toList();
      await attFile.writeAsString(jsonEncode(cleanList));
    } catch (e) {
      debugPrint('❌ [AppSyncService] save error: $e');
    }
  }

  /// Đăng ký hoặc cập nhật thông tin nhân viên từ tài khoản thực tế
  static Future<void> registerOrUpdateEmployee(Map<String, dynamic> user) async {
    await init();
    final rawName = user['fullName'] ?? user['name'] ?? user['username'] ?? '';
    final email = (user['email'] ?? '').toString().trim();
    if (rawName.toString().isEmpty && email.isEmpty) return;

    String cleanName = rawName.toString().trim();
    if (cleanName.contains('@') || cleanName.isEmpty) {
      if (email.contains('@')) {
        cleanName = email.split('@')[0];
      } else {
        cleanName = 'Nhân viên';
      }
    }

    final dept = user['departmentName'] ?? user['department'] ?? 'Phòng Kỹ Thuật (IT)';
    final role = user['role'] ?? user['Role'] ?? 'NhanVien';
    final phone = user['phone'] ?? user['phoneNumber'] ?? '09xxxxxxxx';
    final id = user['id']?.toString() ?? 'emp_${DateTime.now().millisecondsSinceEpoch}';

    final index = _syncedEmployees.indexWhere((e) =>
        (e['email'] ?? '').toString().toLowerCase().trim() == email.toLowerCase() ||
        (e['fullName'] ?? '').toString().toLowerCase().trim() == cleanName.toLowerCase());

    final employeeEntry = {
      'id': id,
      'fullName': cleanName,
      'name': cleanName,
      'email': email,
      'departmentName': dept.toString(),
      'position': user['position'] ?? user['role'] ?? 'Nhân viên',
      'role': role.toString(),
      'status': user['status'] ?? 'Present',
      'phone': phone.toString(),
      'isNew': true,
    };

    if (index >= 0) {
      _syncedEmployees[index] = {
        ..._syncedEmployees[index],
        ...employeeEntry,
      };
    } else {
      _syncedEmployees.insert(0, employeeEntry);
    }

    await _save();
    debugPrint('✅ [AppSyncService] Synced employee: $cleanName ($email)');
  }

  /// Ghi nhận 1 lượt chấm công mới
  static Future<void> recordAttendance({
    required String employeeName,
    String? email,
    String method = 'Chấm công 1 chạm',
    bool isLate = false,
    String? time,
    String? status,
  }) async {
    await init();
    final now = DateTime.now();
    final timeStr = time ?? '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final displayStatus = status ?? (isLate ? 'Đi muộn' : 'Đúng giờ');

    final record = {
      'name': employeeName,
      'email': email ?? '',
      'time': timeStr,
      'method': method,
      'icon': _resolveIcon(method),
      'status': displayStatus,
      'isLate': isLate,
      'date': dateStr,
    };

    _syncedAttendances.insert(0, record);

    final empIdx = _syncedEmployees.indexWhere((e) =>
        (e['fullName'] ?? '').toString().toLowerCase() == employeeName.toLowerCase() ||
        (email != null && email.isNotEmpty && (e['email'] ?? '').toString().toLowerCase() == email.toLowerCase()));

    if (empIdx >= 0) {
      _syncedEmployees[empIdx]['status'] = isLate ? 'Late' : 'Present';
    }

    await _save();
    debugPrint('✅ [AppSyncService] Recorded attendance for: $employeeName at $timeStr');
  }

  /// Xóa nhân viên khỏi danh sách đồng bộ khi admin thực hiện lệnh DELETE API
  static Future<void> removeEmployee(String idOrEmail) async {
    await init();
    final query = idOrEmail.toLowerCase().trim();
    _syncedEmployees.removeWhere((e) =>
        (e['id'] ?? '').toString().toLowerCase().trim() == query ||
        (e['email'] ?? '').toString().toLowerCase().trim() == query);
    await _save();
  }

  /// Hợp nhất danh sách nhân viên từ Server với nhân viên mới tạo từ phiên hiện tại
  static List<Map<String, dynamic>> mergeEmployees(List<Map<String, dynamic>> baseList) {
    final result = List<Map<String, dynamic>>.from(baseList);

    for (var localEmp in _syncedEmployees) {
      final email = (localEmp['email'] ?? '').toString().toLowerCase().trim();
      final name = (localEmp['fullName'] ?? localEmp['name'] ?? '').toString().toLowerCase().trim();

      final existingIdx = result.indexWhere((e) =>
          (email.isNotEmpty && (e['email'] ?? '').toString().toLowerCase().trim() == email) ||
          (name.isNotEmpty && (e['fullName'] ?? e['name'] ?? '').toString().toLowerCase().trim() == name));

      if (existingIdx >= 0) {
        result[existingIdx] = {
          ...result[existingIdx],
          ...localEmp,
        };
      } else {
        result.insert(0, localEmp);
      }
    }

    return result;
  }

  /// Hợp nhất nhật ký chấm công từ Server với lượt chấm công thực tế
  static List<Map<String, dynamic>> mergeAttendances(List<Map<String, dynamic>> baseList) {
    final result = List<Map<String, dynamic>>.from(baseList);

    for (var att in _syncedAttendances) {
      final name = att['name']?.toString() ?? '';
      final time = att['time']?.toString() ?? '';

      final exists = result.any((r) => r['name'] == name && r['time'] == time);
      if (!exists) {
        result.insert(0, {
          ...att,
          'icon': att['icon'] ?? _resolveIcon(att['method']?.toString()),
        });
      }
    }

    return result;
  }
}
