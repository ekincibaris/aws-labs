#!/bin/bash
# Orders shop: a static site served by a small Python web service.
set -euo pipefail

token=$(curl -sS -X PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
instance_id=$(curl -sS -H "X-aws-ec2-metadata-token: $token" http://169.254.169.254/latest/meta-data/instance-id)

mkdir -p /var/www/shop
cat >/var/www/shop/index.html <<HTML
<!doctype html>
<html><head><title>Orders shop</title></head>
<body><h1>Orders shop</h1><p>Served by ${instance_id}</p></body></html>
HTML
echo "ok" >/var/www/shop/health

cat >/etc/systemd/system/shop.service <<'UNIT'
[Unit]
Description=Orders shop web service
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/bin/python3 -m http.server 8080 --directory /var/www/shop
Restart=always
DynamicUser=yes

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now shop.service
