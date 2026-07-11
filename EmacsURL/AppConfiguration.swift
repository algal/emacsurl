import Foundation

enum FrameBehavior: Equatable, Sendable {
  case newFrame
  case reuseExistingOrCreate

  var emacsClientArgument: String {
    switch self {
    case .newFrame:
      "--create-frame"
    case .reuseExistingOrCreate:
      "--reuse-frame"
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
