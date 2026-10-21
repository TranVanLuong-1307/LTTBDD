import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/biometric_registry_service.dart';
import '../../../core/services/app_sync_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/fingerprint_scanner_widget.dart';
import '../employee/employee_dashboard_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../customer/customer_dashboard_screen.dart';
import '../attendance/face_recognition_screen.dart';

class OtpScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  
  const OtpScreen({super.key, required this.user});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  bool _isLoading = false;
  // Controllers cho 6 ô nhập OTP
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _verifyOtp() async {
    String otpCode = _otpControllers.map((c) => c.text).join();
    
    if (otpCode.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đủ 6 số OTP')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final bool isLogin = widget.user['isLogin'] == true;
      final String renderEndpoint = isLogin ? '/auth/verify-otp' : '/auth/verify-email';
      final String localEndpoint = '/Authenticate/verify-otp';

      final requestBody = jsonEncode({
        'challengeId': widget.user['challengeId'] ?? '', 
        'code': otpCode,
        'username': widget.user['username'] ?? widget.user['email'] ?? '',
        'otpCode': otpCode,
      });

      http.Response response;
      try {
        response = await http.post(
          Uri.parse('${ApiConstants.baseUrl}$renderEndpoint'),
          headers: {'Content-Type': 'application/json'},
          body: requestBody,
        ).timeout(Duration(milliseconds: ApiConstants.timeout));

        if (response.statusCode == 404) {
          response = await http.post(
            Uri.parse('${ApiConstants.baseUrl}$localEndpoint'),
            headers: {'Content-Type': 'application/json'},
            body: requestBody,
          ).timeout(Duration(milliseconds: ApiConstants.timeout));
        }
      } catch (_) {
        response = await http.post(
          Uri.parse('${ApiConstants.baseUrl}$localEndpoint'),
          headers: {'Content-Type': 'application/json'},
          body: requestBody,
        ).timeout(Duration(milliseconds: ApiConstants.timeout));
      }

      if (!mounted) return;

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Parse the body to check for nested status or use directly if no nested status
        bool isSuccess = true; // Assume success if 200/201
        if (data is Map && data.containsKey('status')) {
             isSuccess = data['status'] == true;
        }

        if(isSuccess) {
            if (widget.user['isResetPassword'] == true) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 28),
                  SizedBox(width: 8),
                  Text('Xác thực thành công'),
                ],
              ),
              content: const Text(
                'Mã OTP của bạn đã được xác nhận thành công! Bạn có thể sử dụng thông tin mới để đăng nhập.',
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text('Đăng nhập ngay'),
                ),
              ],
            ),
          );
          return;
        }

        // Trường hợp xác thực sau khi Đăng ký mới thành công
        if (widget.user['isRegister'] == true || (!isLogin && (data is! Map || data['token'] == null))) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 28),
                  SizedBox(width: 8),
                  Text('Đăng ký hoàn tất'),
                ],
              ),
              content: const Text(
                'Email của bạn đã được xác thực thành công! Vui lòng đăng nhập để bắt đầu trải nghiệm ứng dụng.',
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text('Đăng nhập ngay'),
                ),
              ],
            ),
          );
          return;
        }

        final userData = data['user'] ?? data['data'] ?? data;

        final rawFullName = userData['fullName'] ?? userData['name'] ?? widget.user['fullName'] ?? widget.user['name'];
        final resolvedUsername = userData['username'] ?? widget.user['username'] ?? widget.user['email'] ?? '';
        final resolvedEmail = userData['email'] ?? widget.user['email'] ?? '';
        
        String cleanFullName;
        if (rawFullName != null && !rawFullName.toString().contains('@')) {
          cleanFullName = rawFullName.toString().trim();
        } else if (resolvedEmail.contains('@')) {
          final prefix = resolvedEmail.split('@')[0];
          cleanFullName = prefix.isNotEmpty ? (prefix[0].toUpperCase() + prefix.substring(1)) : 'Người dùng';
        } else {
          cleanFullName = 'Người dùng';
        }

        final resolvedDept = userData['departmentName'] ?? userData['department'] ?? widget.user['department'] ?? 'Phòng Phát Triển';
        final resolvedAvatar = userData['avatarUrl'] ?? userData['avatar'] ?? widget.user['avatar'] ?? '';
        final token = data['token'] ?? widget.user['token'] ?? '';

        dynamic extractedRole = userData['role'] ?? userData['Role'] ?? data['role'] ?? data['Role'] ?? widget.user['role'];
        dynamic extractedRoles = userData['roles'] ?? userData['Roles'] ?? data['roles'] ?? data['Roles'] ?? widget.user['roles'];

        if (token.toString().isNotEmpty) {
          try {
            final parts = token.toString().split('.');
            if (parts.length == 3) {
              final payload = parts[1];
              final normalized = base64Url.normalize(payload);
              final decodedStr = utf8.decode(base64Url.decode(normalized));
              final jwtData = jsonDecode(decodedStr);
              if (jwtData is Map<String, dynamic>) {
                final jwtRole = jwtData['http://schemas.microsoft.com/ws/2008/06/identity/claims/role'] ??
                    jwtData['role'] ??
                    jwtData['roles'];
                if (jwtRole != null) {
                  extractedRole ??= (jwtRole is List && jwtRole.isNotEmpty) ? jwtRole.first : jwtRole;
                  extractedRoles ??= jwtRole is List ? jwtRole : [jwtRole];
                }
              }
            }
          } catch (_) {}
        }

        final resolvedUser = {
          ...widget.user,
          'username': resolvedUsername,
          'email': resolvedEmail,
          'fullName': cleanFullName,
          'name': cleanFullName,
          'department': resolvedDept,
          'avatar': resolvedAvatar,
          'role': extractedRole,
          'roles': extractedRoles,
          'token': token,
        };

        await AppSyncService.registerOrUpdateEmployee(resolvedUser);

        if (!mounted) return;
        _showBiometricRegistrationPrompt(resolvedUser);
        } else {
            String errorMsg = 'Mã OTP không đúng hoặc đã hết hạn';
            if (data is Map) {
                if (data.containsKey('error')) {
                  errorMsg = data['error'];
                } else if (data.containsKey('message')) {
                  errorMsg = data['message'];
                }
            }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMsg)),
          );
        }
      } else {
        // Handle 400 or other errors
        String errorMsg = 'Mã OTP không đúng hoặc đã hết hạn';
        if (data is Map) {
            if (data.containsKey('error')) {
              errorMsg = data['error'];
            } else if (data.containsKey('message')) {
              errorMsg = data['message'];
            }
        }
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMsg)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể kết nối máy chủ: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _resendOtp() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Server hiện tại không hỗ trợ gửi lại mã. Vui lòng quay lại màn hình trước và ấn Đăng ký lại để nhận mã mới!'),
        backgroundColor: AppColors.orangeAccent,
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.primaryDarkNav),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Stack(
          children: [
            // Background Gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.scaffoldBg,
                    Colors.white,
                    AppColors.scaffoldBg.withValues(alpha: 0.5),
                  ],
                ),
              ),
            ),

            // Điểm nhấn nghệ thuật - Mặt trời vàng góc phải
            Positioned(
              top: -60,
              right: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.amberGlow.withValues(alpha: 0.35),
                      AppColors.orangeAccent.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),

            // Điểm nhấn nghệ thuật - Sóng xanh góc trái dưới
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
                      AppColors.royalBlue.withValues(alpha: 0.25),
                      AppColors.primaryDarkNav.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icon xác thực với hào quang vàng ấm
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: AppColors.yellowLight, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.orangeAccent.withValues(alpha: 0.25),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            )
                          ],
                        ),
                        child: const Icon(
                          Icons.mark_email_read_outlined,
                          size: 54,
                          color: AppColors.primaryDarkNav,
                        ),
                      ),
                      const SizedBox(height: 24),

                      const Text(
                        'Xác thực OTP',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryDarkNav,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.user['email'] != null && widget.user['email'].toString().isNotEmpty
                            ? 'Mã OTP đã được gửi tới:\n${widget.user['email']}'
                            : 'Vui lòng nhập mã OTP 6 số đã nhận.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSub.withValues(alpha: 0.85),
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Card Form OTP
                      Card(
                        elevation: 12,
                        shadowColor: AppColors.primaryDarkNav.withValues(alpha: 0.12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 6 ô nhập OTP
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: List.generate(6, (index) => _buildOtpBox(context, index)),
                              ),
                              const SizedBox(height: 28),

                              _isLoading
                                  ? const Center(child: CircularProgressIndicator(color: AppColors.orangeAccent))
                                  : CustomButton(
                                      text: 'Xác thực',
                                      color: AppColors.darkNavy,
                                      onPressed: _verifyOtp,
                                    ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Gửi lại mã OTP
                      TextButton(
                        onPressed: _resendOtp,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.orangeAccent,
                        ),
                        child: const Text(
                          'Chưa nhận được mã? Gửi lại ngay',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
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
    );
  }

  Widget _buildOtpBox(BuildContext context, int index) {
    return SizedBox(
      width: 46,
      height: 56,
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: AppColors.primaryDarkNav,
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 5) {
            FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
          } else if (value.isEmpty && index > 0) {
            FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
          }
        },
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.royalBlue, width: 2),
          ),
        ),
      ),
    );
  }

  void _showBiometricRegistrationPrompt(Map<String, dynamic> resolvedUser) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.verified_user_rounded, color: Colors.green.shade600, size: 26),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Xác thực OTP thành công!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: AppColors.primaryDarkNav,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Tài khoản đủ điều kiện bảo mật. Hãy chọn phương thức đăng ký sinh trắc học để đăng nhập 1-chạm không cần mật khẩu:',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
            ),
            const SizedBox(height: 16),

            // LỰA CHỌN 1: ĐĂNG KÝ VÂN TAY (Nổi bật màu Cam Ánh Dương Sunshine)
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.pop(ctx);
                _showFingerprintRegistrationDialog(resolvedUser);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.yellowLight, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.orangeAccent.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.fingerprint, color: AppColors.orangeAccent, size: 32),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ĐĂNG KÝ VÂN TAY',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.primaryDarkNav,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Chạm quét vân tay cảm biến thiết bị',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.orangeAccent),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // LỰA CHỌN 2: ĐĂNG KÝ FACE ID (Màu Xanh Hoàng Gia Royal Blue)
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FaceRecognitionScreen(
                      isRegisterMode: true,
                      user: resolvedUser,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.lightBlueBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.lightBluePill, width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.face_retouching_natural_rounded, color: AppColors.royalBlue, size: 32),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ĐĂNG KÝ FACE ID',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.primaryDarkNav,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Quét khuôn mặt bằng camera AI',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.royalBlue),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => _getDestinationDashboard(resolvedUser),
                ),
                (route) => false,
              );
            },
            child: Text('Để sau (Vào trang chủ)', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _getDestinationDashboard(Map<String, dynamic> user) {
    final role = (user['role'] ?? user['department'] ?? '').toString().toLowerCase();
    final username = (user['username'] ?? '').toString().toLowerCase();
    final email = (user['email'] ?? '').toString().toLowerCase();
    if (role.contains('admin') || username.contains('admin') || email.contains('admin')) {
      return AdminDashboardScreen(user: user);
    } else if (role.contains('khach') || role.contains('customer') || role.contains('guest') || username.contains('khach') || email.contains('khach')) {
      return CustomerDashboardScreen(user: user);
    }
    return EmployeeDashboardScreen(user: user);
  }

  void _showFingerprintRegistrationDialog(Map<String, dynamic> resolvedUser) {
    showDialog(
      context: context,
      barrierDismissible: false,
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
                    onPressed: () {
                      Navigator.pop(dialogCtx);
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => _getDestinationDashboard(resolvedUser),
                        ),
                        (route) => false,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FingerprintScannerWidget(
                title: 'ĐĂNG KÝ MẪU VÂN TAY',
                subtitle: 'Chỉ quét khi bạn đặt và giữ ngón tay trên khu vực cảm biến',
                primaryColor: AppColors.orangeAccent,
                onScanSuccess: () async {
                  final emailOrUser = resolvedUser['email'] ?? resolvedUser['username'] ?? '';
                  await BiometricRegistryService.registerFingerprint(emailOrUser);
                  if (dialogCtx.mounted && mounted) {
                    Navigator.of(dialogCtx).pop();
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => _getDestinationDashboard(resolvedUser),
                      ),
                      (route) => false,
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

