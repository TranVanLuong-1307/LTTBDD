# BÁO CÁO NỘP BÀI - DỰ ÁN MÁY CHỦ WEB API CHẤM CÔNG NHÂN VIÊN (LTTBDD)

- **Môn học**: Lập trình thiết bị di động (LTTBDD)
- **Sinh viên thực hiện**: Trần Văn Lương
- **Nhánh phụ trách**: `backend`
- **Đề tài**: Máy chủ Backend Web API Quản lý & Chấm công Nhân viên Doanh nghiệp
- **Công nghệ**: ASP.NET Core 10 Web API, Entity Framework Core, PostgreSQL, Docker, JWT Authentication
- **Máy chủ Production (Cloud Render)**: [https://webapi-chamcong-nhom9-tongnhatbaoan.onrender.com/swagger](https://webapi-chamcong-nhom9-tongnhatbaoan.onrender.com/swagger)

---

## GHI CHÚ CÁC THƯ MỤC CODE MỚI THÊM VÀO (THEO YÊU CẦU ĐỀ BÀI)

Dưới đây là bảng tổng hợp và ghi chú chi tiết **chỉ dành cho các thư mục code mới được thêm vào** trong dự án máy chủ backend, tương ứng đầy đủ với các tiêu chí và yêu cầu nội dung của đề thi môn học Lập trình thiết bị di động (LTTBDD):

```
WebAPI_TongNhatBaoAn/
├── Controllers/                # [YC1 - YC5] Bộ điều khiển xử lý toàn bộ RESTful API endpoints
│   └── Controllers.cs          # Auth, Me, Employees, Shifts, Departments, Office, Attendance, Requests
├── Models/                     # [YC3 - YC6] Định nghĩa Data Model, Entities CSDL và Role phân quyền
│   └── Entities.cs             # Employee, Shift, Department, Office, Attendance, WorkRequest, Otp, Token
├── Dtos/                       # [YC1 - YC5] Data Transfer Objects chuẩn hóa Request / Response
│   └── Dtos.cs                 # DTOs tách biệt tầng giao tiếp, bảo mật dữ liệu nhạy cảm
├── Services/                   # [YC1, YC2, YC5, YC6] Các dịch vụ nghiệp vụ cốt lõi & bảo mật
│   ├── OtpEmailSender.cs       # [YC1, YC2] Dịch vụ tích hợp gửi mã OTP bảo mật qua Brevo HTTPS API
│   └── Services.cs             # [YC2, YC5, YC6] JWT Token, Mã QR HMAC xoay vòng, GPS Haversine, Múi giờ VN
├── Data/                       # [YC7] Tầng dữ liệu & Quản lý cơ sở dữ liệu PostgreSQL
│   ├── AppDb.cs                # [YC7] DbContext Entity Framework Core, cấu hình Indexes & Ràng buộc
│   └── Migrations/             # [YC7] Bản ghi lịch sử di chuyển CSDL tự động (Migrations)
├── Program.cs                  # [YC7] Cấu hình khởi tạo Web API, Middleware, Swagger UI & Rate Limiter
└── Dockerfile                  # [YC7] Đóng gói container Docker phục vụ triển khai Cloud (Render)
```

---

### Chi tiết các thư mục và đối chiếu yêu cầu đề thi

#### 1. Thư mục Bộ điều khiển: `WebAPI_TongNhatBaoAn/Controllers/`
*Tương ứng Yêu cầu 1, Yêu cầu 2, Yêu cầu 3, Yêu cầu 4 và Yêu cầu 5 của đề thi:*
- **`Controllers.cs`**: Tập hợp các RESTful API Controllers đáp ứng trọn vẹn luồng dữ liệu của ứng dụng:
  - **`AuthController`**:
    - **[Yêu cầu 1 - Đăng ký qua Email]**: `POST /api/auth/register` & `POST /api/auth/verify-email`: Xử lý đăng ký tài khoản nhân viên, mã hóa mật khẩu an toàn bằng thuật toán `BCrypt`, tạo challenge OTP và gửi mã xác minh về email.
    - **[Yêu cầu 2 - Đăng nhập 2 bước (Email + OTP)]**: `POST /api/auth/login` (bước 1: kiểm tra tài khoản, mật khẩu, gửi OTP về email) & `POST /api/auth/verify-otp` (bước 2: kiểm tra OTP, cấp cặp Access Token JWT và Refresh Token). Ngoài ra hỗ trợ `POST /api/auth/refresh` và đổi mật khẩu.
  - **`MeController`**:
    - **[Yêu cầu 3 - Phân quyền]**: `GET /api/me`: Trả về thông tin hồ sơ của người dùng hiện tại dựa trên `Claim` định danh trong JWT Bearer Token.
  - **`EmployeesController`**:
    - **[Yêu cầu 3, Yêu cầu 4 - Phân quyền Admin & CRUD Nhân viên]**: Các endpoint quản trị (`GET /api/employees`, `POST /api/employees`, `PUT /api/employees/{id}`, `DELETE /api/employees/{id}`): Cho phép Admin xem danh sách, lọc theo phòng ban, tạo nhân viên mới, phân ca làm việc, thay đổi vai trò (Admin, Manager, Employee), khóa hoặc mở khóa tài khoản.
  - **`ShiftsController`**:
    - **[Yêu cầu 4 - CRUD Ca làm việc]**: `GET /api/shifts`, `POST /api/shifts`, `PUT /api/shifts/{id}`, `DELETE /api/shifts/{id}`: Quản lý ca làm sáng, chiều, hành chính, thời gian bắt đầu, kết thúc và số phút cho phép trễ.
  - **`DepartmentsController`**:
    - **[Yêu cầu 4 - CRUD Phòng ban]**: Quản lý phòng ban doanh nghiệp (IT, Kế toán, Nhân sự, Kinh doanh).
  - **`OfficeController`**:
    - **[Yêu cầu 5 - Tọa độ văn phòng & Mã QR động]**: Cấu hình vị trí GPS trụ sở (Kinh độ, vĩ độ, bán kính Geofence) và sinh mã QR động dùng cho chấm công.
  - **`AttendanceController`**:
    - **[Yêu cầu 5 - 3 Tính năng chấm công nâng cao]**: `POST /api/attendance/check-in` & `POST /api/attendance/check-out`: Tiếp nhận dữ liệu chấm công bao gồm mã QR động, tọa độ GPS thời gian thực, độ chính xác thiết bị. Kiểm tra geofence và tính toán thời gian đi muộn tự động.
    - **[Yêu cầu 6 - Tính năng mới: Chống trùng lặp & Idempotency]**: Sử dụng `IdempotencyKey` đảm bảo khi app mobile đồng bộ lại dữ liệu sau khi mất mạng sẽ không bị ghi đè hay chấm công trùng lặp.
  - **`RequestsController`**:
    - **[Yêu cầu 4, Yêu cầu 6 - CRUD Đơn từ]**: Quản lý quy trình gửi và xét duyệt đơn xin nghỉ phép, giải trình chấm công của nhân viên; Admin/Manager có quyền duyệt (`approve`) hoặc từ chối (`reject`).

#### 2. Thư mục Thực thể & Phân quyền: `WebAPI_TongNhatBaoAn/Models/`
*Tương ứng Yêu cầu 3, Yêu cầu 4 và Yêu cầu 6 của đề thi:*
- **`Entities.cs`**:
  - **[Yêu cầu 3 - Phân quyền 3 Roles]**: Lớp tĩnh `Roles` định nghĩa 3 cấp bậc phân quyền rõ ràng: `Roles.Admin`, `Roles.Manager`, `Roles.Employee`.
  - **`Employee`**: Quản lý thông tin nhân viên, email, tên đăng nhập, mã băm mật khẩu `BCrypt`, phân quyền, trạng thái kích hoạt và xác minh email.
  - **`Shift` & `Department`**: Mô hình hóa ca làm việc và cơ cấu phòng ban trong doanh nghiệp.
  - **`Office`**: Lưu trữ kinh độ, vĩ độ GPS công ty và khóa bí mật `QrSecret`.
  - **`Attendance`**: Bảng dữ liệu chấm công lưu vết chi tiết: thời gian check-in/out, số phút trễ, tọa độ GPS, độ sai số (Accuracy), và khóa bất biến Idempotency.
  - **`WorkRequest`**: Mô hình đơn từ với cơ chế khóa lạc quan (Optimistic Concurrency) qua thuộc tính `Version` (RowVersion).
  - **`OtpChallenge` & `RefreshToken`**: Lưu vết bảo mật chu kỳ sống của mã OTP và mã làm mới JWT token.

#### 3. Thư mục Truyền tải dữ liệu: `WebAPI_TongNhatBaoAn/Dtos/`
*Tương ứng Yêu cầu 1 đến Yêu cầu 5 của đề thi:*
- **`Dtos.cs`**: Định dạng dữ liệu chuẩn (Records/DTOs) phục vụ trao đổi API an toàn:
  - `RegisterRequest`, `LoginRequest`, `VerifyCodeRequest`, `TokenResponse`, `ChallengeResponse`: Chuẩn hóa luồng xác thực.
  - `CheckInRequest`, `CheckOutRequest`, `AttendanceReportItem`: Chuẩn hóa dữ liệu chấm công.
  - **Bảo mật**: Tuyệt đối không để lộ mật khẩu, chuỗi băm (passwordHash) hay mã bí mật QR ra ngoài response.

#### 4. Thư mục Dịch vụ nền & Nghiệp vụ chuyên sâu: `WebAPI_TongNhatBaoAn/Services/`
*Tương ứng Yêu cầu 1, Yêu cầu 2, Yêu cầu 5 và Yêu cầu 6 của đề thi:*
- **`OtpEmailSender.cs`**:
  - **[Yêu cầu 1, Yêu cầu 2 - Gửi OTP qua Email]**: Tích hợp trực tiếp với dịch vụ gửi thư Brevo HTTPS API qua HttpClient, đảm bảo email chứa mã OTP được gửi đến hòm thư người dùng trong vòng vài giây.
- **`Services.cs`**:
  - **`TokenService`**: Cấp phát mã truy cập JWT Bearer Token (thời hạn 30 phút) chứa thông tin claim vai trò và cấp Refresh Token ngẫu nhiên (thời hạn 7 ngày) được mã hóa SHA-256 trong CSDL.
  - **`QrService`**: **[Yêu cầu 5 - Tính năng QR Code động]**: Sinh mã QR động được ký bằng thuật toán HMAC SHA-256 xoay vòng mỗi 60 giây. Kiểm tra tính hợp lệ của mã QR để chống gian lận (chụp ảnh màn hình chia sẻ cho người khác).
  - **`GeoService`**: **[Yêu cầu 5 - Tính năng Geofencing GPS]**: Cung cấp hàm tính khoảng cách địa lý chính xác giữa vị trí người dùng và văn phòng dựa trên công thức Haversine (tính theo mét).
  - **`TimeVn`**: Chuẩn hóa toàn bộ thời gian hệ thống sang múi giờ Việt Nam (UTC+7), lưu trữ chuẩn UTC trong DB.

#### 5. Thư mục Cơ sở dữ liệu: `WebAPI_TongNhatBaoAn/Data/`
*Tương ứng Yêu cầu 7 (Kiến trúc chuẩn hóa, CSDL hoàn chỉnh):*
- **`AppDb.cs`**: Kế thừa `DbContext` của Entity Framework Core, định nghĩa các chỉ mục duy nhất (`Unique Index`) cho Username, Email, TokenHash và cặp (EmployeeId, WorkDate) để chống chấm công trùng lặp.
- **`Data/Migrations/`**: Quản lý lịch sử tiến hóa cơ sở dữ liệu thông qua Code-First Migrations, giúp hệ thống tự động khởi tạo bảng khi triển khai lên máy chủ.

#### 6. Cấu hình hệ thống & Triển khai Đám mây: `Program.cs` & `Dockerfile`
*Tương ứng Yêu cầu 7 (Giao diện API trực quan, dễ dùng, đồng bộ):*
- **`Program.cs`**: Cấu hình toàn bộ Middleware của ứng dụng: xác thực JWT Bearer, phân quyền Role-based, Rate Limiting chống spam/brute-force (giới hạn 20 request/phút), tài liệu tương tác trực quan Swagger / OpenAPI UI, tự động khởi tạo tài khoản Quản trị viên (Admin Seed).
- **`Dockerfile`**: Đóng gói ứng dụng thành Docker container đa tầng (Multi-stage build) trên nền tảng .NET 10, tối ưu dung lượng và sẵn sàng triển khai trên các nền tảng đám mây như Render, Koyeb hoặc Railway.

---

## HƯỚNG DẪN CẤU HÌNH VÀ CHẠY DỰ ÁN

### 1. Truy cập trực tiếp qua Cloud Render (Khuyến nghị)
Hệ thống backend đã được triển khai trực tiếp và đang chạy thực tế trên máy chủ đám mây:
- **Swagger Documentation UI**: [https://webapi-chamcong-nhom9-tongnhatbaoan.onrender.com/swagger](https://webapi-chamcong-nhom9-tongnhatbaoan.onrender.com/swagger)
- **API Base URL**: `https://webapi-chamcong-nhom9-tongnhatbaoan.onrender.com/api`

### 2. Chạy nội bộ (Local Development)

Yêu cầu môi trường: .NET SDK (phiên bản 9.0 hoặc 10.0), PostgreSQL.

```powershell
# Di chuyển vào thư mục dự án
cd WebAPI_TongNhatBaoAn

# Thiết lập các biến môi trường
$env:ConnectionStrings__Default = "Host=localhost;Database=AppChamCong;Username=postgres;Password=<mat_khau>"
$env:Jwt__Key = "DayLaChuoiBiMatJwtCoDoDaiTren32KyTuBaoMat!"
$env:RUN_MIGRATIONS = "true"
$env:Seed__AdminUsername = "admin"
$env:Seed__AdminEmail = "admin@example.com"
$env:Seed__AdminPassword = "AdminPassword@123"
$env:Auth__DebugReturnOtp = "true"

# Chạy máy chủ Web API
dotnet run
```
Mở trình duyệt truy cập: `http://localhost:5000/swagger` để kiểm thử toàn bộ các API endpoints.
