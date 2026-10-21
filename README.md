# BÁO CÁO NỘP BÀI - DỰ ÁN APP CHẤM CÔNG NHÂN VIÊN (LTTBDD)

- **Môn học**: Lập trình thiết bị di động (LTTBDD)
- **Sinh viên thực hiện**: Trần Văn Lương
- **Nhánh phụ trách**: `Luong`
- **Đề tài**: Ứng dụng di động Chấm công cho Nhân viên & Quản lý doanh nghiệp

---

## GHI CHÚ CÁC THƯ MỤC CODE MỚI THÊM VÀO (THEO YÊU CẦU ĐỀ BÀI)

Dưới đây là bảng tổng hợp và ghi chú chi tiết **chỉ dành cho các thư mục code mới được thêm vào** trong dự án, tương ứng đầy đủ với các tiêu chí và yêu cầu nội dung của đề thi:

```
lib/
├── core/
│   ├── constants/              # [YC7] Cấu hình API endpoints và Theme màu sắc ứng dụng
│   │   ├── api_constants.dart
│   │   └── app_colors.dart
│   └── services/               # [YC6] Tính năng mới: Xử lý đồng bộ Offline & Sinh trắc học
│       ├── app_sync_service.dart
│       └── biometric_registry_service.dart
├── data/
│   └── datasources/            # Nguồn dữ liệu giả lập dự phòng khi offline
│       └── mock_data.dart
└── presentation/
    ├── screens/
    │   ├── auth/               # [YC1, YC2] Đăng ký Email, Đăng nhập và OTP
    │   │   ├── register_screen.dart
    │   │   ├── login_screen.dart
    │   │   ├── otp_screen.dart
    │   │   └── forgot_password_screen.dart
    │   ├── admin/              # [YC3, YC4] Quản trị Admin & các chức năng CRUD
    │   │   └── admin_dashboard_screen.dart
    │   ├── employee/           # [YC3, YC4] Dashboard Nhân viên & CRUD Đơn từ
    │   │   └── employee_dashboard_screen.dart
    │   ├── customer/           # [YC3] Màn hình Khách hàng / Đối tác
    │   │   └── customer_dashboard_screen.dart
    │   └── attendance/         # [YC5] 3 tính năng chấm công nâng cao (Camera, GPS, QR/NFC)
    │       ├── face_recognition_screen.dart
    │       ├── location_sharing_screen.dart
    │       └── qr_nfc_attendance_screen.dart
    └── widgets/                # [YC5, YC7] Custom Widgets & Quét vân tay sinh trắc học
        ├── custom_button.dart
        ├── custom_text_field.dart
        └── fingerprint_scanner_widget.dart
```

---

### Chi tiết các thư mục và đối chiếu yêu cầu đề thi

#### 1. Thư mục `lib/presentation/screens/auth/`
*Tương ứng Yêu cầu 1 và Yêu cầu 2 của đề thi:*
- **`register_screen.dart`**: **[Yêu cầu 1] Đăng ký tài khoản qua Email**: Form đăng ký tài khoản với validation email hợp lệ, kiểm tra độ an toàn mật khẩu và kết nối API tạo tài khoản.
- **`login_screen.dart`**: **[Yêu cầu 2] Đăng nhập bước 1**: Nhập Tên đăng nhập / Email và Mật khẩu, xác thực tài khoản ban đầu và khởi tạo quy trình gửi mã xác minh OTP.
- **`otp_screen.dart`**: **[Yêu cầu 2] Đăng nhập bước 2 (OTP)**: Màn hình nhập mã xác thực OTP 6 số để hoàn tất quy trình bảo mật 2 lớp trước khi vào hệ thống.
- **`forgot_password_screen.dart`**: Hỗ trợ khôi phục mật khẩu thông qua xác nhận mã gửi về email người dùng.

#### 2. Thư mục Phân quyền: `lib/presentation/screens/admin/`, `employee/`, `customer/`
*Tương ứng Yêu cầu 3 và Yêu cầu 4 của đề thi:*
- **`admin/admin_dashboard_screen.dart`**:
  - **[Yêu cầu 3 - Role Admin]**: Màn hình quản trị trung tâm dành cho người dùng có quyền Admin.
  - **[Yêu cầu 4 - Chức năng CRUD]**: Toàn quyền quản lý: Thêm, xem danh sách, chỉnh sửa và xóa nhân viên (CRUD Nhân viên); Tạo ca làm việc, duyệt / từ chối đơn xin nghỉ phép của nhân viên, trích xuất và lọc báo cáo chấm công.
