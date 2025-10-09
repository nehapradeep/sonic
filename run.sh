#!/usr/bin/env bash
# run.sh - start a mock SONiC container (nginx + Flask mock REST server) and a Debian client
# Designed for macOS Docker Desktop; safe, lab-only.
set -e

NETWORK="sonic-net"
SONIC_IMAGE="nginx:alpine"        # force mock server on macOS
SONIC_CONTAINER="sonic"
CLIENT_CONTAINER="client"
REPO_MOUNT="$(pwd)"

echo "[*] Ensure docker network exists: ${NETWORK}"
docker network inspect ${NETWORK} >/dev/null 2>&1 || docker network create ${NETWORK}

echo "[*] Remove old containers if present"
docker rm -f ${SONIC_CONTAINER} ${CLIENT_CONTAINER} >/dev/null 2>&1 || true

echo "[*] Pulling mock SONiC image (${SONIC_IMAGE}) and client (debian:12)"
docker pull ${SONIC_IMAGE} >/dev/null 2>&1 || true
docker pull debian:12 >/dev/null 2>&1 || true

echo "[*] Starting mock SONiC container (privileged so we can demo iptables)"
docker run -dit --name ${SONIC_CONTAINER} --network ${NETWORK} --privileged ${SONIC_IMAGE} sh -c "sleep infinity"

echo "[*] Starting client container and mounting repo at /work"
docker run -dit --name ${CLIENT_CONTAINER} --network ${NETWORK} -v "${REPO_MOUNT}":/work debian:12 bash

echo "[*] Installing minimal tools inside client (best-effort; may take a minute)"
docker exec -it ${CLIENT_CONTAINER} bash -lc "apt-get update >/dev/null || true; DEBIAN_FRONTEND=noninteractive apt-get install -y python3 python3-venv python3-pip curl tcpdump iputils-ping >/dev/null || true"
# create venv to avoid PEP668 issues and install requests
docker exec -it ${CLIENT_CONTAINER} bash -lc "python3 -m venv /root/venv && /root/venv/bin/pip install --upgrade pip >/dev/null 2>&1 || true; /root/venv/bin/pip install requests >/dev/null 2>&1 || true"

# Install Python + Flask in the SONIC container (alpine uses apk)
echo "[*] Installing Python & Flask inside mock SONiC container"
docker exec -it ${SONIC_CONTAINER} sh -lc "apk add --no-cache python3 py3-pip >/dev/null || true; pip3 install flask >/dev/null 2>&1 || true"

# Write the mock server (mock_sonic.py) into the SONIC container and start it
echo "[*] Installing mock REST server inside SONiC container (port 8080)"
docker exec -it ${SONIC_CONTAINER} sh -lc "cat > /mock_sonic.py <<'PY'
from flask import Flask, jsonify, request
app = Flask(__name__)

# basic unauthenticated telemetry endpoint (GET)
@app.route('/restconf/data', methods=['GET'])
def data():
    return jsonify({
        'hostname': 'mock-sonic',
        'version': '0.0-mock',
        'interfaces': [
            {'name':'Ethernet0','admin':'up','ip':'10.0.0.1/24'},
            {'name':'Ethernet1','admin':'down','ip':None}
        ],
        'vlans': [{'id':10,'name':'VLAN10'}],
        'topology': [{'neighbor':'leaf1','port':'Ethernet0'}]
    })

# simple "config write" POST endpoint that simulates requiring auth (we won't enforce it here)
@app.route('/restconf/config', methods=['POST'])
def config():
    # echo back posted JSON for demonstrative purposes (non-destructive)
    payload = request.get_json(silent=True) or {}
    return jsonify({'status':'accepted','payload':payload})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
PY
"

# start the mock server in background inside SONIC container
docker exec -d ${SONIC_CONTAINER} sh -lc "python3 /mock_sonic.py &> /tmp/mock_sonic.log & echo \$! >/tmp/mock_sonic.pid"

echo
echo "[*] Containers started:"
docker ps --filter "name=${SONIC_CONTAINER}" --filter "name=${CLIENT_CONTAINER}"
SONIC_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${SONIC_CONTAINER})
CLIENT_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${CLIENT_CONTAINER})
echo "SONIC container IP: ${SONIC_IP}"
echo "CLIENT container IP: ${CLIENT_IP}"
echo
echo "To probe: docker exec -it ${CLIENT_CONTAINER} bash"
echo "Inside client, activate venv: source /root/venv/bin/activate"
echo "Run: python3 /work/sonic_check.py ${SONIC_IP}"
echo
echo "To harden (demo): docker exec -it ${SONIC_CONTAINER} sh -c '/work/harden_sonic.sh ${CLIENT_IP}'"
