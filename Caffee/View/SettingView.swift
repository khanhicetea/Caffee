import Defaults
import KeyboardShortcuts
import LaunchAtLogin
import SwiftUI

/// Root of the Settings window: one tab per area.
struct SettingsRootView: View {
  var body: some View {
    TabView {
      GeneralView()
        .tabItem { Label("Chung", systemImage: "gearshape") }
      TypingSettingsView()
        .tabItem { Label("Kiểu gõ", systemImage: "keyboard") }
      AppsSettingsView()
        .tabItem { Label("Ứng dụng", systemImage: "square.grid.2x2") }
      AdvancedSettingsView()
        .tabItem { Label("Nâng cao", systemImage: "wrench.and.screwdriver") }
      AboutSettingsView()
        .tabItem { Label("Giới thiệu", systemImage: "info.circle") }
    }
    .frame(width: 520)
  }
}

struct GeneralView: View {
  @Environment(AppState.self) var appState
  @Default(.checkForUpdatesAutomatically) var checkForUpdatesAutomatically
  @Default(.showModeHUD) var showModeHUD

  var body: some View {
    @Bindable var appState = appState
    Form {
      Section {
        Toggle("Gõ tiếng Việt", isOn: $appState.enabled)
        KeyboardShortcuts.Recorder("Phím tắt bật/tắt", name: .toggleInputMode)
        Toggle("Hiện chữ V/E khi đổi chế độ", isOn: $showModeHUD)
          .help("Hiện nhanh chữ V hoặc E giữa màn hình khi chuyển giữa tiếng Việt và tiếng Anh.")
      }

      Section {
        LaunchAtLogin.Toggle("Mở khi khởi động Mac")
        Toggle("Tự động kiểm tra cập nhật", isOn: $checkForUpdatesAutomatically)
      }
    }
    .formStyle(.grouped)
    .fixedSize(horizontal: false, vertical: true)
  }
}

struct TypingSettingsView: View {
  @Environment(AppState.self) var appState

  var body: some View {
    @Bindable var appState = appState
    Form {
      Section {
        Picker("Kiểu gõ", selection: $appState.typingMethod) {
          ForEach(TypingMethods.allCases, id: \.self) { method in
            Text(method.rawValue).tag(method)
          }
        }
        .pickerStyle(.segmented)
      }

      Section {
        Picker("Vị trí dấu thanh", selection: $appState.tonePlacement) {
          Text("hòa, thủy, khỏe").tag(TonePlacement.firstVowel)
          Text("hoà, thuỷ, khoẻ").tag(TonePlacement.secondVowel)
        }
        .help("Đặt dấu thanh ở nguyên âm đầu hay nguyên âm sau trong oa, oe, uy.")

        Toggle("Kiểm tra chính tả", isOn: $appState.spellingCheck)
          .help(
            "Tự trả về chữ gốc khi từ không phải tiếng Việt (ví dụ \"window\"). Tắt để luôn áp dụng dấu."
          )

        Toggle("Cho phép phụ âm ngoại lai (z, w, j, f)", isOn: $appState.allowedZWJF)
          .help(
            "Cho phép gõ các từ như \"zalo\", \"wifi\", \"jack\", \"fan\" mà không bị hoàn tác.")
      }
    }
    .formStyle(.grouped)
    .fixedSize(horizontal: false, vertical: true)
  }
}

struct AboutSettingsView: View {
  private let appVersion = Bundle.main.appVersionLong

  var body: some View {
    VStack(spacing: 6) {
      Image("Cficon")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 12))
      Text("Caffee \(appVersion)")
        .font(.headline)
      Text(
        "Không có tính năng gì ngoài gõ tiếng Việt!\nPhát triển bởi [KhanhIceTea](https://khanhicetea.com)."
      )
      .multilineTextAlignment(.center)
      .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 32)
  }
}

struct GeneralView_Previews: PreviewProvider {
  static var previews: some View {
    SettingsRootView()
      .environment(AppState())
      .previewDisplayName("Settings preview")
  }
}
