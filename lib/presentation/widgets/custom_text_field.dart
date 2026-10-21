import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class CustomTextField extends StatefulWidget {
  final String label;
  final String hint;
  final IconData prefixIcon;
  final bool isPassword;
  final TextInputType keyboardType;
  final TextEditingController? controller;

  const CustomTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.controller,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  // Trạng thái để kiểm soát việc ẩn/hiện mật khẩu
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    // Mặc định, nếu là trường mật khẩu thì sẽ bị che (true)
    _obscureText = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: widget.controller,
        obscureText: _obscureText,
        keyboardType: widget.keyboardType,
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: TextStyle(color: Colors.grey.shade700, fontSize: 14),
          hintText: widget.hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(widget.prefixIcon, color: AppColors.royalBlue, size: 22),
          
          // Thêm icon con mắt vào cuối (suffixIcon) nếu đây là trường mật khẩu
          suffixIcon: widget.isPassword
              ? IconButton(
                  icon: Icon(
                    _obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: Colors.grey.shade600,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureText = !_obscureText;
                    });
                  },
                )
              : null,

          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.oceanPrimary, width: 2.0),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}

