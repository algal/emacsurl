import XCTest

@testable import EmacsURL

final class EmacsClientArgumentsTests: XCTestCase {
  func testNewFrameIsTheDefault() {
    XCTAssertEqual(AppConfiguration.default.frameBehavior, .newFrame)
  }

  func testBuildsNewFrameArguments() throws {
    let request = try request(
      "emacs-file:/ssh:box:~/project/main.py?line=47&column=3"
    )

    XCTAssertEqual(
      EmacsClientArguments.make(
        for: request,
        frameBehavior: .newFrame
      ),
      [
        "--no-wait",
        "--create-frame",
        "--",
        "+47:3",
        "/ssh:box:~/project/main.py",
      ]
    )
  }

  func testCanSwitchToFrameReuseWithoutChangingRequestLogic() throws {
    let request = try request("emacs-file:/tmp/foo")

    XCTAssertEqual(
      EmacsClientArguments.make(
        for: request,
        frameBehavior: .reuseExistingOrCreate
      ),
      [
        "--no-wait",
        "--reuse-frame",
        "--",
        "/tmp/foo",
      ]
    )
  }

  func testBuildsLineWithoutColumn() throws {
    let request = try request("emacs-file:/tmp/foo?line=12")

    XCTAssertEqual(
      EmacsClientArguments.make(
        for: request,
        frameBehavior: .newFrame
      ),
      [
        "--no-wait",
        "--create-frame",
        "--",
        "+12",
        "/tmp/foo",
      ]
    )
  }

  func testClientAcceptsSuccessfulProcessExit() async throws {
    let client = EmacsClient(
      locator: EmacsClientLocator(candidatePaths: ["/usr/bin/true"]),
      processRunner: EmacsClientProcessRunner()
    )

    try await client.open(
      request("emacs-file:/tmp/foo"),
      frameBehavior: .newFrame
    )
  }

  func testClientReportsFailedProcessExit() async throws {
    let client = EmacsClient(
      locator: EmacsClientLocator(candidatePaths: ["/usr/bin/false"]),
      processRunner: EmacsClientProcessRunner()
    )

    do {
      try await client.open(
        request("emacs-file:/tmp/foo"),
        frameBehavior: .newFrame
      )
      XCTFail("Expected the client process to fail")
    } catch let error as HandlerError {
      XCTAssertEqual(error, .clientFailed(1, ""))
    }
  }

  private func request(_ string: String) throws -> EmacsRequest {
    try EmacsRequest(url: XCTUnwrap(URL(string: string)))
  }
}
