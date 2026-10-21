import 'package:flutter/material.dart';

class AppColors {
  // 1. Hệ màu Xanh Đại Dương Chủ Đạo (Ocean Blue Palette)
  static const Color oceanDeep = Color(0xFF0B2545);       // Xanh đại dương thẳm (Header, AppBar, Nút chính)
  static const Color oceanDark = Color(0xFF134074);       // Xanh đại dương đậm
  static const Color oceanNavy = Color(0xFF0D2B45);       // Dark Navy đại dương
  static const Color oceanPrimary = Color(0xFF0077B6);    // Xanh biển rực rỡ (Điểm nhấn, Icon chính, Primary)
  static const Color oceanMedium = Color(0xFF0096C7);     // Xanh đại dương tươi
  static const Color oceanLight = Color(0xFF00B4D8);      // Xanh mặt biển rạng ngời
  static const Color oceanCyan = Color(0xFF48CAE4);       // Xanh ngọc sóng biển
  static const Color oceanIce = Color(0xFFADE8F4);        // Lam băng phát sáng nhẹ
  static const Color oceanSoft = Color(0xFFE0F2FE);       // Sóng biển êm dịu

  // Tương thích ngược với các biến cũ (Backwards compatibility)
  static const Color primaryDarkNav = oceanDeep;
  static const Color darkNavy = oceanDeep;
  static const Color navyCardStart = oceanDeep;
  static const Color navyCardEnd = oceanDark;
  static const Color darkButtonColor = oceanDeep;
  static const Color royalBlue = oceanPrimary;

  // 2. Hệ màu Ánh Sáng Rực Rỡ (Luminous Sunburst & Radiant Glow)
  static const Color sunlightGold = Color(0xFFFFB703);    // Vàng ánh nắng bình minh
  static const Color sunlightAmber = Color(0xFFF59E0B);   // Ánh sáng hổ phách ấm áp
  static const Color sunlightOrange = Color(0xFFFB8500);  // Cam ánh sáng rực rỡ
  static const Color sunlightGlow = Color(0xFFFEF08A);    // Ánh sáng tỏa dịu
  static const Color sunlightLight = Color(0xFFFFF7ED);   // Nền sáng ánh nắng

  // Tương thích ngược với các biến cũ
  static const Color orangeAccent = sunlightOrange;
  static const Color amberGlow = sunlightAmber;
  static const Color yellowLight = sunlightGold;

  // 3. Highlight & Nền Biển Nhẹ Nhàng
  static const Color lightBluePill = Color(0xFFE0F2FE);   // Highlight pill chọn tab / badge
  static const Color lightBlueBg = Color(0xFFEDF7FD);     // Nền icon bo góc nhẹ
  static const Color oceanGlass = Color(0xCCFFFFFF);     // Nền kính mờ Glassmorphism

  // 4. Nền & Khung thẻ
  static const Color scaffoldBg = Color(0xFFF0F7FB);      // Nền sáng pha lam ngọc nhạt thanh khiết
  static const Color cardBg = Colors.white;               // Nền thẻ trắng tinh tế
  static const Color borderLight = Color(0xFFDCE7F0);     // Viền khung input
  static const Color borderGlow = Color(0x8048CAE4);      // Viền phát sáng ánh biển

  // 5. Màu chữ
  static const Color textDark = Color(0xFF0B2545);        // Tiêu đề chữ đại dương đậm
  static const Color textSub = Color(0xFF1E3A5F);         // Chữ phụ cấp 1
  static const Color textMuted = Color(0xFF64748B);       // Chữ phụ mờ, gợi ý

  // 6. Trạng thái
  static const Color success = Color(0xFF10B981);         // Xanh lá thành công
  static const Color warning = Color(0xFFF59E0B);         // Cảnh báo vàng nắng
  static const Color error = Color(0xFFEF4444);           // Đỏ báo lỗi

  // 7. Gradients Đại Dương & Ánh Sáng (Gradients chuẩn toàn hệ thống)
  static const LinearGradient oceanPrimaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [oceanDeep, oceanDark, oceanPrimary],
  );

  static const LinearGradient oceanHeaderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF07192F), Color(0xFF0C2B4E), Color(0xFF005885)],
  );

  static const LinearGradient oceanWaveGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [oceanPrimary, oceanLight],
  );

  static const LinearGradient sunlightGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [sunlightGold, sunlightOrange],
  );

  static const LinearGradient oceanSunlightCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0B2545), Color(0xFF134074), Color(0xFF0077B6)],
  );

  static const LinearGradient oceanBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFE6F3FA),
      Colors.white,
      Color(0xFFE0F2FE),
    ],
  );
}
