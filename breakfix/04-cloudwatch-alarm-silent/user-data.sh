#!/bin/bash
# orders-cache: an in-memory cache service, monitored by the CloudWatch agent.
set -euo pipefail

dnf install -y amazon-cloudwatch-agent

cat >/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'JSON'
{
  "agent": {
    "metrics_collection_interval": 60
  },
  "metrics": {
    "namespace": "CWAgent",
    "append_dimensions": {
      "ImageId": "${aws:ImageId}",
      "InstanceId": "${aws:InstanceId}",
      "InstanceType": "${aws:InstanceType}"
    },
    "metrics_collected": {
      "mem": {
        "measurement": ["mem_used_percent"]
      }
    }
  }
}
JSON

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

# The cache has grown to about 500 MiB, which is well over 60 % of a t4g.micro's memory.
cat >/usr/local/bin/orders-cache <<'PY'
#!/usr/bin/python3
import time

cache = b"x" * (500 * 1024 * 1024)
while True:
    time.sleep(3600)
PY
chmod 755 /usr/local/bin/orders-cache

cat >/etc/systemd/system/orders-cache.service <<'UNIT'
[Unit]
Description=orders-cache (simulated in-memory cache)
After=network-online.target

[Service]
ExecStart=/usr/local/bin/orders-cache
Restart=always
DynamicUser=yes

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now orders-cache.service
