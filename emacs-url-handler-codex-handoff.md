# Emacs URL Handler for macOS — Codex Handoff

> Historical design handoff. The implemented and current contract is documented
> in `README.md`. In particular, the final scheme is `emacs-file`, and the
> canonical syntax is `emacs-file:<emacs-filename>` rather than the earlier
> `emacs://open?path=...` proposal retained below for design history.

## Goal

Build a small native macOS helper app that owns a custom URL scheme, extracts an Emacs filename—especially a TRAMP path such as:

```text
/ssh:box:~/gits/stackchan/
```

—and opens it in GUI Emacs through `emacsclient`.

The intended workflow is:

```text
custom URL
    ↓
macOS Launch Services
    ↓
small native URL-handler app
    ↓
decode Emacs filename
    ↓
invoke emacsclient safely
    ↓
open path in GUI Emacs
```

The app should be simple, focused, modern, and reliable.

---

## Context and decisions already made

### Do not use Hammerspoon

Hammerspoon was considered as a generic URL-to-command bridge, but rejected.

Reason:

- prior direct experience found it poorly maintained and somewhat unreliable;
- this task is narrow enough that a native helper is preferable;
- Xcode is available;
- implementation cost is now low enough that inheriting a general-purpose automation framework is not attractive.

### Do not revive the old EmacsHandler codebase literally

There is an old project:

- EmacsHandler: https://github.com/typester/emacs-handler

Its conceptual contract is useful:

```text
emacs://...
    ↓
parse URL
    ↓
call emacsclient
```

But the project is from the macOS 10.5/10.6 era and should be treated as historical reference, not a foundation.

### Do not fork EmacsOpen as the main architecture

There is a newer project:

- EmacsOpen: https://github.com/mbhutton/EmacsOpen

Assessment:

- it is a real Swift/Xcode codebase, not merely a sketch;
- it has substantial work around `emacsclient`, frame opening, Emacs activation, daemon behavior, CLI support, Finder integration, and broader macOS/Emacs lifecycle concerns;
- it declares itself pre-alpha;
- it has no stable releases;
- a generic `emacs://` URL handler is apparently still a roadmap item rather than the central completed feature;
- its scope is much broader than this project.

Decision:

> Build a new small app. Use EmacsOpen only as a reference for macOS-specific details such as locating `emacsclient`, activating Emacs, and handling daemon/frame state.

Do not fork unless later inspection reveals an unexpectedly clean reusable subsystem.

### Emacs Client.app is also reference material, not the foundation

The Emacs Plus project includes an `Emacs Client.app`:

- https://github.com/d12frosted/homebrew-emacs-plus
- relevant documentation is under `docs/emacs-client-app.md`

It is useful precedent for:

- invoking `emacsclient`;
- locating bundled binaries;
- activating GUI Emacs;
- receiving macOS open events;
- handling modern macOS app-launch behavior.

But it does not directly provide the desired generic TRAMP-aware custom URL contract.

### Build from scratch

The narrow requirement is approximately:

```text
URL registration
URL parsing
typed request
emacsclient invocation
Emacs activation
small settings surface
tests
```

This is likely only a few hundred lines of Swift plus tests.

The main architectural advantage is exact scope, not sophistication.

---

## Version 1 scope

Version 1 should:

1. Register a custom URL scheme, preferably `emacs`.
2. Accept an encoded Emacs filename in a query parameter.
3. Preserve TRAMP syntax exactly after URL decoding.
4. Optionally accept line and column numbers.
5. Invoke `emacsclient` directly using `Process`, never through a shell.
6. Create a GUI frame.
7. Return immediately rather than waiting for the file visit to finish.
8. Activate GUI Emacs if appropriate.
9. Report errors through logging and optionally a native alert.
10. Include unit tests for URL parsing and argument construction.

Version 1 should **not** try to become a general Emacs lifecycle manager.

In particular, daemon startup may be deferred.

Initial contract:

> A usable Emacs server is already running.

That means the simplest initial invocation is:

```bash
emacsclient --no-wait --create-frame PATH
```

Daemon auto-start can be added later if desired.

---

## Canonical URL contract

Use an explicit query parameter rather than trying to encode TRAMP syntax directly as a hierarchical URL path.

Canonical form:

```text
emacs://open?path=<percent-encoded-emacs-filename>
```

Example Emacs filename:

```text
/ssh:box:~/gits/stackchan/
```

Canonical encoded URL:

```text
emacs://open?path=%2Fssh%3Abox%3A~%2Fgits%2Fstackchan%2F
```

Optional line and column:

```text
emacs://open?path=%2Fssh%3Abox%3A~%2Fgits%2Fstackchan%2Fmain.py&line=47&column=3
```

Decoded request:

```text
path   = /ssh:box:~/gits/stackchan/main.py
line   = 47
column = 3
```

### Why query parameters

TRAMP filenames contain syntax such as:

```text
/ssh:box:~/...
```

That syntax is meaningful to Emacs, not to a generic URL parser.

Using a `path=` query parameter gives a clear boundary:

```text
URL parser decodes one string
Emacs interprets that string as a filename
```

Do not attempt to fully parse or validate TRAMP grammar in the helper.

Emacs is the authority on Emacs filename syntax.

---

## Security requirements

The URL handler is an externally reachable input boundary.

### Never use a shell

Do not do this:

```swift
/bin/sh -c "emacsclient ..."
```

Do this:

```swift
let process = Process()
process.executableURL = ...
process.arguments = [...]
```

The Emacs filename must be passed as one process argument.

This avoids:

- shell injection;
- quoting bugs;
- spaces and apostrophe issues;
- accidental interpretation of `$`, backticks, semicolons, or redirections.

### Minimal validation

Reasonable validation:

- scheme must be `emacs`;
- action/host must be `open` or absent if a fallback syntax is later supported;
- `path` must exist as a query parameter;
- decoded path must be nonempty;
- reject NUL characters;
- impose a sane maximum length;
- line and column must be positive integers;
- perhaps reject absurd line/column sizes.

Do not attempt to validate all legitimate Emacs or TRAMP filenames.

### Host allowlist

A TRAMP hostname allowlist is probably unnecessary unless links will frequently come from untrusted web pages.

It can be added later as an optional policy feature.

---

## Suggested Xcode project

Create:

```text
macOS → App
Language: Swift
Interface: SwiftUI or AppKit
```

A SwiftUI app template is acceptable even though the app has no main visible window.

Suggested product name:

```text
EmacsURL
```

Possible bundle identifier:

```text
com.alexisgallagher.EmacsURL
```

The app should behave as an accessory/background app.

Set:

```xml
<key>LSUIElement</key>
<true/>
```

This removes the normal Dock presence.

---

## URL scheme registration

Add the following to `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.alexisgallagher.emacs-url</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>emacs</string>
        </array>
    </dict>
</array>
```

The app must be built and launched or installed so Launch Services sees the registration.

Initial manual test:

```bash
open 'emacs://open?path=%2Fssh%3Abox%3A~%2Fgits%2Fstackchan%2F'
```

---

## Suggested source layout

```text
EmacsURL/
├── EmacsURLApp.swift
├── AppDelegate.swift
├── EmacsRequest.swift
├── EmacsClient.swift
├── EmacsClientLocator.swift
├── EmacsActivator.swift
├── SettingsView.swift          # optional for v1
└── Tests/
    ├── EmacsRequestTests.swift
    ├── EmacsArgumentTests.swift
    └── EmacsClientLocatorTests.swift
```

---

## Minimal app entry point

```swift
import SwiftUI

@main
struct EmacsURLApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
```

A Settings scene can later expose configuration.

---

## URL receiving

Use the macOS application delegate:

```swift
import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(
        _ application: NSApplication,
        open urls: [URL]
    ) {
        for url in urls {
            do {
                let request = try EmacsRequest(url: url)
                try EmacsClient.shared.open(request)
            } catch {
                NSLog(
                    "Failed to handle %@: %@",
                    url.absoluteString,
                    error.localizedDescription
                )
            }
        }
    }
}
```

Possible refinement:

- present a native alert for user-actionable errors;
- log silently for malformed URLs;
- process multiple URLs in one `emacsclient` invocation if useful.

---

## Typed request model

Suggested request type:

