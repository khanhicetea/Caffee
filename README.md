#  Caffee

Bộ gõ tiếng Việt đơn giản nhất (native cho mac, viết bằng Swift, support macOS 14+ Sonoma trở lên)

## Chức năng

- Gõ tiếng Việt (đặt dấu theo kiểu cũ - vì tính thẩm mỹ và nhất quán - chữ viết là 1 data vì vậy nó nên nhất quán cách viết và đặt dấu)
- Hỗ trợ 2 kiểu gõ thông dụng nhất ( TELEX và VNI )
- Hỗ trợ nhớ chế độ gõ (Vi - En) theo ứng dụng (ví dụ app A là Vi, switch qua app B trước đó là En, switch lại app A thì chuyển về Vi). Lựa chọn được lưu lại sau khi mở lại app, và có thể ghim một ứng dụng luôn gõ Việt hoặc luôn gõ Anh (Cài đặt > Ứng dụng)
- Chọn cách gửi phím riêng cho từng ứng dụng (Cài đặt > Ứng dụng) để sửa lỗi chữ ở các app khó tính như Terminal, Electron, Office
- Chọn vị trí đặt dấu (hòa, thủy hay hoà, thuỷ), bật/tắt kiểm tra chính tả và phụ âm ngoại lai (z, w, j, f)
- Hiện nhanh chữ V/E giữa màn hình mỗi khi đổi chế độ
- Hỗ trợ fix lỗi thanh địa chỉ của trình duyệt và Excel (do tính năng tự gợi ý)
- Hỗ trợ tạo Hot key để chuyển nhanh chế độ gõ En - Vi trong app mà không cần bấm chuột
- Hỗ trợ khởi động cùng hệ điều hành (và tự động chạy ngầm trên System Menu)
- Điều khiển từ script / Shortcuts / Raycast (xem mục **Tự động hóa** bên dưới)

## Cài đặt

1. Tải file .dmg phiên bản mới nhất về, mở file lên, xuất hiện khung cửa sổ
2. Kéo thả app tên Caffee vào thư mục Applications
3. Mở app Caffee bằng LaunchPad hoặc Spotlight (lần đầu macOS sẽ hỏi có muốn mở app không, xác nhận Mở)
4. Sau khi mở app lần đầu cần cài đặt quyền hệ thống để bộ gõ hoạt động được (theo hướng dẫn trên App)
5. Ngay sau khi cấp quyền, bộ gõ tự hoạt động (không cần mở lại App). Nếu biểu tượng trên menu bar báo lỗi, chọn "Thử lại" trong menu

## Nâng cấp phiên bản

Vào menu bar > chọn 'Check for Updates' để kiểm tra và nâng cấp phiên bản mới nhất.

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

5. App có dùng AI để phát triển không ?

Có, trước năm 2026 hoàn toàn kiến trúc bộ gõ (Engine) là do tự mình nghĩ và phát triển. Từ 2026, mình dùng AI để tìm bugs, cải thiện UX, và phát triển các tính năng mới dựa trên kiến trúc bộ gõ (Engine).

Mọi commits đều được review và test kĩ trước khi push và release app.

6. Vì sao biểu tượng ổ khóa vẫn hiện sau khi rời ô mật khẩu hoặc mở lại Caffee?

- Ổ khóa cho biết **macOS Secure Input** đang bật. Đây là khóa của hệ thống, không phải chế độ được Caffee lưu lại. macOS không chuyển sự kiện bàn phím cho bộ gõ khi bất kỳ ứng dụng nào giữ khóa này, kể cả ứng dụng chạy nền.
- Hãy đóng ô/hộp thoại mật khẩu. Nếu vẫn bị khóa, thoát và mở lại ứng dụng đã bật Secure Input (thường là trình duyệt, Terminal hoặc ứng dụng quản lý mật khẩu). Với Terminal, kiểm tra mục **Terminal > Secure Keyboard Entry**.
- Caffee tự kiểm tra trạng thái khóa và hoạt động lại khi khóa được nhả. Mở lại riêng Caffee không thể gỡ khóa của ứng dụng khác. Bấm mục **Bàn phím bị khóa bởi macOS (Secure Input)…** trong menu để xem hướng dẫn.
- Để tìm ứng dụng giữ khóa, có thể chạy lệnh chỉ đọc sau trong Terminal:

  ```sh
  ioreg -l -w 0 | grep -o '"kCGSSessionSecureInputPID"[[:space:]]*=[[:space:]]*[0-9]*' | sort -u
  ```

  Nếu có PID, dùng `ps -p PID -o comm=` (thay `PID` bằng số vừa tìm được) để xem tiến trình. Thông tin chẩn đoán này có thể không xuất hiện trên một số phiên bản macOS; không có kết quả không có nghĩa là Secure Input đã tắt. Không cần và không nên buộc tắt bảo vệ mật khẩu từ Caffee.
- Tham khảo: [Apple TN2150 — Using Secure Event Input Fairly](https://developer.apple.com/library/archive/technotes/tn2150/_index.html).

## Tự động hóa

Có thể đổi chế độ gõ từ Terminal, script, Shortcuts, Raycast hay Alfred:

```sh
open caffee://mode/vi          # bật tiếng Việt (en: tắt, toggle: đảo)
open caffee://method/telex     # đổi kiểu gõ (vni)
echo vi > ~/Library/Application\ Support/Caffee/switch   # vi | en | toggle | telex | vni
```

File điều khiển nằm trong thư mục riêng của bạn (không dùng `/tmp` nữa vì người dùng khác trên máy có thể ghi vào đó). Để báo lỗi, vào Cài đặt > Nâng cao > **Xuất nhật ký chẩn đoán** và đính kèm file.

## Package .dmg file

```shell
create-dmg "Caffee.app"
```

## LICENSE

GNU General Public License v3.0

(The GNU GPLv3 also lets people do almost anything they want with your project, except distributing closed source versions.)
