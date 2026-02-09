import Cocoa
import SwiftUI

struct GuideView: View {
  @Environment(AppState.self) var appState

  @State var requested: Bool = false
  @State var checkOk: Bool = false

  var textBody = """
    Chào bạn, các bộ gõ cần được cấp quyền hệ thống để chạy được, bạn làm theo hướng dẫn bên dưới (vui lòng đọc hết 4 bước rồi thực hiện): \n
    1. Bấm nút Xin cấp quyền ứng dụng bên dưới, sau đó bấm nút 'Open System Settings'\n
    2. Trong hộp thoại 'Accessibility', bạn mở công tắc cấp phép app Caffee.\n
    3. Hệ điều hành sẽ xác nhận lại, bạn xác thực bằng vân tay hoặc mật khẩu.\n
    4. Bạn đã cấp quyền thành công, vui lòng bấm 'Kiểm tra quyền'.
    """

  var body: some View {
    VStack(alignment: .center) {
      Text(textBody)
        .multilineTextAlignment(.leading)
        .lineSpacing(4.0)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .font(.system(size: 15.0))
      if checkOk {
        Button(
          "OK ! Bấm để tắt App (sau đó vui lòng mở lại lần nữa)",
          systemImage: "gear.badge.checkmark",
          action: {
            NSApp.terminate(nil)
          }
        )
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
      } else {
        HStack {
          Button(
            "Xin cấp quyền", systemImage: "gear.badge",
            action: {
              requested = true
              if appState.eventHook.isTrusted(prompt: true) {
                checkOk = true
              }
            }
          )
          .buttonStyle(.borderedProminent)
          .controlSize(.large)

          if requested {
            Button(
              "Kiểm tra quyền", systemImage: "gear.badge.questionmark",
              action: {
                checkOk = appState.eventHook.isTrusted(prompt: false)
                if !checkOk {
                  requested = false
                }
              }
            )
            .controlSize(.large)
          }

        }
      }
    }.frame(width: 520, height: 400)
  }
}

class WindowController: NSWindowController {
  override init(window: NSWindow? = nil) {
    super.init(window: window)
    if window == nil {
      let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
        styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
        backing: .buffered, defer: false)
      window.center()
      window.setFrameAutosaveName("Main Window")
      window.title = "Caffee"
      self.window = window
    }
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

struct GuideView_Previews: PreviewProvider {
  static var previews: some View {
    GuideView()
      .environment(AppState())
      .previewLayout(PreviewLayout.sizeThatFits)
      .padding()
      .previewDisplayName("GuideView preview")
  }
}
