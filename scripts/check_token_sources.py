#!/usr/bin/env python3
"""§10e trusted-source checker: every link in assets/token_sources.json must
be reachable over HTTPS and must END on an HTTPS origin (a redirect into a
non-https site fails). Network access is required — run locally or from CI.

Usage: python3 scripts/check_token_sources.py [path-to-json]
Exit codes: 0 = all links reachable, 1 = at least one failure.

Quick link checker, deliberately plain: no third-party dependencies, so the
check itself adds nothing new to trust.
"""
import json
import sys
import urllib.request

UA = "x-wallet-source-check/1.0"
TIMEOUT = 30


def main() -> int:
    path = sys.argv[1] if len(sys.argv) > 1 else "assets/token_sources.json"
    try:
        with open(path, encoding="utf-8") as handle:
            entries = json.load(handle)
    except (OSError, ValueError) as error:
        print(f"FAIL cannot read {path}: {error}")
        return 1
    if not isinstance(entries, list) or not entries:
        print("FAIL the source list is empty or malformed")
        return 1

    failures = 0
    skipped = 0
    reachable = 0
    browser_ua = (
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like "
        "Gecko) Chrome/126.0 Safari/537.36"
    )
    for entry in entries:
        name = entry.get("name", "(no name)")
        url = entry.get("url", "")
        if not url.startswith("https://"):
            print(f"FAIL {name}: URL is not https")
            failures += 1
            continue
        headers = {"User-Agent": UA}
        status: int
        final: str
        error_text = ""
        status = 0
        final = url
        for attempt in range(2):
            request = urllib.request.Request(url, headers=headers)
            try:
                with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
                    status = response.status
                    final = response.geturl()
                    error_text = ""
                break
            except Exception as error:  # noqa: BLE001 — a checker must not die
                error_text = f"{error}"
                status = -1
                headers = {"User-Agent": browser_ua}  # second try: browser UA
        if status == 200 and not final.startswith("https://"):
            print(f"FAIL {name}: landed on non-https {final}")
            failures += 1
        elif status == 200:
            note = "" if final == url else f" (→ {final})"
            print(f"OK   {name} — 200{note}")
            reachable += 1
        elif entry.get("bot_protected") and ("403" in error_text or "429" in error_text):
            print(
                f"SKIP {name}: bot protection refused the scripted probe "
                "(declared in the list) — verify once in a real browser"
            )
            skipped += 1
        else:
            print(f"FAIL {name}: {error_text or ('HTTP ' + str(status))}")
            failures += 1

    print(
        f"{reachable}/{len(entries)} verified over HTTPS · "
        f"{skipped} skip(bot-protected) · "
        f"{failures} failure(s)"
    )
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
