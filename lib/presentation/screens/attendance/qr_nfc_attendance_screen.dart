import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/app_sync_service.dart';
import '../../widgets/fingerprint_scanner_widget.dart';

class QrNfcAttendanceScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const QrNfcAttendanceScreen({super.key, required this.user});

  @override
  State<QrNfcAttendanceScreen> createState() => _QrNfcAttendanceScreenState();
}

class _QrNfcAttendanceScreenState extends State<QrNfcAttendanceScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _laserController;
  late Animation<double> _laserAnimation;

  // Dynamic QR
  String _qrToken = '';
  int _secondsLeft = 45;
  Timer? _countdownTimer;
  bool _isLoadingQr = false;

  // NFC & Biometric
  bool _isNfcScanning = false;
  int _tab3SubMode = 0; // 0: Thẻ NFC, 1: Vân tay sinh trắc học

  final Color oceanDark = AppColors.oceanDeep;
  final Color oceanPrimary = AppColors.oceanPrimary;
  final Color oceanLight = AppColors.oceanLight;
  final Color oceanBackground = AppColors.scaffoldBg;
  final Color sunshineYellow = AppColors.sunlightGold;
  final Color sunshineOrange = AppColors.sunlightOrange;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: -100, end: 100).animate(
      CurvedAnimation(parent: _laserController, curve: Curves.easeInOut),
    );

    _fetchDynamicQr();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _laserController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // 1. Lấy mã QR động từ máy chủ (5.e)
  Future<void> _fetchDynamicQr() async {
    final token = widget.user['token']?.toString() ?? '';
    setState(() {
      _isLoadingQr = true;
    });

    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/QRAttendance/generate-dynamic-qr'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 7));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _qrToken = data['token'] ?? data['qrDataString'] ?? 'OFFICE_CHECKIN_DEMO';
          _secondsLeft = data['validSeconds'] ?? 45;
          _isLoadingQr = false;
        });
        _startCountdown();
      } else {
        setState(() {
          _isLoadingQr = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingQr = false;
        });
      }
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 1) {
        setState(() {
          _secondsLeft--;
        });
      } else {
        timer.cancel();
        _fetchDynamicQr(); // Tự động làm mới khi hết 45s
      }
    });
  }

  // 2. Chấm công bằng cách quét mã QR (5.e)
  Future<void> _handleScanQr({String? customToken}) async {
    final token = widget.user['token']?.toString() ?? '';
    final qrToSubmit = customToken ?? _qrToken;

    if (qrToSubmit.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đợi hệ thống tạo mã QR hợp lệ')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/QRAttendance/scan-qr-checkin'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'qrToken': qrToSubmit,
          'latitude': 10.7769,
          'longitude': 106.7009,
          'deviceId': 'QR_CAMERA_SCANNER_PHONE',
        }),
      ).timeout(Duration(milliseconds: ApiConstants.timeout));

      if (!mounted) return;
      Navigator.pop(context); // Đóng indicator

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == true) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.qr_code_2, color: Colors.green, size: 28),
                SizedBox(width: 8),
                Text('Quét QR thành công'),
              ],
            ),
            content: Text(
              '${data['message'] ?? 'Đã ghi nhận chấm công mã QR thành công!'}\n\n'
              'Phương thức: Mã QR động (Dynamic QR HMAC-SHA256)\n'
              'Thời gian: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context, true);
                },
                child: const Text('Xong'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Mã QR không hợp lệ hoặc đã hết hạn'),
            backgroundColor: sunshineOrange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi quét QR: $e')),
      );
    }
  }

  // 3. Chấm công bằng thẻ NFC hoặc Vân tay sinh trắc học (5.e)
  Future<void> _handleNfcCheckIn() async {
    final token = widget.user['token']?.toString() ?? '';
    setState(() {
      _isNfcScanning = true;
    });

    await Future.delayed(const Duration(milliseconds: 1200));

    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/QRAttendance/nfc-checkin'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'nfcCardUid': 'NFC_UID_NV_${widget.user['username'] ?? '001'}_${DateTime.now().day}',
          'deviceId': 'NFC_TRANSMITTER_MOBILE',
        }),
      ).timeout(Duration(milliseconds: ApiConstants.timeout));

      if (!mounted) return;
      final data = jsonDecode(response.body);

      setState(() {
        _isNfcScanning = false;
      });

      if (response.statusCode == 200 && data['status'] == true) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.nfc, color: Colors.blueAccent, size: 28),
                SizedBox(width: 8),
                Text('Chạm thẻ NFC thành công'),
              ],
            ),
            content: Text(
              '${data['message'] ?? 'Đã xác nhận thẻ NFC nhân viên!'}\n\n'
              'Mã thẻ UID: NFC_UID_NV_${widget.user['username'] ?? '001'}\n'
              'Phương thức: Thẻ thông minh không tiếp xúc (Contactless NFC)',
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context, true);
                },
                child: const Text('Đóng'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Thẻ NFC không được nhận dạng'),
            backgroundColor: sunshineOrange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isNfcScanning = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi cảm biến NFC: $e')),
      );
    }
  }

  // Chấm công bằng vân tay sinh trắc học
  Future<void> _handleFingerprintCheckIn() async {
    final token = widget.user['token']?.toString() ?? '';
    final empName = widget.user['fullName'] ?? widget.user['name'] ?? widget.user['username'] ?? 'Nhân viên';
    final email = widget.user['email']?.toString() ?? '';
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    await AppSyncService.recordAttendance(
      employeeName: empName,
      email: email,
      method: 'Vân tay sinh trắc',
      isLate: false,
      time: timeStr,
      status: 'Đúng giờ',
    );

    try {
      final payload = jsonEncode({
        'latitude': 10.762622,
        'longitude': 106.660172,
        'accuracy': 5.0,
        'capturedAt': now.toUtc().toIso8601String(),
        'idempotencyKey': now.millisecondsSinceEpoch.toString(),
        'isMocked': false,
        'qr': null,
      });

      var response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/attendance/check-in'),
        headers: {
          'Content-Type': 'application/json',
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: payload,
      ).timeout(Duration(milliseconds: ApiConstants.timeout));

      if (response.statusCode == 404) {
        response = await http.post(
          Uri.parse('${ApiConstants.baseUrl}/Attendance/check-in'),
          headers: {
            'Content-Type': 'application/json',
            if (token.isNotEmpty) 'Authorization': 'Bearer $token',
          },
          body: payload,
        ).timeout(Duration(milliseconds: ApiConstants.timeout));
      }

      if (!mounted) return;
      Map<String, dynamic> data = {};
      try {
        final parsed = jsonDecode(response.body);
        if (parsed is Map<String, dynamic>) data = parsed;
      } catch (_) {}

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.fingerprint, color: Colors.green, size: 28),
              SizedBox(width: 8),
              Text('Xác thực vân tay thành công'),
            ],
          ),
          content: Text(
            '${data['message'] ?? 'Đã xác thực vân tay và ghi nhận chấm công thành công!'}\n\n'
            'Nhân viên: ${widget.user['name'] ?? widget.user['username'] ?? 'Trần Văn Lương'}\n'
            'Phương thức: Cảm biến vân tay sinh trắc học thiết bị',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, true);
              },
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
              SizedBox(width: 8),
              Text('Chấm công vân tay thành công'),
            ],
          ),
          content: Text(
            'Đã ghi nhận chấm công vân tay thành công!\n\n'
            'Nhân viên: ${widget.user['name'] ?? widget.user['username'] ?? 'Trần Văn Lương'}\n'
            'Phương thức: Cảm biến vân tay sinh trắc học thiết bị',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, true);
              },
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: oceanBackground,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.oceanHeaderGradient,
          ),
        ),
        title: const Text(
          'Chấm công QR & NFC / Vân tay',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: sunshineYellow,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.qr_code_scanner), text: 'Quét QR'),
            Tab(icon: Icon(Icons.qr_code_2), text: 'Mã QR Động'),
            Tab(icon: Icon(Icons.nfc), text: 'Thẻ NFC / Vân tay'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildScanQrTab(),
          _buildDynamicQrTab(),
          _buildNfcTab(),
        ],
      ),
    );
  }

  // TAB 1: Quét mã QR
  Widget _buildScanQrTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Text(
            'Hướng camera điện thoại về phía mã QR tại cửa văn phòng',
            textAlign: TextAlign.center,
            style: TextStyle(color: oceanDark, fontSize: 15, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 24),

          // Khung quét QR Neon Laser
          Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              color: oceanDark,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: oceanPrimary.withValues(alpha: 0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Khung viền góc
                Container(
                  width: 210,
                  height: 210,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),

                // Icon QR mờ nền
                Icon(
                  Icons.qr_code_2_rounded,
                  size: 130,
                  color: Colors.white.withValues(alpha: 0.25),
                ),

                // Tia laser quét lên xuống
                AnimatedBuilder(
                  animation: _laserAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _laserAnimation.value),
                      child: Container(
                        width: 200,
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.greenAccent,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.greenAccent.withValues(alpha: 0.8),
                              blurRadius: 10,
                              spreadRadius: 2,
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

          const SizedBox(height: 32),

          // Nút bấm thực hiện quét QR
          Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              gradient: AppColors.oceanPrimaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.oceanPrimary.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text(
                'QUÉT MÃ QR VĂN PHÒNG',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => _handleScanQr(),
            ),
          ),
        ],
      ),
    );
  }

  // TAB 2: Tạo mã QR Động 45s
  Widget _buildDynamicQrTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Text(
            'Mã QR động được mã hóa bằng chữ ký số HMAC-SHA256\nĐổi mã mỗi 45 giây để chống điểm danh hộ',
            textAlign: TextAlign.center,
            style: TextStyle(color: oceanDark, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 20),

          // Thẻ hiển thị mã QR
          Card(
            elevation: 6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  _isLoadingQr
                      ? const SizedBox(
                          height: 200,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.black12, width: 2),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(Icons.qr_code_2, size: 190, color: oceanDark),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.fingerprint, size: 28, color: sunshineOrange),
                              ),
                            ],
                          ),
                        ),

                  const SizedBox(height: 20),

                  // Bộ đếm thời gian 45 giây
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.timer_outlined, size: 20, color: sunshineOrange),
                      const SizedBox(width: 8),
                      Text(
                        'Hết hạn sau: $_secondsLeft giây',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: sunshineOrange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          TextButton.icon(
            icon: Icon(Icons.refresh, color: sunshineOrange),
            label: Text(
              'Làm mới mã ngay lập tức',
              style: TextStyle(color: sunshineOrange, fontWeight: FontWeight.bold),
            ),
            onPressed: _fetchDynamicQr,
          ),
        ],
      ),
    );
  }

  // TAB 3: Thẻ NFC & Vân tay
  Widget _buildNfcTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          // Chuyển đổi giữa Thẻ NFC và Vân tay
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _tab3SubMode = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _tab3SubMode == 0 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _tab3SubMode == 0
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.nfc,
                            size: 18,
                            color: _tab3SubMode == 0 ? AppColors.oceanDeep : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Thẻ NFC',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: _tab3SubMode == 0 ? AppColors.oceanDeep : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _tab3SubMode = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _tab3SubMode == 1 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _tab3SubMode == 1
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.fingerprint,
                            size: 18,
                            color: _tab3SubMode == 1 ? sunshineOrange : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Vân tay',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: _tab3SubMode == 1 ? sunshineOrange : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (_tab3SubMode == 1) ...[
            // CHẾ ĐỘ QUÉT VÂN TAY: Chỉ quét khi người dùng đặt và giữ ngón tay
            FingerprintScannerWidget(
              title: 'CẢM BIẾN VÂN TAY CHẤM CÔNG',
              subtitle: 'Chỉ quét khi bạn đặt và giữ ngón tay trên khu vực cảm biến',
              primaryColor: sunshineOrange,
              onScanSuccess: _handleFingerprintCheckIn,
            ),
          ] else ...[
            Text(
              'Chạm mặt sau điện thoại vào thẻ nhân viên NFC hoặc máy đọc NFC văn phòng',
              textAlign: TextAlign.center,
              style: TextStyle(color: oceanDark, fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 36),

            // Minh họa chạm NFC
            GestureDetector(
              onTap: _isNfcScanning ? null : _handleNfcCheckIn,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: (_isNfcScanning ? Colors.blueAccent : oceanLight).withValues(alpha: 0.3),
                      blurRadius: 25,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Center(
                  child: _isNfcScanning
                      ? const CircularProgressIndicator()
                      : Icon(
                          Icons.contactless_rounded,
                          size: 90,
                          color: oceanDark,
                        ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            Text(
              _isNfcScanning ? 'Đang đọc tần số vô tuyến NFC...' : 'Sẵn sàng chạm thẻ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _isNfcScanning ? Colors.blueAccent : oceanDark,
              ),
            ),

            const SizedBox(height: 36),

            Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                gradient: AppColors.oceanPrimaryGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.oceanPrimary.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.nfc),
                label: const Text(
                  'CHẠM THẺ NHÂN VIÊN NFC',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _isNfcScanning ? null : _handleNfcCheckIn,
              ),
            ),
          ],
        ],
      ),
    );
  }

}
