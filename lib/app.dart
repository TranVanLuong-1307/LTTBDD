import 'package:flutter/material.dart';
import 'core/constants/app_colors.dart';
import 'presentation/screens/auth/login_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Chấm Công',
      debugShowCheckedModeBanner: false, // Tắt chữ DEBUG ở góc phải
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.oceanPrimary,
          primary: AppColors.oceanPrimary,
          secondary: AppColors.sunlightGold,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: AppColors.scaffoldBg,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.oceanDeep,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.oceanDeep,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 3,
            shadowColor: AppColors.oceanPrimary.withValues(alpha: 0.3),
          ),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const LoginScreen(),
    );
  }
}
