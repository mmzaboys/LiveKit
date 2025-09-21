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
  enabled: true
  domain: ${LIVEKIT_DOMAIN}
  cert_file: /etc/letsencrypt/live/${LIVEKIT_DOMAIN}/fullchain.pem
  key_file: /etc/letsencrypt/live/${LIVEKIT_DOMAIN}/privkey.pem
  tls_port: 5349
  udp_port: 3478
prometheus_port: 6789
keys:
  ${LIVEKIT_API_KEY}: ${LIVEKIT_API_SECRET}
EOF

cat > "./config.yaml" <<EOF
api_key: ${LIVEKIT_API_KEY}
api_secret: ${LIVEKIT_API_SECRET}
ws_url: ws://localhost:7880
redis:
  address: localhost:6379
prometheus_port: 1001  
sip_port: 5060
rtp_port: 10000-20000
use_external_ip: true
logging:
  level: debug
EOF

cat > "./egress.yaml" <<EOF
redis:
    address: localhost:6379
prometheus_port: 1000
log_level: info    
api_key: ${LIVEKIT_API_KEY}
api_secret: ${LIVEKIT_API_SECRET}
ws_url: wss://${LIVEKIT_DOMAIN}
EOF

cat > "./nginx/secure/default.conf.template" <<EOF

listen 443 ssl;
    server_name ${LIVEKIT_DOMAIN};
    server_tokens off;
    client_max_body_size 20M;

    ssl_certificate /etc/letsencrypt/live/${LIVEKIT_DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${LIVEKIT_DOMAIN}/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
    location /rtc {
        proxy_pass http://localhost:7880;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 86400;
    }
    # HTTP proxy عادي
    location / {
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Url-Scheme $scheme;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Host $http_host;
        proxy_redirect off;
        proxy_pass http://localhost:7880; 
    }
    location /agent {
        proxy_pass http://localhost:7880/agent;
        proxy_http_version 1.1;

        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 86400s;
    }


}
EOF