```swift
import Foundation

struct EmacsRequest: Equatable {
    let path: String
    let line: Int?
    let column: Int?

    init(url: URL) throws {
        guard url.scheme?.lowercased() == "emacs" else {
            throw HandlerError.unsupportedScheme
        }

        guard url.host == "open" || url.host == nil else {
            throw HandlerError.unsupportedAction
        }

        guard let components = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
        ) else {
            throw HandlerError.invalidURL
        }

        let items = components.queryItems ?? []

        guard
            let path = items.first(where: { $0.name == "path" })?.value,
            !path.isEmpty
        else {
            throw HandlerError.missingPath
        }

        guard !path.contains("\0") else {
            throw HandlerError.invalidPath
        }

        self.path = path
        self.line = Self.positiveInteger(named: "line", in: items)
        self.column = Self.positiveInteger(named: "column", in: items)
    }

    private static func positiveInteger(
        named name: String,
        in items: [URLQueryItem]
    ) -> Int? {
        guard
            let value = items.first(where: { $0.name == name })?.value,
            let number = Int(value),
            number > 0
        else {
            return nil
        }

        return number
    }
}
```

Suggested error enum:

```swift
enum HandlerError: LocalizedError {
    case unsupportedScheme
    case unsupportedAction
    case invalidURL
    case missingPath
    case invalidPath
    case invalidClientPath
    case clientFailed(Int32, String)

    var errorDescription: String? {
        switch self {
        case .unsupportedScheme:
            return "Unsupported URL scheme."
        case .unsupportedAction:
            return "Unsupported Emacs URL action."
        case .invalidURL:
            return "Malformed URL."
        case .missingPath:
            return "The URL contains no Emacs path."
        case .invalidPath:
            return "The URL contains an invalid Emacs path."
        case .invalidClientPath:
            return "The configured emacsclient executable does not exist."
        case let .clientFailed(status, message):
            return "emacsclient failed with status \(status): \(message)"
        }
    }
}
```

Important design principle:

```text
URL → EmacsRequest → emacsclient arguments
```

Keep parsing separate from process invocation.

---

## `emacsclient` invocation

Basic arguments:

```text
--no-wait
--create-frame
PATH
```

Optional line/column argument:

```text
+LINE:COLUMN
```

Example:

```bash
emacsclient \
  --no-wait \
  --create-frame \
  +47:3 \
  '/ssh:box:~/gits/stackchan/main.py'
```

Suggested implementation:

```swift
import Foundation

final class EmacsClient {
    static let shared = EmacsClient()

    private init() {}

    func open(_ request: EmacsRequest) throws {
        let executableURL = try EmacsClientLocator().locate()

        var arguments = [
            "--no-wait",
            "--create-frame"
        ]

        if let line = request.line {
            if let column = request.column {
                arguments.append("+\(line):\(column)")
            } else {
                arguments.append("+\(line)")
            }
        }

        arguments.append(request.path)

        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        let stderr = Pipe()
        process.standardError = stderr

        try process.run()

        DispatchQueue.global().async {
            process.waitUntilExit()

            guard process.terminationStatus != 0 else {
                return
            }

            let data = stderr.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8) ?? ""

            NSLog(
                "emacsclient exited %d: %@",
                process.terminationStatus,
                message
            )
        }
    }
}
```

Because `--no-wait` is used, `emacsclient` should return quickly after handing the request to Emacs.

Do not synchronously block the app waiting for TRAMP connection establishment or file opening.

---

## Locating `emacsclient`

Likely candidates include:

```text
/opt/homebrew/bin/emacsclient
/usr/local/bin/emacsclient
/Applications/Emacs.app/Contents/MacOS/bin/emacsclient
```

The actual path depends on the Emacs distribution.

A locator can check:

1. user-configured path in `UserDefaults`;
2. common Homebrew paths;
3. bundled location inside `/Applications/Emacs.app`;
4. perhaps locations discovered from known app bundles.

Suggested:

```swift
import Foundation

struct EmacsClientLocator {
    func locate() throws -> URL {
        let candidates = [
            UserDefaults.standard.string(
                forKey: "emacsClientPath"
            ),
            "/opt/homebrew/bin/emacsclient",
            "/usr/local/bin/emacsclient",
            "/Applications/Emacs.app/Contents/MacOS/bin/emacsclient"
        ].compactMap { $0 }

        for candidate in candidates
        where FileManager.default.isExecutableFile(atPath: candidate) {
            return URL(fileURLWithPath: candidate)
        }

        throw HandlerError.invalidClientPath
    }
}
```

Potential issue:

Apps launched by Launch Services do not inherit the same shell environment as Terminal.

Therefore:

- do not rely on `$PATH`;
- do not invoke `which`;
- use explicit filesystem paths;
- allow a user-selected executable.

A native file chooser in Settings is a good later addition.

---

## Emacs server setup

The GUI Emacs instance should run an Emacs server.

In Emacs configuration:

```elisp
(require 'server)

(unless (server-running-p)
  (server-start))
```

Manual test before debugging the URL handler:

```bash
/actual/path/to/emacsclient \
  --no-wait \
  --create-frame \
  '/ssh:box:~/gits/stackchan/'
```

This should open the remote directory in Dired.

If that fails, fix Emacs/TRAMP/server setup before debugging the macOS helper.

---

## Daemon and fallback behavior

There are several possible policies.

### Simplest v1

Require an already-running server:

```bash
emacsclient --no-wait --create-frame PATH
```

This is the preferred initial scope.

### Optional later behavior

Use:

```bash
emacsclient \
  --no-wait \
  --create-frame \
  --alternate-editor= \
  PATH
```

An empty alternate editor can cause a daemon to be started when no server exists.

However, this introduces policy questions:

- which Emacs binary should be used;
- whether to launch `Emacs.app` or `emacs --daemon`;
- which socket/server name is intended;
- how GUI activation should work;
- whether environment initialization differs.

Therefore daemon startup should probably be a later deliberate feature.

### Multiple servers

Possible future settings:

```text
--socket-name NAME
```

or:

```text
--server-file FILE
```

This should not be included until there is a real need.

---

## Activating GUI Emacs

This is one area where EmacsOpen and Emacs Client.app may contain valuable edge-case knowledge.

Possible straightforward implementation:

```swift
NSWorkspace.shared.launchApplication("Emacs")
```

or modern equivalent using an application URL.

However, blindly launching Emacs may start a second instance depending on distribution and configuration.

Prefer to inspect:

- how EmacsOpen identifies the relevant Emacs process;
- how it raises the correct window;
- how Emacs Plus `Emacs Client.app` activates Emacs;
- whether `emacsclient --create-frame` alone causes proper foreground activation.

A good v1 sequence may be:

1. invoke `emacsclient`;
2. allow it to create the frame;
3. activate the running Emacs application via `NSRunningApplication`;
4. avoid launching a new app if a running one can be identified.

Potential identification strategies:

- bundle identifier;
- executable path;
- application name;
- process owning the server;
- user-configured Emacs app bundle.

This is the main implementation area worth borrowing from existing projects.

---

## Settings

A minimal Settings view could include:

```text
Emacs client executable
Emacs application bundle
Server/socket name
Start daemon if unavailable
Activate Emacs after opening
Show errors as alerts
```

For version 1, only the executable path may be necessary.

Persist with `UserDefaults`.

A “Test” button could invoke:

```text
emacsclient --eval '(emacs-version)'
```

or open a temporary local path.

---

## Testing plan

### URL parsing tests

Test:

```text
emacs://open?path=%2Fssh%3Abox%3A~%2Fgits%2Fstackchan%2F
```

Expected:

```swift
EmacsRequest(
    path: "/ssh:box:~/gits/stackchan/",
    line: nil,
    column: nil
)
```

Test local path:

```text
emacs://open?path=%2FUsers%2Falexis%2Fnotes%20and%20drafts%2Fidea.md
```

Test file with line/column:

```text
emacs://open?path=%2Ftmp%2Ffoo.py&line=12&column=4
```

Test rejection:

- wrong scheme;
- wrong host/action;
- missing `path`;
- empty `path`;
- NUL in path;
- line `0`;
- negative line;
- nonnumeric line.

Decide whether invalid line/column should be ignored or reject the entire URL.

Recommendation:

- reject malformed explicit values rather than silently ignore them;
- optional absence is fine.

### Argument construction tests

Given:

```swift
path = "/ssh:box:~/gits/stackchan/main.py"
line = 47
column = 3
```

Expected argument array:

```swift
[
    "--no-wait",
    "--create-frame",
    "+47:3",
    "/ssh:box:~/gits/stackchan/main.py"
]
```

This logic should be factored into a pure function so it can be tested without launching a process.

### Integration tests

1. Start GUI Emacs server.
2. Run direct `emacsclient` command.
3. Build and launch app.
4. Run:

```bash
open 'emacs://open?path=%2Fssh%3Abox%3A~%2Fgits%2Fstackchan%2F'
```

5. Confirm:
   - existing Emacs instance receives request;
   - no duplicate Emacs app instance starts;
   - remote Dired buffer opens;
   - Emacs comes to foreground;
   - helper has no Dock icon;
   - paths containing spaces work;
   - malformed URLs fail safely.

---

## URL generation helper

Python:

