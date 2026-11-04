#!/bin/bash
# inventory-api: serves current stock levels on port 8080.
set -euo pipefail

mkdir -p /var/www/inventory
cat >/var/www/inventory/stock.json <<'JSON'
{"sku": "TSHIRT-RED-M", "in_stock": 42}
JSON

cat >/etc/systemd/system/inventory-api.service <<'UNIT'
[Unit]
Description=inventory-api
After=network-online.target

[Service]
ExecStart=/usr/bin/python3 -m http.server 8080 --directory /var/www/inventory
Restart=always
DynamicUser=yes

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now inventory-api.service
