#!/bin/bash
# ============================================================
# OMV POST-REINSTALL RESTORE SCRIPT
# Run this AFTER a fresh OMV install on the USB boot drive.
#
# Usage:
#   bash restore-after-reinstall.sh <backup-file.tar.gz>
#
# What it does:
#   1. Restores config.xml (all OMV settings)
#   2. Adds RAID mount to fstab (preserves fresh boot entries)
#   3. Applies custom fixes (journal cap, minidlna, postfix)
#   4. Runs omv-salt to regenerate all OMV-managed configs
# ============================================================

BACKUP_DIR="/srv/dev-disk-by-uuid-d9768db6-bc3b-43af-bf94-280f444566c1/omv-backups"
RAID="/srv/dev-disk-by-uuid-d9768db6-bc3b-43af-bf94-280f444566c1"

if [ -z "$1" ]; then
  echo "Available backups:"
  ls -lh $BACKUP_DIR/omv-config-*.tar.gz 2>/dev/null
  echo ""
  echo "Usage: bash restore-after-reinstall.sh <backup-file.tar.gz>"
  exit 0
fi

BACKUP_FILE="$1"
[ ! -f "$BACKUP_FILE" ] && echo "ERROR: $BACKUP_FILE not found" && exit 1

TMPDIR=$(mktemp -d)
echo "=== Post-reinstall restore from: $BACKUP_FILE ==="
echo "Extracting to temp dir..."
tar -xzf "$BACKUP_FILE" -C "$TMPDIR"

# --- Step 1: Restore OMV config.xml ---
echo "[1/5] Restoring OMV config.xml..."
cp "$TMPDIR/etc/openmediavault/config.xml" /etc/openmediavault/config.xml
echo "   Done."

# --- Step 2: Add RAID to fstab (safe merge - keeps fresh boot entries) ---
echo "[2/5] Adding RAID mount to fstab..."
if ! grep -q 'd9768db6-bc3b-43af-bf94-280f444566c1' /etc/fstab; then
  cat >> /etc/fstab << 'FSTAB'

# >>> [openmediavault]
/dev/disk/by-uuid/d9768db6-bc3b-43af-bf94-280f444566c1\t/srv/dev-disk-by-uuid-d9768db6-bc3b-43af-bf94-280f444566c1\text4\tdefaults,nofail,user_xattr,usrjquota=aquota.user,grpjquota=aquota.group,jqfmt=vfsv0,acl\t0 2
/srv/dev-disk-by-uuid-d9768db6-bc3b-43af-bf94-280f444566c1/data/\t/export/data\tnone\tbind,nofail\t0 0
# Journal on RAID
/srv/dev-disk-by-uuid-d9768db6-bc3b-43af-bf94-280f444566c1/system-journal\t/var/log/journal\tnone\tbind,nofail,x-systemd.requires-mounts-for=/srv/dev-disk-by-uuid-d9768db6-bc3b-43af-bf94-280f444566c1\t0 0
# <<< [openmediavault]
FSTAB
  echo "   RAID entries added to fstab."
else
  echo "   RAID already in fstab, skipping."
fi

# --- Step 3: Restore custom fix files ---
echo "[3/5] Restoring custom fixes..."
mkdir -p /etc/systemd/journald.conf.d
cp "$TMPDIR/etc/systemd/journald.conf.d/size-limit.conf" /etc/systemd/journald.conf.d/ 2>/dev/null && echo "   Journal size cap restored."
cp "$TMPDIR/etc/default/minidlna" /etc/default/minidlna 2>/dev/null && echo "   MiniDLNA fix restored."
cp "$TMPDIR/etc/postfix/main.cf" /etc/postfix/main.cf 2>/dev/null && echo "   Postfix config restored."
cp "$TMPDIR/etc/postfix/sasl_passwd" /etc/postfix/sasl_passwd 2>/dev/null && postmap /etc/postfix/sasl_passwd && echo "   Postfix credentials restored."
cp "$TMPDIR/etc/ssh/sshd_config" /etc/ssh/sshd_config 2>/dev/null && echo "   SSH config restored."

# --- Step 4: Apply OMV config ---
echo "[4/5] Running omv-salt to regenerate all OMV configs..."
systemctl daemon-reload
mkdir -p "$RAID"
mount "$RAID" 2>/dev/null || true
omv-salt deploy run --all 2>&1 | tail -5
echo "   Done."

# --- Step 5: Restart services ---
echo "[5/5] Restarting services..."
systemctl restart systemd-journald nginx php8.2-fpm openmediavault-engined smbd 2>/dev/null
systemctl reload monit 2>/dev/null
echo "   Done."

rm -rf "$TMPDIR"
echo ""
echo "=== Restore complete! Reboot recommended. ==="
