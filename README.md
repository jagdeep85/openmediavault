# openmediavault
OMV Backup & Restore Guide
Backup Location
Backups are stored on the RAID array at:
`/srv/dev-disk-by-uuid-d9768db6-bc3b-43af-bf94-280f444566c1/omv-backups/`
Auto-backup runs daily at 2am, last 10 kept.
---
Files in This Folder
`omv-config-DATE.tar.gz` — Daily config backups
`restore.sh` — Restore on the same OMV install
`restore-after-reinstall.sh` — Restore after a fresh OMV reinstall
`README.md` — This file
---
What Each Backup Contains
`/etc/openmediavault/config.xml` — All OMV settings (shares, users, services)
`/etc/fstab` — Disk mount points
`/etc/exports` — NFS exports
`/etc/samba/smb.conf` — Samba share config
`/etc/monit/conf.d/` — Service monitoring config
`/etc/systemd/journald.conf.d/` — Journal size cap (200MB)
`/etc/default/minidlna` — MiniDLNA no-rescan fix
`/etc/postfix/main.cf` + `sasl_passwd` — Email notification config
`/etc/ssh/sshd_config` — SSH server config
---
Scenario 1: Restore on the Same Install
Use when OMV is running but configs got corrupted.
```bash
# List available backups
bash /srv/dev-disk-by-uuid-d9768db6-bc3b-43af-bf94-280f444566c1/omv-backups/restore.sh

# Restore a specific backup
bash /srv/dev-disk-by-uuid-d9768db6-bc3b-43af-bf94-280f444566c1/omv-backups/restore.sh      /srv/dev-disk-by-uuid-d9768db6-bc3b-43af-bf94-280f444566c1/omv-backups/omv-config-DATE.tar.gz
```
The script saves a pre-restore snapshot before making any changes.
---
Scenario 2: Restore After Fresh OMV Reinstall
Use when you reinstall OMV on the USB boot drive from scratch.
Step 1 - Install fresh OMV 7 on the USB drive
Boot from the OMV 7 installer ISO and install as normal.
Step 2 - SSH in and mount the RAID
```bash
ssh root@192.168.1.110
mkdir -p /srv/dev-disk-by-uuid-d9768db6-bc3b-43af-bf94-280f444566c1
mount /dev/md0 /srv/dev-disk-by-uuid-d9768db6-bc3b-43af-bf94-280f444566c1
```
Step 3 - Run the reinstall restore script
```bash
bash /srv/dev-disk-by-uuid-d9768db6-bc3b-43af-bf94-280f444566c1/omv-backups/restore-after-reinstall.sh      /srv/dev-disk-by-uuid-d9768db6-bc3b-43af-bf94-280f444566c1/omv-backups/omv-config-DATE.tar.gz
```
Step 4 - Reboot
```bash
reboot
```
What the reinstall script does:
Restores `config.xml` (all OMV settings)
Safely merges RAID + journal mount entries into fstab (preserves new boot USB UUIDs)
Restores custom fixes (journal cap, MiniDLNA, postfix, SSH)
Runs `omv-salt deploy run --all` to regenerate all OMV config files
Restarts all services
> **WARNING:** Do NOT use `restore.sh` after a reinstall.
> It overwrites fstab completely which would break the new boot drive UUID and make the system unbootable.
---
Taking a Manual Backup
```bash
/usr/local/bin/omv-backup.sh
```
---
Custom Fixes Applied (2026-05-06)
These are included in every backup and restored by the scripts.
Removed missing NTFS disk (UUID 2A82B97182B941DD) — was causing zombie process buildup and outages
Journal moved to RAID — prevents USB flash drive I/O saturation
Journal capped at 200MB — `/etc/systemd/journald.conf.d/size-limit.conf`
MiniDLNA rescan disabled — removed `-r` flag, was scanning 1.5TB on every boot
Postfix timeouts tightened — `smtp_connect_timeout=10s`, `maximal_queue_lifetime=1d`
NFS disabled — `systemctl disable nfs-server`
Postfix queue flushed — 551 stuck alert emails cleared
