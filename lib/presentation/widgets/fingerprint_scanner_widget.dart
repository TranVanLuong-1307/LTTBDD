import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';

class FingerprintScannerWidget extends StatefulWidget {
  final Future<void> Function() onScanSuccess;
  final String title;
  final String? subtitle;
  final double size;
  final Color primaryColor;
  final Duration scanDuration;

  const FingerprintScannerWidget({
    super.key,
    required this.onScanSuccess,
    this.title = 'KHU VỰC CẢM BIẾN VÂN TAY',
    this.subtitle,
    this.size = 150.0,
    this.primaryColor = AppColors.orangeAccent,
    this.scanDuration = const Duration(milliseconds: 1400),
  });

  @override
  State<FingerprintScannerWidget> createState() => _FingerprintScannerWidgetState();
}

class _FingerprintScannerWidgetState extends State<FingerprintScannerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _scanController;
  bool _isHolding = false;
  bool _isSuccess = false;
  bool _hasError = false;
  String _statusText = 'Đặt và giữ ngón tay vào khu vực quét';

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: widget.scanDuration,
    )..addListener(() {
        if (mounted && _isHolding) {
          setState(() {});
        }
      })
      ..addStatusListener((status) async {
        if (status == AnimationStatus.completed && _isHolding) {
          try {
            HapticFeedback.heavyImpact();
          } catch (_) {}
          setState(() {
            _isSuccess = true;
            _isHolding = false;
            _hasError = false;
            _statusText = '🎉 Xác thực vân tay thành công!';
          });
          await Future.delayed(const Duration(milliseconds: 600));
          if (mounted) {
            await widget.onScanSuccess();
          }
        }
      });
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_isSuccess) return;
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
    setState(() {
      _isHolding = true;
      _hasError = false;
      _statusText = 'Đang quét cảm biến... Giữ yên ngón tay';
    });
    _scanController.forward(from: 0.0);
  }

  void _onPointerUp(PointerUpEvent event) {
    _handleTouchReleased();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _handleTouchReleased();
  }

  void _handleTouchReleased() {
    if (_isSuccess) return;
    if (_isHolding) {
      try {
        HapticFeedback.lightImpact();
      } catch (_) {}
      setState(() {
        _isHolding = false;
        _hasError = true;
        _statusText = '⚠️ Đã nhấc ngón tay! Vui lòng giữ ngón tay trên khu vực quét.';
      });
      _scanController.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _scanController.value;
    final int percent = (progress * 100).toInt();

    Color ringColor;
    Color iconColor;
    Color bgColor;

    if (_isSuccess) {
      ringColor = Colors.green.shade600;
      iconColor = Colors.green.shade600;
      bgColor = Colors.green.shade50;
    } else if (_isHolding) {
      ringColor = widget.primaryColor;
      iconColor = widget.primaryColor;
      bgColor = widget.primaryColor.withValues(alpha: 0.12);
    } else if (_hasError) {
      ringColor = Colors.red.shade400;
      iconColor = Colors.red.shade400;
      bgColor = Colors.red.shade50;
    } else {
      ringColor = AppColors.oceanCyan.withValues(alpha: 0.4);
      iconColor = AppColors.oceanPrimary;
      bgColor = AppColors.oceanSoft.withValues(alpha: 0.5);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tiêu đề khu vực quét
        Text(
          widget.title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: AppColors.primaryDarkNav,
          ),
        ),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            widget.subtitle!,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 18),

        // CẢM BIẾN VÂN TAY (Chỉ quét khi chạm và giữ ngón tay)
        Listener(
          onPointerDown: _onPointerDown,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Vòng sóng lan tỏa khi đang giữ ngón tay
              if (_isHolding)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: widget.size + 30,
                  height: widget.size + 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.primaryColor.withValues(alpha: 0.18),
                  ),
                ),

              // Vòng tròn cảm biến chính
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: bgColor,
                  border: Border.all(
                    color: ringColor,
                    width: _isHolding ? 3.0 : 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ringColor.withValues(alpha: _isHolding ? 0.35 : 0.12),
                      blurRadius: _isHolding ? 20 : 10,
                      spreadRadius: _isHolding ? 4 : 1,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    _isSuccess ? Icons.check_circle_rounded : Icons.fingerprint,
                    size: widget.size * 0.52,
                    color: iconColor,
                  ),
                ),
              ),

              // Vòng xoay tiến trình % khi giữ ngón tay
              if (_isHolding && !_isSuccess)
                SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 4.5,
                    valueColor: AlwaysStoppedAnimation<Color>(widget.primaryColor),
                    backgroundColor: Colors.transparent,
                  ),
                ),

              // Tia laser quét mô phỏng chạy lên xuống khi quét
              if (_isHolding && !_isSuccess)
                Positioned(
                  top: (widget.size * 0.2) + (widget.size * 0.6 * progress),
                  child: Container(
                    width: widget.size * 0.65,
                    height: 2.5,
                    decoration: BoxDecoration(
                      color: widget.primaryColor,
                      boxShadow: [
                        BoxShadow(
                          color: widget.primaryColor.withValues(alpha: 0.8),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Hiển thị phần trăm tiến trình khi đang giữ ngón tay
        if (_isHolding && !_isSuccess)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: widget.primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$percent%',
              style: TextStyle(
                color: widget.primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),

        const SizedBox(height: 8),

        // Trạng thái hướng dẫn rõ ràng
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            _statusText,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: (_isHolding || _isSuccess || _hasError)
                  ? FontWeight.bold
                  : FontWeight.w500,
              color: _isSuccess
                  ? Colors.green.shade700
                  : (_hasError
                      ? Colors.red.shade700
                      : (_isHolding ? widget.primaryColor : AppColors.textMuted)),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Gợi ý nhấn giữ
        if (!_isSuccess)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.touch_app_outlined,
                size: 16,
                color: _isHolding ? widget.primaryColor : Colors.grey.shade500,
              ),
              const SizedBox(width: 6),
              Text(
                'Nhấn và giữ ngón tay đến khi hoàn tất 100%',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
