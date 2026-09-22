# pve-kiosk

Show the Proxmox VE web UI on the server's own screen instead of the text login.

Plug a monitor, keyboard and mouse into your Proxmox host. When it boots you get the normal web login page, full screen, instead of the text `login:` prompt. The text console is still there on **Ctrl+Alt+F2**.

It uses [cage](https://github.com/cage-kiosk/cage), a Wayland compositor that runs one app full screen, and Chromium in kiosk mode. There's no desktop environment, display manager or X server, and nothing runs as root.

## Quick install

On the Proxmox host, as root:

```sh
git clone https://github.com/MacsInSpace/pve-kiosk.git && cd pve-kiosk && ./install.sh
```

Or with `curl`, which every Proxmox install has (no `git` needed):

```sh
curl -fsSL https://github.com/MacsInSpace/pve-kiosk/archive/refs/heads/main.tar.gz | tar xz && cd pve-kiosk-main && ./install.sh
```

Options and details are under [Install](#install).

## Requirements

- Proxmox VE 8 or 9 (Debian 12 or 13)
- A GPU the host can use: integrated Intel/AMD graphics or a basic onboard chip. A GPU that's passed through to a VM (vfio) belongs to the VM, not the host.
- No desktop login manager (gdm, lightdm, sddm) enabled on the host
- Internet access for `apt` (installs `cage`, `chromium` and about 55 dependencies, roughly 350 MB)

Sharing an iGPU with LXC containers for Plex or Jellyfin transcoding is fine. The host keeps the i915/amdgpu driver and the kiosk shares the card with them.

## Install

On the Proxmox host, as root:

```sh
git clone https://github.com/MacsInSpace/pve-kiosk.git
cd pve-kiosk
./install.sh
```

The screen switches to the web UI straight away, with no reboot needed. The kiosk also starts at every boot from then on.

| Option | What it does |
| --- | --- |
| `--url URL` | Open another page instead, such as `https://grafana.lan:3000/`. Full URL, port included |
| `--no-restrict` | Let links go to any site. By default the browser can only open the kiosk page's own site |
| `--scale N` | Zoom, e.g. `--scale 1.5` for a 4K screen |
| `--no-start` | Install and enable, but don't take over the screen until the next boot |
| `--force` | Install on plain Debian without Proxmox VE (needs `--url`) |

Re-running `install.sh` is safe. It updates the scripts and keeps your settings.

## Using it

| Keys | |
| --- | --- |
| **Ctrl+Alt+F2** | Text login (the normal console) |
| **Ctrl+Alt+F1** | Back to the web UI |
| **Ctrl+W** | Close a VM/container console window that opened on top |
| **F5** | Reload the page |
| **Ctrl+Plus / Ctrl+Minus** | Zoom in and out |

Proxmox logs you out after two hours like it always does, and the kiosk goes back to the login page. Closing the last window, or a browser crash, restarts the kiosk within three seconds.

## Settings

Edit `/etc/pve-kiosk/kiosk.conf`, then `systemctl restart pve-kiosk`.

```sh
PVE_KIOSK_URL=''          # empty = local web UI; or a full URL, e.g. 'http://homepage.lan:3000/'
PVE_KIOSK_RESTRICT='yes'  # only the kiosk page's own site
PVE_KIOSK_ALLOW=''        # extra allowed sites, e.g. 'https://pve.proxmox.com'
PVE_KIOSK_SCALE=''        # zoom factor, e.g. '1.5'
CAGE_ARGS=''              # '-m last' for one monitor, '-m extend' to span
CHROMIUM_FLAGS=''         # anything else for Chromium
```

## Certificates

You shouldn't see a certificate warning:

- **Default self-signed certificate**: the kiosk opens `https://127.0.0.1:8006` and trusts your cluster's own CA (`/etc/pve/pve-root-ca.pem`), for the kiosk user only.
- **Custom or ACME (Let's Encrypt) certificate**: the kiosk opens `https://<name on the certificate>:8006` and resolves that name to 127.0.0.1 inside the browser. It works without DNS and without internet.

Both are rechecked every time the kiosk starts, so a renewed or regenerated certificate only needs `systemctl restart pve-kiosk`.

## Uninstall

```sh
./uninstall.sh           # text login back on tty1, keeps settings
./uninstall.sh --purge   # also removes the settings and the pvekiosk user
```

The packages are left installed. `apt-get remove cage chromium && apt-get autoremove` removes them.

## Security

- The kiosk shows a login page. Anyone at the keyboard still needs a Proxmox username and password, just as they do at the text console. It never logs in automatically.
- Chromium runs as `pvekiosk`, a system user that can't log in, with no sudo and no access to `/etc/pve`. A small root step (`prestart`) runs before each start to read the certificates and write the browser policy.
- A managed Chromium policy switches off password saving, autofill, sign-in and sync, and by default blocks every site except the Proxmox UI.
- Physical access to a server has always meant full access to it. This doesn't change that, and it doesn't make it worse.

## Troubleshooting

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md). Start with:

```sh
systemctl status pve-kiosk
journalctl -u pve-kiosk -b
```

How it fits together: [docs/HOW-IT-WORKS.md](docs/HOW-IT-WORKS.md).

## Tested on

- Proxmox VE 9.2 (Debian 13), Intel Raptor Lake iGPU, also shared with LXC containers for hardware transcoding

Reports from other hardware and from Proxmox VE 8 are welcome.

## License

MIT
