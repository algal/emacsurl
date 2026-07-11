import Foundation

struct EmacsRequest: Equatable, Sendable {
  static let maximumFilenameLength = 16 * 1024
  static let maximumPosition = Int(Int32.max)

  let filename: String
  let line: Int?
  let column: Int?

  init(url: URL) throws {
    guard
      let components = URLComponents(
        url: url,
        resolvingAgainstBaseURL: false
      ),
      components.scheme?.lowercased() == "emacs-file"
    else {
      throw HandlerError.unsupportedScheme
    }

    guard
      components.user == nil,
      components.password == nil,
      components.host == nil,
      components.port == nil
    else {
      throw HandlerError.unexpectedAuthority
    }

    guard components.fragment == nil else {
      throw HandlerError.unexpectedFragment
    }

    let filename = components.path
    guard !filename.isEmpty else {
      throw HandlerError.missingFilename
    }

    guard filename.hasPrefix("/") || filename.hasPrefix("~") else {
      throw HandlerError.relativeFilename
    }

    guard !filename.unicodeScalars.contains(where: { $0.value == 0 }) else {
      throw HandlerError.invalidFilename
    }

    guard filename.utf8.count <= Self.maximumFilenameLength else {
      throw HandlerError.filenameTooLong
    }

    let parameters = try Self.parameters(from: components.queryItems ?? [])
    let line = try Self.positiveInteger(named: "line", in: parameters)
    let column = try Self.positiveInteger(named: "column", in: parameters)

    guard column == nil || line != nil else {
      throw HandlerError.columnRequiresLine
    }

    self.filename = filename
    self.line = line
    self.column = column
  }

  private static func parameters(
    from items: [URLQueryItem]
  ) throws -> [String: String?] {
    var result: [String: String?] = [:]

    for item in items {
      guard item.name == "line" || item.name == "column" else {
        throw HandlerError.unsupportedParameter(item.name)
      }

      guard result[item.name] == nil else {
        throw HandlerError.duplicateParameter(item.name)
      }

      result[item.name] = .some(item.value)
    }

    return result
  }

  private static func positiveInteger(
    named name: String,
    in parameters: [String: String?]
  ) throws -> Int? {
    guard let wrappedValue = parameters[name] else {
      return nil
    }

    guard
      let value = wrappedValue,
      !value.isEmpty,
      value.utf8.allSatisfy({ (48...57).contains($0) }),
      let number = Int(value),
      (1...maximumPosition).contains(number)
    else {
      throw name == "line" ? HandlerError.invalidLine : HandlerError.invalidColumn
    }

    return number
  }
}
