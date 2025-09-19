#!/bin/bash

set -e

# Source the .env file
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi
cat > "./livekit.yaml" <<EOF
port: 7880
bind_addresses:
  - ""
rtc:
  tcp_port: 7881
  port_range_start: 50000
  port_range_end: 60000
  use_external_ip: true
  enable_loopback_candidate: false
redis:
  address: localhost:6379
turn:

  enabled: false

  domain: ${LIVEKIT_DOMAIN}
  cert_file: ./nginx/certbot/conf/live/${LIVEKIT_DOMAIN}/fullchain.pem
  key_file: ./nginx/certbot/conf/live/${LIVEKIT_DOMAIN}/privkey.pem
  tls_port: 5349
  udp_port: 3478

keys:
  ${LIVEKIT_API_KEY}: ${LIVEKIT_API_SECRET}
EOF

cat > "./config.yaml" <<EOF
api_key: ${LIVEKIT_API_KEY}
api_secret: ${LIVEKIT_API_SECRET}
ws_url: ws://localhost:7880
redis:
  address: localhost:6379
sip_port: 5060
rtp_port: 10000-20000
use_external_ip: true
logging:
  level: debug
EOF

cat > "./egress.yaml" <<EOF
redis:
    address: localhost:6379
api_key: ${LIVEKIT_API_KEY}
api_secret: ${LIVEKIT_API_SECRET}
ws_url: wss://${LIVEKIT_DOMAIN}
EOF