```python
from urllib.parse import urlencode

path = "/ssh:box:~/gits/stackchan/"

url = "emacs://open?" + urlencode({
    "path": path,
})

print(url)
```

Expected:

```text
emacs://open?path=%2Fssh%3Abox%3A~%2Fgits%2Fstackchan%2F
```

A future CLI helper could be:

```bash
emacs-url '/ssh:box:~/gits/stackchan/'
```

which prints or opens the encoded URL.

This is optional and outside the core app.

---

## Potential compatibility extensions

These should be deferred unless useful.

### Alternate compact form

Possible human-readable syntax:

```text
emacs:/ssh:box:~/gits/stackchan/
```

This is more ambiguous under generic URL parsing and should not be canonical.

### Local file URLs

Could accept:

```text
emacs://open?url=file:///Users/alexis/foo.txt
```

But `path=` is simpler and directly supports both local and TRAMP filenames.

### Org protocol

Could later register or forward:

```text
org-protocol://
```

But this is outside the current goal.

### Multiple files

Could allow repeated parameters:

```text
emacs://open?path=...&path=...
```

or a JSON payload.

Not needed initially.

### Eval support

Could add:

```text
emacs://eval?form=...
```

This is substantially more dangerous and should not be implemented casually.

Opening filenames is much safer than arbitrary Lisp evaluation.

---

## Recommended inspection targets before coding activation behavior

Clone and inspect:

```bash
git clone https://github.com/mbhutton/EmacsOpen.git
git clone https://github.com/d12frosted/homebrew-emacs-plus.git
git clone https://github.com/typester/emacs-handler.git
```

Questions to answer from the code:

### EmacsOpen

- How does it locate `emacsclient`?
- How does it detect an existing frame?
- How does it activate Emacs?
- Does it use bundle IDs, process names, or Apple Events?
- Does it contain reusable Swift types for process invocation?
- What dependencies does it introduce?
- Is the activation behavior reliable on current macOS?

### Emacs Plus `Emacs Client.app`

- How is the helper app generated?
- How are open events received?
- How does it identify the bundled `emacsclient`?
- How does it foreground GUI Emacs?
- What macOS 26-specific workarounds are present?

### EmacsHandler

- What URL syntax did it define?
- Did it contain any useful compatibility conventions?
- Is there any expectation among existing links for a particular path/query format?

Use these as references only.

---

## Recommended implementation strategy for Codex

1. Create a new Xcode macOS app project.
2. Add `LSUIElement`.
3. Register `emacs` URL scheme.
4. Implement `EmacsRequest`.
5. Add parser tests.
6. Implement pure argument-builder logic.
7. Add argument tests.
8. Implement explicit-path `emacsclient` locator.
9. Implement `Process` invocation without a shell.
10. Test with local files.
11. Test with a TRAMP directory.
12. Inspect EmacsOpen/Emacs Plus activation code.
13. Add robust foreground activation.
14. Add a minimal Settings view only if needed.
15. Package as a normal app bundle.

---

## Key design principles

1. **Narrow contract**
   - This is a URL-to-Emacs bridge, not a general Emacs manager.

2. **Preserve Emacs filenames**
   - The decoded path is opaque to the helper.
   - Emacs interprets TRAMP syntax.

3. **No shell**
   - Use `Process.executableURL` and `Process.arguments`.

4. **Typed boundary**
   - Parse into an `EmacsRequest` before invoking anything.

5. **Explicit paths**
   - Launch Services apps should not depend on shell `$PATH`.

6. **Defer daemon policy**
   - Require a running server first.
   - Add startup behavior only after the simple path is reliable.

7. **Borrow edge-case knowledge, not project scope**
   - Existing projects are references for macOS activation and Emacs discovery.

---

## Current recommendation

Build a fresh standalone Swift macOS app:

```text
EmacsURL.app
```

Canonical contract:

```text
emacs://open?path=<encoded-emacs-filename>
```

Example:

```text
emacs://open?path=%2Fssh%3Abox%3A~%2Fgits%2Fstackchan%2F
```

Invoke:

```bash
emacsclient --no-wait --create-frame '/ssh:box:~/gits/stackchan/'
```

Do not fork EmacsOpen initially.

Use EmacsOpen and Emacs Plus `Emacs Client.app` to inform the tricky macOS-specific details:

```text
locating emacsclient
finding the right Emacs app
raising the correct frame
avoiding duplicate instances
handling daemon/server state
```

Everything else should remain purpose-built and small.
