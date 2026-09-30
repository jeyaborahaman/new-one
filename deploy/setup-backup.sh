#!/usr/bin/env bash
# Nightly MySQL backup for Jeyabo. Run once as root:  bash /srv/jeyabo/deploy/setup-backup.sh
# Keeps 14 daily compressed dumps in /var/backups/jeyabo. Copy them OFF this server too (see the note at the end):
# a backup on the same disk does not protect you from losing the server.
set -euo pipefail
DIR=/var/backups/jeyabo; KEEP_DAYS=14
mkdir -p $DIR && chmod 700 $DIR

cat > /usr/local/bin/jeyabo-backup <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
DIR=/var/backups/jeyabo; KEEP_DAYS=14
STAMP=$(date -u +%Y%m%d-%H%M%S)
OUT="$DIR/jeyabo-$STAMP.sql.gz"
# --single-transaction gives a consistent snapshot without locking the live app. Root talks to MySQL over the local socket.
mysqldump --single-transaction --routines --triggers --no-tablespaces jeyabo | gzip -9 > "$OUT.tmp"
# refuse to keep an empty or truncated dump
[ "$(gzip -dc "$OUT.tmp" | tail -c 200 | grep -c 'Dump completed')" -ge 1 ] || { rm -f "$OUT.tmp"; echo "backup incomplete" >&2; exit 1; }
mv "$OUT.tmp" "$OUT"; chmod 600 "$OUT"
find "$DIR" -name 'jeyabo-*.sql.gz' -mtime +$KEEP_DAYS -delete
echo "ok $OUT $(du -h "$OUT" | cut -f1)"
SCRIPT
chmod 700 /usr/local/bin/jeyabo-backup

cat > /etc/cron.d/jeyabo-backup <<'CRON'
# every night at 03:10 UTC
10 3 * * * root /usr/local/bin/jeyabo-backup >> /var/log/jeyabo-backup.log 2>&1
CRON
chmod 644 /etc/cron.d/jeyabo-backup

echo "== running one backup now to prove it works"
/usr/local/bin/jeyabo-backup
ls -lh $DIR
cat <<'NOTE'

Done. Backups run nightly at 03:10 UTC; log: /var/log/jeyabo-backup.log
To restore:   gunzip -c /var/backups/jeyabo/jeyabo-<date>.sql.gz | mysql jeyabo
IMPORTANT: also turn on Hostinger's "Snapshot & backups" for this VPS (hPanel > VPS > Snapshot & backups),
or copy /var/backups/jeyabo to another place (your computer, or object storage) regularly.
NOTE
