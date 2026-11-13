# AGENTS.md: reMarkable Share

A menu bar app for macOS 15+ (SwiftPM, SwiftUI + WebKit). It streams a reMarkable 2
screen through goMarkableStream, which it controls over SSH on the USB link. See
README.md for what the app does.

## Rules

- Keep `RemarkableShareCore` free of AppKit and SwiftUI, and unit-test anything you add
  there. Run `swift test` before committing.
- Never build shell strings from untrusted input. Commands that run on the tablet live in
  `RemoteCommands`. A password reaches a command only after it passes
  `PasswordPolicy.isSafe` (alphanumeric only).
- Never persist the tablet root password. The askpass helper reads it from the
  environment and deletes itself afterwards.
- When you bump goMarkableStream, update `streamVersion` and `streamSHA256` together in
  `TabletConfig.swift`. Take the SHA from that release's `checksums.txt`, and verify the
  `/login` contract and the `localStorage` keys in `client/auth.js`.
- Keep the bundle id `com.areosa.remarkable-share` stable. macOS ties the Local Network
  and Keychain decisions to it.
- `NSLocalNetworkUsageDescription` in `Resources/Info.plist` is required. Without it,
  macOS silently blocks the app, which is exactly the bug in the official app.
- Don't commit `build.noindex/` or `.build/`.

## Verify end-to-end

With the tablet plugged in:

1. Run `./scripts/install.sh`.
2. Run `open remarkable-share://share/usb`. A viewer window should open, and
   `ssh -i ~/.ssh/remarkable_ed25519 root@10.11.99.1 pidof goMarkableStream` should print
   a PID.
3. Run `open remarkable-share://stop`. The PID should be gone.
