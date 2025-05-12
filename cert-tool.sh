#!/usr/bin/env bash
# certbot_webmail_setup.sh
# Interactive script to obtain SSL certificates via Certbot
# for multiple web+mail domains using webroot plugin.

set -euo pipefail

# Functions
confirm() {
  # Prompt yes/no
  read -rp "$1 [y/N]: " ans
  [[ "$ans" =~ ^[Yy] ]] && return 0 || return 1
}

# Intro
cat << 'EOF'
This script will help you obtain Let's Encrypt certificates for your websites
and include a mail service SAN for mail services. It uses the webroot plugin.
To avoid rate limits, you can test with --staging first.
EOF

# Ask for email
read -rp "Enter your email for Let's Encrypt registration: " LE_EMAIL

# Choose staging or production
echo
echo "Choose mode:"
echo "1) Staging (for testing, no production certs)"
echo "2) Production (live certificates)"
read -rp "Select [1-2]: " MODE
if [[ "$MODE" == "1" ]]; then
  CERTBOT_SERVER="--staging"
  echo "Running in staging mode. No rate limit concerns."
else
  CERTBOT_SERVER=""
  echo "Running in production mode. Ensure you respect rate limits."
fi

echo
echo "You will be prompted for each website directory and its domains."

doing=1
while true; do
  echo
echo "--- Site #$doing ---"
  # Webroot directory
  read -rp "Enter webroot directory (e.g. /var/www/example.com): " WEBROOT
  if [[ ! -d "$WEBROOT" ]]; then
    echo "Directory does not exist. Please enter a valid path." >&2
    continue
  fi

  # Primary domain
  read -rp "Enter primary domain (e.g. example.com): " DOMAIN
  DOMAIN_CLEAN=${DOMAIN,,}

  # Mail host customization
  default_mail="mail.$DOMAIN_CLEAN"
  read -rp "Enter mail host (e.g. mail.$DOMAIN_CLEAN) [$default_mail]: " MAILHOST
  MAILHOST=${MAILHOST:-$default_mail}

  # Build domains list
  DOMAINS="-d $DOMAIN_CLEAN -d $MAILHOST"

  echo
echo "About to request cert for:"
echo "  Web: $DOMAIN_CLEAN"
echo "  Mail: $MAILHOST"
echo "Using webroot: $WEBROOT"
  confirm "Proceed?" || { echo "Skipping this site."; ((doing++)); continue; }

  # Run certbot
  sudo certbot certonly \
    $CERTBOT_SERVER \
    --non-interactive \
    --agree-tos \
    --email "$LE_EMAIL" \
    --webroot -w "$WEBROOT" \
    $DOMAINS

  echo "Certificate obtained for $DOMAIN_CLEAN and $MAILHOST."
  ((doing++))
  echo
  if ! confirm "Would you like to add another site?"; then
    break
  fi
done

echo
echo "All done. Your certificates are in /etc/letsencrypt/live/."
echo "Remember to reload your web and mail services to use the new certs."
