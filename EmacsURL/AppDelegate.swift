import AppKit
import OSLog

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

  func open(_ url: URL) async {
    do {
      let request = try EmacsRequest(url: url)
      try await client.open(
        request,
        frameBehavior: configuration.frameBehavior
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
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let coordinator = OpenCoordinator(configuration: .default)

  func application(
    _ application: NSApplication,
    open urls: [URL]
  ) {
    for url in urls {
      Task { [coordinator] in
        await coordinator.open(url)
      }
    }
  }
}
