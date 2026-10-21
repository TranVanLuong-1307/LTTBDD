import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../auth/login_screen.dart';

/// Màn hình Cổng Thông Tin Dành Cho Khách Hàng / Đối Tác (Customer Dashboard)
/// Hoàn thiện phân quyền 3 cấp độ: Admin -> Quản trị; Nhân viên -> Chấm công; Khách hàng -> Cổng dịch vụ
class CustomerDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const CustomerDashboardScreen({super.key, required this.user});

  @override
  State<CustomerDashboardScreen> createState() => _CustomerDashboardScreenState();
}

class _CustomerDashboardScreenState extends State<CustomerDashboardScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _myRequests = [];
  String? _officeQrCode;

  @override
  void initState() {
    super.initState();
    _fetchCustomerData();
  }

  Future<void> _fetchCustomerData() async {
    setState(() => _isLoading = true);
    final token = widget.user['token']?.toString() ?? '';
    final headers = {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    // 1. Lấy danh sách yêu cầu / lịch hẹn của khách hàng từ /api/requests
    try {
      final res = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/requests'),
        headers: headers,
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data is List ? data : (data is Map && data['items'] is List ? data['items'] as List : null);
        if (list != null) {
          _myRequests = list.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    } catch (_) {}

    // 2. Lấy mã QR thẻ khách vào văn phòng từ /api/office/qr
    try {
      final qrRes = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/office/qr'),
        headers: headers,
      ).timeout(const Duration(seconds: 6));

      if (qrRes.statusCode == 200) {
        final data = jsonDecode(qrRes.body);
        _officeQrCode = data is Map ? (data['qr'] ?? data['code'] ?? data['token']?.toString()) : null;
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteCustomerRequest(String id) async {
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
          _myRequests.removeWhere((r) => r['id']?.toString() == id);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã hủy lịch hẹn / yêu cầu thành công!'), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (_) {}
  }

  void _showCreateAppointmentDialog() {
    final reasonCtrl = TextEditingController();
    String appointmentType = 'Gặp gỡ trao đổi công tác';
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Icon(Icons.calendar_month_rounded, color: AppColors.oceanPrimary, size: 26),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Đặt Lịch Hẹn / Gửi Yêu Cầu',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.oceanDeep),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Loại dịch vụ / Lý do hẹn:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: appointmentType,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Gặp gỡ trao đổi công tác', child: Text('Trao đổi công tác đối tác')),
                    DropdownMenuItem(value: 'Tham quan văn phòng & Demo', child: Text('Tham quan & Trải nghiệm giải pháp')),
                    DropdownMenuItem(value: 'Hỗ trợ kỹ thuật & Ký hợp đồng', child: Text('Hỗ trợ kỹ thuật / Ký kết')),
                    DropdownMenuItem(value: 'Liên hệ khách vãng lai', child: Text('Khách vãng lai liên hệ')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => appointmentType = val);
                  },
                ),
                const SizedBox(height: 14),
                const Text('Ngày hẹn làm việc:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.oceanDeep),
                        ),
                        Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.oceanPrimary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Nội dung chi tiết / Ghi chú:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Nhập nội dung bạn muốn làm việc cùng công ty...',
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Hủy', style: TextStyle(color: Colors.grey.shade600)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.oceanPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                if (reasonCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vui lòng nhập nội dung yêu cầu'), backgroundColor: Colors.orange),
                  );
                  return;
                }
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                final token = widget.user['token']?.toString() ?? '';
                final fromDateStr = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';

                try {
                  final res = await http.post(
                    Uri.parse('${ApiConstants.baseUrl}/requests'),
                    headers: {
                      'Content-Type': 'application/json',
                      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
                    },
                    body: jsonEncode({
                      'type': appointmentType,
                      'reason': reasonCtrl.text.trim(),
                      'from': fromDateStr,
                      'to': fromDateStr,
                    }),
                  ).timeout(const Duration(seconds: 8));

                  if (res.statusCode == 200 || res.statusCode == 201) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Đã gửi yêu cầu hẹn làm việc thành công lên hệ thống!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _fetchCustomerData();
                  } else {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Không thể gửi yêu cầu (${res.statusCode})'), backgroundColor: Colors.red),
                    );
                  }
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Lỗi gửi yêu cầu: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Gửi Yêu Cầu'),
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
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi Cổng Khách Hàng?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
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
    final displayName = widget.user['fullName'] ?? widget.user['name'] ?? widget.user['username'] ?? 'Quý Khách';
    final email = widget.user['email']?.toString() ?? '';

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.oceanHeaderGradient,
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.sunlightGradient,
              ),
              child: const Icon(Icons.business_center_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CỔNG KHÁCH HÀNG & ĐỐI TÁC',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5),
                ),
                Text(
                  'Kính chào, $displayName',
                  style: const TextStyle(fontSize: 12, color: AppColors.sunlightGold, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Làm mới',
            onPressed: _fetchCustomerData,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            tooltip: 'Đăng xuất',
            onPressed: _showLogoutDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.oceanPrimary))
          : RefreshIndicator(
              onRefresh: _fetchCustomerData,
              color: AppColors.oceanPrimary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Card 1: Thẻ Khách Hàng / Đối Tác
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: AppColors.oceanPrimaryGradient,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.oceanDark.withValues(alpha: 0.25),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.verified_user_rounded, color: AppColors.sunlightGold, size: 14),
                                    SizedBox(width: 6),
                                    Text(
                                      'VAI TRÒ: KHÁCH HÀNG / ĐỐI TÁC',
                                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.contactless_rounded, color: Colors.white, size: 28),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            displayName,
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                          ),
                          if (email.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(email, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                          ],
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                                  label: const Text('MÃ QR KHÁCH VÀO CỔNG'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.sunlightGold,
                                    foregroundColor: AppColors.oceanDark,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                        title: const Text('Mã QR Thẻ Khách Vãng Lai', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade100,
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: const Icon(Icons.qr_code_2_rounded, size: 160, color: AppColors.oceanDeep),
                                            ),
                                            const SizedBox(height: 14),
                                            Text(
                                              'Mã xác thực: ${_officeQrCode ?? 'OFFICE-GUEST-PASS'}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.oceanPrimary),
                                            ),
                                            const SizedBox(height: 6),
                                            const Text(
                                              'Vui lòng quét mã tại cổng an ninh hoặc sảnh lễ tân văn phòng để được cấp quyền vào làm việc.',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(fontSize: 12, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Tiêu đề: Tác vụ & Đặt lịch
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Dịch Vụ & Lịch Hẹn Của Bạn',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.oceanDeep),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Tạo Yêu Cầu'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.oceanPrimary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onPressed: _showCreateAppointmentDialog,
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Danh sách đơn / yêu cầu từ database
                    if (_myRequests.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.assignment_outlined, size: 54, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'Chưa có yêu cầu hoặc lịch hẹn nào',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.oceanDeep),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Nhấn "+ Tạo Yêu Cầu" để gửi lịch hẹn hoặc yêu cầu hỗ trợ trực tiếp đến bộ phận quản trị.',
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
                        itemCount: _myRequests.length,
                        itemBuilder: (context, idx) {
                          final item = _myRequests[idx];
                          final status = item['status']?.toString() ?? 'Pending';
                          final type = item['type'] ?? 'Yêu cầu hỗ trợ';
                          final reason = item['reason'] ?? '';
                          final from = item['from'] ?? item['startDate'] ?? '';

                          Color statusColor = Colors.orange;
                          String statusText = 'Chờ xử lý';
                          if (status == 'Approved') {
                            statusColor = Colors.green;
                            statusText = 'Đã chấp thuận';
                          } else if (status == 'Rejected') {
                            statusColor = Colors.red;
                            statusText = 'Đã từ chối';
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.event_note_rounded, color: AppColors.oceanPrimary, size: 20),
                                          const SizedBox(width: 8),
                                          Text(type, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                        ],
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                                            ),
                                            child: Text(
                                              statusText,
                                              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                          ),
                                          if (status == 'Pending' && item['id'] != null) ...[
                                            const SizedBox(width: 4),
                                            IconButton(
                                              icon: const Icon(Icons.cancel_outlined, size: 20, color: Colors.redAccent),
                                              tooltip: 'Hủy lịch hẹn',
                                              onPressed: () => _deleteCustomerRequest(item['id'].toString()),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (reason.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(reason, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                                  ],
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today_outlined, size: 13, color: Colors.grey.shade500),
                                      const SizedBox(width: 4),
                                      Text('Ngày hẹn: $from', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                    const SizedBox(height: 24),

                    // Thông tin liên hệ công ty & Hỗ trợ
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.location_city_rounded, color: AppColors.oceanPrimary, size: 22),
                              const SizedBox(width: 8),
                              const Text('Thông Tin Liên Hệ Doanh Nghiệp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            ],
                          ),
                          const Divider(height: 20),
                          _buildContactRow(Icons.place_outlined, 'Trụ sở: Tòa nhà TechCenter, Quận 1, TP. Hồ Chí Minh'),
                          const SizedBox(height: 8),
                          _buildContactRow(Icons.phone_in_talk_outlined, 'Hotline lễ tân: 1900 6868 (8:00 - 17:30)'),
                          const SizedBox(height: 8),
                          _buildContactRow(Icons.email_outlined, 'Hỗ trợ khách hàng: support@company.com'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildContactRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.oceanPrimary),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: Colors.grey.shade700))),
      ],
    );
  }
}
