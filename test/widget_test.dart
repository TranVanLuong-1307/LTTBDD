import 'package:flutter_test/flutter_test.dart';

import 'package:tranvanluong_ui/app.dart';

void main() {
  testWidgets('App load smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Kiểm tra xem màn hình đăng nhập có hiển thị không
    expect(find.text('Đăng nhập'), findsWidgets);
  });
}
