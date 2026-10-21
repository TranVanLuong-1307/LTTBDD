import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isOutlined;
  final Color? color;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isOutlined = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.oceanDeep;
    final bool applyGradient = !isOutlined && color == null;

    return Container(
      width: double.infinity,
      height: 52,
      decoration: isOutlined
          ? null
          : BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: applyGradient ? AppColors.oceanPrimaryGradient : null,
              color: applyGradient ? null : effectiveColor,
              boxShadow: [
                BoxShadow(
                  color: AppColors.oceanPrimary.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
      child: isOutlined
          ? OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                side: BorderSide(color: effectiveColor, width: 1.5),
              ),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: effectiveColor,
                ),
              ),
            )
          : ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: applyGradient ? Colors.transparent : effectiveColor,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
    );
  }
}

