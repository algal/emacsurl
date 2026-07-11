import SwiftUI

@main
struct EmacsURLApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self)
  private var appDelegate

  var body: some Scene {
    Settings {
      EmptyView()
    }
  }
}
