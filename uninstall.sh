#!/bin/bash
# pve-kiosk uninstaller: puts the text login back on tty1.
#
#   ./uninstall.sh           remove the kiosk, keep settings, user and packages
#   ./uninstall.sh --purge   also remove the settings and the pvekiosk user
set -euo pipefail

PURGE=0
case "${1:-}" in
  --purge) PURGE=1 ;;
  "") ;;
  -h|--help) sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) echo "unknown option: $1" >&2; exit 1 ;;
esac
[ "$(id -u)" = 0 ] || { echo "run as root" >&2; exit 1; }

echo "==> Stopping the kiosk and restoring the tty1 login"
systemctl disable --now pve-kiosk.service >/dev/null 2>&1 || true
rm -f /etc/systemd/system/pve-kiosk.service
systemctl daemon-reload
systemctl enable getty@tty1.service >/dev/null 2>&1 || true
systemctl start getty@tty1.service || true

echo "==> Removing files"
rm -rf /usr/local/lib/pve-kiosk /usr/local/share/doc/pve-kiosk
rm -f /etc/chromium/policies/managed/pve-kiosk.json

if [ "$PURGE" = 1 ]; then
  echo "==> Removing settings and the pvekiosk user"
  rm -rf /etc/pve-kiosk
  if id pvekiosk >/dev/null 2>&1; then
    pkill -u pvekiosk 2>/dev/null || true
    userdel -r pvekiosk 2>/dev/null || userdel pvekiosk
  fi
fi

cat <<DONE

Done. The packages are still installed. To remove them too:
  apt-get remove cage chromium && apt-get autoremove
DONE
