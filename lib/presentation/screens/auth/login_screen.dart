import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../widgets/custom_text_field.dart';
import 'register_screen.dart';
import 'otp_screen.dart';
import 'forgot_password_screen.dart';
import '../attendance/face_recognition_screen.dart';
import '../employee/employee_dashboard_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../customer/customer_dashboard_screen.dart';
import '../../widgets/fingerprint_scanner_widget.dart';
import '../../../core/services/biometric_registry_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _floatingAnimation;

  // Đồng bộ hệ màu chuẩn của toàn bộ hệ thống
  final Color oceanDark = AppColors.oceanDeep;
  final Color oceanPrimary = AppColors.oceanPrimary;
  final Color oceanLight = AppColors.oceanLight;
  final Color oceanBackground = AppColors.scaffoldBg;
  final Color sunshineYellow = AppColors.sunlightGold;
  final Color sunshineOrange = AppColors.sunlightOrange;

  @override
  void initState() {
    super.initState();
    // Tạo hiệu ứng lơ lửng và tỏa sáng cho Logo
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _floatingAnimation = Tween<double>(begin: 0, end: 15).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  void _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Vui lòng nhập đầy đủ email và mật khẩu'),
          backgroundColor: sunshineOrange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final inputUser = _emailController.text.trim();
      final username = inputUser.contains('@') ? inputUser.split('@')[0] : inputUser;

      http.Response response;
      try {
        response = await http.post(
          Uri.parse('${ApiConstants.baseUrl}/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'username': username,
            'password': _passwordController.text,
          }),
        ).timeout(Duration(milliseconds: ApiConstants.timeout));

        // Nếu 400 hoặc 401 và người dùng nhập email, thử thêm lần nữa với full email
        if ((response.statusCode == 400 || response.statusCode == 401) && inputUser != username) {
          try {
            final retryResponse = await http.post(
              Uri.parse('${ApiConstants.baseUrl}/auth/login'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'username': inputUser,
                'password': _passwordController.text,
              }),
            ).timeout(const Duration(seconds: 8));

            if (retryResponse.statusCode == 200) {
              response = retryResponse;
            }
          } catch (_) {}
        }

        if (response.statusCode == 404) {
          response = await http.post(
            Uri.parse('${ApiConstants.baseUrl}/Authenticate/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': username,
              'password': _passwordController.text,
            }),
          ).timeout(Duration(milliseconds: ApiConstants.timeout));
        }
      } catch (e) {
        // Dự phòng endpoint Authenticate nếu auth/login gặp sự cố
        try {
          response = await http.post(
            Uri.parse('${ApiConstants.baseUrl}/Authenticate/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': username,
              'password': _passwordController.text,
            }),
          ).timeout(Duration(milliseconds: ApiConstants.timeout));
        } catch (_) {
          rethrow;
        }
      }

      if (!mounted) return;

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && (data is Map && (data['status'] == true || data.containsKey('challengeId') || data.containsKey('token')))) {
        final tempSession = data['tempSession'] ?? username;
        final userData = data['user'] ?? data['data'] ?? data;
        
        final rawFullName = userData['fullName'] ?? userData['name'];
        String cleanFullName;
        if (rawFullName != null && !rawFullName.toString().contains('@')) {
          cleanFullName = rawFullName.toString().trim();
        } else if (_emailController.text.contains('@')) {
          final prefix = _emailController.text.split('@')[0];
          cleanFullName = prefix.isNotEmpty ? (prefix[0].toUpperCase() + prefix.substring(1)) : 'Người dùng';
        } else {
          cleanFullName = 'Người dùng';
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpScreen(
              user: {
                'username': tempSession,
                'email': _emailController.text.trim(),
                'fullName': cleanFullName,
                'name': cleanFullName,
                'department': userData['departmentName'] ?? userData['department'] ?? 'Phòng Phát Triển',
                'role': userData['role'] ?? userData['Role'] ?? data['role'] ?? data['Role'],
                'roles': userData['roles'] ?? userData['Roles'] ?? data['roles'] ?? data['Roles'],
                'primaryRole': userData['primaryRole'] ?? userData['PrimaryRole'] ?? data['primaryRole'],
                'targetDashboard': userData['targetDashboard'] ?? userData['TargetDashboard'] ?? data['targetDashboard'],
                'avatar': userData['avatarUrl'] ?? userData['avatar'] ?? '',
                'challengeId': data['challengeId'],
                'isLogin': true,
                if (data['token'] != null) 'token': data['token'],
              },
            ),
          ),
        );
      } else {
        String errorMsg = 'Đăng nhập không thành công';
        if (data is Map) {
          if (data.containsKey('error')) {
            errorMsg = data['error'];
          } else if (data.containsKey('message')) {
            errorMsg = data['message'];
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: sunshineOrange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi kết nối máy chủ: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
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
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(), // Chạm ra ngoài để ẩn bàn phím
      child: Scaffold(
        body: Stack(
          children: [
          // Background Gradient đẹp mắt
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

          // Điểm nhấn nghệ thuật (Artistic shapes) - Mặt trời góc phải
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    sunshineYellow.withValues(alpha: 0.4),
                    sunshineOrange.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // Điểm nhấn nghệ thuật - Sóng biển góc trái dưới
          Positioned(
            bottom: -100,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
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
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(), // Cuộn mượt mà hơn
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo hệ thống với hiệu ứng Animation
                      AnimatedBuilder(
                        animation: _floatingAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, -_floatingAnimation.value),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: sunshineYellow, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: sunshineOrange.withValues(alpha: 0.2 + (_floatingAnimation.value / 100)), // Tỏa sáng theo nhịp
                                    blurRadius: 15 + _floatingAnimation.value,
                                    spreadRadius: _floatingAnimation.value / 3,
                                    offset: const Offset(0, 8),
                                  )
                                ],
                              ),
                              child: child,
                            ),
                          );
                        },
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.work_outline,
                            size: 50,
                            color: oceanPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      
                      // Text chào mừng
                      Text(
                        'Đăng nhập',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: oceanDark,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Hệ thống quản lý chấm công nhân viên',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: oceanPrimary.withValues(alpha: 0.8),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),

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
                              CustomTextField(
                                controller: _emailController,
                                label: 'Email',
                                hint: 'Nhập email của bạn',
                                prefixIcon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 4),
                              CustomTextField(
                                controller: _passwordController,
                                label: 'Mật khẩu',
                                hint: 'Nhập mật khẩu',
                                prefixIcon: Icons.lock_outline,
                                isPassword: true,
                              ),

                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ForgotPasswordScreen(
                                          initialEmail: _emailController.text.trim(),
                                        ),
                                      ),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: sunshineOrange,
                                  ),
                                  child: const Text(
                                    'Quên mật khẩu?',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Nút Đăng nhập
                              _isLoading
                                  ? Center(child: CircularProgressIndicator(color: sunshineYellow))
                                  : _buildLoginButton(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Đăng nhập bằng sinh trắc học
                      Text(
                        'Hoặc đăng nhập bằng sinh trắc học',
                        style: TextStyle(
                          color: oceanDark.withValues(alpha: 0.7),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 5.a Đăng nhập bằng khuôn mặt
                          _buildBiometricLoginOption(
                            icon: Icons.face_retouching_natural,
                            label: 'Face ID',
                            color: oceanPrimary,
                            onTap: _handleFaceIdLogin,
                          ),
                          const SizedBox(width: 32),
                          // 5.e Đăng nhập bằng vân tay
                          _buildBiometricLoginOption(
                            icon: Icons.fingerprint,
                            label: 'Vân tay',
                            color: sunshineOrange,
                            onTap: _handleFingerprintLogin,
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),

                      // Chuyển sang đăng ký
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Chưa có tài khoản?',
                            style: TextStyle(
                              color: oceanDark.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const RegisterScreen()),
                              );
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: sunshineOrange,
                            ),
                            child: const Text(
                              'Đăng ký ngay', 
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [oceanPrimary, oceanDark],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: oceanPrimary.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: ElevatedButton(
        onPressed: _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent, // Để lộ gradient background
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          'Đăng nhập',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricLoginOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(40),
          splashColor: color.withValues(alpha: 0.3),
          highlightColor: color.withValues(alpha: 0.1),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: 0.4),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Icon(
              icon,
              size: 32,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: oceanDark,
          ),
        ),
      ],
    );
  }

  Future<void> _handleFaceIdLogin() async {
    final email = _emailController.text.trim();
    final isRegistered = await BiometricRegistryService.isFaceRegistered(email);
    if (!mounted) return;

    if (!isRegistered) {
      _showBiometricNotRegisteredDialog(title: 'Face ID');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FaceRecognitionScreen(
          isLoginMode: true,
          user: {'email': email},
        ),
      ),
    );
  }

  Future<void> _handleFingerprintLogin() async {
    final email = _emailController.text.trim();
    final isRegistered = await BiometricRegistryService.isFingerprintRegistered(email);
    if (!mounted) return;

    if (!isRegistered) {
      _showBiometricNotRegisteredDialog(title: 'Vân tay');
      return;
    }

    final activeEmail = email.isNotEmpty ? email : (await BiometricRegistryService.getLatestRegisteredUser() ?? '');
    if (!mounted) return;
    _showFingerprintLoginDialog(email: activeEmail);
  }

  void _showBiometricNotRegisteredDialog({required String title}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Icon(Icons.shield_outlined, color: sunshineOrange, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Yêu cầu đăng ký $title',
                style: TextStyle(
                  color: oceanDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: sunshineOrange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: sunshineOrange, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tài khoản chưa đăng ký $title!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: oceanDark,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Để đảm bảo bảo mật cao, bạn cần đăng nhập bằng OTP một lần để kích hoạt sinh trắc học:\n\n'
              '1️⃣ Nhập Email & Mật khẩu rồi bấm "ĐĂNG NHẬP"\n'
              '2️⃣ Nhập mã OTP 6 số gửi đến hòm thư Gmail\n'
              '3️⃣ Sau khi nhập OTP xong, màn hình sẽ hiện ngay nút [👉 ĐĂNG KÝ VÂN TAY] để bạn quét ngón tay lưu vào thiết bị!',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.45),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Đã hiểu', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: oceanPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: const Text('Đăng nhập bằng OTP'),
          ),
        ],
      ),
    );
  }

  void _showFingerprintLoginDialog({required String email}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
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
                    Icon(Icons.fingerprint, color: sunshineOrange, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Đăng nhập Vân tay',
                      style: TextStyle(
                        color: oceanDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FingerprintScannerWidget(
              title: 'CẢM BIẾN VÂN TAY THIẾT BỊ',
              subtitle: 'Chỉ quét khi bạn đặt và giữ ngón tay trên cảm biến',
              primaryColor: sunshineOrange,
              onScanSuccess: () async {
                Navigator.pop(ctx);
                final isAdmin = email.toLowerCase().contains('admin');
                final isCustomer = email.toLowerCase().contains('khach') || email.toLowerCase().contains('customer') || email.toLowerCase().contains('guest');
                final roleStr = isAdmin ? 'Admin' : (isCustomer ? 'KhachHang' : 'NhanVien');
                final userPayload = {
                  'username': email.isNotEmpty ? email : 'user01',
                  'email': email,
                  'name': isAdmin ? 'Trần Văn Lương (Admin)' : (isCustomer ? 'Quý Khách Hàng' : 'Trần Văn Lương'),
                  'department': isAdmin ? 'Ban Quản Trị' : (isCustomer ? 'Khách Hàng' : 'Nhân viên'),
                  'role': roleStr,
                  'token': 'BIOMETRIC_FINGERPRINT_VERIFIED_TOKEN',
                };

                Widget dest;
                if (isAdmin) {
                  dest = AdminDashboardScreen(user: userPayload);
                } else if (isCustomer) {
                  dest = CustomerDashboardScreen(user: userPayload);
                } else {
                  dest = EmployeeDashboardScreen(user: userPayload);
                }

                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => dest),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
