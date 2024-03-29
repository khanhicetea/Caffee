import Cocoa
import SwiftUI

func openAccessibilitySettings() {
  let script = """
    tell application "System Preferences"
        activate
        set current pane to pane "com.apple.preference.security"
        reveal anchor "Privacy_Accessibility" of pane "com.apple.preference.security"
    end tell
    """

  if let appleScript = NSAppleScript(source: script) {
    var error: NSDictionary?
    appleScript.executeAndReturnError(&error)
    if let error = error {
      print("Error: \(error)")
    }
  }
}

struct UpgradeAppView: View {
  @EnvironmentObject var appState: AppState

  @State var openedSettings = false

  var textBody = """
    Bộ gõ cần được cấp lại quyền mỗi lần Update bản mới, bạn làm theo hướng dẫn bên dưới (vui lòng đọc hết 4 bước rồi thực hiện): \n
    1. Bấm nút 'Open System Settings' bên dưới để mở hộp thoại cấp quyền\n
    2. Trong hộp thoại 'Accessibility', bạn chọn dòng Caffee đã cấp quyền lúc trước và bấm nút có dấu '-' để xóa ra.\n
    3. Hệ điều hành sẽ xác nhận lại, bạn xác thực bằng vân tay hoặc mật khẩu.\n
    4. Bạn đã xóa quyền của App cũ thành công, vui lòng tắt App và mở lại để cấp quyền như lúc cài ban đầu'.
    """

  var body: some View {
    VStack(alignment: .center) {
      Text(textBody)
        .multilineTextAlignment(.leading)
        .lineSpacing(4.0)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .font(.system(size: 15.0))

      HStack {
        Button(
          "Open System Settings", systemImage: "gear.badge",
          action: {
            if appState.eventHook.isTrusted(prompt: true) {
              openedSettings = true
            }
          }
        )
        .buttonStyle(.borderedProminent)
        .controlSize(.large)

        if openedSettings {
          Button(
            "Tắt App", systemImage: "xmark",
            action: {
              NSApp.terminate(nil)
            }
          )
          .controlSize(.large)
        }

      }
    }.frame(width: 520, height: 400)
  }
}

struct UpgradeAppView_Previews: PreviewProvider {
  static var previews: some View {
    UpgradeAppView()
      .environmentObject(AppState())
      .previewLayout(PreviewLayout.sizeThatFits)
      .padding()
      .previewDisplayName("UpgradeAppView preview")
  }
}
