#!/bin/bash
# pve-kiosk installer: shows the Proxmox VE web UI on the host's own screen
# instead of the text login. Safe to re-run; it keeps /etc/pve-kiosk/kiosk.conf.
#
#   ./install.sh [--url URL] [--no-restrict] [--scale N] [--no-start] [--force]
set -euo pipefail

SRC=$(cd "$(dirname "$0")" && pwd)
LIB=/usr/local/lib/pve-kiosk
DOC=/usr/local/share/doc/pve-kiosk
CONF_DIR=/etc/pve-kiosk
CONF=$CONF_DIR/kiosk.conf
UNIT=/etc/systemd/system/pve-kiosk.service
KIOSK_USER=pvekiosk
KIOSK_HOME=/var/lib/pvekiosk

URL='' RESTRICT='' SCALE='' START=1 FORCE=0

usage() {
  cat <<USAGE
Usage: $0 [options]

  --url URL       open this page instead of the local Proxmox web UI
  --no-restrict   let the browser follow links to any site
  --scale N       zoom factor, e.g. 1.5 for a 4K screen
  --no-start      install and enable, but leave tty1 alone until the next boot
  --force         install on a machine without Proxmox VE (needs --url)
  -h, --help      show this help

Settings are saved in $CONF. Uninstall with ./uninstall.sh.
USAGE
}

say() { printf '\033[1m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[33mwarning:\033[0m %s\n' "$*" >&2; }
die() { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --url) URL=${2:?--url needs a value}; shift 2 ;;
    --url=*) URL=${1#*=}; shift ;;
    --no-restrict) RESTRICT=no; shift ;;
    --scale) SCALE=${2:?--scale needs a value}; shift 2 ;;
    --scale=*) SCALE=${1#*=}; shift ;;
    --no-start) START=0; shift ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; die "unknown option: $1" ;;
  esac
done

[ "$(id -u)" = 0 ] || die "run as root"
for v in "$URL" "$SCALE"; do
  case "$v" in *\'*) die "values may not contain a single quote" ;; esac
done

# --- checks ---------------------------------------------------------------
if command -v pveversion >/dev/null 2>&1; then
  say "Found $(pveversion)"
elif [ "$FORCE" = 1 ]; then
  [ -n "$URL" ] || die "--force on a machine without Proxmox VE needs --url"
  warn "Proxmox VE not found, installing anyway (--force)"
else
  die "Proxmox VE not found (no pveversion). Use --force --url URL for plain Debian."
fi

if systemctl is-enabled display-manager.service >/dev/null 2>&1; then
  die "a desktop login manager ($(readlink -f /etc/systemd/system/display-manager.service | xargs basename)) is enabled and would fight the kiosk for the screen. Disable it first."
fi

ls /dev/dri/card* >/dev/null 2>&1 || warn "no /dev/dri/card* display device. If the GPU is passed through to a VM (vfio), the host has no screen to draw on."

# --- packages -------------------------------------------------------------
say "Installing packages (cage, chromium)"
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
# Only packages that are not already on a Proxmox host: naming an installed
# package would make apt upgrade it as a side effect.
apt-get install -y -q --no-install-recommends cage chromium libnss3-tools fonts-dejavu-core
# Captured first: with pipefail, grep -q closing the pipe early fails the check.
cage_help=$(cage -h 2>&1 || true)
case "$cage_help" in *" -s"*) ;; *) die "this cage is too old: it has no -s (VT switching). Needs cage 0.1.2 or newer." ;; esac

# --- user -----------------------------------------------------------------
if ! id "$KIOSK_USER" >/dev/null 2>&1; then
  say "Creating system user $KIOSK_USER"
  useradd --system --user-group --create-home --home-dir "$KIOSK_HOME" --shell /usr/sbin/nologin "$KIOSK_USER"
fi
for g in video render input; do
  getent group "$g" >/dev/null && usermod -a -G "$g" "$KIOSK_USER"
done

# --- files ----------------------------------------------------------------
say "Installing files"
install -d "$LIB" "$DOC" "$CONF_DIR"
install -m 0755 "$SRC/files/prestart" "$SRC/files/launch" "$SRC/files/browser" "$LIB/"
install -m 0644 "$SRC/files/pve-kiosk.service" "$UNIT"
install -m 0644 "$SRC/README.md" "$DOC/"
[ -d "$SRC/docs" ] && cp -R "$SRC/docs" "$DOC/"
if [ ! -f "$CONF" ]; then
  install -m 0644 "$SRC/files/kiosk.conf" "$CONF"
  echo "wrote $CONF"
fi

set_conf() { # key value
  local esc
  esc=$(printf '%s' "$2" | sed -e 's/[\\&|]/\\&/g')
  if grep -q "^$1=" "$CONF"; then
    sed -i "s|^$1=.*|$1='$esc'|" "$CONF"
  else
    printf "%s='%s'\n" "$1" "$2" >>"$CONF"
  fi
}
[ -n "$URL" ] && set_conf PVE_KIOSK_URL "$URL"
[ -n "$RESTRICT" ] && set_conf PVE_KIOSK_RESTRICT "$RESTRICT"
[ -n "$SCALE" ] && set_conf PVE_KIOSK_SCALE "$SCALE"

# --- services -------------------------------------------------------------
say "Enabling the kiosk on tty1, text login on tty2"
systemctl daemon-reload
systemctl disable getty@tty1.service >/dev/null 2>&1 || true
systemctl enable getty@tty2.service >/dev/null 2>&1 || true
systemctl enable pve-kiosk.service >/dev/null

# The kiosk itself shows up in who on tty1; only a real login counts.
if [ "$START" = 1 ] && who | awk -v u="$KIOSK_USER" '$2 == "tty1" && $1 != u' | grep -q .; then
  warn "someone is logged in on tty1. Not starting now so their session is not killed."
  START=0
fi

if [ "$START" = 1 ]; then
  systemctl start getty@tty2.service || true
  systemctl restart pve-kiosk.service
  sleep 5
  if systemctl is-active --quiet pve-kiosk.service; then
    say "Kiosk is running on the local screen"
  else
    warn "the kiosk did not stay up. See: journalctl -u pve-kiosk -b"
  fi
else
  say "Installed. The kiosk starts at the next boot, or now with: systemctl start pve-kiosk"
fi

cat <<DONE

  Ctrl+Alt+F2   text login        Ctrl+Alt+F1   back to the web UI
  Settings:     $CONF  (then: systemctl restart pve-kiosk)
  Logs:         journalctl -u pve-kiosk -b
  Remove:       $SRC/uninstall.sh
DONE
