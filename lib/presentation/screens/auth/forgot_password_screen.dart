import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../widgets/custom_text_field.dart';
import 'otp_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String? initialEmail;

  const ForgotPasswordScreen({super.key, this.initialEmail});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _emailController;
  bool _isLoading = false;

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
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _handleSendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Vui lòng nhập địa chỉ email của bạn'),
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
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/Authenticate/test-send-otp?toEmail=$email'),
      ).timeout(Duration(milliseconds: ApiConstants.timeout));

      if (!mounted) return;

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Mã xác thực OTP đã được gửi đến email!'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpScreen(
              user: {
                'email': email,
                'username': email,
                'isResetPassword': true,
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Không thể gửi mã xác nhận. Vui lòng kiểm tra lại email.'),
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        extendBodyBehindAppBar: true,
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
            // Background Gradient
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

            // Điểm nhấn nghệ thuật
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
                      sunshineYellow.withValues(alpha: 0.35),
                      sunshineOrange.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
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
                      oceanLight.withValues(alpha: 0.35),
                      oceanPrimary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),

            // Nội dung chính
            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),

                    // Icon Reset Password
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: sunshineYellow, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: sunshineOrange.withValues(alpha: 0.25),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            )
                          ],
                        ),
                        child: Icon(
                          Icons.lock_reset_rounded,
                          size: 60,
                          color: oceanPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Tiêu đề
                    Text(
                      'Quên mật khẩu?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: oceanDark,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Đừng lo lắng! Hãy nhập email liên kết với tài khoản của bạn để nhận mã xác thực OTP khôi phục mật khẩu.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: oceanPrimary.withValues(alpha: 0.8),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Form Card
                    Card(
                      elevation: 12,
                      shadowColor: oceanPrimary.withValues(alpha: 0.15),
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
                            CustomTextField(
                              controller: _emailController,
                              label: 'Email',
                              hint: 'Nhập email tài khoản của bạn',
                              prefixIcon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 28),

                            // Nút gửi mã OTP
                            _isLoading
                                ? Center(child: CircularProgressIndicator(color: sunshineYellow))
                                : _buildSendButton(context),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Quay lại đăng nhập
                    Center(
                      child: TextButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, size: 18, color: AppColors.orangeAccent),
                        label: const Text(
                          'Quay lại Đăng nhập',
                          style: TextStyle(
                            color: AppColors.orangeAccent,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
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

  Widget _buildSendButton(BuildContext context) {
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
        onPressed: _handleSendOtp,
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
          'Gửi mã xác nhận',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

