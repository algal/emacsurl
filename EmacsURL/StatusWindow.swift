import SwiftUI

/// Persisted user preferences. The frame behavior used to be a source-code
/// constant in `AppConfiguration`; it now lives here so the status window can
/// change it at runtime, and `AppDelegate` reads it when handling a URL.
@MainActor
final class SettingsStore: ObservableObject {
  static let shared = SettingsStore()

  private enum Key {
    static let frameBehavior = "frameBehavior"
  }

  @Published var frameBehavior: FrameBehavior {
    didSet { defaults.set(frameBehavior.rawValue, forKey: Key.frameBehavior) }
  }

  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    if let raw = defaults.string(forKey: Key.frameBehavior),
      let stored = FrameBehavior(rawValue: raw) {
      frameBehavior = stored
    } else {
      frameBehavior = AppConfiguration.default.frameBehavior
    }
  }
}

/// A read-only snapshot of whether the helper can currently reach Emacs.
struct EmacsStatus: Sendable, Equatable {
  enum Reachability: Sendable, Equatable {
    case checking
    case reachable
    case unreachable
    case clientNotFound
  }

  var clientPath: String?
  var reachability: Reachability

  static let initial = EmacsStatus(clientPath: nil, reachability: .checking)
}

/// Probes for `emacsclient` and whether an Emacs server answers, without any
/// side effects — in particular it never starts a daemon.
struct StatusChecker: Sendable {
  let candidatePaths: [String]

  func check() async -> EmacsStatus {
    guard let clientPath = locateClient() else {
      return EmacsStatus(clientPath: nil, reachability: .clientNotFound)
    }
    let reachable = await pingServer(clientPath: clientPath)
    return EmacsStatus(
      clientPath: clientPath,
      reachability: reachable ? .reachable : .unreachable
    )
  }

  private func locateClient() -> String? {
    candidatePaths.first {
      FileManager.default.isExecutableFile(atPath: $0)
    }
  }

  private func pingServer(clientPath: String) async -> Bool {
    await withCheckedContinuation { continuation in
      DispatchQueue.global(qos: .userInitiated).async {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: clientPath)
        // No --alternate-editor: a status check must never spawn a daemon.
        process.arguments = ["--eval", "t"]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        // Scrub ALTERNATE_EDITOR so an empty value inherited from the
        // environment cannot turn this read-only probe into a daemon launch.
        var environment = ProcessInfo.processInfo.environment
        environment.removeValue(forKey: "ALTERNATE_EDITOR")
        process.environment = environment

        do {
          try process.run()
          process.waitUntilExit()
          continuation.resume(returning: process.terminationStatus == 0)
        } catch {
          continuation.resume(returning: false)
        }
      }
    }
  }
}

/// The contents of the status window shown on a manual launch. Confirms the
/// helper is installed and running, surfaces Emacs reachability, exposes the
/// frame-behavior preference, and offers a way to quit.
struct StatusView: View {
  @ObservedObject var settings: SettingsStore
  let checker: StatusChecker
  let quit: () -> Void

  @State private var status = EmacsStatus.initial
  @State private var isChecking = false

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      header
      Divider()
      statusSection
      Divider()
      framePreference
      Divider()
      footer
    }
    .padding(20)
    .frame(width: 400)
    .task { await refresh() }
  }

  private var header: some View {
    HStack(spacing: 12) {
      Image(nsImage: NSApp.applicationIconImage)
        .resizable()
        .frame(width: 52, height: 52)
      VStack(alignment: .leading, spacing: 2) {
        Text("EmacsURL").font(.headline)
        Text("Opening emacs-file: links in Emacs")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
    }
  }

  private var statusSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Circle()
          .fill(indicatorColor)
          .frame(width: 10, height: 10)
        Text(statusHeadline).fontWeight(.medium)
        Spacer()
        if isChecking {
          ProgressView().controlSize(.small)
        } else {
          Button("Refresh") { Task { await refresh() } }
            .controlSize(.small)
        }
      }
      Text(clientDetail)
        .font(.callout)
        .foregroundStyle(.secondary)
        .textSelection(.enabled)
    }
  }

  private var framePreference: some View {
    VStack(alignment: .leading, spacing: 6) {
      Picker("When opening a file:", selection: $settings.frameBehavior) {
        Text("Open in a new frame").tag(FrameBehavior.newFrame)
        Text("Reuse an existing frame").tag(FrameBehavior.reuseExistingOrCreate)
      }
      .pickerStyle(.radioGroup)
    }
  }

  private var footer: some View {
    HStack {
      Text("Runs in the background; no Dock icon.")
        .font(.footnote)
        .foregroundStyle(.tertiary)
      Spacer()
      Button("Quit EmacsURL") { quit() }
        .keyboardShortcut("q")
    }
  }

  private var indicatorColor: Color {
    switch status.reachability {
    case .checking: .secondary
    case .reachable: .green
    case .unreachable: .orange
    case .clientNotFound: .red
    }
  }

  private var statusHeadline: String {
    switch status.reachability {
    case .checking: "Checking Emacs…"
    case .reachable: "Emacs server is reachable"
    case .unreachable: "Emacs server not responding"
    case .clientNotFound: "emacsclient not found"
    }
  }

  private var clientDetail: String {
    switch status.reachability {
    case .checking:
      "Looking for emacsclient and a running server…"
    case .reachable:
      "emacsclient: \(status.clientPath ?? "—")"
    case .unreachable:
      "emacsclient: \(status.clientPath ?? "—")\nStart a server with (server-start) in Emacs."
    case .clientNotFound:
      "Install Emacs, or add emacsclient to a searched path."
    }
  }

  private func refresh() async {
    isChecking = true
    status = await checker.check()
    isChecking = false
  }
}
