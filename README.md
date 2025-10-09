SONiC mock testbed (macOS Docker) - quick start
-----------------------------------------------

Files:
 - run.sh           : start mock SONiC + client containers; mounts repo into client
 - sonic_check.py   : safe probes (requires requests)
 - harden_sonic.sh  : iptables demo (run inside sonic container)
 - mock_sonic.py    : Flask mock server (injected by run.sh)

Setup & run:
1. Open terminal and cd to this project folder.
2. Make scripts executable (one-time):
   chmod +x run.sh sonic_check.py harden_sonic.sh

3. Start the environment:
   ./run.sh

   Expected output shows two containers: "sonic" and "client" and prints their IPs.

4. Enter client shell:
   docker exec -it client bash

5. Inside client, activate the venv:
   source /root/venv/bin/activate

6. Run the probe against the printed SONIC IP:
   python3 /work/sonic_check.py <SONIC_IP>

   Example output (mock server):
     RESTCONF telemetry: 200
     JSON (pretty):
     {
       "hostname": "mock-sonic",
       "interfaces": [...]
     }

7. Capture traffic (on host) for evidence:
   #### Start tcpdump in client and write to mounted repo
   docker exec -d client bash -lc "tcpdump -i any -w /work/sonic_test_before.pcap tcp port 8080"
   #### run probe
   docker exec -it client bash -lc "source /root/venv/bin/activate && python3 /work/sonic_check.py <SONIC_IP>"
   #### stop tcpdump
   docker exec -it client bash -lc "pkill tcpdump || true"

   The file sonic_test_before.pcap will be in the host project folder.

8. Harden the mock SONiC to allow only the client IP:
   From host (replace with printed CLIENT_IP):
   docker exec -it sonic sh -c "/work/harden_sonic.sh <CLIENT_IP>"

9. Re-run the probe (after hardening) and capture pcap again:
   sonic_test_after.pcap

Notes:
 - Everything here is lab-only and non-destructive.

