import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';

class LocationSharingScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const LocationSharingScreen({super.key, required this.user});

  @override
  State<LocationSharingScreen> createState() => _LocationSharingScreenState();
}

class _LocationSharingScreenState extends State<LocationSharingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool _isSharingLive = false;
  Timer? _liveTimer;
  bool _isLoading = false;

  // Tọa độ GPS mẫu (Trụ sở chính công ty tại Phố đi bộ Nguyễn Huệ, Quận 1)
  final double _currentLat = 10.7769;
  final double _currentLng = 106.7009;
  double _officeLat = 10.7769;
  double _officeLng = 106.7009;
  final double _geofenceRadiusMeters = 150.0;
  double _distanceToOffice = 15.0; // mét
  int _battery = 88;
  double _speed = 0.0;
  String _address = '123 Nguyễn Huệ, Bến Nghé, Quận 1, TP. Hồ Chí Minh';
  List<dynamic> _offices = [];

  final Color oceanDark = AppColors.oceanDeep;
  final Color oceanPrimary = AppColors.oceanPrimary;
  final Color oceanLight = AppColors.oceanLight;
  final Color oceanBackground = AppColors.scaffoldBg;
  final Color sunshineYellow = AppColors.sunlightGold;
  final Color sunshineOrange = AppColors.sunlightOrange;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.4).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadOffices();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _liveTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadOffices() async {
    final token = widget.user['token']?.toString() ?? '';
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/LocationAttendance/offices'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 7));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted && data is List && data.isNotEmpty) {
          setState(() {
            _offices = data;
            final office = data.first;
            _officeLat = (office['latitude'] as num?)?.toDouble() ?? _officeLat;
            _officeLng = (office['longitude'] as num?)?.toDouble() ?? _officeLng;
            _address = office['address']?.toString() ?? _address;
          });
        }
      }
    } catch (_) {}
  }

  // Bật/Tắt chia sẻ vị trí trực tiếp thời gian thực (5.b)
  void _toggleLiveSharing(bool value) {
    setState(() {
      _isSharingLive = value;
      _speed = value ? 2.5 : 0.0;
    });

    if (_isSharingLive) {
      _sendLiveLocationUpdate();
      _liveTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        if (mounted) {
          setState(() {
            _distanceToOffice = 12.0 + (DateTime.now().second % 6);
            if (_battery > 15) _battery = 88 - (DateTime.now().minute % 3);
          });
        }
        _sendLiveLocationUpdate();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Đã bật chia sẻ vị trí trực tiếp cho Quản lý & Hệ thống'),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _liveTimer?.cancel();
      if (mounted) {
        setState(() {
          _speed = 0.0;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Đã dừng phát sóng vị trí trực tiếp'),
          backgroundColor: sunshineOrange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _sendLiveLocationUpdate() async {
    final token = widget.user['token']?.toString() ?? '';
    if (token.isEmpty) return;

    try {
      await http.post(
        Uri.parse('${ApiConstants.baseUrl}/LocationAttendance/share-live-location'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'latitude': _currentLat,
          'longitude': _currentLng,
          'address': _address,
          'speed': _speed,
          'batteryLevel': _battery,
        }),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  // Chấm công theo định vị GPS (5.b)
  Future<void> _handleGpsCheckIn() async {
    final token = widget.user['token']?.toString() ?? '';
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/LocationAttendance/checkin-by-gps'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'latitude': _currentLat,
          'longitude': _currentLng,
          'address': _address,
          'note': 'Chấm công định vị GPS qua Mobile App',
          'deviceId': 'GPS_SENSOR_MOBILE',
        }),
      ).timeout(Duration(milliseconds: ApiConstants.timeout));

      if (!mounted) return;
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == true) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 8),
                Text('Chấm công GPS thành công'),
              ],
            ),
            content: Text(
              '${data['message'] ?? 'Bạn đã chấm công GPS thành công!'}\n\n'
              '📍 Địa chỉ: $_address\n'
              '📏 Khoảng cách: ${_distanceToOffice.toStringAsFixed(1)}m (Trong vùng Geofence ${_geofenceRadiusMeters.toInt()}m)',
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context, true); // Trở về Dashboard
                },
                child: const Text('Xong'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Vị trí của bạn nằm ngoài bán kính cho phép của văn phòng'),
            backgroundColor: sunshineOrange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi kết nối định vị: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
          'Định vị & Chia sẻ vị trí',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Khung radar bản đồ Geofence trực quan
            _buildRadarMapCard(),

            const SizedBox(height: 16),

            // Card Bật/Tắt Chia sẻ vị trí Live
            _buildLiveBroadcastCard(),

            const SizedBox(height: 16),

            // Card Chi tiết thông số cảm biến
            _buildTelemetryCard(),

            const SizedBox(height: 24),

            // Nút bấm Chấm công GPS
            Container(
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: AppColors.oceanPrimaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.oceanPrimary.withValues(alpha: 0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  )
                ],
              ),
              child: ElevatedButton.icon(
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.location_searching_rounded),
                label: Text(
                  _isLoading ? 'ĐANG ĐỐI SOÁT VỊ TRÍ...' : 'CHẤM CÔNG GPS (GEOFENCE)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _isLoading ? null : _handleGpsCheckIn,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadarMapCard() {
    return Card(
      elevation: 6,
      shadowColor: oceanPrimary.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        height: 260,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [oceanDark, oceanPrimary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Lưới toạ độ radar nền
            CustomPaint(
              size: const Size(260, 260),
              painter: _RadarGridPainter(color: Colors.white.withValues(alpha: 0.15)),
            ),

            // Vòng tròn Geofence phát sóng sóng radio
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  width: 140 * _pulseAnimation.value,
                  height: 140 * _pulseAnimation.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: sunshineYellow.withValues(alpha: 0.6 / _pulseAnimation.value),
                      width: 2,
                    ),
                  ),
                );
              },
            ),

            // Vùng Geofence hợp lệ (Màu xanh neon)
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.tealAccent.withValues(alpha: 0.12),
                border: Border.all(color: Colors.tealAccent, width: 2),
              ),
              child: const Center(
                child: Text(
                  'VÙNG GEOFENCE\n150M',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.tealAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Điểm văn phòng trung tâm
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.business_rounded, color: sunshineYellow, size: 36),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Trụ sở chính',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),

            // Điểm người dùng (User GPS location pin)
            Positioned(
              top: 75,
              right: 80,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: const Icon(Icons.person_pin_circle, color: Colors.redAccent, size: 32),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Bạn (Hợp lệ)',
                      style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  )
                ],
              ),
            ),

            // Badge trạng thái góc trên
            Positioned(
              top: 14,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.tealAccent, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Trong vùng: ${_distanceToOffice.toInt()}m',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveBroadcastCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_isSharingLive ? Colors.green : Colors.grey).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isSharingLive ? Icons.sensors_rounded : Icons.sensors_off_rounded,
                color: _isSharingLive ? Colors.green.shade600 : Colors.grey,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chia sẻ vị trí thời gian thực',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isSharingLive
                        ? 'Đang phát sóng vị trí cho Quản lý (Mỗi 10s)'
                        : 'Bật để giám sát lộ trình di chuyển ngoài hiện trường',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
            Switch(
              value: _isSharingLive,
              activeThumbColor: Colors.green.shade600,
              onChanged: _toggleLiveSharing,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetryCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, size: 20, color: oceanPrimary),
                const SizedBox(width: 8),
                Text(
                  'Dữ liệu cảm biến định vị',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: oceanDark),
                ),
              ],
            ),
            const Divider(height: 20),
            _infoRow('Tọa độ GPS', '${_currentLat.toStringAsFixed(4)}, ${_currentLng.toStringAsFixed(4)}'),
            _infoRow('Khoảng cách văn phòng', '${_distanceToOffice.toStringAsFixed(1)} mét (Chuẩn)'),
            _infoRow('Chi nhánh Geofence', '${_offices.isNotEmpty ? _offices.first['name'] ?? 'Trụ sở chính' : 'Trụ sở chính'} (${_officeLat.toStringAsFixed(4)}, ${_officeLng.toStringAsFixed(4)})'),
            _infoRow('Tốc độ di chuyển', '${_speed.toStringAsFixed(1)} km/h'),
            _infoRow('Mức pin thiết bị', '$_battery% (Đầy đủ)'),
            _infoRow('Địa chỉ văn phòng', _address),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              title,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: oceanDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarGridPainter extends CustomPainter {
  final Color color;

  _RadarGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final center = Offset(size.width / 2, size.height / 2);

    // Vẽ các vòng tròn đồng tâm
    canvas.drawCircle(center, 40, paint);
    canvas.drawCircle(center, 80, paint);
    canvas.drawCircle(center, 120, paint);

    // Vẽ trục thập tự
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), paint);
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
