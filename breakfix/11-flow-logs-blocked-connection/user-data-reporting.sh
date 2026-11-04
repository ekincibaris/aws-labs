#!/bin/bash
# reporting-01: runs the stock report, which calls inventory-api.
# In production it runs nightly; in this lab it runs every minute.
set -euo pipefail

cat >/usr/local/bin/stock-report <<'SH'
#!/bin/bash
url=$(aws ssm get-parameter --region eu-central-1 --name /flowlogs-lab/inventory-url \
  --query Parameter.Value --output text)
if body=$(curl -sS --max-time 5 "$url" 2>&1); then
  echo "OK: fetched stock from $url: $body"
else
  echo "FAIL: could not fetch stock from $url: $body"
  exit 1
fi
SH
chmod 755 /usr/local/bin/stock-report

cat >/etc/systemd/system/stock-report.service <<'UNIT'
[Unit]
Description=Stock report

[Service]
Type=oneshot
ExecStart=/usr/local/bin/stock-report
UNIT

cat >/etc/systemd/system/stock-report.timer <<'UNIT'
[Unit]
Description=Run the stock report every minute

[Timer]
OnBootSec=1min
OnUnitActiveSec=1min

[Install]
WantedBy=timers.target
UNIT

systemctl daemon-reload
systemctl enable --now stock-report.timer
