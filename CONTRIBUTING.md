# Contributing

Thanks for helping. Bug reports, ideas and pull requests are all welcome.

## Report a bug or suggest a feature

[Open an issue](https://github.com/andreareosa/remarkable-share/issues) and include:

- Your macOS version and your tablet's firmware version
- Whether you were sharing over USB or Wi-Fi
- What happened, with a screenshot if you can

Never post your tablet's root password or your SSH key.

## Send a pull request

1. Fork the repo and create a branch.
2. Make your change. If you change any logic, add a test in
   `Tests/RemarkableShareCoreTests`.
3. Run `./scripts/check.sh` and make sure it passes. It runs the tests and builds the app.
4. Open a pull request that says what you changed and how you tested it.

## Rules

The app runs commands as root on people's tablets, so:

- Commands sent to the tablet go through `RemoteCommands`, and never include
  unchecked input.
- Never store the tablet's root password.
- When updating goMarkableStream, change its version and SHA-256 together in
  `TabletConfig.swift`.

## Ideas

- Support the reMarkable Paper Pro
- An "Update streaming tool" menu item
- Reconnect automatically when the tablet wakes up
- A button to save the current page as an image

By contributing, you agree your work is released under the [MIT License](./LICENSE).
