import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  // Máy chủ API Online Render chính thức theo yêu cầu
  static const String renderUrl = 'https://webapi-chamcong-nhom9-tongnhatbaoan.onrender.com/api';

  static String get baseUrl {
    final envUrl = dotenv.env['API_BASE_URL']?.trim();
    if (envUrl != null && envUrl.isNotEmpty && !envUrl.contains('localhost')) {
      return envUrl;
    }
    return renderUrl;
  }

  static int get timeout {
    final timeoutStr = dotenv.env['API_TIMEOUT'] ?? '25000';
    return int.tryParse(timeoutStr) ?? 25000;
  }
}
