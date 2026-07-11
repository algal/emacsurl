import XCTest

@testable import EmacsURL

final class EmacsRequestTests: XCTestCase {
  func testParsesTRAMPFilenameLiterally() throws {
    let request = try request(
      "emacs-file:/ssh:box:~/gits/stackchan/main.py"
    )

    XCTAssertEqual(request.filename, "/ssh:box:~/gits/stackchan/main.py")
    XCTAssertNil(request.line)
    XCTAssertNil(request.column)
  }

  func testParsesLocalFilename() throws {
    let request = try request(
      "emacs-file:/Users/alexis/notes%20and%20drafts/idea.md"
    )

    XCTAssertEqual(
      request.filename,
      "/Users/alexis/notes and drafts/idea.md"
    )
  }

  func testParsesHomeRelativeFilename() throws {
    XCTAssertEqual(
      try request("emacs-file:~/notes/idea.md").filename,
      "~/notes/idea.md"
    )
  }

  func testParsesLineAndColumn() throws {
    let request = try request(
      "emacs-file:/tmp/foo.py?line=47&column=3"
    )

    XCTAssertEqual(request.line, 47)
    XCTAssertEqual(request.column, 3)
  }

  func testDecodesReservedFilenameCharactersOnce() throws {
    let request = try request(
      "emacs-file:/tmp/a%20b%23c%3Fd%25e.txt"
    )

    XCTAssertEqual(request.filename, "/tmp/a b#c?d%e.txt")
  }

  func testRejectsWrongScheme() {
    assertError("emacs:/tmp/foo", equals: .unsupportedScheme)
  }

  func testRejectsAuthority() {
    assertError(
      "emacs-file://box/tmp/foo",
      equals: .unexpectedAuthority
    )
  }

  func testRejectsBareRelativeFilename() {
    assertError(
      "emacs-file:project/main.py",
      equals: .relativeFilename
    )
  }

  func testRejectsColumnWithoutLine() {
    assertError(
      "emacs-file:/tmp/foo?column=3",
      equals: .columnRequiresLine
    )
  }

  func testRejectsInvalidPositionValues() {
    assertError("emacs-file:/tmp/foo?line=0", equals: .invalidLine)
    assertError("emacs-file:/tmp/foo?line=-1", equals: .invalidLine)
    assertError("emacs-file:/tmp/foo?line=x", equals: .invalidLine)
    assertError(
      "emacs-file:/tmp/foo?line=1&column=0",
      equals: .invalidColumn
    )
  }

  func testRejectsDuplicateAndUnknownParameters() {
    assertError(
      "emacs-file:/tmp/foo?line=1&line=2",
      equals: .duplicateParameter("line")
    )
    assertError(
      "emacs-file:/tmp/foo?frame=reuse",
      equals: .unsupportedParameter("frame")
    )
  }

  func testRejectsFragment() {
    assertError(
      "emacs-file:/tmp/foo#section",
      equals: .unexpectedFragment
    )
  }

  func testRejectsNUL() {
    assertError(
      "emacs-file:/tmp/foo%00bar",
      equals: .invalidFilename
    )
  }

  private func request(_ string: String) throws -> EmacsRequest {
    let url = try XCTUnwrap(URL(string: string))
    return try EmacsRequest(url: url)
  }

  private func assertError(
    _ string: String,
    equals expectedError: HandlerError,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertThrowsError(
      try request(string),
      file: file,
      line: line
    ) { error in
      XCTAssertEqual(
        error as? HandlerError,
        expectedError,
        file: file,
        line: line
      )
    }
  }
}
