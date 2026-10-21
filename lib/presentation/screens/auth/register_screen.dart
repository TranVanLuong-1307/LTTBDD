import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/app_sync_service.dart';
import '../../widgets/custom_text_field.dart';
import 'otp_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _selectedRole = 'NhanVien'; // 'NhanVien' hoặc 'KhachHang'
  bool _isLoading = false;

  // Đồng bộ hệ màu chuẩn của toàn bộ hệ thống
  final Color oceanDark = AppColors.oceanDeep; 
  final Color oceanPrimary = AppColors.oceanPrimary; 
  final Color oceanLight = AppColors.oceanLight; 
  final Color oceanBackground = AppColors.scaffoldBg; 
  final Color sunshineYellow = AppColors.sunlightGold;
  final Color sunshineOrange = AppColors.sunlightOrange;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleRegister() async {
    if (_fullNameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Vui lòng điền đầy đủ thông tin'),
          backgroundColor: sunshineOrange,
        ),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Mật khẩu xác nhận không khớp'),
          backgroundColor: sunshineOrange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final String email = _emailController.text.trim();
      final String generatedUsername = email.contains('@') ? email.split('@')[0] : email;

      http.Response response;
      final registerBody = jsonEncode({
        'username': generatedUsername,
        'name': _fullNameController.text.trim(),
        'fullName': _fullNameController.text.trim(),
        'email': email,
        'password': _passwordController.text,
        'role': _selectedRole,
      });

      try {
        response = await http.post(
          Uri.parse('${ApiConstants.baseUrl}/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: registerBody,
        ).timeout(Duration(milliseconds: ApiConstants.timeout));

        if (response.statusCode == 404) {
          response = await http.post(
            Uri.parse('${ApiConstants.baseUrl}/Authenticate/register'),
            headers: {'Content-Type': 'application/json'},
            body: registerBody,
          ).timeout(Duration(milliseconds: ApiConstants.timeout));
        }
      } catch (_) {
        response = await http.post(
          Uri.parse('${ApiConstants.baseUrl}/Authenticate/register'),
          headers: {'Content-Type': 'application/json'},
          body: registerBody,
        ).timeout(Duration(milliseconds: ApiConstants.timeout));
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        final data = jsonDecode(response.body);

        await AppSyncService.registerOrUpdateEmployee({
          'fullName': _fullNameController.text.trim(),
          'name': _fullNameController.text.trim(),
          'email': email,
          'departmentName': _selectedRole == 'KhachHang' ? 'Khách Hàng & Đối Tác' : 'Phòng Kỹ Thuật (IT)',
          'position': _selectedRole == 'KhachHang' ? 'Khách Hàng' : 'Nhân viên',
          'role': _selectedRole,
          'status': 'Present',
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Đăng ký thành công! Vui lòng kiểm tra hòm thư Gmail để lấy mã OTP.'),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpScreen(
              user: {
                'email': email,
                'username': generatedUsername,
                'fullName': _fullNameController.text.trim(),
                'name': _fullNameController.text.trim(),
                'role': _selectedRole,
                'department': _selectedRole == 'KhachHang' ? 'Khách Hàng' : 'Phòng Kỹ Thuật (IT)',
                'challengeId': data['challengeId'], // Lấy challengeId từ response
                'isRegister': true,
              },
            ),
          ),
        );
      } else {
        if (!mounted) return;
        // Parse the error message if it's JSON
        String errorMessage = response.body;
        bool isAlreadyExists = false;
        try {
            final errorData = jsonDecode(response.body);
            if (errorData is Map && errorData.containsKey('error')) {
                errorMessage = errorData['error'];
                if (errorMessage.toLowerCase().contains('tồn tại')) {
                  isAlreadyExists = true;
                }
            }
        } catch (e) {
            // Ignore JSON parse error, keep the original body
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $errorMessage'),
            backgroundColor: sunshineOrange,
            behavior: SnackBarBehavior.floating,
            action: isAlreadyExists
                ? SnackBarAction(
                    label: 'Đăng nhập ngay',
                    textColor: Colors.white,
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  )
                : null,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể kết nối máy chủ: $e'),
          backgroundColor: Colors.red,
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
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(), // Chạm ra ngoài để ẩn bàn phím
      child: Scaffold(
        extendBodyBehindAppBar: true, // Để Gradient tràn lên cả AppBar
        appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: oceanDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background Gradient nghệ thuật
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  oceanBackground,
                  Colors.white,
                  oceanBackground.withValues(alpha: 0.5),
                ],
              ),
            ),
          ),

          // Điểm nhấn nghệ thuật (Artistic shapes) - Mặt trời góc phải trên
          Positioned(
            top: -50,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    sunshineYellow.withValues(alpha: 0.3),
                    sunshineOrange.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // Điểm nhấn nghệ thuật - Sóng biển góc trái dưới
          Positioned(
            bottom: -80,
            left: -60,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    oceanLight.withValues(alpha: 0.4),
                    oceanPrimary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // Nội dung chính
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(), // Cuộn mượt mà hơn
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Tiêu đề
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tạo tài khoản',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: oceanDark,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Đăng ký để tham gia hệ thống',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: oceanPrimary.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Card Form Nhập Liệu
                  Card(
                    elevation: 12,
                    shadowColor: oceanPrimary.withValues(alpha: 0.15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        color: Colors.white.withValues(alpha: 0.9), // Glassmorphism nhẹ
                      ),
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Chọn vai trò người dùng (Nhân viên / Khách hàng)
                          Container(
                            padding: const EdgeInsets.all(4),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: oceanBackground,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _selectedRole = 'NhanVien'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: _selectedRole == 'NhanVien' ? oceanPrimary : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'Nhân viên',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: _selectedRole == 'NhanVien' ? Colors.white : oceanDark,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _selectedRole = 'KhachHang'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: _selectedRole == 'KhachHang' ? oceanPrimary : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'Khách hàng / Đối tác',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: _selectedRole == 'KhachHang' ? Colors.white : oceanDark,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          CustomTextField(
                            controller: _fullNameController,
                            label: 'Họ và tên',
                            hint: 'Nhập họ tên của bạn',
                            prefixIcon: Icons.person_outline,
                          ),
                          const SizedBox(height: 4),
                          CustomTextField(
                            controller: _emailController,
                            label: 'Email',
                            hint: 'Nhập địa chỉ email',
                            prefixIcon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 4),
                          CustomTextField(
                            controller: _passwordController,
                            label: 'Mật khẩu',
                            hint: 'Tạo mật khẩu',
                            prefixIcon: Icons.lock_outline,
                            isPassword: true,
                          ),
                          const SizedBox(height: 4),
                          CustomTextField(
                            controller: _confirmPasswordController,
                            label: 'Xác nhận mật khẩu',
                            hint: 'Nhập lại mật khẩu',
                            prefixIcon: Icons.lock_outline,
                            isPassword: true,
                          ),
                          const SizedBox(height: 24),

                          // Nút Đăng ký Gradient
                          _isLoading
                              ? Center(child: CircularProgressIndicator(color: sunshineYellow))
                              : _buildRegisterButton(context),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Quay lại đăng nhập
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Đã có tài khoản?',
                        style: TextStyle(
                          color: oceanDark.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: sunshineOrange,
                        ),
                        child: const Text(
                          'Đăng nhập',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20), // Khoảng trống cho màn hình dài
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildRegisterButton(BuildContext context) {
    return Container(
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
      child: ElevatedButton(
        onPressed: _handleRegister,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          'Đăng ký',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }
}
