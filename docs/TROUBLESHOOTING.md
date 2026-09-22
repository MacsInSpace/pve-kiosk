# Troubleshooting

Get to a shell with **Ctrl+Alt+F2** at the server, or over SSH.

```sh
systemctl status pve-kiosk
journalctl -u pve-kiosk -b
```

## Black screen or a blinking cursor

- `journalctl -u pve-kiosk -b` and look for `cage` or `wlroots` errors.
- `ls /dev/dri`. If it's empty, the host has no display driver. A GPU passed through to a VM (vfio) can't be used by the host.
- `systemctl is-enabled display-manager` should say "not found" or "disabled".
- The monitor was plugged in after boot: `systemctl restart pve-kiosk`.

## The service keeps restarting, then stops

systemd gives up after 10 failed starts in 2 minutes. Fix the cause, then:

```sh
systemctl reset-failed pve-kiosk && systemctl start pve-kiosk
```

## "This site can't be reached"

pveproxy isn't answering. Check `systemctl status pveproxy`. The kiosk waits 30 seconds for it at start. Press F5 once it's up.

## Certificate warning

- Default certificate: `systemctl restart pve-kiosk` re-imports the CA. Check that `/etc/pve/pve-root-ca.pem` exists.
- Custom certificate: the journal line `custom certificate for <name>` shows the name the kiosk picked. If it's wrong, set `PVE_KIOSK_URL` in `/etc/pve-kiosk/kiosk.conf`. Note that for a hostname other than 127.0.0.1 or localhost you also need that name to resolve (DNS or `/etc/hosts`).

## Wrong keyboard layout

The kiosk uses the console layout from `/etc/default/keyboard`:

```sh
dpkg-reconfigure keyboard-configuration
systemctl restart pve-kiosk
```

## Wrong monitor, or I want both

cage 0.2 (Debian 13) spans all connected outputs by default. cage 0.1 (Debian 12) uses only the last one. In `/etc/pve-kiosk/kiosk.conf` set `CAGE_ARGS='-m last'` for one screen or `CAGE_ARGS='-m extend'` to span, then restart.

## Everything is tiny on a 4K screen

Set `PVE_KIOSK_SCALE='1.5'` (or `2`) and restart, or use Ctrl+Plus / Ctrl+Minus in the browser.

## A console window is stuck on top

VM and container consoles open as new windows, and in kiosk mode they have no close button. Press **Ctrl+W**.

## Put the text login back quickly

```sh
systemctl stop pve-kiosk      # until the next boot
./uninstall.sh                # for good
```
