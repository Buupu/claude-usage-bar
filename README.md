# claude-usage-bar

Your **real** Claude usage in the macOS menu bar — the same numbers Claude Code's `/usage` shows, fetched live from Anthropic's API. Not an estimate reconstructed from local logs.

```
✳ 42%
──────────────────────────────
Session (5h)     ████░░░░░░  42%
  resets 18:40
Weekly · all     █░░░░░░░░░  12%
  resets Mon 09:00
Weekly · Opus    ██░░░░░░░░  23%
  resets Mon 09:00
──────────────────────────────
Extra usage: 0.00 / 30.00 GBP
```

The menu bar shows whichever limit is closest to capping; the dropdown shows all of them with reset times in your local timezone. Bars turn orange at 70% and red at 90%.

## Requirements

- macOS
- [Claude Code](https://claude.com/claude-code) installed and signed in (this is where the auth token comes from)
- A Claude subscription (Pro / Max / Team)

## Install

```sh
brew install --cask swiftbar
```

Launch SwiftBar once and pick (or create) a plugin folder, then drop the plugin in:

```sh
curl -o ~/path/to/your/plugin/folder/claude-usage.2m.py \
  https://raw.githubusercontent.com/Buupu/claude-usage-bar/main/claude-usage.2m.py
chmod +x ~/path/to/your/plugin/folder/claude-usage.2m.py
```

The `2m` in the filename is the refresh interval — rename to `claude-usage.5m.py` etc. to taste. There's also a manual **Refresh** item in the dropdown.

> **First run:** macOS will ask whether the plugin may read the `Claude Code-credentials` Keychain item. Click **Always Allow**.

## How it works (and the caveats)

Claude Code stores an OAuth token in your macOS Keychain under `Claude Code-credentials`. This plugin reads that token and calls the same endpoint the `/usage` command uses:

```
GET https://api.anthropic.com/api/oauth/usage
Authorization: Bearer <token>
anthropic-beta: oauth-2025-04-20
```

Which means:

- **This is an undocumented API.** Anthropic could change or remove it at any time, and this plugin would break. It is not an official integration.
- **Read-only.** The plugin never writes to the Keychain and never refreshes the token itself. If the token expires, the plugin tells you to open Claude Code, which refreshes it automatically.
- **Nothing leaves your machine** except the one authenticated request to `api.anthropic.com`. No analytics, no third parties. It's ~150 lines of stdlib-only Python — [read it](claude-usage.2m.py).

## Troubleshooting

| Menu bar shows | Meaning |
|---|---|
| `✳ sign in` | No credentials in Keychain — run `claude` in a terminal and sign in |
| `✳ token expired` | Token lapsed — open Claude Code once, it refreshes automatically |
| `✳ offline` | Couldn't reach `api.anthropic.com` |
| `✳ ⚠︎` | Unexpected API response — open an issue with the dropdown text |

## License

MIT
