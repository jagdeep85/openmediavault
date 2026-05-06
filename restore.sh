#!/bin/bash
BACKUP_DIR="/srv/dev-disk-by-uuid-d9768db6-bc3b-43af-bf94-280f444566c1/omv-backups"

if [ -z "$1" ]; then
  echo "Available backups:"
  ls -lh $BACKUP_DIR/omv-config-*.tar.gz 2>/dev/null || echo "No backups found"
  echo ""
  echo "Usage: bash $BACKUP_DIR/restore.sh <backup-file.tar.gz>"
  exit 0
fi

BACKUP_FILE="$1"
[ ! -f "$BACKUP_FILE" ] && echo "ERROR: $BACKUP_FILE not found" && exit 1

echo "=== Restoring: $BACKUP_FILE ==="

echo "[1/4] Saving current state first..."
tar -czf "$BACKUP_DIR/pre-restore-$(date +%Y-%m-%d_%H%M).tar.gz"   /etc/openmediavault/config.xml /etc/fstab /etc/exports   /etc/samba/smb.conf /etc/monit/conf.d/   /etc/systemd/journald.conf.d/ /etc/default/minidlna   /etc/postfix/main.cf /etc/ssh/sshd_config 2>/dev/null
echo "   Current state saved."

echo "[2/4] Extracting backup..."
tar -xzf "$BACKUP_FILE" -C /
echo "   Done."

echo "[3/4] Applying OMV config..."
omv-salt deploy run --all 2>/dev/null && echo "   Applied." || echo "   WARNING: check omv-salt output manually"

echo "[4/4] Restarting services..."
systemctl daemon-reload
systemctl restart systemd-journald nginx php8.2-fpm openmediavault-engined smbd 2>/dev/null
systemctl reload monit 2>/dev/null
echo "   Done."

echo ""
echo "=== Restore complete ==="
echo "Pre-restore snapshot saved in: $BACKUP_DIR"
