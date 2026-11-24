#!/usr/bin/env python3
"""Sets a TestFlight build's "What to Test" text from the PRs it ships.

Two steps, run by .github/workflows/deploy-ios.yml after the upload:

  notes   Writes the text to stdout: every PR merged between the last
          successful TestFlight deploy and this commit, newest first, each as
          its title followed by the first section of its description. Titles
          are always kept; descriptions are added while they fit in Apple's
          4,000-character limit. Needs `gh` (GH_TOKEN) and GITHUB_REPOSITORY.

  upload  Reads the text from a file and sets it as the build's What to Test,
          waiting for App Store Connect to list the build first (it appears a
          few minutes after the upload). Needs pyjwt[crypto] and the App Store
          Connect API key the deploy already uses.

Locally, `notes --sha <sha>` previews what a build would say.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

MAX_CHARS = 4000  # App Store Connect's limit for whatsNew.
ASC_API = "https://api.appstoreconnect.apple.com/v1"


# --- notes -------------------------------------------------------------------


def gh_api(path: str) -> object:
    out = subprocess.run(["gh", "api", path], check=True, capture_output=True, text=True).stdout
    return json.loads(out)


def previous_deploy_sha(repo: str) -> str | None:
    """The commit the last successful TestFlight deploy built, if any."""
    out = subprocess.run(
        ["gh", "run", "list", "--repo", repo, "--workflow", "deploy-ios.yml", "--branch", "main",
         "--status", "success", "--limit", "1", "--json", "headSha"],
        check=True, capture_output=True, text=True,
    ).stdout
    runs = json.loads(out)
    return runs[0]["headSha"] if runs else None


def shipped_prs(repo: str, sha: str, since: str | None) -> list[dict]:
    """PRs merged into main whose commits are in since..sha, newest first."""
    if since and since != sha:
        compare = gh_api(f"repos/{repo}/compare/{since}...{sha}")
        shas = [c["sha"] for c in compare["commits"]]
    else:
        shas = [sha]
    prs: dict[int, dict] = {}
    # Newest commits first, and a cap so a huge gap can't make hundreds of calls.
    for commit in list(reversed(shas))[:100]:
        for pr in gh_api(f"repos/{repo}/commits/{commit}/pulls"):
            if pr.get("merged_at") and pr["base"]["ref"] == "main":
                prs.setdefault(pr["number"], pr)
    return sorted(prs.values(), key=lambda pr: pr["merged_at"], reverse=True)


def first_section(body: str | None) -> str:
    """The description's opening section (Summary / What changes), as plain text."""
    if not body:
        return ""
    lines = body.replace("\r\n", "\n").split("\n")
    headings = [i for i, line in enumerate(lines) if line.startswith("## ")]
    if headings:
        end = headings[1] if len(headings) > 1 else len(lines)
        lines = lines[headings[0] + 1:end]
    kept = []
    for line in lines:
        stripped = line.strip()
        # Stacking notes, issue links and the attribution aren't for testers.
        if stripped.startswith(">") or re.match(r"(?i)^(closes|fixes|resolves) #\d+", stripped) \
                or "Generated with [Claude Code]" in stripped:
            continue
        kept.append(line)
    return plain_text("\n".join(kept))


