import Foundation

enum HandlerError: Error, Equatable, LocalizedError, Sendable {
  case unsupportedScheme
  case unexpectedAuthority
  case unexpectedFragment
  case missingFilename
  case relativeFilename
  case invalidFilename
  case filenameTooLong
  case unsupportedParameter(String)
  case duplicateParameter(String)
  case invalidLine
  case invalidColumn
  case columnRequiresLine
  case clientNotFound
  case processLaunchFailed(String)
  case clientFailed(Int32, String)

  var errorDescription: String? {
    switch self {
    case .unsupportedScheme:
      "The URL does not use the emacs-file scheme."
    case .unexpectedAuthority:
      "An emacs-file URL must contain an Emacs filename, not a URL host."
    case .unexpectedFragment:
      "Fragments are not supported in emacs-file URLs."
    case .missingFilename:
      "The URL contains no Emacs filename."
    case .relativeFilename:
      "Bare relative filenames are unsupported because their base directory is unknown."
    case .invalidFilename:
      "The URL contains an invalid Emacs filename."
    case .filenameTooLong:
      "The Emacs filename is too long."
    case .unsupportedParameter(let name):
      "The URL contains the unsupported parameter ‘\(name)’."
    case .duplicateParameter(let name):
      "The URL contains more than one ‘\(name)’ parameter."
    case .invalidLine:
      "The line parameter must be a positive decimal integer."
    case .invalidColumn:
      "The column parameter must be a positive decimal integer."
    case .columnRequiresLine:
      "A column parameter requires a line parameter."
    case .clientNotFound:
      "No emacsclient executable was found."
    case .processLaunchFailed(let message):
      "Unable to launch emacsclient: \(message)"
    case .clientFailed(let status, let message):
      message.isEmpty
        ? "emacsclient exited with status \(status)."
        : "emacsclient exited with status \(status): \(message)"
    }
  }
}
