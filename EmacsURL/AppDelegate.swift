import AppKit
import OSLog
import SwiftUI

actor OpenCoordinator {
  private let configuration: AppConfiguration
  private let client: EmacsClient
  private let logger = Logger(
    subsystem: "com.alexisgallagher.EmacsURL",
    category: "URLHandling"
  )

  init(configuration: AppConfiguration) {
    self.configuration = configuration
    client = EmacsClient(
      locator: EmacsClientLocator(
        candidatePaths: configuration.emacsClientCandidatePaths
      ),
      processRunner: EmacsClientProcessRunner()
    )
  }

  func open(_ url: URL, frameBehavior: FrameBehavior) async {
    do {
      let request = try EmacsRequest(url: url)
      try await client.open(
        request,
        frameBehavior: frameBehavior
      )
      await EmacsActivator.activate(
        bundleIdentifier: configuration.emacsBundleIdentifier
      )
    } catch {
      logger.error("Failed to handle an emacs-file URL")
      await ErrorPresenter.present(error)
    }
  }
}

@MainActor
enum EmacsActivator {
  static func activate(bundleIdentifier: String) {
    guard
      let application =
        NSRunningApplication
        .runningApplications(withBundleIdentifier: bundleIdentifier)
        .first
    else {
      return
    }

    if NSApp.isActive {
      NSApp.yieldActivation(to: application)
    }
    application.activate()
  }
}

@MainActor
enum ErrorPresenter {
  static func present(_ error: Error) {
    NSApp.activate()

    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = "EmacsURL could not open the file"
    alert.informativeText = error.localizedDescription
    alert.runModal()
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
  private let configuration = AppConfiguration.default
  private let settings = SettingsStore.shared
  private lazy var coordinator = OpenCoordinator(configuration: configuration)
  private var statusWindowController: NSWindowController?

  // MARK: URL handling

  func application(
    _ application: NSApplication,
    open urls: [URL]
  ) {
    let frameBehavior = settings.frameBehavior
    for url in urls {
      Task { [coordinator] in
        await coordinator.open(url, frameBehavior: frameBehavior)
      }
    }
  }

  // MARK: Status window

  func applicationDidFinishLaunching(_ notification: Notification) {
    // Show the window only for a plain launch (Finder double-click, `open` with
    // no URL). A launch triggered by an emacs-file: URL stays headless.
    let isDefaultLaunch =
      notification.userInfo?[NSApplication.launchIsDefaultUserInfoKey] as? Bool
      ?? true
    if isDefaultLaunch {
      showStatusWindow()
    }
  }

  func applicationShouldHandleReopen(
    _ sender: NSApplication,
    hasVisibleWindows flag: Bool
  ) -> Bool {
    // Re-opening the app from Finder/Spotlight is how the user reaches the
    // window again — and quits the helper — when it is running headless.
    showStatusWindow()
    return true
  }

  func applicationShouldTerminateAfterLastWindowClosed(
    _ sender: NSApplication
  ) -> Bool {
    // Closing the status window returns to the background; it must not quit.
    false
  }

  private func showStatusWindow() {
    if statusWindowController == nil {
      let view = StatusView(
        settings: settings,
        checker: StatusChecker(
          candidatePaths: configuration.emacsClientCandidatePaths
        ),
        quit: { NSApp.terminate(nil) }
      )
      let window = NSWindow(contentViewController: NSHostingController(rootView: view))
      window.title = "EmacsURL"
      window.styleMask = [.titled, .closable]
      window.isReleasedWhenClosed = false
      window.delegate = self
      window.center()
      statusWindowController = NSWindowController(window: window)
    }

    // Become a regular app while the window is visible so it takes focus and
    // appears in Cmd-Tab; drop back to an agent when it closes.
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
    statusWindowController?.showWindow(nil)
    statusWindowController?.window?.makeKeyAndOrderFront(nil)
  }

  func windowWillClose(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
  }
}
