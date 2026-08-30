# Codex Usage Menu

[简体中文](docs/README.zh-CN.md)

A lightweight native macOS menu-bar utility for viewing local Codex activity and, when available, the current account usage window.

## Features

- Native Swift/AppKit application with no third-party dependencies.
- Local token and thread statistics from `~/.codex/state_5.sqlite`.
- Account plan display from the locally installed Codex authentication file.
- Configurable automatic refresh.
- Clear stale/error state instead of silently showing an old percentage.

## Important compatibility notice

Local activity statistics use Codex files on your Mac. The remaining-usage percentage is experimental: it uses the backend route currently used by Codex/ChatGPT rather than a documented public developer API. The route or response format can change without notice. Do not build billing, purchasing, or operational decisions around this display.

## Privacy

The app reads local Codex files. When refreshing account usage, it sends the existing access token only to `https://chatgpt.com`. It does not send the token, email address, local database, or usage history to the project author or another analytics service. Review the source and [SECURITY.md](SECURITY.md) before running it.

## Requirements

- macOS 13 or newer.
- Xcode Command Line Tools (`swiftc`).
- Codex installed and signed in.
- `/usr/bin/sqlite3` for local activity statistics.

## Build and run

```bash
./run-codex-usage-menu.sh
```

Build only:

```bash
swiftc CodexUsageMenu.swift -o CodexUsageMenu -framework AppKit
```

Settings are stored in:

```text
~/Library/Application Support/CodexUsageMenu/settings.json
```

## Distribution and commercial options

The source is MIT licensed. A repository owner may separately offer notarized binaries, automatic updates, managed installation, or support. See [COMMERCIAL.md](COMMERCIAL.md).

## License

MIT.
