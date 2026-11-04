#!/usr/bin/env python3
"""Build the place, upload as a Saved version, run a Luau probe via Open Cloud.

Key: env ROBLOX_OC_KEY, else file at ROBLOX_OC_KEY_FILE (default ~/.secrets/roblox_oc_key).
The key is never printed.
"""
import json, os, subprocess, sys, time, urllib.request, urllib.error

UNIVERSE = os.environ.get("ROBLOX_UNIVERSE_ID", "10774638719")
PLACE = os.environ.get("ROBLOX_PLACE_ID", "93557582559322")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
API = "https://apis.roblox.com"


def key():
    k = os.environ.get("ROBLOX_OC_KEY", "").strip()
    if not k:
        path = os.path.expanduser(os.environ.get("ROBLOX_OC_KEY_FILE", "~/.secrets/roblox_oc_key"))
        with open(path) as f:
            k = f.read().strip()
    if not k:
        sys.exit("no Open Cloud key")
    return k


KEY = key()


def req(method, url, body=None, ctype="application/json", tries=5):
    for i in range(tries):
        r = urllib.request.Request(url, data=body, method=method,
                                   headers={"x-api-key": KEY, "Content-Type": ctype,
                                            "User-Agent": "bahce-simulator-opencloud-test/1.0"})
        try:
            with urllib.request.urlopen(r, timeout=120) as resp:
                return json.loads(resp.read() or b"{}")
        except urllib.error.HTTPError as e:
            msg = e.read().decode(errors="replace")[:500]
            if e.code in (429, 500, 502, 503, 504) and i < tries - 1:
                time.sleep(2 ** i * 2)
                continue
            sys.exit(f"HTTP {e.code} {method} {url.split('?')[0]}: {msg}")


def main():
    out = os.path.join(ROOT, "build", "BahceSimulator.rbxl")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    subprocess.run(["rojo", "build", "-o", out], cwd=ROOT, check=True)

    with open(out, "rb") as f:
        v = req("POST", f"{API}/universes/v1/{UNIVERSE}/places/{PLACE}/versions?versionType=Saved",
                f.read(), "application/octet-stream")["versionNumber"]
    print(f"Uploaded saved version {v}")

    with open(os.path.join(ROOT, "scripts", "opencloud_probe.luau")) as f:
        script = f.read()
    base = f"{API}/cloud/v2/universes/{UNIVERSE}/places/{PLACE}/versions/{v}/luau-execution-session-tasks"
    task = req("POST", base, json.dumps({"script": script, "timeout": "120s"}).encode())
    path = task["path"]
    print(f"Task {path}")

    deadline = time.time() + 300
    while task.get("state") not in ("COMPLETE", "FAILED", "CANCELLED"):
        if time.time() > deadline:
            sys.exit("timed out waiting for task")
        time.sleep(3)
        task = req("GET", f"{API}/cloud/v2/{path}")
    print(f"Task state: {task['state']}")

    logs = req("GET", f"{API}/cloud/v2/{path}/logs?maxPageSize=100")
    print("---- server logs ----")
    for page in logs.get("luauExecutionSessionTaskLogs", []):
        for m in page.get("messages", []):
            print("  " + m)

    if task["state"] != "COMPLETE":
        print("FAIL:", json.dumps(task.get("error", {})))
        sys.exit(1)
    results = task.get("output", {}).get("results", [])
    summary = json.loads(results[0]) if results else {}
    print(f"---- report (init: {summary.get('initMode')}) ----")
    for c in summary.get("checks", []):
        print(f"  [{'PASS' if c['pass'] else 'FAIL'}] {c['name']}  {c['detail']}")
    print(f"{summary.get('passed')}/{summary.get('total')} checks passed")
    sys.exit(0 if summary.get("ok") else 1)


if __name__ == "__main__":
    main()
