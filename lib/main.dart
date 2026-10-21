import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app.dart';

void main() async {
  // Bắt buộc khai báo khi thực hiện các tác vụ bất đồng bộ trước khi runApp
  WidgetsFlutterBinding.ensureInitialized();
  
  // Tải file .env
  await dotenv.load(fileName: ".env");
  
  runApp(const MyApp());
}
