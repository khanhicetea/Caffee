import AppKit

// CaffeeApp is the main entry point of the application.
@main
struct CaffeeApp {

  // The main function sets up the application delegate and starts the main event loop.
  static func main() {
    // Initialize the AppDelegate which will manage the application lifecycle.

    let appDelegate = AppDelegate()

    // Get the shared NSApplication instance and set the delegate.
    let app = NSApplication.shared
    app.delegate = appDelegate

    // Set the application activation policy to accessory.
    // This means the app doesn't appear in the Dock or Force Quit window.
    app.setActivationPolicy(.accessory)

    // Start the main event loop of the application.
    _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
  }
}
