import Foundation

enum FrameBehavior: String, CaseIterable, Equatable, Sendable {
  case newFrame
  case reuseExistingOrCreate

  /// The frame-related arguments to pass to `emacsclient`.
  ///
  /// `--create-frame` forces a new frame. For reuse we deliberately pass *no*
  /// frame flag: emacsclient's default is to visit the file in the currently
  /// selected frame, which reliably reuses an existing one. `--reuse-frame`
  /// (`-r`) looks correct but, on the macOS NS build, creates a new frame when
  /// the client has no associated display — which is exactly our case.
  var emacsClientArguments: [String] {
    switch self {
    case .newFrame:
      ["--create-frame"]
    case .reuseExistingOrCreate:
      []
    }
  }
}

struct AppConfiguration: Sendable {
  let frameBehavior: FrameBehavior
  let emacsBundleIdentifier: String
  let emacsClientCandidatePaths: [String]

  static let `default` = AppConfiguration(
    // Change this one value if regular use shows that frame reuse is better UX.
    frameBehavior: .newFrame,
    emacsBundleIdentifier: "org.gnu.Emacs",
    emacsClientCandidatePaths: [
      "/Applications/Emacs.app/Contents/MacOS/bin/emacsclient",
      "/opt/homebrew/bin/emacsclient",
      "/usr/local/bin/emacsclient",
    ]
  )
}
