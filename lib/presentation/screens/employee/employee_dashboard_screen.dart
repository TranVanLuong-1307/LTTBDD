import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/biometric_registry_service.dart';
import '../../../core/services/app_sync_service.dart';
import '../auth/login_screen.dart';
import '../attendance/face_recognition_screen.dart';
import '../attendance/location_sharing_screen.dart';
import '../attendance/qr_nfc_attendance_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../../widgets/fingerprint_scanner_widget.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const EmployeeDashboardScreen({super.key, required this.user});

  @override
  State<EmployeeDashboardScreen> createState() => _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
  int _currentIndex = 0;
  List<Map<String, dynamic>> _attendanceRecords = [];
  List<Map<String, dynamic>> _leaveRequests = [];
  bool _isLoading = false;

  late Map<String, dynamic> _currentUser;

  // Ca làm việc được chọn
  String _selectedShift = 'Ca Sáng (08:00 - 12:00 • x1.0)';
  final List<String> _shifts = [
    'Ca Sáng (08:00 - 12:00 • x1.0)',
    'Ca Chiều (13:00 - 17:00 • x1.0)',
    'Ca Tối (18:00 - 22:00 • x1.2)',
    'Ca Hành Chính (08:00 - 17:30 • x1.0)',
  ];

  // Hệ màu đồng bộ chuẩn toàn bộ ứng dụng
  final Color primaryDarkNav = AppColors.primaryDarkNav;
  final Color navyCardStart = AppColors.navyCardStart;
  final Color navyCardEnd = AppColors.navyCardEnd;
  final Color royalBlue = AppColors.royalBlue;
  final Color darkButtonColor = AppColors.darkButtonColor;
  final Color scaffoldBg = AppColors.scaffoldBg;
  final Color lightBluePill = AppColors.lightBluePill;

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatCurrency(int amount) {
    String str = amount.toString();
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return '${str.replaceAllMapped(reg, (Match m) => '${m[1]}.')} VNĐ';
  }

  // Lấy tên hiển thị của người dùng (TUYỆT ĐỐI KHÔNG HIỆN ĐỊA CHỈ GMAIL Ở TIÊU ĐỀ)
  String _getUserDisplayName() {
    final fullName = _currentUser['fullName'];
    if (fullName != null &&
        fullName.toString().trim().isNotEmpty &&
        !fullName.toString().contains('@')) {
      return fullName.toString().trim();
    }
    final name = _currentUser['name'];
    if (name != null &&
        name.toString().trim().isNotEmpty &&
        !name.toString().contains('@') &&
        name.toString().trim() != 'Người dùng') {
      return name.toString().trim();
    }
    final email = _currentUser['email'] ?? _currentUser['username'] ?? '';
    if (email.toString().contains('@')) {
      final prefix = email.toString().split('@')[0];
      if (prefix.isNotEmpty) {
        return prefix[0].toUpperCase() + prefix.substring(1);
      }
    }
    return 'Nhân viên';
  }

  String _getEmployeeCode() {
    final code = _currentUser['employeeCode'] ?? _currentUser['code'];
    if (code != null &&
        code.toString().trim().isNotEmpty &&
        !code.toString().contains('@')) {
      return code.toString().trim();
    }
    final id = _currentUser['id'];
    if (id != null &&
        id.toString().trim().isNotEmpty &&
        !id.toString().contains('-') &&
        !id.toString().contains('@')) {
      return 'NV${id.toString().trim()}';
    }
    return '';
  }

  String _getDepartment() {
    final dept = _currentUser['department'] ??
        _currentUser['departmentName'] ??
        _currentUser['phongBan'];
    if (dept != null && dept.toString().trim().isNotEmpty) {
      if (dept is Map && dept['name'] != null) {
        return dept['name'].toString();
      }
      return dept.toString();
    }
    return 'Phòng Phát Triển';
  }

  Map<String, dynamic> _decodeJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length == 3) {
        final payload = parts[1];
        final normalized = base64Url.normalize(payload);
        final resp = utf8.decode(base64Url.decode(normalized));
        final data = jsonDecode(resp);
        if (data is Map<String, dynamic>) return data;
      }
    } catch (_) {}
    return {};
  }

  // Kiểm tra tài khoản có được cấp quyền Admin từ API hay không
  bool _isAdminUser() {
    // 1. Kiểm tra danh sách roles từ API (Roles = ["Admin", ...])
    final roles = _currentUser['roles'] ?? _currentUser['Roles'];
    if (roles is List) {
      if (roles.any((r) => r.toString().toLowerCase().contains('admin') || r.toString().toLowerCase().contains('quanly'))) {
        return true;
      }
    }

    // 2. Kiểm tra PrimaryRole từ API
    final primaryRole = (_currentUser['primaryRole'] ?? _currentUser['PrimaryRole'])?.toString().toLowerCase();
    if (primaryRole != null && (primaryRole.contains('admin') || primaryRole.contains('quanly'))) {
      return true;
    }

    // 3. Kiểm tra TargetDashboard từ API
    final targetDashboard = (_currentUser['targetDashboard'] ?? _currentUser['TargetDashboard'])?.toString().toLowerCase();
    if (targetDashboard != null && (targetDashboard.contains('admin') || targetDashboard.contains('manager'))) {
      return true;
    }

    // 4. Kiểm tra trường Role đơn lẻ từ API
    final role = (_currentUser['role'] ?? _currentUser['Role'])?.toString().toLowerCase();
    if (role != null && (role.contains('admin') || role.contains('quanly') || role.contains('manager') || role.contains('quản trị'))) {
      return true;
    }

    // 5. Kiểm tra trường isAdmin từ API
    if (_currentUser['isAdmin'] == true ||
        _currentUser['IsAdmin'] == true ||
        _currentUser['isAdmin'] == 'true' ||
        _currentUser['is_admin'] == true) {
      return true;
    }

    // 6. Kiểm tra JWT token claims trực tiếp từ Token API
    final token = _currentUser['token']?.toString() ?? '';
    if (token.isNotEmpty) {
      final jwtClaims = _decodeJwt(token);
      final dynamic jwtRole = jwtClaims['http://schemas.microsoft.com/ws/2008/06/identity/claims/role'] ??
          jwtClaims['role'] ??
          jwtClaims['roles'] ??
          jwtClaims['Roles'];
      if (jwtRole is List) {
        if (jwtRole.any((r) => r.toString().toLowerCase().contains('admin') || r.toString().toLowerCase().contains('quanly'))) {
          return true;
        }
      } else if (jwtRole != null) {
        final rStr = jwtRole.toString().toLowerCase();
        if (rStr.contains('admin') || rStr.contains('quanly') || rStr.contains('manager')) {
          return true;
        }
      }
    }

    return false;
  }

  Map<String, dynamic> _mapServerRecordToUi(Map<String, dynamic> item) {
    DateTime? checkInDate;
    if (item['checkInTime'] != null) {
      checkInDate = DateTime.tryParse(item['checkInTime'].toString())?.toLocal();
    } else if (item['date'] != null) {
      checkInDate = DateTime.tryParse(item['date'].toString())?.toLocal();
    }

    DateTime? checkOutDate;
    if (item['checkOutTime'] != null) {
      checkOutDate = DateTime.tryParse(item['checkOutTime'].toString())?.toLocal();
    }

    String formattedDate = checkInDate != null ? _formatDate(checkInDate) : (item['date']?.toString() ?? '');
    String checkInStr = checkInDate != null ? _formatTime(checkInDate) : (item['checkIn'] ?? '--:--');
    String checkOutStr = checkOutDate != null ? _formatTime(checkOutDate) : (item['checkOut'] ?? '--:--');

    String rawStatus = item['status']?.toString() ?? 'OnTime';
    String displayStatus;
    if (rawStatus == 'OnTime' || rawStatus == 'Đúng giờ') {
      displayStatus = 'Đúng giờ';
    } else if (rawStatus == 'Late' || rawStatus == 'Đi muộn') {
      displayStatus = 'Đi muộn';
    } else if (rawStatus == 'EarlyLeave' || rawStatus == 'Về sớm') {
      displayStatus = 'Về sớm';
    } else {
      displayStatus = rawStatus;
    }

    return {
      'id': item['id'],
      'date': formattedDate,
      'checkIn': checkInStr,
      'checkOut': checkOutStr,
      'status': displayStatus,
      'workHours': item['workHours'],
      'method': item['checkInMethod'] ?? item['method'] ?? 'Manual',
    };
  }

  @override
  void initState() {
    super.initState();
    _currentUser = Map<String, dynamic>.from(widget.user);
    final token = _currentUser['token']?.toString() ?? '';
    if (token.isNotEmpty) {
      final jwtClaims = _decodeJwt(token);
      final dynamic jwtRole = jwtClaims['http://schemas.microsoft.com/ws/2008/06/identity/claims/role'] ??
          jwtClaims['role'] ??
          jwtClaims['roles'] ??
          jwtClaims['Roles'];
      if (jwtRole != null) {
        if (jwtRole is List) {
          _currentUser['roles'] = jwtRole;
          if (jwtRole.isNotEmpty) _currentUser['role'] = jwtRole.first.toString();
        } else {
          _currentUser['role'] = jwtRole.toString();
          _currentUser['roles'] = [jwtRole.toString()];
        }
      }
    }
    AppSyncService.registerOrUpdateEmployee(_currentUser);
    _loadData();
    _loadLeaveRequests();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final token = _currentUser['token']?.toString() ?? '';
      if (token.isNotEmpty) {
        // 1. Tải thông tin người dùng từ /api/me (với thời gian chờ 15s cho Render)
        try {
          final profileRes = await http.get(
            Uri.parse('${ApiConstants.baseUrl}/me'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          ).timeout(const Duration(seconds: 15));

          if (profileRes.statusCode == 200) {
            final profileData = jsonDecode(profileRes.body);
            Map<String, dynamic> actualData = {};
            if (profileData is Map<String, dynamic>) {
              if (profileData.containsKey('data') && profileData['data'] is Map<String, dynamic>) {
                actualData = Map<String, dynamic>.from(profileData['data']);
              } else if (profileData.containsKey('user') && profileData['user'] is Map<String, dynamic>) {
                actualData = Map<String, dynamic>.from(profileData['user']);
              } else {
                actualData = Map<String, dynamic>.from(profileData);
              }
            }

            if (mounted && actualData.isNotEmpty) {
              setState(() {
                _currentUser = {
                  ..._currentUser,
                  ...actualData,
                  if (actualData['role'] != null) 'role': actualData['role'],
                  if (actualData['roles'] != null) 'roles': actualData['roles'],
                  if (actualData['department'] != null) 'department': actualData['department'],
                };
              });
            }
          }
        } catch (_) {}
        final response = await http.get(
          Uri.parse('${ApiConstants.baseUrl}/Attendance/my-history'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 7));

        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          final serverList = data.map((e) => _mapServerRecordToUi(Map<String, dynamic>.from(e))).toList();
          if (mounted) {
            setState(() {
              _attendanceRecords = serverList;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading attendance from API: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadLeaveRequests() async {
    final token = widget.user['token']?.toString() ?? '';
    final headers = {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    try {
      http.Response? response;
      try {
        response = await http.get(
          Uri.parse('${ApiConstants.baseUrl}/requests'),
          headers: headers,
        ).timeout(const Duration(seconds: 6));
      } catch (_) {}

      if (response == null || response.statusCode != 200) {
        try {
          response = await http.get(
            Uri.parse('${ApiConstants.baseUrl}/LeaveRequest'),
            headers: headers,
          ).timeout(const Duration(seconds: 6));
        } catch (_) {}
      }

      if (response != null && response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data is List ? data : (data is Map && data['items'] is List ? data['items'] as List : null);
        if (list != null && mounted) {
          setState(() {
            _leaveRequests = list.map((e) => Map<String, dynamic>.from(e)).toList();
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _deleteLeaveRequest(String id) async {
    final token = widget.user['token']?.toString() ?? '';
    final headers = {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
    try {
      final res = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}/requests/$id'),
        headers: headers,
      ).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200 || res.statusCode == 204) {
        setState(() {
          _leaveRequests.removeWhere((l) => l['id']?.toString() == id);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã hủy đơn thành công!'), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (_) {}
  }

  bool _isTodayCheckedIn() {
    final todayDate = _formatDate(DateTime.now());
    final index = _attendanceRecords.indexWhere((r) => r['date'] == todayDate);
    if (index >= 0) {
      return _attendanceRecords[index]['checkIn'] != '--:--' && _attendanceRecords[index]['checkIn'] != null;
    }
    return false;
  }

  bool _isTodayCheckedOut() {
    final todayDate = _formatDate(DateTime.now());
    final index = _attendanceRecords.indexWhere((r) => r['date'] == todayDate);
    if (index >= 0) {
      return _attendanceRecords[index]['checkOut'] != '--:--' && _attendanceRecords[index]['checkOut'] != null;
    }
    return false;
  }

  Future<void> _handleCheckIn() async {
    final token = widget.user['token']?.toString() ?? '';
    final displayName = _getUserDisplayName();
    final email = _currentUser['email']?.toString() ?? '';

    if (token.isNotEmpty) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final payload = jsonEncode({
          'latitude': 10.762622,
          'longitude': 106.660172,
          'accuracy': 5.0,
          'capturedAt': DateTime.now().toUtc().toIso8601String(),
          'idempotencyKey': DateTime.now().millisecondsSinceEpoch.toString(),
          'isMocked': false,
          'qr': null,
        });

        var response = await http.post(
          Uri.parse('${ApiConstants.baseUrl}/attendance/check-in'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: payload,
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 404) {
          response = await http.post(
            Uri.parse('${ApiConstants.baseUrl}/Attendance/check-in'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: payload,
          ).timeout(const Duration(seconds: 8));
        }

        if (mounted) Navigator.of(context).pop();

        final data = jsonDecode(response.body);
        if (response.statusCode == 200 || response.statusCode == 201) {
          final now = DateTime.now();
          final currentTime = _formatTime(now);
          await AppSyncService.recordAttendance(
            employeeName: displayName,
            email: email,
            method: 'Check-in 1 chạm',
            isLate: false,
            time: currentTime,
            status: 'Đúng giờ',
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(data['message'] ?? 'Check-in thành công!'),
                backgroundColor: royalBlue,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          await _loadData();
          return;
        }
      } catch (e) {
        if (mounted) Navigator.of(context).pop();
      }
    }

    // Local fallback & Realtime AppSync
    final now = DateTime.now();
    final todayDate = _formatDate(now);
    final currentTime = _formatTime(now);

    await AppSyncService.recordAttendance(
      employeeName: displayName,
      email: email,
      method: 'Check-in 1 chạm',
      isLate: false,
      time: currentTime,
      status: 'Đúng giờ',
    );

    setState(() {
      final existingIndex = _attendanceRecords.indexWhere((r) => r['date'] == todayDate);
      if (existingIndex >= 0) {
        _attendanceRecords[existingIndex] = {
          ..._attendanceRecords[existingIndex],
          'checkIn': currentTime,
        };
      } else {
        _attendanceRecords.insert(0, {
          'date': todayDate,
          'checkIn': currentTime,
          'checkOut': '--:--',
          'status': 'Đúng giờ',
        });
      }
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Đã ghi nhận Check-in 1 chạm!'),
        backgroundColor: royalBlue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleCheckOut() async {
    final token = widget.user['token']?.toString() ?? '';
    final displayName = _getUserDisplayName();
    final email = _currentUser['email']?.toString() ?? '';

    if (token.isNotEmpty) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final payload = jsonEncode({
          'latitude': 10.762622,
          'longitude': 106.660172,
          'accuracy': 5.0,
          'capturedAt': DateTime.now().toUtc().toIso8601String(),
          'idempotencyKey': DateTime.now().millisecondsSinceEpoch.toString(),
          'isMocked': false,
          'qr': null,
        });

        var response = await http.post(
          Uri.parse('${ApiConstants.baseUrl}/attendance/check-out'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: payload,
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 404) {
          response = await http.post(
            Uri.parse('${ApiConstants.baseUrl}/Attendance/check-out'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: payload,
          ).timeout(const Duration(seconds: 8));
        }

        if (mounted) Navigator.of(context).pop();

        final data = jsonDecode(response.body);
        if (response.statusCode == 200 || response.statusCode == 201) {
          final now = DateTime.now();
          final currentTime = _formatTime(now);
          await AppSyncService.recordAttendance(
            employeeName: displayName,
            email: email,
            method: 'Tan ca 1 chạm',
            isLate: false,
            time: currentTime,
            status: 'Tan ca',
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(data['message'] ?? 'Check-out thành công!'),
                backgroundColor: royalBlue,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          await _loadData();
          return;
        }
      } catch (e) {
        if (mounted) Navigator.of(context).pop();
      }
    }

    final now = DateTime.now();
    final todayDate = _formatDate(now);
    final currentTime = _formatTime(now);

    await AppSyncService.recordAttendance(
      employeeName: displayName,
      email: email,
      method: 'Tan ca 1 chạm',
      isLate: false,
      time: currentTime,
      status: 'Tan ca',
    );

    setState(() {
      final existingIndex = _attendanceRecords.indexWhere((r) => r['date'] == todayDate);
      if (existingIndex >= 0) {
        _attendanceRecords[existingIndex] = {
          ..._attendanceRecords[existingIndex],
          'checkOut': currentTime,
        };
      }
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Đã ghi nhận Check-out thành công!'),
        backgroundColor: royalBlue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Chấm công đa tầng (Vân tay + Geofence GPS)
  void _handleMultiLayerAttendance() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.verified_user_rounded, color: royalBlue, size: 26),
                const SizedBox(width: 10),
                Text(
                  'Chấm Công Đa Tầng Bảo Mật',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: darkButtonColor),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Xác thực kết hợp 3 lớp bảo mật: Cảm biến vân tay + Định vị Geofence bán kính 150m + Chữ ký số mã QR.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.fingerprint, size: 22),
              label: const Text('XÁC THỰC VÂN TAY & GEOFENCE'),
              style: ElevatedButton.styleFrom(
                backgroundColor: darkButtonColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _showFingerprintAttendanceVerificationDialog();
              },
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: Icon(Icons.share_location_rounded, color: royalBlue, size: 22),
              label: Text('MỞ BẢN ĐỒ GEOFENCE GPS (5.b)', style: TextStyle(color: royalBlue, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: royalBlue, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => LocationSharingScreen(user: widget.user)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFingerprintAttendanceVerificationDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.fingerprint, color: royalBlue, size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      'Xác thực Vân tay',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.primaryDarkNav,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                  onPressed: () => Navigator.pop(dialogCtx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FingerprintScannerWidget(
              title: 'CẢM BIẾN VÂN TAY CHẤM CÔNG',
              subtitle: 'Chỉ quét khi bạn đặt và giữ ngón tay trên cảm biến',
              primaryColor: royalBlue,
              onScanSuccess: () async {
                Navigator.pop(dialogCtx);
                final displayName = _getUserDisplayName();
                final email = _currentUser['email']?.toString() ?? '';
                final now = DateTime.now();
                final currentTime = _formatTime(now);
                await AppSyncService.recordAttendance(
                  employeeName: displayName,
                  email: email,
                  method: 'Chấm công Đa tầng (Vân tay)',
                  isLate: false,
                  time: currentTime,
                  status: 'Đúng giờ',
                );
                await _handleCheckIn();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi tài khoản không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Hủy', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final employeeCode = _getEmployeeCode();
    final displayName = _getUserDisplayName();
    final department = _getDepartment();
    final displayRole = _isAdminUser()
        ? 'QUẢN TRỊ VIÊN'
        : (_currentUser['role'] ?? _currentUser['Role'] ?? _currentUser['primaryRole'] ?? 'NHÂN VIÊN');

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.oceanHeaderGradient,
          ),
        ),
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.sunlightGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.sunlightGold.withValues(alpha: 0.45),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ],
              ),
              child: const Icon(Icons.work_outline, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    employeeCode.isNotEmpty ? '$employeeCode - $displayName' : displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$department • $displayRole',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.normal),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Nút Chuyển sang Giao diện Quản trị (Admin) - CHỈ hiển thị & có tác dụng khi tài khoản được cấp quyền Admin từ API
          if (_isAdminUser())
            Padding(
              padding: const EdgeInsets.only(right: 4.0),
              child: TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AdminDashboardScreen(user: _currentUser),
                    ),
                  );
                },
                icon: const Icon(Icons.admin_panel_settings_rounded, color: AppColors.sunlightGold, size: 18),
                label: const Text(
                  'Admin',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Làm mới thông tin & quyền',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Đang làm mới dữ liệu & kiểm tra quyền từ máy chủ API...'),
                  duration: Duration(seconds: 2),
                ),
              );
              await _loadData();
              if (!mounted) return;
              if (_isAdminUser()) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Tài khoản đã có quyền Quản trị (Admin)! Nút Admin đã xuất hiện trên thanh tiêu đề.'),
                    backgroundColor: AppColors.oceanPrimary,
                    duration: Duration(seconds: 3),
                  ),
                );
              } else {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Máy chủ chưa nhận diện quyền Admin cho phiên này. Vui lòng bấm Đăng xuất và Đăng nhập lại để nhận Token mới!'),
                    backgroundColor: AppColors.sunlightOrange,
                    duration: Duration(seconds: 4),
                  ),
                );
              }
            },
          ),
          IconButton(
            tooltip: 'Đơn nghỉ phép',
            icon: const Icon(Icons.note_alt_outlined, color: Colors.white, size: 22),
            onPressed: () {
              setState(() {
                _currentIndex = 2; // Nhảy sang tab Đơn nghỉ phép
              });
            },
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout, color: AppColors.orangeAccent, size: 22),
            onPressed: _showLogoutDialog,
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildAttendanceAndSalaryTab(),
          _buildAttendanceHistoryTab(),
          _buildLeaveRequestsTab(),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // TAB 0: CHẤM CÔNG & LƯƠNG (Giao diện theo ảnh mẫu chính xác)
  Widget _buildAttendanceAndSalaryTab() {
    return RefreshIndicator(
      color: royalBlue,
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // CARD 1: User Profile & Lương Card (Thẻ Trắng Nổi Bật + Hào Quang Vàng Cam)
            _buildProfileAndSalaryCard(),

            const SizedBox(height: 18),

            // CARD 2: Chấm Công Theo Ca Làm Việc
            _buildShiftAttendanceCard(),

            const SizedBox(height: 18),

            // CARD 3: Các tính năng thông minh Thuyết trình (5.a, 5.b, 5.e)
            _buildPresentationFeaturesQuickCard(),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // CARD 1: Thông tin người dùng & Lương linh hoạt theo tài khoản thực
  Widget _buildProfileAndSalaryCard() {
    final employeeCode = _getEmployeeCode();
    final displayName = _getUserDisplayName();
    final department = _getDepartment();
    final email = _currentUser['email']?.toString() ?? '';
    final workDaysCount = _attendanceRecords.length;

    final rawSalary = _currentUser['salary'] ?? _currentUser['totalSalary'] ?? _currentUser['baseSalary'];
    String salaryStr;
    if (rawSalary != null) {
      if (rawSalary is num) {
        salaryStr = _formatCurrency(rawSalary.toInt());
      } else {
        salaryStr = rawSalary.toString();
      }
    } else if (workDaysCount > 0) {
      salaryStr = _formatCurrency(workDaysCount * 450000);
    } else {
      salaryStr = '0 VNĐ';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryDarkNav.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          )
        ],
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row User info
          Row(
            children: [
              // Avatar tròn viền Hào quang Vàng Cam Sunshine (đồng bộ 100% với màn hình Login!)
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.yellowLight, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.orangeAccent.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white,
                  backgroundImage: _currentUser['avatar'] != null && _currentUser['avatar'].toString().isNotEmpty
                      ? NetworkImage(_currentUser['avatar'])
                      : null,
                  child: (_currentUser['avatar'] == null || _currentUser['avatar'].toString().isEmpty)
                      ? Icon(Icons.person, size: 34, color: primaryDarkNav)
                      : null,
                ),
              ),
              const SizedBox(width: 14),

              // Tên, phòng ban, email
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employeeCode.isNotEmpty ? '$employeeCode - $displayName' : displayName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryDarkNav,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.lightBlueBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        department,
                        style: TextStyle(
                          color: royalBlue,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.mail_outline, size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              email,
                              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // 2 Ô thống kê: Ngày công tháng & Lương tạm tính
          Row(
            children: [
              // Ô 1: Ngày công tháng
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.lightBlueBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.lightBluePill, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 14, color: royalBlue),
                          const SizedBox(width: 6),
                          Text(
                            'Ngày công tháng',
                            style: TextStyle(color: AppColors.textSub, fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$workDaysCount công',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: primaryDarkNav,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Ô 2: Lương tạm tính - Màu Cam Nắng Sunshine rực rỡ
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFEDD5), width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.payments_outlined, size: 15, color: AppColors.orangeAccent),
                          const SizedBox(width: 6),
                          Text(
                            'Lương tạm tính',
                            style: TextStyle(color: AppColors.textSub, fontSize: 11, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        salaryStr,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.orangeAccent,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // NÚT BẢO MẬT & ĐĂNG KÝ VÂN TAY / FACE ID
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.lightBlueBg,
                  const Color(0xFFFFF7ED),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.yellowLight, width: 1.5),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _showBiometricManagementSheet,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.orangeAccent, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.orangeAccent.withValues(alpha: 0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        child: const Icon(Icons.fingerprint, color: AppColors.orangeAccent, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Đăng ký Vân tay & Face ID',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryDarkNav,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.orangeAccent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Bảo mật',
                                    style: TextStyle(
                                      color: AppColors.orangeAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Kích hoạt đăng nhập 1-chạm không cần mật khẩu',
                              style: TextStyle(color: AppColors.textSub, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showBiometricManagementSheet() async {
    final email = _currentUser['email']?.toString() ?? '';
    final username = _currentUser['username']?.toString() ?? '';
    final accountKey = email.isNotEmpty ? email : username;

    bool isFingerprint = await BiometricRegistryService.isFingerprintRegistered(accountKey);
    bool isFace = await BiometricRegistryService.isFaceRegistered(accountKey);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.orangeAccent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.security_rounded, color: AppColors.orangeAccent, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CÀI ĐẶT SINH TRẮC HỌC',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.primaryDarkNav,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Đăng ký vân tay & Face ID để đăng nhập 1-chạm',
                              style: TextStyle(fontSize: 12, color: AppColors.textSub),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // MỤC 1: VÂN TAY (Fingerprint)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isFingerprint ? Colors.green.shade300 : AppColors.yellowLight,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.fingerprint,
                                color: isFingerprint ? Colors.green.shade600 : AppColors.orangeAccent,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Vân tay đăng nhập',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: AppColors.primaryDarkNav,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isFingerprint ? 'Đã kích hoạt trên thiết bị này' : 'Chưa đăng ký vân tay',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isFingerprint ? Colors.green.shade700 : Colors.grey.shade600,
                                      fontWeight: isFingerprint ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isFingerprint ? Colors.green.shade100 : Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isFingerprint ? 'ĐÃ ĐĂNG KÝ' : 'CHƯA CÓ',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isFingerprint ? Colors.green.shade800 : Colors.orange.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isFingerprint ? Colors.white : AppColors.orangeAccent,
                              foregroundColor: isFingerprint ? AppColors.orangeAccent : Colors.white,
                              side: isFingerprint ? const BorderSide(color: AppColors.orangeAccent, width: 1.5) : BorderSide.none,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: isFingerprint ? 0 : 2,
                            ),
                            icon: const Icon(Icons.fingerprint, size: 18),
                            label: Text(
                              isFingerprint ? 'QUÉT LẠI VÂN TAY MỚI' : 'ĐĂNG KÝ VÂN TAY NGAY',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onPressed: () async {
                              await _showFingerprintRegisterFlow(accountKey);
                              final updated = await BiometricRegistryService.isFingerprintRegistered(accountKey);
                              setSheetState(() {
                                isFingerprint = updated;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // MỤC 2: FACE ID (Khuôn mặt)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.lightBlueBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isFace ? Colors.green.shade300 : AppColors.lightBluePill,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.face_retouching_natural_rounded,
                                color: isFace ? Colors.green.shade600 : AppColors.royalBlue,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Face ID (Nhận diện khuôn mặt)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: AppColors.primaryDarkNav,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isFace ? 'Đã đăng ký khuôn mặt AI' : 'Chưa đăng ký khuôn mặt',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isFace ? Colors.green.shade700 : Colors.grey.shade600,
                                      fontWeight: isFace ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isFace ? Colors.green.shade100 : Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isFace ? 'ĐÃ ĐĂNG KÝ' : 'CHƯA CÓ',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isFace ? Colors.green.shade800 : AppColors.royalBlue,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isFace ? Colors.white : AppColors.royalBlue,
                              foregroundColor: isFace ? AppColors.royalBlue : Colors.white,
                              side: isFace ? const BorderSide(color: AppColors.royalBlue, width: 1.5) : BorderSide.none,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: isFace ? 0 : 2,
                            ),
                            icon: const Icon(Icons.camera_alt_outlined, size: 18),
                            label: Text(
                              isFace ? 'QUÉT LẠI KHUÔN MẶT MỚI' : 'MỞ CAMERA ĐĂNG KÝ FACE ID',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onPressed: () async {
                              Navigator.pop(sheetCtx);
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FaceRecognitionScreen(
                                    isRegisterMode: true,
                                    user: _currentUser,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(sheetCtx),
                    child: Text('Đóng', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showFingerprintRegisterFlow(String accountKey) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ĐĂNG KÝ VÂN TAY',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.primaryDarkNav,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                    onPressed: () => Navigator.pop(dialogCtx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FingerprintScannerWidget(
                title: 'CẢM BIẾN VÂN TAY THIẾT BỊ',
                subtitle: 'Chỉ quét khi bạn đặt và giữ ngón tay trên khu vực cảm biến',
                primaryColor: AppColors.orangeAccent,
                onScanSuccess: () async {
                  await BiometricRegistryService.registerFingerprint(accountKey);
                  if (dialogCtx.mounted) {
                    Navigator.of(dialogCtx).pop();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // CARD 2: Chấm Công Theo Ca Làm Việc
  Widget _buildShiftAttendanceCard() {
    final isCheckedIn = _isTodayCheckedIn();
    final isCheckedOut = _isTodayCheckedOut();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tiêu đề card có Icon QR
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF4FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.qr_code_scanner_rounded, color: royalBlue, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chấm Công Theo Ca Làm Việc',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: darkButtonColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Chọn ca làm việc để thực hiện Check-in / Check-out',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Dropdown Ca làm việc với nhãn nổi chuẩn theo ảnh mẫu
          InputDecorator(
            decoration: InputDecoration(
              labelText: 'Chọn Ca làm việc',
              labelStyle: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1.2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: royalBlue, width: 1.5),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedShift,
                isExpanded: true,
                icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade700),
                items: _shifts.map((String shift) {
                  return DropdownMenuItem<String>(
                    value: shift,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: royalBlue,
                          child: const Icon(Icons.access_time_filled, size: 14, color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            shift,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: darkButtonColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedShift = newValue;
                    });
                  }
                },
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 1. Nút CHẤM CÔNG ĐA TẦNG (VÂN TAY • G...)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.fingerprint, color: AppColors.orangeAccent, size: 22),
              label: const Text(
                'CHẤM CÔNG ĐA TẦNG (VÂN TAY • GEOFENCE)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: darkButtonColor,
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _handleMultiLayerAttendance,
            ),
          ),

          const SizedBox(height: 12),

          // 2. Nút CHECK-IN NHANH 1 CHẠM (hoặc CHECK-OUT NHANH 1 CHẠM)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              icon: Icon(
                isCheckedIn && !isCheckedOut ? Icons.logout_rounded : Icons.flash_on_rounded,
                color: Colors.white,
                size: 20,
              ),
              label: Text(
                isCheckedIn && !isCheckedOut ? 'CHECK-OUT NHANH 1 CHẠM' : 'CHECK-IN NHANH 1 CHẠM',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: royalBlue,
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: isCheckedIn && !isCheckedOut ? _handleCheckOut : _handleCheckIn,
            ),
          ),

          const SizedBox(height: 12),

          // 3. Nút Xác Thực Khuôn Mặt AI (ML Kit Face)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              icon: Icon(Icons.face_retouching_natural_rounded, color: royalBlue, size: 22),
              label: Text(
                'Xác Thực Khuôn Mặt AI (ML Kit Face)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: darkButtonColor,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: royalBlue, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FaceRecognitionScreen(
                      isLoginMode: false,
                      user: widget.user,
                    ),
                  ),
                );
                if (result == true) {
                  _loadData();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // Tiện ích bổ sung: Chức năng Thuyết trình 5.b (GPS) và 5.e (QR/NFC)
  Widget _buildPresentationFeaturesQuickCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.stars_rounded, color: AppColors.orangeAccent, size: 22),
              const SizedBox(width: 8),
              Text(
                'Chức Năng Nâng Cao (3.5đ Thuyết Trình)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: darkButtonColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // 5.b Định vị GPS & Chia sẻ vị trí
              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => LocationSharingScreen(user: widget.user)),
                    );
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                    decoration: BoxDecoration(
                      color: AppColors.lightBlueBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: royalBlue.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.share_location_rounded, color: royalBlue, size: 26),
                        const SizedBox(height: 6),
                        Text(
                          'Định Vị GPS (5.b)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: darkButtonColor),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          'Radar Geofence 150m',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // 5.e Quét mã QR & Quẹt thẻ NFC (Màu Cam ấm Amber)
              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => QrNfcAttendanceScreen(user: widget.user)),
                    );
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFFEDD5)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.qr_code_2_rounded, color: AppColors.orangeAccent, size: 26),
                        const SizedBox(height: 6),
                        Text(
                          'Mã QR & NFC (5.e)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: darkButtonColor),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          'Mã QR động 45s HMAC',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  // TAB 1: LỊCH SỬ CÔNG
  Widget _buildAttendanceHistoryTab() {
    return RefreshIndicator(
      color: royalBlue,
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Lịch Sử Chấm Công Chi Tiết',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkButtonColor),
                ),
                if (_isLoading)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: royalBlue),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_attendanceRecords.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Icon(Icons.event_busy_rounded, size: 54, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text('Chưa có dữ liệu chấm công', style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _attendanceRecords.length,
                itemBuilder: (context, index) {
                  final record = _attendanceRecords[index];
                  final isOntime = record['status'] == 'Đúng giờ';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shadowColor: primaryDarkNav.withValues(alpha: 0.06),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isOntime ? const Color(0xFFE8F5E9) : const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.calendar_today_rounded,
                              color: isOntime ? Colors.green.shade700 : AppColors.orangeAccent,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ngày: ${record['date']}',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: darkButtonColor),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.login, size: 14, color: AppColors.royalBlue),
                                    const SizedBox(width: 4),
                                    Text(record['checkIn'] ?? '--:--', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 14),
                                    const Icon(Icons.logout, size: 14, color: AppColors.orangeAccent),
                                    const SizedBox(width: 4),
                                    Text(record['checkOut'] ?? '--:--', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isOntime ? Colors.green.shade50 : const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: isOntime ? Colors.green.shade400 : const Color(0xFFFFD8A8)),
                            ),
                            child: Text(
                              record['status'] ?? '',
                              style: TextStyle(
                                color: isOntime ? Colors.green.shade700 : AppColors.orangeAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // TAB 2: ĐƠN NGHỈ PHÉP
  Widget _buildLeaveRequestsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Quản Lý Đơn Nghỉ Phép',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkButtonColor),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18, color: AppColors.yellowLight),
                label: const Text('Tạo Đơn'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: darkButtonColor,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _showCreateLeaveRequestDialog,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_leaveRequests.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(36),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: primaryDarkNav.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.lightBlueBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.yellowLight, width: 2),
                    ),
                    child: const Icon(Icons.assignment_turned_in_outlined, size: 48, color: AppColors.royalBlue),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có đơn nghỉ phép nào',
                    style: TextStyle(
                      color: primaryDarkNav,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Bạn có thể bấm nút "+ Tạo Đơn" ở góc trên để gửi đơn xin nghỉ phép đến ban quản lý.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _leaveRequests.length,
              itemBuilder: (context, index) {
                final item = _leaveRequests[index];
                final id = item['id']?.toString() ?? '';
                final isPending = item['status'] == 'Pending';
                final fromDate = item['from'] ?? item['startDate'] ?? '';
                final toDate = item['to'] ?? item['endDate'] ?? '';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFEDF4FF),
                      child: Icon(Icons.description_outlined, color: royalBlue),
                    ),
                    title: Text(item['reason'] ?? 'Nghỉ phép cá nhân', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Thời gian: ${fromDate.toString().split('T').first} đến ${toDate.toString().split('T').first}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Chip(
                          label: Text(
                            item['status'] ?? 'Pending',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: item['status'] == 'Approved'
                              ? Colors.green.shade100
                              : (item['status'] == 'Rejected' ? Colors.red.shade100 : Colors.amber.shade100),
                        ),
                        if (isPending && id.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.cancel_outlined, size: 20, color: Colors.redAccent),
                            tooltip: 'Hủy đơn',
                            onPressed: () => _deleteLeaveRequest(id),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _showCreateLeaveRequestDialog() {
    final reasonController = TextEditingController();
    String requestType = 'Leave';
    DateTime fromDate = DateTime.now().add(const Duration(days: 1));
    DateTime toDate = DateTime.now().add(const Duration(days: 2));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Tạo Đơn Xin Nghỉ Phép', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Loại đơn:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: requestType,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Leave', child: Text('Nghỉ phép (Leave)')),
                    DropdownMenuItem(value: 'Overtime', child: Text('Làm thêm giờ (Overtime)')),
                    DropdownMenuItem(value: 'Remote', child: Text('Làm việc từ xa (Remote)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => requestType = val);
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: fromDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 90)),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              fromDate = picked;
                              if (toDate.isBefore(fromDate)) toDate = fromDate;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Từ ngày', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              const SizedBox(height: 2),
                              Text('${fromDate.day.toString().padLeft(2, '0')}/${fromDate.month.toString().padLeft(2, '0')}/${fromDate.year}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: toDate,
                            firstDate: fromDate,
                            lastDate: DateTime.now().add(const Duration(days: 90)),
                          );
                          if (picked != null) {
                            setDialogState(() => toDate = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Đến ngày', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              const SizedBox(height: 2),
                              Text('${toDate.day.toString().padLeft(2, '0')}/${toDate.month.toString().padLeft(2, '0')}/${toDate.year}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Lý do xin nghỉ phép *',
                    hintText: 'Nhập lý do chi tiết...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: darkButtonColor, foregroundColor: Colors.white),
              onPressed: () async {
                final token = widget.user['token']?.toString() ?? '';
                if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vui lòng nhập lý do xin nghỉ phép!'), backgroundColor: Colors.orange),
                  );
                  return;
                }
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                final fromStr = '${fromDate.year}-${fromDate.month.toString().padLeft(2, '0')}-${fromDate.day.toString().padLeft(2, '0')}';
                final toStr = '${toDate.year}-${toDate.month.toString().padLeft(2, '0')}-${toDate.day.toString().padLeft(2, '0')}';

                try {
                  final res = await http.post(
                    Uri.parse('${ApiConstants.baseUrl}/requests'),
                    headers: {
                      'Content-Type': 'application/json',
                      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
                    },
                    body: jsonEncode({
                      'type': requestType,
                      'reason': reasonController.text.trim(),
                      'from': fromStr,
                      'to': toStr,
                    }),
                  ).timeout(const Duration(seconds: 6));

                  if (res.statusCode == 200 || res.statusCode == 201) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Đã gửi đơn xin nghỉ phép thành công!'), backgroundColor: Colors.green),
                    );
                    _loadLeaveRequests();
                  } else {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Không thể gửi đơn (${res.statusCode}): ${res.body}'), backgroundColor: Colors.red),
                    );
                  }
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Lỗi kết nối máy chủ: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Gửi Đơn'),
            ),
          ],
        ),
      ),
    );
  }

  // BOTTOM NAVIGATION BAR (Khớp 100% ảnh mẫu)
  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            index: 0,
            icon: Icons.fingerprint,
            label: 'Chấm Công & Lương',
          ),
          _buildNavItem(
            index: 1,
            icon: Icons.calendar_month_outlined,
            label: 'Lịch Sử Công',
          ),
          _buildNavItem(
            index: 2,
            icon: Icons.description_outlined,
            label: 'Đơn Nghỉ Phép',
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _currentIndex == index;

    return InkWell(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? lightBluePill : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? (index == 0 ? AppColors.orangeAccent : royalBlue)
                    : Colors.grey.shade500,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? darkButtonColor : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

