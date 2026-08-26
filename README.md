# TT -SMATS PRO RBZ

Extension SketchUp viết bằng Ruby, giao diện tiếng Việt.

## Chức năng

- `Vẽ ván AUTU`: nhập Độ dày, click đúng hai điểm chéo trong View 3D. Plugin tự nhận diện mặt phẳng, chiều dài và chiều rộng; di chuột hiển thị kích thước trước khi click thứ hai để tạo ván.
- Nhấn `Tab` trong lúc vẽ để đổi hướng: tự động, XY, XZ, YZ.
- Sau mỗi ván, công cụ tự chờ ván tiếp theo với cùng độ dày. Chọn `Đổi độ dày và tiếp tục vẽ` khi cần nhập độ dày mới.
- Preview hiển thị dạng khung khối 3D gồm mặt trên, mặt dưới và cạnh bên theo độ dày.
- `Kiểm tra bản cập nhật`: gọi manifest GitHub không đồng bộ, không làm treo SketchUp khi khởi động.
- Mỗi lệnh có callback Ruby riêng, menu trong `Extensions` và toolbar có icon.

## Cài đặt phát triển

1. Chép `tt_smats_pro.rb` và thư mục `tt_smats_pro` vào thư mục `Plugins` của SketchUp.
2. Khởi động SketchUp. Vào `Extensions > TT -SMATS PRO RBZ`.
3. Chạy `ruby package.rb` để tạo file RBZ theo version hiện tại.
4. Cài RBZ bằng `Extension Manager > Install Extension`.

## Cập nhật GitHub

Khi phát hành version mới, cập nhật `VERSION` trong `tt_smats_pro/main.rb`, sửa `update.json`, chạy lại `ruby package.rb`, rồi tải RBZ lên GitHub Release. Plugin chỉ mở trang Release khi có version mới; việc cài archive vẫn do Extension Manager xử lý để tránh tự ý thay đổi file SketchUp.

`SketchupExtension` đăng ký ở loader root nên SketchUp chỉ nạp metadata lúc khởi động. Runtime và kết nối mạng chỉ được gọi khi người dùng bấm lệnh.