- **`employee/employee_dashboard_screen.dart`**:
  - **[Yêu cầu 3 - Role Nhân viên]**: Bảng điều khiển công việc cá nhân của nhân viên, theo dõi ca làm, số công trong tháng.
  - **[Yêu cầu 4 - Chức năng CRUD]**: Tạo đơn xin nghỉ phép mới (Create), xem lịch sử đơn từ và ca làm (Read), cập nhật thông tin cá nhân (Update), hủy đơn nghỉ phép khi chờ duyệt (Delete).
- **`customer/customer_dashboard_screen.dart`**:
  - **[Yêu cầu 3 - Role Khách hàng]**: Giao diện dành riêng cho khách hàng / đối tác xem thông tin, đặt lịch hẹn làm việc và liên hệ công ty.

#### 3. Thư mục Chấm công đặc biệt: `lib/presentation/screens/attendance/` & `widgets/`
*Tương ứng Yêu cầu 5 (Chọn 3 trong 6 tính năng thuyết trình):*
- **`attendance/face_recognition_screen.dart`**:
  - **[Tính năng 5a - Đăng ký & Nhận diện khuôn mặt]**: Tích hợp camera thời gian thực để quét và phát hiện khuôn mặt của nhân viên khi check-in / check-out.
- **`attendance/location_sharing_screen.dart`**:
  - **[Tính năng 5b - Chia sẻ vị trí & Geofence GPS]**: Xác định vị trí địa lý GPS hiện tại của nhân viên, đối soát với tọa độ công ty trong bán kính cho phép (Geofence) để đảm bảo nhân viên có mặt đúng nơi làm việc.
- **`attendance/qr_nfc_attendance_screen.dart`**:
  - **[Tính năng 5e - Nhận diện QR Code & Thẻ NFC]**: Hỗ trợ quét mã QR động tại cổng văn phòng hoặc chạm thẻ nhân viên NFC để hoàn tất ghi nhận công.
- **`widgets/fingerprint_scanner_widget.dart`**:
  - **[Tính năng 5e - Cảm biến vân tay sinh trắc học]**: Component mô phỏng và tương tác cảm biến vân tay sinh trắc học bảo mật cao.

#### 4. Thư mục Dịch vụ nền & Tính năng mới: `lib/core/services/`
*Tương ứng Yêu cầu 6 (Tính năng mới tự đề xuất):*
- **`app_sync_service.dart`**:
  - **[Yêu cầu 6 - Offline Attendance & Auto Background Sync]**: Tính năng cho phép nhân viên vẫn có thể chấm công bình thường ngay cả khi mất mạng / không có Internet. Dữ liệu chấm công được lưu tạm vào hàng đợi (Sync Queue) trên thiết bị, và dịch vụ sẽ tự động đồng bộ hóa lên máy chủ đám mây ngay khi phát hiện có mạng trở lại.
- **`biometric_registry_service.dart`**: Dịch vụ quản lý, lưu trữ và đối chiếu dữ liệu sinh trắc học khuôn mặt và dấu vân tay an toàn.

#### 5. Thư mục Cấu hình & Giao diện dùng chung: `lib/core/constants/` & `lib/presentation/widgets/`
*Tương ứng Yêu cầu 7 (Giao diện đẹp, dễ dùng, đồng bộ):*
- **`core/constants/api_constants.dart`**: Định nghĩa các API endpoints kết nối đến máy chủ backend (.NET Web API).
- **`core/constants/app_colors.dart`**: Bộ thiết kế hệ màu hiện đại (Modern Teal & Slate Gradient), độ tương phản cao, hài hòa.
- **`presentation/widgets/custom_button.dart` & `custom_text_field.dart`**: Các component nút bấm, trường nhập liệu đồng bộ giao diện người dùng, hiệu ứng phản hồi mượt mà.

---

## HƯỚNG DẪN CHẠY DỰ ÁN

1. Cài đặt các thư viện phụ thuộc:
   ```bash
   flutter pub get
   ```
2. Chạy ứng dụng trên máy thật hoặc giả lập:
   ```bash
   flutter run
   ```