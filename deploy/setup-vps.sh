#!/usr/bin/env bash
# Jeyabo API: first-time setup on a fresh Ubuntu 22.04/24.04 VPS. Run as root:
#   DOMAIN=api.example.com REPO=https://github.com/jeyaborahaman/new-one.git BRANCH=claude/jeyabo-social-network-fs3aq0 bash setup-vps.sh
set -euo pipefail
: "${DOMAIN:?set DOMAIN}"; : "${REPO:?set REPO}"; BRANCH="${BRANCH:-main}"
APP=/srv/jeyabo

echo "== packages"
apt-get update -y && apt-get install -y curl git ufw fail2ban nginx redis-server mysql-server certbot python3-certbot-nginx
curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && apt-get install -y nodejs
npm i -g pm2

echo "== firewall (SSH, HTTP, HTTPS only)"
ufw default deny incoming; ufw allow OpenSSH; ufw allow 80,443/tcp; ufw --force enable

ENV_FILE=$APP/apps/api/.env
FIRST_RUN=0; [ -f "$ENV_FILE" ] || FIRST_RUN=1   # secrets are generated once; re-running never rotates them

if [ $FIRST_RUN = 1 ]; then
  echo "== redis: localhost only, password"
  REDIS_PASS=$(openssl rand -hex 24)
  sed -i "s/^# *requirepass .*/requirepass $REDIS_PASS/; s/^bind .*/bind 127.0.0.1 ::1/" /etc/redis/redis.conf
  systemctl restart redis-server

  echo "== mysql: database + least-privilege user"
  DB_PASS=$(openssl rand -hex 24)
  mysql -e "CREATE DATABASE IF NOT EXISTS jeyabo CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE USER IF NOT EXISTS 'jeyabo'@'localhost' IDENTIFIED BY '$DB_PASS';
ALTER USER 'jeyabo'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON jeyabo.* TO 'jeyabo'@'localhost'; FLUSH PRIVILEGES;"
fi

echo "== app"
id deploy &>/dev/null || adduser --disabled-password --gecos "" deploy
if [ -d $APP/.git ]; then sudo -u deploy git -C $APP pull --ff-only; else git clone --branch "$BRANCH" "$REPO" $APP; fi
chown -R deploy:deploy $APP
cd $APP/apps/api
sudo -u deploy npm ci --omit=dev
if [ $FIRST_RUN = 1 ]; then
  cp .env.example .env
  sed -i "s|^NODE_ENV=.*|NODE_ENV=production|; s|^DB_PASSWORD=.*|DB_PASSWORD=$DB_PASS|; s|^JWT_SECRET=.*|JWT_SECRET=$(openssl rand -hex 48)|; s|^REDIS_URL=.*|REDIS_URL=redis://:$REDIS_PASS@127.0.0.1:6379|; s|^CORS_ORIGINS=.*|CORS_ORIGINS=https://$DOMAIN|; s|^API_PUBLIC_URL=.*||" .env
  echo "API_PUBLIC_URL=https://$DOMAIN" >> .env
  chown deploy:deploy .env; chmod 600 .env
fi
sudo -u deploy npm run migrate
sudo -u deploy pm2 startOrReload ecosystem.config.js --update-env
sudo -u deploy pm2 save
env PATH=$PATH pm2 startup systemd -u deploy --hp /home/deploy | tail -1 | bash

echo "== nginx + TLS"
sed "s/api.example.com/$DOMAIN/g" $APP/deploy/nginx-api.conf > /etc/nginx/sites-available/jeyabo-api
ln -sf /etc/nginx/sites-available/jeyabo-api /etc/nginx/sites-enabled/; rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx
certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "${EMAIL:-admin@$DOMAIN}" --redirect || echo "TLS skipped: point the DNS A record for $DOMAIN to this server, then re-run certbot."

echo "== done"; curl -s http://127.0.0.1:4000/health; echo
echo "Next: edit $APP/apps/api/.env (R2, FCM, Agora, Google/Apple keys), then: sudo -u deploy pm2 reload jeyabo-api --update-env"
