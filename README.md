# EmacsURL

https://github.com/user-attachments/assets/fbcbf1e3-f482-47c6-9c11-dfd47796a653

EmacsURL is a small native macOS helper that opens an Emacs filename in a
running GUI Emacs server. It supports local filenames and remote filenames
handled by TRAMP.

The app is a resident `LSUIElement` agent: it receives URLs without showing a
Dock icon, invokes `emacsclient` directly without a shell, and foregrounds the
running Emacs application after a successful request.

## Running and quitting

Install the app by moving `EmacsURL.app` to `/Applications` and launching it
once so Launch Services registers the `emacs-file:` scheme. After that you never
need to start it by hand: macOS launches it on demand whenever an `emacs-file:`
URL is opened, and it stays resident with no Dock or menu bar icon.

Because it is otherwise invisible, launching the app directly — or re-opening it
from Finder or Spotlight — shows a small status window. The window confirms the
helper is running, reports whether `emacsclient` and a running Emacs server can
be found, lets you choose the frame behavior, and offers a Quit button. Opening
the app from an `emacs-file:` URL never shows this window; it stays headless.

## URL contract

The only supported scheme is `emacs-file`:

```text
emacs-file:<percent-encoded-emacs-filename>
```

The decoded scheme-specific path is the same string passed to `emacsclient`.
The helper does not parse or construct TRAMP syntax.

Examples:

```text
# Local absolute filename
emacs-file:/Users/alexis/notes/idea.md

# Local home-relative filename
emacs-file:~/notes/idea.md

# TRAMP filename relative to the remote home directory
emacs-file:/ssh:box:~/gits/stackchan/main.py

# TRAMP filename with an absolute remote path
emacs-file:/ssh:box:/srv/stackchan/main.py

# Optional one-based line and column
emacs-file:/ssh:box:~/gits/stackchan/main.py?line=47&column=3
```

Characters with structural meaning in a URL must be percent encoded. Common
examples include space as `%20`, `?` as `%3F`, `#` as `%23`, `%` as `%25`, and
`|` as `%7C`. Decoding happens exactly once.

The parser accepts absolute filenames beginning with `/` and home-relative
filenames beginning with `~`. It rejects bare relative filenames because the
URL does not carry the originating process's working directory. It also
rejects URL authorities, fragments, duplicate parameters, unknown parameters,
NUL characters, and malformed positions. `column` requires `line`.

## Emacs behavior

Version 1 requires an already-running Emacs server. A typical Emacs setup is:

```elisp
(require 'server)
(unless (server-running-p)
  (server-start))
```

The default request is equivalent to:

```text
emacsclient --no-wait --create-frame -- EMACS_FILENAME
```

For a positioned request, `+LINE:COLUMN` is inserted after `--` and before the
filename.

Frame behavior is a preference in the status window: "Open in a new frame"
(`emacsclient --create-frame`, the default) or "Reuse an existing frame"
(`emacsclient --reuse-frame`). The choice is persisted in user defaults and read
when a URL is handled, without changing URL parsing or client execution. The
default for a fresh install is the single `frameBehavior` value in
`EmacsURL/AppConfiguration.swift`.

The app looks for `emacsclient` at:

```text
/Applications/Emacs.app/Contents/MacOS/bin/emacsclient
/opt/homebrew/bin/emacsclient
/usr/local/bin/emacsclient
```

It activates the running application with bundle identifier `org.gnu.Emacs`
after `emacsclient` exits successfully. It does not start an Emacs daemon or a
second Emacs application.

## Build and test

Requirements:

- macOS 15 or later
- Xcode 26.6
- Swift 6

Open `EmacsURL.xcodeproj` in Xcode, or build from the command line:

```bash
xcodebuild \
  -project EmacsURL.xcodeproj \
  -scheme EmacsURL \
  -configuration Debug \
  build
```

Run the unit and subprocess integration tests with:

```bash
xcodebuild \
  -project EmacsURL.xcodeproj \
  -scheme EmacsURL \
  -configuration Debug \
  test
```

The tests cover literal local and TRAMP filename parsing, percent decoding,
strict query validation, argument construction for both frame policies, and
successful and failed subprocess exits.

After building and launching the app so Launch Services registers it, a manual
test is:

```bash
open 'emacs-file:/ssh:box:~/gits/stackchan/'
```

The first manual test should be performed with EmacsURL completely terminated
to verify cold-launch URL delivery.

## Security boundary

The current threat model assumes trusted URLs. The app still treats the URL as
structured input, never invokes a shell, inserts an option terminator before
the filename, limits input sizes, and avoids logging the filename or complete
URL. The target is intentionally not App Sandbox-enabled because the
`emacsclient` subprocess must communicate with an Emacs server outside an app
container.
