#!/usr/bin/env python3
"""Issue a long-lived Dropbox refresh token for upload_dropbox.py. A person runs this once.

Dropbox only issues a refresh token after the app owner approves the app in a browser, so an AI session cannot
do this step. Run it in your own terminal, then store the printed value as DROPBOX_REFRESH_TOKEN in the
environment settings (never in the repository or in chat).

Before approving, enable the scopes in the App Console (Permissions tab) and press Submit:
  files.content.write   (required for the upload)
  sharing.write         (only for --link)
A token only carries the scopes enabled at approval time; change the scopes first, then re-run this tool.

  DROPBOX_APP_KEY=... DROPBOX_APP_SECRET=... python3 sjrpg_3d/tools/dropbox_auth.py
  python3 sjrpg_3d/tools/dropbox_auth.py --url-only      # only print the approval URL (needs DROPBOX_APP_KEY)
"""
from __future__ import annotations

import argparse
import getpass
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

AUTHORIZE_URL = "https://www.dropbox.com/oauth2/authorize"
TOKEN_URL = "https://api.dropbox.com/oauth2/token"
REQUIRED_SCOPE = "files.content.write"


def authorize_url(app_key: str) -> str:
    # token_access_type=offline is what makes Dropbox return a refresh token; without a redirect_uri the code is shown on screen.
    query = urllib.parse.urlencode({"client_id": app_key, "response_type": "code", "token_access_type": "offline"})
    return f"{AUTHORIZE_URL}?{query}"


def exchange(app_key: str, app_secret: str, code: str) -> dict:
    form = urllib.parse.urlencode(
        {"grant_type": "authorization_code", "code": code, "client_id": app_key, "client_secret": app_secret}
    ).encode()
    request = urllib.request.Request(TOKEN_URL, data=form)
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)
    except urllib.error.HTTPError as err:
        raise SystemExit(f"Dropbox rejected the code (it is single-use and expires in minutes): {err.read().decode('utf-8', 'replace')[:300]}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--url-only", action="store_true", help="print the approval URL and exit")
    args = parser.parse_args()

    app_key = os.environ.get("DROPBOX_APP_KEY") or input("App key: ").strip()
    print(f"\n1) Open this URL, sign in, press Allow, and copy the code shown:\n\n{authorize_url(app_key)}\n")
    if args.url_only:
        return 0
    app_secret = os.environ.get("DROPBOX_APP_SECRET") or getpass.getpass("App secret (hidden): ").strip()
    code = input("2) Paste the code: ").strip()
    token = exchange(app_key, app_secret, code)
    refresh = token.get("refresh_token")
    scopes = token.get("scope", "").split()
    if not refresh:
        print("No refresh_token in the response; the URL must keep token_access_type=offline.", file=sys.stderr)
        return 1
    if REQUIRED_SCOPE not in scopes:
        print(f"Warning: granted scopes {scopes} lack {REQUIRED_SCOPE}; enable it in the App Console, Submit, and run this again.", file=sys.stderr)
    print(f"\nGranted scopes: {' '.join(scopes)}")
    print("DROPBOX_REFRESH_TOKEN (store it in the environment settings, not in the repository):")
    print(refresh)
    return 0 if REQUIRED_SCOPE in scopes else 1


if __name__ == "__main__":
    sys.exit(main())
