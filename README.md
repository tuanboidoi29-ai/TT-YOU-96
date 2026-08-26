# TT -SMATS PRO RBZ

Extension SketchUp viết bằng Ruby, giao diện tiếng Việt.

## Chức năng

- `Vẽ ván AUTU`: nhập Dài/Rộng/Dày, sau đó click điểm đặt trong model.
- `Kiểm tra bản cập nhật`: gọi manifest GitHub không đồng bộ, không làm treo SketchUp khi khởi động.
- Mỗi lệnh có callback Ruby riêng, menu trong `Extensions` và toolbar có icon.

## Cài đặt phát triển

1. Chép `tt_smats_pro.rb` và thư mục `tt_smats_pro` vào thư mục `Plugins` của SketchUp.
2. Khởi động SketchUp. Vào `Extensions > TT -SMATS PRO RBZ`.
3. Chạy `ruby package.rb` để tạo file `TT-SMATS-PRO-RBZ-v1.0.0.rbz`.
4. Cài RBZ bằng `Extension Manager > Install Extension`.

## Cập nhật GitHub

Khi phát hành version mới, cập nhật `VERSION` trong `tt_smats_pro/main.rb`, sửa `update.json`, chạy lại `ruby package.rb`, rồi tải RBZ lên GitHub Release. Plugin chỉ mở trang Release khi có version mới; việc cài archive vẫn do Extension Manager xử lý để tránh tự ý thay đổi file SketchUp.

`SketchupExtension` đăng ký ở loader root nên SketchUp chỉ nạp metadata lúc khởi động. Runtime và kết nối mạng chỉ được gọi khi người dùng bấm lệnh.