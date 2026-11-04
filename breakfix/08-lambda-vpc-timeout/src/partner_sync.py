"""partner-sync: sends order updates to a partner's public API.

The partner only accepts calls from allow-listed IP addresses, so the function
starts by looking up the public IP address its traffic leaves from.
"""

import urllib.request

CHECKIP_URL = "https://checkip.amazonaws.com"


def handler(event, context):
    # No explicit timeout, like many real HTTP clients.
    with urllib.request.urlopen(CHECKIP_URL) as response:
        egress_ip = response.read().decode().strip()

    print(f"outbound traffic leaves from {egress_ip}")
    return {"egress_ip": egress_ip, "status": "ready to sync"}
