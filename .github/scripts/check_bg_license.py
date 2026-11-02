"""Fail the release when BG_LICENSE_KEY is a trial key or belongs to another app.

A trial key builds fine and works until its expiry, then tracking locks in
the store build (the trial keys of 2.0.0+48 ran out on 03.11.2026). The
key is a JWT, so its claims can be read without the signing secret.

Usage: BG_LICENSE_KEY=... python3 check_bg_license.py <app id>
"""

import base64
import json
import os
import sys

app_id = sys.argv[1]
payload = os.environ["BG_LICENSE_KEY"].split(".")[1]
claims = json.loads(base64.urlsafe_b64decode(payload + "=" * (-len(payload) % 4)))

print(
    f"licence: os={claims.get('os')} app_id={claims.get('app_id')} "
    f"trial={claims.get('trial')} max_build_stamp={claims.get('max_build_stamp')}"
)

errors = []
if claims.get("trial"):
    errors.append("the licence is a trial key")
if claims.get("app_id") not in (None, app_id):
    errors.append(f"the licence is for {claims['app_id']}, not {app_id}")
elif "app_id" not in claims:
    print(f"::warning::the licence has no app_id claim to compare with {app_id}")

for error in errors:
    print(f"::error::{error}")
sys.exit(1 if errors else 0)
