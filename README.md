# claude-usage-bar

Your **real** Claude usage in the macOS menu bar — the same numbers Claude Code's `/usage` shows, fetched live from Anthropic's API. Not an estimate reconstructed from local logs.

A native SwiftUI app: session and weekly usage rings, per-model limits, reset times in your local timezone, extra-usage spend. Follows your system light/dark appearance. The menu bar shows whichever limit is closest to capping, turning orange at 70% and red at 90%.

<img width="307" height="385" alt="Screenshot 2026-07-12 at 20 14 51" src="https://github.com/user-attachments/assets/fdd8d1ef-78c9-4604-ad3d-11bd75974c36" />


## Requirements

- macOS 14+
- [Claude Code](https://claude.com/claude-code) installed and signed in (this is where the auth token comes from)
- A Claude subscription (Pro / Max / Team)

## Install

```sh
brew tap buupu/claude-usage-bar https://github.com/Buupu/claude-usage-bar
brew trust buupu/claude-usage-bar      # newer Homebrew requires trusting third-party taps
brew install claude-usage-bar
brew services start claude-usage-bar   # start now + at login
```

The app builds from source on your machine (needs Xcode Command Line Tools), so there's no Gatekeeper friction and nothing to notarize — you can read every line it runs.

> **First run:** macOS will ask whether the app may read the `Claude Code-credentials` Keychain item. Click **Always Allow**.

### Or build it yourself

```sh
git clone https://github.com/Buupu/claude-usage-bar && cd claude-usage-bar
swift build -c release
.build/release/claude-usage-bar &
```

## How it works (and the caveats)

Claude Code stores an OAuth token in your macOS Keychain under `Claude Code-credentials`. This app reads that token and calls the same endpoint the `/usage` command uses:

```
GET https://api.anthropic.com/api/oauth/usage
Authorization: Bearer <token>
anthropic-beta: oauth-2025-04-20
```

Which means:

- **This is an undocumented API.** Anthropic could change or remove it at any time, and this app would break. It is not an official integration.
- **Read-only.** The app never writes to the Keychain and never refreshes the token itself. If the token expires, the app tells you to open Claude Code, which refreshes it automatically.
- **Only the access token is used.** The Keychain item also contains a long-lived `refreshToken` — this app never reads it, so it can't mint new tokens or touch your Claude Code session. It extracts `accessToken` (and its expiry), nothing else.
- **Nothing leaves your machine** except the one authenticated request to `api.anthropic.com` every 2 minutes. No analytics, no third parties.

## Troubleshooting

| Menu bar shows | Meaning |
|---|---|
| `✳ sign in` | No credentials in Keychain — run `claude` in a terminal and sign in |
| `✳ expired` | Token lapsed — open Claude Code once, it refreshes automatically |
| `✳ offline` | Couldn't reach `api.anthropic.com` |
| `✳ ⚠︎` | Unexpected API response — open an issue with the popover text |

Prefer a scriptable, zero-build version? The original SwiftBar plugin lives at the [`swiftbar-plugin`](https://github.com/Buupu/claude-usage-bar/tree/swiftbar-plugin) tag.

## License

MIT
