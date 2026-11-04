#!/bin/bash
# Transcoding worker. The simulated job keeps one of the two vCPUs fully busy,
# so each worker sits at roughly 50 % CPU.
set -euo pipefail

cat >/usr/local/bin/transcoder <<'PY'
#!/usr/bin/python3
import hashlib

chunk = b"x" * (1024 * 1024)
while True:
    hashlib.sha256(chunk).digest()
PY
chmod 755 /usr/local/bin/transcoder

cat >/etc/systemd/system/transcoder.service <<'UNIT'
[Unit]
Description=Video transcoding worker (simulated)
After=network-online.target

[Service]
ExecStart=/usr/local/bin/transcoder
Restart=always
DynamicUser=yes

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now transcoder.service