def plain_text(markdown: str) -> str:
    """TestFlight shows plain text, so drop the markdown that would show as symbols."""
    text = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", markdown)  # links -> their text
    text = re.sub(r"\*\*(.+?)\*\*", r"\1", text)
    text = re.sub(r"(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*])", r"\1", text)
    text = text.replace("`", "")
    text = re.sub(r"(?m)^#{1,6}\s+", "", text)
    text = re.sub(r"(?m)^(\s*)[-*]\s+", r"\1• ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def compose(prs: list[dict], limit: int = MAX_CHARS) -> str:
    titles = [f"{pr['title'].strip()} (#{pr['number']})" for pr in prs]
    details = [first_section(pr.get("body")) for pr in prs]
    blocks = list(titles)

    def size() -> int:
        return len("\n\n".join(blocks))

    # Every title fits first (truncating only if even the titles alone don't),
    # then each description in turn, newest first, cut at a line if need be.
    for i, detail in enumerate(details):
        if not detail:
            continue
        room = limit - size() - 1  # the newline between title and detail
        if room <= 0:
            break
        if len(detail) > room:
            cut = detail[: room - 1]
            cut = cut[: cut.rfind("\n")] if "\n" in cut else ""
            if not cut.strip():
                continue
            detail = cut.rstrip() + "\n…"
        blocks[i] = f"{titles[i]}\n{detail}"
    text = "\n\n".join(blocks)
    return text if len(text) <= limit else text[: limit - 1] + "…"


def cmd_notes(args: argparse.Namespace) -> None:
    repo = args.repo or os.environ["GITHUB_REPOSITORY"]
    since = args.since if args.since is not None else previous_deploy_sha(repo)
    prs = shipped_prs(repo, args.sha, since or None)
    if prs:
        text = compose(prs)
    else:
        # A manual run with nothing merged since the last build: say what it is.
        commit = gh_api(f"repos/{repo}/commits/{args.sha}")
        text = commit["commit"]["message"].split("\n")[0]
    print(text)


# --- upload ------------------------------------------------------------------


def asc_token() -> str:
    import jwt  # pyjwt[crypto]; only the upload step needs it.

    with open(os.environ["ASC_KEY_PATH"], encoding="utf-8") as f:
        key = f.read()
    now = int(time.time())
    return jwt.encode(
        {"iss": os.environ["APP_STORE_CONNECT_ISSUER_ID"], "iat": now, "exp": now + 15 * 60,
         "aud": "appstoreconnect-v1"},
        key, algorithm="ES256",
        headers={"kid": os.environ["APP_STORE_CONNECT_KEY_ID"], "typ": "JWT"},
    )


def asc(method: str, path: str, body: dict | None = None) -> dict:
    req = urllib.request.Request(
        f"{ASC_API}{path}", method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={"Authorization": f"Bearer {asc_token()}", "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.loads(resp.read() or b"{}")


def find_build(app_id: str, version: str, build_number: str) -> dict | None:
    query = urllib.parse.urlencode({
        "filter[app]": app_id,
        "filter[version]": build_number,
        "filter[preReleaseVersion.version]": version,
        "limit": 1,
    })
    builds = asc("GET", f"/builds?{query}")["data"]
    return builds[0] if builds else None


def set_whats_new(build_id: str, locale: str, text: str) -> None:
    existing = asc("GET", f"/builds/{build_id}/betaBuildLocalizations")["data"]
    match = next((l for l in existing if l["attributes"]["locale"] == locale), None)
    if match:
        asc("PATCH", f"/betaBuildLocalizations/{match['id']}", {"data": {
            "type": "betaBuildLocalizations", "id": match["id"], "attributes": {"whatsNew": text}}})
    else:
        asc("POST", "/betaBuildLocalizations", {"data": {
            "type": "betaBuildLocalizations",
            "attributes": {"locale": locale, "whatsNew": text},
            "relationships": {"build": {"data": {"type": "builds", "id": build_id}}}}})


def cmd_upload(args: argparse.Namespace) -> None:
    with open(args.notes_file, encoding="utf-8") as f:
        text = f.read().strip()[:MAX_CHARS]
    apps = asc("GET", "/apps?" + urllib.parse.urlencode({"filter[bundleId]": args.bundle_id}))["data"]
    if not apps:
        sys.exit(f"No App Store Connect app has bundle ID {args.bundle_id}.")
    app_id = apps[0]["id"]

    deadline = time.time() + args.timeout
    last_error = "the build never appeared in App Store Connect"
    while time.time() < deadline:
        try:
            build = find_build(app_id, args.version, args.build_number)
            if build:
                set_whats_new(build["id"], args.locale, text)
                state = build["attributes"].get("processingState")
                print(f"Set What to Test on {args.version} ({args.build_number}), processing state {state}.")
                return
        except urllib.error.HTTPError as e:
            # Apple can refuse the edit while the build is still processing; retry.
            last_error = f"HTTP {e.code}: {e.read().decode(errors='replace')[:500]}"
            print(f"Not yet: {last_error}", file=sys.stderr)
        time.sleep(30)
    sys.exit(f"Gave up after {args.timeout}s: {last_error}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)

    notes = sub.add_parser("notes", help="print the What to Test text")
    notes.add_argument("--sha", required=True, help="the commit being shipped")
    notes.add_argument("--since", help="the last shipped commit (default: last successful deploy-ios run)")
    notes.add_argument("--repo", help="owner/name (default: $GITHUB_REPOSITORY)")
    notes.set_defaults(func=cmd_notes)

    upload = sub.add_parser("upload", help="set the text on the build in App Store Connect")
    upload.add_argument("--notes-file", required=True)
    upload.add_argument("--bundle-id", required=True)
    upload.add_argument("--version", required=True, help="build name, e.g. 1.45.0")
    upload.add_argument("--build-number", required=True)
    upload.add_argument("--locale", default="en-US")
    upload.add_argument("--timeout", type=int, default=30 * 60, help="seconds to wait for the build")
    upload.set_defaults(func=cmd_upload)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
