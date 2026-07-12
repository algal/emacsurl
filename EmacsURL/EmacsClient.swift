import Foundation

struct EmacsClientArguments {
  static func make(
    for request: EmacsRequest,
    frameBehavior: FrameBehavior
  ) -> [String] {
    var arguments = ["--no-wait"]
    arguments.append(contentsOf: frameBehavior.emacsClientArguments)
    arguments.append("--")

    if let line = request.line {
      if let column = request.column {
        arguments.append("+\(line):\(column)")
      } else {
        arguments.append("+\(line)")
      }
    }

    arguments.append(request.filename)
    return arguments
  }
}

struct EmacsClientLocator: Sendable {
  let candidatePaths: [String]

  func locate() throws -> URL {
    for path in candidatePaths
    where FileManager.default.isExecutableFile(atPath: path) {
      return URL(fileURLWithPath: path)
    }

    throw HandlerError.clientNotFound
  }
}

struct ProcessResult: Sendable {
  let terminationStatus: Int32
  let standardError: String
}

struct EmacsClientProcessRunner: Sendable {
  func run(
    executableURL: URL,
    arguments: [String]
  ) async throws -> ProcessResult {
    try await withCheckedThrowingContinuation { continuation in
      DispatchQueue.global(qos: .userInitiated).async {
        let process = Process()
        let standardError = Pipe()

        process.executableURL = executableURL
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = standardError

        do {
          try process.run()

          // Drain while the child runs so a full pipe cannot block it.
          let errorData = standardError.fileHandleForReading.readDataToEndOfFile()
          process.waitUntilExit()

          continuation.resume(
            returning: ProcessResult(
              terminationStatus: process.terminationStatus,
              standardError: String(decoding: errorData, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            )
          )
        } catch {
          continuation.resume(
            throwing: HandlerError.processLaunchFailed(
              error.localizedDescription
            )
          )
        }
      }
    }
  }
}

struct EmacsClient: Sendable {
  let locator: EmacsClientLocator
  let processRunner: EmacsClientProcessRunner

  func open(
    _ request: EmacsRequest,
    frameBehavior: FrameBehavior
  ) async throws {
    let executableURL = try locator.locate()
    let arguments = EmacsClientArguments.make(
      for: request,
      frameBehavior: frameBehavior
    )
    let result = try await processRunner.run(
      executableURL: executableURL,
      arguments: arguments
    )

    guard result.terminationStatus == 0 else {
      throw HandlerError.clientFailed(
        result.terminationStatus,
        String(result.standardError.prefix(4_096))
      )
    }
  }
}
