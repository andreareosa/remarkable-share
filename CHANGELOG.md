# Changelog

All notable changes to this project are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.0.0] - 2026-11-13

First release.

### Added

- A menu bar app that shows your reMarkable 2 screen in its own window, with no browser
  or login form.
- Sharing over USB, or over Wi-Fi using HTTPS that trusts only the tablet's own
  certificate.
- One-time setup: enter the tablet's root password once to install a dedicated SSH key.
  The password isn't stored.
- Automatic install and repair of the streaming tool (goMarkableStream v1.4.0, checked
  against its SHA-256).
- Launch at Login.
- A `remarkable-share://` URL scheme for Shortcuts, Raycast and scripts.
- Sharing stops on the tablet when you close the viewer or quit the app.

[Unreleased]: https://github.com/andreareosa/remarkable-share/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/andreareosa/remarkable-share/releases/tag/v1.0.0
