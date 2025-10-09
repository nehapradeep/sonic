#!/usr/bin/env python3
"""
sonic_check.py - safe, read-only probes for the mock SONiC REST endpoints.
Usage: python3 sonic_check.py <SONIC_IP>
This script is intentionally non-destructive. It prints outputs to stdout.
"""

import sys, json, socket, requests

if len(sys.argv) < 2:
    print("Usage: python3 sonic_check.py <SONIC_IP>")
    sys.exit(2)

SONIC = sys.argv[1]
REST_ROOT = f"http://{SONIC}:8080/"
REST_DATA = f"http://{SONIC}:8080/restconf/data"
REST_CONFIG = f"http://{SONIC}:8080/restconf/config"
GRPC_PORT = 57400

def check_http(url):
    try:
        r = requests.get(url, timeout=4)
        return (r.status_code, r.text[:800])
    except Exception as e:
        return ("error", str(e))

def check_grpc(host, port=GRPC_PORT):
    s = socket.socket()
    s.settimeout(2.0)
    try:
        s.connect((host, port))
        s.close()
        return True
    except Exception as e:
        return False

print(f"[+] Probing mock SONiC at {SONIC}")
print("----")
print("REST root:", REST_ROOT)
status, body = check_http(REST_ROOT)
print("Result:", status)
if isinstance(body, str) and len(body) > 0:
    print("Body (truncated):")
    print(body[:400])
print("----")
print("RESTCONF telemetry:", REST_DATA)
status, body = check_http(REST_DATA)
print("Result:", status)
try:
    j = json.loads(body) if isinstance(body, str) else None
    if j:
        print("JSON (pretty):")
        print(json.dumps(j, indent=2))
except Exception:
    pass
print("----")
print("gRPC (port probe):", GRPC_PORT)
print("gRPC port open?:", check_grpc(SONIC, GRPC_PORT))
print("----")
print("Non-destructive POST (config simulation) - will POST a small JSON to /restconf/config and print response")
try:
    r = requests.post(REST_CONFIG, json={"demo":"test"}, timeout=4)
    print("POST status:", r.status_code)
    print("POST body (truncated):", r.text[:400])
except Exception as e:
    print("POST error:", e)

print("\nNote: This probe is safe and intended for lab use only.")
