# Changelog

## v0.1.0 - 2026-09-22

First release.

- `install.sh` puts the Proxmox VE web UI full screen on the local console (cage + Chromium on tty1), with the text login moved to tty2.
- Picks a URL that matches the certificate pveproxy serves: 127.0.0.1 for the default one, the certificate's hostname for a custom or ACME one.
- Trusts the cluster CA for the kiosk user only, re-imported on every start.
- Chromium policy: only the kiosk site by default, no password saving, sign-in or sync.
- Uses the console keyboard layout; falls back to software rendering without a GPU render node.
- Settings in `/etc/pve-kiosk/kiosk.conf`: URL (any full URL, port included), site restriction, extra allowed sites, zoom, cage and Chromium flags.
- `uninstall.sh`, with `--purge` to remove the settings and the kiosk user.
- Tested on Proxmox VE 9.2 (Debian 13) with an Intel iGPU.
