# How pve-kiosk works

## What runs where

```
systemd
`-- pve-kiosk.service  (tty1, user pvekiosk, replaces getty@tty1)
    |-- ExecStartPre=+ /usr/local/lib/pve-kiosk/prestart   (root)
    |     |-- picks the URL from the certificate pveproxy serves
    |     |-- imports /etc/pve/pve-root-ca.pem into ~pvekiosk/.pki/nssdb
    |     |-- waits up to 30 s for port 8006
    |     |-- writes /etc/chromium/policies/managed/pve-kiosk.json
    |     `-- writes /run/pve-kiosk/session.env (URL, keyboard, renderer)
    `-- ExecStart= /usr/local/lib/pve-kiosk/launch          (pvekiosk)
          `-- cage -s -- /usr/local/lib/pve-kiosk/browser
                `-- chromium --kiosk --ozone-platform=wayland https://127.0.0.1:8006/
```

`getty@tty2` is enabled, so a text login is always one key press away.

## Files

| Path | What |
| --- | --- |
| `/etc/systemd/system/pve-kiosk.service` | The service |
| `/usr/local/lib/pve-kiosk/prestart` | Root setup step, runs before every start |
| `/usr/local/lib/pve-kiosk/launch` | Starts cage with the saved environment |
| `/usr/local/lib/pve-kiosk/browser` | Starts Chromium with the kiosk flags |
| `/etc/pve-kiosk/kiosk.conf` | Your settings. The installer never overwrites it |
| `/etc/chromium/policies/managed/pve-kiosk.json` | Browser policy, rewritten on every start |
| `/run/pve-kiosk/session.env` | Values worked out by prestart for this run |
| `/var/lib/pvekiosk/` | Kiosk user's home: Chromium profile and certificate database |

## Design decisions

**cage instead of X11 and a window manager.** cage runs one app full screen and nothing else. It's a small package with no desktop to lock down, and it's the usual way to build a Wayland kiosk.

**A systemd service on tty1 instead of autologin.** The service opens a logind session on tty1 (`PAMName=login`), which gives cage access to the GPU and input devices without running as root and without a display manager. `Conflicts=getty@tty1.service` hands tty1 back and forth cleanly.

**`cage -s`.** Without it cage blocks VT switching, and then there's no local way to get a shell while the kiosk is up. If the network is down, the console is the only way in.

**A root prestart on every start instead of once at install.** The certificate files live in `/etc/pve` (pmxcfs), which the kiosk user can't read. Doing the work at each start means renewed ACME certificates, regenerated CAs and changed settings all apply with a service restart.

**Resolve the certificate's hostname inside the browser.** A custom certificate never covers 127.0.0.1. `--host-resolver-rules="MAP name 127.0.0.1"` lets Chromium check the certificate against its real name while still connecting locally, without editing `/etc/hosts` for the whole system.

**Trust the CA per user.** The Proxmox CA goes into the kiosk user's NSS database only, not the system trust store, so no other program on the host starts trusting it.

**Software rendering when there's no render node.** Some servers only have a basic display chip (BMC/ASPEED) or boot with `nomodeset`. Then there's a `/dev/dri/card*` but no `renderD*`. prestart switches wlroots to pixman and Chromium to `--disable-gpu`, which is slower but works.

## Upgrades

`cage` and `chromium` come from Debian and update with the rest of the host (`apt full-upgrade`). A Chromium update takes effect the next time the kiosk restarts: `systemctl restart pve-kiosk`.
