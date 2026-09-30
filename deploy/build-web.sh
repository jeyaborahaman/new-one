#!/usr/bin/env bash
# Build the Flutter web app on the server and serve it over HTTPS. Run as root AFTER setup-vps.sh:
#   bash /srv/jeyabo/deploy/build-web.sh                       # serves https://app.jeyabo.com, API https://api.jeyabo.com
#   WEB_DOMAIN=jeyabo.com API_URL=https://api.jeyabo.com bash /srv/jeyabo/deploy/build-web.sh
# The DNS A record for WEB_DOMAIN must already point at this server.
set -euo pipefail
WEB_DOMAIN="${WEB_DOMAIN:-app.jeyabo.com}"
API_URL="${API_URL:-https://api.${WEB_DOMAIN#app.}}"
EMAIL="${EMAIL:-admin@${WEB_DOMAIN#app.}}"
APP=/srv/jeyabo; FLUTTER=/opt/flutter; FLUTTER_VERSION=3.47.5; WEBROOT=/var/www/jeyabo

echo "== flutter sdk"
apt-get install -y curl git unzip xz-utils zip >/dev/null
if [ ! -x $FLUTTER/bin/flutter ]; then
  curl -fsSL -o /tmp/flutter.tar.xz "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  tar -xf /tmp/flutter.tar.xz -C /opt && rm /tmp/flutter.tar.xz
fi
chown -R deploy:deploy $FLUTTER

echo "== build web ($API_URL)"
sudo -u deploy git -C $APP pull --ff-only
sudo -u deploy bash -c "export PATH=$FLUTTER/bin:\$PATH CI=true; cd $APP/apps/mobile_web && flutter config --no-analytics >/dev/null && flutter pub get && flutter build web --release --dart-define=API_URL=$API_URL"

echo "== publish to $WEBROOT"
mkdir -p $WEBROOT && rm -rf "${WEBROOT:?}"/* && cp -r $APP/apps/mobile_web/build/web/. $WEBROOT/
chown -R www-data:www-data $WEBROOT

echo "== nginx"
cat > /etc/nginx/sites-available/jeyabo-web <<NGINX
server {
  listen 80; server_name $WEB_DOMAIN;
  root $WEBROOT; index index.html;
  add_header X-Content-Type-Options nosniff always;
  add_header Referrer-Policy strict-origin-when-cross-origin always;
  gzip on; gzip_types text/css application/javascript application/json image/svg+xml application/wasm;
  # The app shell and service workers must never be cached, or users keep an old version.
  location ~* (^/index\.html\$|^/flutter_service_worker\.js\$|^/flutter_bootstrap\.js\$|^/firebase-messaging-sw\.js\$|^/version\.json\$) { add_header Cache-Control "no-cache"; add_header X-Content-Type-Options nosniff always; try_files \$uri =404; }
  location / { add_header Cache-Control "public, max-age=3600"; add_header X-Content-Type-Options nosniff always; try_files \$uri \$uri/ /index.html; }  # add_header in a location replaces the server-level ones, so it is repeated
}
NGINX
ln -sf /etc/nginx/sites-available/jeyabo-web /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx
certbot --nginx -d "$WEB_DOMAIN" --non-interactive --agree-tos -m "$EMAIL" --redirect || echo "TLS skipped: point the DNS A record for $WEB_DOMAIN to this server, then re-run this script."

echo "== let the API accept browser calls from this site"
ENV_FILE=$APP/apps/api/.env
if grep -q '^CORS_ORIGINS=' $ENV_FILE; then sed -i "s|^CORS_ORIGINS=.*|CORS_ORIGINS=https://$WEB_DOMAIN|" $ENV_FILE; else echo "CORS_ORIGINS=https://$WEB_DOMAIN" >> $ENV_FILE; fi
sudo -u deploy pm2 reload jeyabo-api --update-env
echo "== done: https://$WEB_DOMAIN"
