#!/bin/bash
set -e

PORT=2777

if [ -z "$uuid" ]; then
    uuid=$(uuidgen)
fi

cat > /tmp/config.json <<EOF
{
  "inbounds": [{
    "type": "vless",
    "listen": "0.0.0.0",
    "listen_port": $PORT,
    "users": [{"uuid": "$uuid", "flow": ""}],
    "transport": { "type": "ws", "path": "/vless" }
  }],
  "outbounds": [{"type": "direct"}]
}
EOF

echo "=========================================="
echo "  UUID: $uuid"
echo "  Port: $PORT   Path: /vless"
echo "=========================================="

exec sing-box run -c /tmp/config.json
```
