#  Caffee

Bộ gõ tiếng Việt đơn giản nhất (native cho mac, viết bằng Swift, support macOS 13+ Ventura trở lên)

## Chức năng

- Gõ tiếng Việt (đặt dấu theo kiểu cũ - vì tính thẩm mỹ và nhất quán - chữ viết là 1 data vì vậy nó nên nhất quán cách viết và đặt dấu)
- Hỗ trợ 2 kiểu gõ thông dụng nhất ( TELEX và VNI )
- Hỗ trợ nhớ chế độ gõ (Vi - En) theo ứng dụng (ví dụ app A là Vi, switch qua app B trước đó là En, switch lại app A thì chuyển về Vi)
- Hỗ trợ fix lỗi thanh địa chỉ của trình duyệt và Excel (do tính năng tự gợi ý)
- Hỗ trợ tạo Hot key để chuyển nhanh chế độ gõ En - Vi trong app mà không cần bấm chuột
- Hỗ trợ khởi động cùng hệ điều hành (và tự động chạy ngầm trên System Menu)

## Cài đặt

1. Tải file .dmg phiên bản mới nhất về, mở file lên, xuất hiện khung cửa sổ
2. Kéo thả app tên Caffee vào thư mục Applications
3. Mở app Caffee bằng LaunchPad hoặc Spotlight (lần đầu macOS sẽ hỏi có muốn mở app không, xác nhận Mở)
4. Sau khi mở app lần đầu cần cài đặt quyền hệ thống để bộ gõ hoạt động được (theo hướng dẫn trên App)
5. Sau khi làm theo hướng dẫn trên App, tắt App và mở lại 1 lần nữa là có thể dùng được bình thường

## Nâng cấp phiên bản

Nếu đã từng dùng phiên bản cũ, bạn có thể tải file .dmg của bản mới nhất về làm từ bước 1-3 như trên (không cần cấp lại quyền). Nhưng trước khi nâng cấp vui lòng Quit app bản cũ bằng cách click biểu tượng trên Menu, chọn Quit App.

## Build

Nhớ cài cái tool `swift-format` vì mình cho nó format code trước khi build (không thích thì vào Build Phases bỏ ra nhé)

```shell
$ brew install swift-format
```

Build như 1 macOS bình thường (XCode 15+)

## FAQ

1. App có an toàn không ?

- App trên website chính thức sẽ an toàn, do chính tay mình Code, chính tay mình Build, chính tay mình gửi lên Apple ký số để phân phối App (1 lớp quét virus dạng nhẹ).
- Nếu bạn hỏi tại sao phải tin mình ? Đúng! Bạn không cần tin. Mình tin mình làm điều đúng đắn.

2. Sao phải cấp quyền macOS thì mới dùng được App ?

- Đầu tiên việc bạn đặt ra câu hỏi mỗi khi cấp quyền là một tư duy bảo mật tốt!
- Nếu bạn dùng macOS đã lâu sẽ thấy macOS có 2 dạng bộ gõ :
    + Chính thức nguyên tem của hệ điều hành, do Apple viết dựa trên Engine tiếng việt của Unikey, nhưng cách hoạt động là nó tạo 1 cái input giả (gọi là Buffer ảo) để bạn nhập Tiếng Việt vào đó, đó là lý do mà nó thường có gạch chân. Đến khi bạn bấm 1 key kết thúc 1 từ (như Space hay chấm phẩy), hệ điều hành mới Commit cái từ tiếng Việt đó xuống cái Input thật. Nên sẽ có hiện tượng bạn chưa gõ xong từ mà bấm chuột qua khung khác là nó Move cái từ bạn vừa gõ qua khung đó. Và còn rất nhiều bug phát sinh do dùng Input giả.
    + Hàng chế (Caffee, GoTiengViet, OpenKey, EVKey, ...), do lập trình viên VN mơ ước về một trải nghiệm gõ tiếng Việt tốt hơn trên macOS như trên Windows (Unikey làm rất tốt). Các hàng chế này hoạt động cơ bản trên cách "Listen" (nghe toàn bộ keyboard được bấm) của bạn trên macOS, chuyển nó qua Tiếng Việt theo kiểu gõ bạn chọn, rồi lại "Send" các ký tự Tiếng Việt này xuống thẳng Input thật cho bạn. Vì thế mà tất cả app kiểu hàng chế này phải xin 2 quyền cơ bản là Listen và Send (quyền nào cũng nguy hiểm nếu tác giả không ngay thẳng)
- **Lưu ý :** Một khi đã cấp quyền, bạn có thể lấy lại quyền nếu muốn (nhưng nhớ tắt App trước khi làm vì đây là cái bug to đùng ở phía macOS, nó sẽ crash cả cái máy, bạn chỉ có nước bấm giữ Power để tắt hoàn toàn máy).

3. Tại sao app miễn phí ?

- Ban đầu mình cũng dự tính thương mại bán License app này, nhưng nghĩ lại market VN hơi chua :
    + Thị trường quá quen với hàng Free (như mình cũng vậy)
    + Thị trường cũng đã có các app Free (OpenKey, EVKey) với hàng tá tính năng kiểu gõ với bảng Settings to đùng
    + Cổng thanh toán ở VN khá chán, bán App thì lên Apple Store là ngon nhất (vừa tạo được niềm tin uy tín, vừa trải nghiệm mua nhanh gọn lẹ). Nhưng khổ nổi loại app này được liệt kê vào danh mục cấm lên App (do đó bạn thấy các app trước không lên được - vì 2 cái quyền khá nhạy cảm)

4. Tại sao Open-source ?

- Mình dự tính là Free nhưng sẽ Closed-Source, nhưng nghĩ lại tài hèn sức mọn, cái đống mã này chẳng bỏ gì với tài năng của các dev VN khác
- Việc open-source cho các Dev khác chung sở thích và muốn hiểu hơn về bộ gõ có thể đóng góp
- Mình thấy đa phần các App trước OpenSource viết khá khó hiểu (như OpenKey viết bằng Obj-C) và Engine nhìn rất Hard-core (mỗi khi mình muốn Contribute phải vận rất nhiều nội công học lại - nên đa phần bỏ cuộc ở bước đọc code)

## Package .dmg file

```shell
create-dmg \
  --volname "Caffee Installer" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --icon "Caffee.app" 200 190 \
  --hide-extension "Caffee.app" \
  --app-drop-link 600 185 \
  "Caffee-Installer.dmg" \
  "Caffee1.4/"
```

## LICENSE

GNU General Public License v3.0

(The GNU GPLv3 also lets people do almost anything they want with your project, except distributing closed source versions.)
