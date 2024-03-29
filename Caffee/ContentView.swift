import SwiftUI

@available(macOS 12.0, *)
struct ContentView: View {
  var telex = Telex()

  @State private var str = "Hello"
  @FocusState private var isFocused: Bool

  var body: some View {
    TextField(
      "Enter the text",
      text: $str
    )
    .focused($isFocused)
    .onTapGesture { isFocused = true }
    .border(.black)
    .font(.title)
    Text(telex.transform_text(for: str))
      .font(.title)
      .padding(16)
  }
}
