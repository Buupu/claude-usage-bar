#!/usr/bin/env python3
# <xbar.title>Claude Usage</xbar.title>
# <xbar.version>v0.1.0</xbar.version>
# <xbar.author>Sammy Fattah</xbar.author>
# <xbar.author.github>sammyfattah</xbar.author.github>
# <xbar.desc>Live Claude plan usage in your menu bar — the same numbers Claude Code's /usage shows, straight from Anthropic's API.</xbar.desc>
# <xbar.dependencies>python3, Claude Code (signed in)</xbar.dependencies>
# <xbar.abouturl>https://github.com/sammyfattah/claude-usage-bar</xbar.abouturl>
# <swiftbar.runInBash>false</swiftbar.runInBash>

import json
import subprocess
import sys
import urllib.error
import urllib.request
from datetime import datetime

KEYCHAIN_SERVICE = "Claude Code-credentials"
USAGE_URL = "https://api.anthropic.com/api/oauth/usage"
USAGE_PAGE = "https://claude.ai/settings/usage"

ICON = "✳"

# percent → menu bar colour (SwiftBar `color=` param). None = default text colour.
def colour_for(percent, severity="normal"):
    if severity not in ("normal", None) or percent >= 90:
        return "#ff3b30"  # red
    if percent >= 70:
        return "#ff9500"  # orange
    return None


def bar(percent, width=10):
    filled = min(width, round(percent / 100 * width))
    return "█" * filled + "░" * (width - filled)


def fmt_reset(iso):
    dt = datetime.fromisoformat(iso).astimezone()
    now = datetime.now().astimezone()
    days = (dt.date() - now.date()).days
    if days == 0:
        day = ""
    elif days == 1:
        day = "tomorrow "
    else:
        day = dt.strftime("%a ")
    return f"{day}{dt.strftime('%H:%M')}"


def emit_error(title, *detail):
    print(f"{ICON} {title}")
    print("---")
    for line in detail:
        print(line)
    print("---")
    print("Refresh | refresh=true")
    sys.exit(0)


def get_token():
    try:
        raw = subprocess.run(
            ["/usr/bin/security", "find-generic-password", "-s", KEYCHAIN_SERVICE, "-w"],
            capture_output=True, text=True, check=True, timeout=10,
        ).stdout.strip()
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
        emit_error(
            "sign in",
            "No Claude Code credentials found in your Keychain.",
            "Run `claude` in a terminal and sign in, then refresh.",
        )
    try:
        return json.loads(raw)["claudeAiOauth"]["accessToken"]
    except (json.JSONDecodeError, KeyError):
        emit_error("⚠︎", "Couldn't parse Claude Code credentials from Keychain.")


def fetch_usage(token):
    req = urllib.request.Request(
        USAGE_URL,
        headers={
            "Authorization": f"Bearer {token}",
            "anthropic-beta": "oauth-2025-04-20",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return json.load(resp)
    except urllib.error.HTTPError as e:
        if e.code in (401, 403):
            emit_error(
                "token expired",
                "Your Claude Code token has expired.",
                "Open Claude Code (run `claude`) — it refreshes the token automatically.",
            )
        emit_error("⚠︎", f"Anthropic API returned HTTP {e.code}.")
    except (urllib.error.URLError, TimeoutError):
        emit_error("offline", "Couldn't reach api.anthropic.com.")


LIMIT_LABELS = {
    "session": "Session (5h)",
    "weekly_all": "Weekly · all models",
}


def limit_label(limit):
    kind = limit.get("kind", "")
    if kind in LIMIT_LABELS:
        return LIMIT_LABELS[kind]
    scope = limit.get("scope") or {}
    model = (scope.get("model") or {}).get("display_name")
    if model:
        return f"Weekly · {model}"
    return kind.replace("_", " ").title()


def main():
    data = fetch_usage(get_token())
    limits = data.get("limits") or []

    if not limits:
        emit_error("⚠︎", "No limit data in API response — the endpoint may have changed.")

    # Menu bar title: whichever limit is closest to capping.
    worst = max(limits, key=lambda l: l.get("percent") or 0)
    pct = worst.get("percent") or 0
    colour = colour_for(pct, worst.get("severity"))
    title = f"{ICON} {pct}%"
    print(f"{title} | color={colour}" if colour else title)

    print("---")
    for limit in limits:
        p = limit.get("percent") or 0
        c = colour_for(p, limit.get("severity"))
        line = f"{limit_label(limit)}  {bar(p)}  {p}%"
        params = "font=Menlo size=12" + (f" color={c}" if c else "")
        print(f"{line} | {params}")
        print(f"resets {fmt_reset(limit['resets_at'])} | size=11 color=#8e8e93")

    spend = data.get("spend") or {}
    if spend.get("enabled") and spend.get("limit"):
        exp = spend["limit"].get("exponent", 2)
        cur = spend["limit"].get("currency", "")
        used = spend.get("used", {}).get("amount_minor", 0) / 10**exp
        cap = spend["limit"].get("amount_minor", 0) / 10**exp
        print("---")
        print(f"Extra usage: {used:.2f} / {cap:.2f} {cur} | size=12")

    print("---")
    print(f"Open usage settings | href={USAGE_PAGE}")
    print("Refresh | refresh=true")


if __name__ == "__main__":
    main()
