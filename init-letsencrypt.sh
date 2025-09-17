#!/bin/bash

set -e

# Source the .env file
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

if ! command -v docker >/dev/null 2>&1; then
    echo "Error: Docker is not installed." >&2
    exit 1
fi

if ! command -v docker-compose >/dev/null 2>&1 && ! command -v "docker compose" >/dev/null 2>&1; then
    echo "Error: Docker Compose is not installed." >&2
    exit 1
fi

domains=(${APP_DOMAIN})
echo "Domains: ${domains[*]}"

rsa_key_size=2048
data_path="./nginx/certbot"
email="${SSL_EMAIL:-}" # Adding a valid address is recommended
staging=1 # Set to 0 for production

# Create necessary folders
mkdir -p "$data_path/conf/live/$domains"

# Download recommended TLS parameters
if [ ! -f "$data_path/conf/options-ssl-nginx.conf" ] || [ ! -f "$data_path/conf/ssl-dhparams.pem" ]; then
    echo "### Downloading recommended TLS parameters ..."
    mkdir -p "$data_path/conf"
    curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf \
        -o "$data_path/conf/options-ssl-nginx.conf"
    curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem \
        -o "$data_path/conf/ssl-dhparams.pem"
fi

# Create dummy certificate
echo "### Creating dummy certificate for ${domains[*]} ..."
path="/etc/letsencrypt/live/$domains"
docker compose run --rm --entrypoint "\
  openssl req -x509 -nodes -newkey rsa:$rsa_key_size -days 1 \
    -keyout '$path/privkey.pem' \
    -out '$path/fullchain.pem' \
    -subj '/CN=localhost'" certbot

# Start Nginx
echo "### Starting Nginx ..."
docker compose up -d nginx

# Delete dummy certificate
echo "### Deleting dummy certificate ..."
docker compose run --rm --entrypoint "\
  rm -Rf /etc/letsencrypt/live/$domains && \
  rm -Rf /etc/letsencrypt/archive/$domains && \
  rm -Rf /etc/letsencrypt/renewal/$domains.conf" certbot

# Prepare domain arguments for certbot
domain_args=""
for domain in "${domains[@]}"; do
    domain_args="$domain_args -d $domain"
done

# Email argument
email_arg="--register-unsafely-without-email"
[ -n "$email" ] && email_arg="--email $email"

# Staging argument
staging_arg=""
[ "$staging" -ne 0 ] && staging_arg="--staging"

# Request Let's Encrypt certificate
echo "### Requesting Let's Encrypt certificate ..."
docker compose run --rm --entrypoint "\
  certbot certonly --webroot -w /var/www/certbot \
    $staging_arg \
    $email_arg \
    $domain_args \
    --rsa-key-size $rsa_key_size \
    --agree-tos \
    --force-renewal" certbot

# Reload Nginx to use new certificates
echo "### Reloading Nginx ..."
docker compose exec nginx nginx -s reload

echo "### All done!"
