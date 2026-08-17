# Cavalry on Linux

Install [Cavalry](https://cavalry.studio) — the procedural animation tool by
Canva — on Linux, using Wine. This project provides:

- A one-command terminal installer (`./install.sh`) for Debian/Ubuntu/Mint,
  Fedora/RHEL, Arch (and derivatives), and openSUSE.
- A graphical installer (`gui/cavalry-gui.py`) for people who prefer buttons
  to terminals.
- An optional **patched Wine** build (`./install.sh --build-wine`) that fixes
  the Cavalry connection-drag bug under Wine.
- A `cavalry://` URL handler so Canva sign-in opens Cavalry correctly.
- AUR packages (`cavalry`, `cavalry-wine`) for Arch users.

## Quick start

### Terminal installer (recommended)

```bash
git clone https://github.com/ruiribeiro04/CavalryOnLinux-Installer.git
cd CavalryOnLinux-Installer
./install.sh
```

Then launch Cavalry from your application menu (or run `./cavalry-launcher`)
and sign in with a free Canva account.

### Graphical installer (curl one-liner)

Prefer buttons over the terminal? Pipe the GUI installer straight from the
repo — no clone needed:

```bash
curl -sSL https://raw.githubusercontent.com/ruiribeiro04/CavalryOnLinux-Installer/main/gui/cavalry-gui.py | python3
```

The GUI installer auto-detects your distro, offers to install PyQt6 if it is
missing (falling back to the terminal installer if it cannot), and provides
**Install / Update / Uninstall / View Logs** buttons with a live progress view.

> **PyQt6 install table** — the GUI auto-installs this for you; manual commands:
>
> | Distro family | Command |
> |---|---|
> | Arch/Artix/CachyOS/EndeavourOS/XeroLinux/Manjaro | `sudo pacman -S python-pyqt6` |
> | Fedora/Nobara/RHEL | `sudo dnf install python3-pyqt6 python3-pyqt6-svg` |
> | openSUSE Tumbleweed | `sudo zypper install python313-PyQt6` |
> | openSUSE Leap | `sudo zypper install python3-PyQt6` |
> | Debian/Ubuntu/Mint/Pop!/Zorin/PikaOS | `sudo apt install python3-pyqt6` |
> | Ubuntu 25.10 / PikaOS (QtSvg) | `sudo apt install python3-pyqt6.qtsvg` |

> First run downloads the official Cavalry installer (~90 MB) from
> cavalry.studio and sets up a Wine prefix at `~/.cavalry`. You need a GPU
> with OpenGL 4.1 support (Intel Gen 12+ iGPU, most AMD/NVIDIA GPUs).

## Options

```
./install.sh              standard install (system Wine)
./install.sh --build-wine also build the patched Wine (20–60 min, fixes
                          connection dragging)
./install.sh --wine PATH   use a specific Wine binary
./install.sh --prefix DIR  use a custom WINEPREFIX (default ~/.cavalry)
./install.sh --uninstall   remove launchers + app (keep prefix/data)
./uninstall.sh             interactive uninstall (prefix + cache optional)
./cavalry-launcher         launch Cavalry
```

## Tested

Verified end-to-end on **Arch-based (CachyOS)** with system **Wine 11.15**,
`winetricks dxvk corefonts fontsmooth=rgb`, and Mesa. Result:

- Wine prefix created at `~/.cavalry` (~1.3 GB).
- Official installer downloaded (~90 MB) from cavalry.studio and installed
  silently via `msiexec /i ... /qn /norestart`.
- `Cavalry.exe` present at `~/.cavalry/drive_c/Program Files/Cavalry/`.
- Launcher (`Cavalry.desktop`) and `cavalry://` protocol handler installed,
  verified by triggering `xdg-open cavalry://...` and watching the real
  handler spawn `Cavalry.exe` under Wine.
- Full uninstall → reinstall cycle passes (launcher, handler, prefix, cache
  all removed; everything reinstalls cleanly).

During testing three installer bugs were found and fixed:

1. The MSI path passed to msiexec was polluted by status output (now printed
   to stderr — `download_msi` emits only the path on stdout).
2. msiexec flag style was wrong for Linux Wine (`//i //quiet` → `/i /qn`).
3. `xdg-settings set default-url-scheme-handler` got the full path instead of
   the desktop-file ID, so the `cavalry://` binding was never written to
   `mimeapps.list` and browser sign-in callbacks could not reach the app. The
   installer now registers via both xdg-settings *and* a direct, self-healing
   write to `mimeapps.list` (`register_mime_handler`).
4. The main launcher (`Cavalry.desktop`) wrongly declared
   `MimeType=x-scheme-handler/cavalry`, so desktop environments offered two
   candidates for `cavalry://` links. Only the dedicated protocol handler
   (`cavalry-handler.desktop`) may claim the scheme.

> **Sign-in works like this**: launch Cavalry from your application menu or
> with `./cavalry-launcher` (this sets the working directory to the Cavalry
> install dir, matching the handler's `Path=` line so Wine IPC can reach the
> running instance), then click **Sign In *inside* the app** and complete the
> browser redirect. If you instead fire `cavalry://auth/callback` manually
> while no in-app sign-in is pending, the app logs `Auth has no pending auth
> flow` and ignores it.

## Why Wine? Why this installer?

- Cavalry is Windows-only (Windows 10+). It is a Qt6/OpenGL 4.1 application
  and runs well on stock Wine 11+.
- The community discovered a connection-drag bug under Wine; the fix is a
  small patch to Wine itself (`patch/cavalry-connection-noodle-park-and-overlay.patch`,
  from [cavalry-connection-fix](https://github.com/ruiribeiro04/cavalry-connection-fix)).
  This installer can build that patched Wine for you.
- We never redistribute or modify Cavalry itself — the installer downloads
  the official `.msi` at install time, and you sign in with your own account.
  See `docs/LEGAL.md`.

## Installer layout

```
install.sh          terminal installer (entry point)
uninstall.sh        interactive uninstaller
cavalry-launcher    launches Cavalry under Wine
lib/                shared bash modules (distro, wine, prefix, install, launcher)
gui/cavalry-gui.py  PyQt6 graphical installer
patch/              the Wine connection-drag patch (LGPL-2.1-or-later)
assets/             .desktop template + icon
aur/                AUR package sources (cavalry, cavalry-wine)
docs/               LEGAL.md, WINE.md, DISTROS.md
```

## Troubleshooting

- **Sign-in opens a blank window** → close it, relaunch Cavalry; the
  `cavalry://` handler should route the callback correctly now.
- **Black/white viewport** → your GPU/driver may not meet the OpenGL 4.1
  requirement; update your graphics drivers (or Mesa).
- **Wayland + NVIDIA glitches** → the installer forces Wine to X11/XWayland
  (`Graphics = x11,wayland`); restart Wine after changing it.

Full details in `docs/WINE.md` and `docs/DISTROS.md`.

## License

- Installer code and scripts: **GPL-3.0** (`LICENSE`).
- The Wine patch in `patch/` is derived from Wine (LGPL-2.1-or-later) and is
  used unmodified; see `docs/LEGAL.md`.
- Cavalry itself is proprietary Canva software — see Canva's Terms of Use.

## Acknowledgements

This project builds on the work of the Cavalry-on-Linux community:

- [micahlt — CavalryOnLinux.md](https://gist.github.com/micahlt/3c97f834adaf688fe18344c0f546466c)
  — the original manual Wine install guide, winetricks recipe, and the
  `cavalry://` protocol-handler `.desktop` file for Canva sign-in.
- [dezuhan — Cavalry on Linux (adapted guide)](https://gist.github.com/dezuhan/a6e50a2c3e0432d270d28b0521236efb)
  — the `Path=` working-directory fix: the protocol handler must run from the
  Cavalry install dir, otherwise Wine IPC between instances breaks and the
  sign-in callback opens a new window instead of reaching the running app.
- [hexadecimal233 — nix-cavalry](https://github.com/hexadecimal233/nix-cavalry)
  — Nix packaging of Cavalry under Wine; confirms the `%U` + `MimeType`
  handling of the `cavalry://` callback.
- [Dhruvin743 — cavalry-connection-fix](https://github.com/Dhruvin743/cavalry-connection-fix)
  — the Wine patch fixing the connection-drag bug under Wine (derived from
  Wine, LGPL-2.1-or-later); see `docs/LEGAL.md`.
- [ryzendew — Linux-Affinity-Installer](https://github.com/ryzendew/Linux-Affinity-Installer)
  — inspiration for the PyQt6 GUI installer and per-distro dependency layout.
- [ElementalWarrior/wine](https://gitlab.winehq.org/ElementalWarrior/wine) and
  [Kron4ek/Wine-Builds](https://github.com/Kron4ek/Wine-Builds) — Wine fork
  and prebuilt-binary resources evaluated while choosing the Wine strategy.

Cavalry is a product of Canva (formerly Scene Group). This project is not
affiliated with or endorsed by Canva.
