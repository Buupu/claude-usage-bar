# claude-usage-bar

Your **real** Claude usage in the macOS menu bar — the same numbers Claude Code's `/usage` shows, fetched live from Anthropic's API. Not an estimate reconstructed from local logs.

A native SwiftUI app: session and weekly usage rings, per-model limits, reset times in your local timezone, extra-usage spend. Follows your system light/dark appearance. The menu bar shows whichever limit is closest to capping, turning orange at 70% and red at 90%.

<img width="306" height="382" alt="Screenshot 2026-07-12 at 20 22 17" src="https://github.com/user-attachments/assets/cbc89e77-637f-416c-a239-f139635727a9" />

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

Which means **this is an undocumented API** — Anthropic could change or remove it at any time, and this app would break. It is not an official integration.

## Security

**No new access is created.** This app doesn't sign you in, doesn't request scopes, and doesn't mint credentials. It reads the token Claude Code already holds and calls the same endpoint Claude Code's `/usage` already calls — so installing it exposes your account to nothing that your existing Claude Code install doesn't already do. If you trust Claude Code on your machine, this app adds no new capability, only a new (small, auditable) codebase handling the same secret.

How the token is handled, specifically:

- **Read once per launch, held in memory only.** Never written to disk, never logged, never passed to another process. macOS asks for your approval the first time (that's the Keychain dialog — the OS working as intended, not being bypassed).
- **Only the `accessToken` is read.** The Keychain item also contains a long-lived `refreshToken`; this app never touches it, so it can't mint new tokens or interfere with your Claude Code session. When the access token expires, the app just tells you to open Claude Code, which refreshes it itself.
- **One destination, ever.** The token is sent solely to the hardcoded `https://api.anthropic.com` URL — one request every 3 minutes — over an ephemeral `URLSession` that refuses redirects and caches nothing to disk. There are no other endpoints, no analytics, no third parties.
- **Keychain is never written to.** Strictly read-only.
- **Injection-resistant.** The binary is signed with the hardened runtime, so `DYLD_INSERT_LIBRARIES`-style tricks can't piggyback on your Keychain approval to read the token through this app.

Honest limitations: the app is ad-hoc signed (no paid Apple Developer identity), so each upgraded binary triggers one fresh Keychain prompt — and ultimately you're trusting this repository's source code. That's why it builds from source on your machine: the entire app is a few hundred lines of Swift you can read before running.

## Troubleshooting

| Menu bar shows | Meaning |
|---|---|
| `✳ sign in` | No credentials in Keychain — run `claude` in a terminal and sign in |
| `✳ expired` | Token lapsed — open Claude Code once, it refreshes automatically |
| `✳ offline` | Couldn't reach `api.anthropic.com` |
| `✳ ⏳` | Rate limited — the app backs off and retries automatically |
| `✳ ⚠︎` | Unexpected API response — open an issue with the popover text |

Prefer a scriptable, zero-build version? The original SwiftBar plugin lives at the [`swiftbar-plugin`](https://github.com/Buupu/claude-usage-bar/tree/swiftbar-plugin) tag.

## License

MIT
