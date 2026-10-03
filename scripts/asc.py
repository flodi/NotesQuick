#!/usr/bin/env python3
"""App Store Connect helper for NotesQuick.

Credentials never live in this repository:
  ASC_API_ISSUER   Issuer ID (required)
  the .p8 key is looked up in ~/.appstoreconnect/private_keys/ (the first one valid for the team)

  asc.py key                prints the Key ID of the valid .p8
  asc.py finalize <build>   waits until both builds (iOS and macOS) are processed and adds them to the
                            internal TestFlight groups; without this step a build is uploaded but never
                            reaches the testers
"""
import base64, glob, json, os, re, socket, sys, time, urllib.error, urllib.request

API = "https://api.appstoreconnect.apple.com"

try:
    from cryptography.hazmat.primitives import hashes
    from cryptography.hazmat.primitives.asymmetric import ec
    from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature
    from cryptography.hazmat.primitives.serialization import load_pem_private_key
except ImportError:
    sys.exit("Needs 'cryptography' (pip3 install cryptography)")


def b64(d):
    return base64.urlsafe_b64encode(d).rstrip(b"=")


def make_token(kid, path):
    issuer = os.environ.get("ASC_API_ISSUER") or sys.exit("Set ASC_API_ISSUER to your App Store Connect Issuer ID")
    key = load_pem_private_key(open(path, "rb").read(), password=None)
    header = b64(json.dumps({"alg": "ES256", "kid": kid, "typ": "JWT"}).encode())
    payload = b64(json.dumps({"iss": issuer, "exp": int(time.time()) + 1200, "aud": "appstoreconnect-v1"}).encode())
    r, s = decode_dss_signature(key.sign(header + b"." + payload, ec.ECDSA(hashes.SHA256())))
    return (header + b"." + payload + b"." + b64(r.to_bytes(32, "big") + s.to_bytes(32, "big"))).decode()


def api(token, method, path, body=None, tries=6):
    """Returns (status, json). Retries when the connection cannot be opened (the request never left)."""
    data = json.dumps(body).encode() if body is not None else None
    for attempt in range(tries):
        req = urllib.request.Request(path if path.startswith("http") else API + path, data=data, method=method,
                                     headers={"Authorization": "Bearer " + token, "Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=15 if method == "GET" else 90) as r:
                raw = r.read()
                return r.status, (json.loads(raw) if raw else {})
        except urllib.error.HTTPError as e:
            raw = e.read().decode(errors="replace")
            try:
                return e.code, json.loads(raw)
            except ValueError:
                return e.code, raw[:500]
        except (urllib.error.URLError, socket.timeout, TimeoutError) as e:
            if method != "GET" and not isinstance(getattr(e, "reason", None), (TimeoutError, socket.timeout, OSError)):
                raise
            time.sleep(1 + attempt)
    sys.exit(f"network: {method} {path} unreachable")


def find_key():
    """Different Macs hold different .p8 files (also of other teams): try each one."""
    for path in sorted(glob.glob(os.path.expanduser("~/.appstoreconnect/private_keys/AuthKey_*.p8"))):
        kid = re.search(r"AuthKey_(\w+)\.p8", path).group(1)
        token = make_token(kid, path)
        st, _ = api(token, "GET", "/v1/apps?limit=1")
        if st == 200:
            return kid, token
        print(f"  {kid}: skipped ({st})", file=sys.stderr)
    sys.exit("No valid App Store Connect key for the team on this machine.")


BUNDLE_ID = "com.notesquick.app"


def finalize(version):
    _, token = find_key()
    st, apps = api(token, "GET", f"/v1/apps?filter[bundleId]={BUNDLE_ID}")
    if st != 200 or not apps["data"]:
        sys.exit(f"App {BUNDLE_ID} not found on App Store Connect.")
    app_id = apps["data"][0]["id"]
    builds = []
    for _ in range(60):  # up to 30 minutes
        st, d = api(token, "GET", f"/v1/builds?filter[app]={app_id}&filter[version]={version}"
                                  "&fields[builds]=version,processingState")
        builds = d["data"] if st == 200 else []
        states = [b["attributes"]["processingState"] for b in builds]
        print(f"build {version}: {states or 'not visible yet'}", flush=True)
        if len(builds) >= 2 and all(s != "PROCESSING" for s in states):
            break
        time.sleep(30)
    valid = [b for b in builds if b["attributes"]["processingState"] == "VALID"]
    if len(valid) < 2:
        sys.exit("Builds not ready: check App Store Connect > TestFlight.")
    st, groups = api(token, "GET", f"/v1/apps/{app_id}/betaGroups")
    for group in groups["data"]:
        if not group["attributes"].get("isInternalGroup") or group["attributes"].get("hasAccessToAllBuilds"):
            continue
        st, resp = api(token, "POST", f"/v1/betaGroups/{group['id']}/relationships/builds",
                       {"data": [{"type": "builds", "id": b["id"]} for b in valid]})
        print(f"added to group '{group['attributes']['name']}' ->", st, resp if st >= 300 else "")
    print("Ready on TestFlight.")


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "key":
        print(find_key()[0])
    elif len(sys.argv) >= 3 and sys.argv[1] == "finalize":
        finalize(sys.argv[2])
    else:
        sys.exit(__doc__)
