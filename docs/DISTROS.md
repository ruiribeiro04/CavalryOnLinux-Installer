# Supported distributions & dependencies

## Supported (auto-detected)

| Family | Package manager | Examples |
|---|---|---|
| Debian/Ubuntu | `apt` | Debian, Ubuntu, Linux Mint, Pop!_OS, Zorin, elementary, PikaOS, Kali |
| Fedora/RHEL | `dnf` | Fedora, RHEL, CentOS, Nobara, Rocky, AlmaLinux |
| Arch | `pacman` | Arch, EndeavourOS, Manjaro, CachyOS, Garuda, Artix |
| openSUSE | `zypper` | openSUSE Leap / Tumbleweed, SLES |

Detection reads `/etc/os-release` (`ID`, `ID_LIKE`); anything else falls back
to whatever package manager binary exists and warns.

## What gets installed

### Standard install (no build)

- **wine** (or wine-staging) — the engine. If missing, the installer points
  you at the distro command below; on Arch it can pull `wine` from the
  official repos.
- **winetricks** — prefix setup (dxvk, corefonts, fontsmooth).
- **curl** or **wget** — download the official installer.
- **cabextract / msiextract** (best-effort) — MSI handling helpers.
- **PyQt6** (optional) — only for the graphical installer.

### `--build-wine` (build dependencies)

Installing Wine build deps is the most distro-specific part. The installer
runs the package manager for you (with sudo); here is what it maps to:

- **apt**: `git`, `apt-get build-dep wine`, `gcc-mingw-w64`,
  `opencl-headers`, `libgl1-mesa-dev`, `libegl1-mesa-dev`, `libvulkan-dev`,
  `libgnutls28-dev`, `libxslt1-dev`, `libasound2-dev`, `libpulse-dev`,
  `libpipewire-0.3-dev`, `libsdl2-dev`, `libcups2-dev`.
- **dnf**: `git`, `dnf builddep wine`, `mingw64-gcc`, `mingw32-gcc`,
  `opencl-headers`, `mesa-libGL-devel`, `mesa-libEGL-devel`,
  `vulkan-loader-devel`, `gnutls-devel`, `libxslt-devel`, `alsa-lib-devel`,
  `pulseaudio-libs-devel`, `pipewire-devel`, `SDL2-devel`, `cups-devel`.
- **pacman**: `git`, `base-devel`, `mingw-w64-gcc`, `opencl-headers`, `mesa`,
  `vulkan-icd-loader`, `gnutls`, `libxslt`, `alsa-lib`, `libpulse`,
  `pipewire`, `sdl2`, `cups`.
- **zypper**: `git`, `pattern devel_basis`, `gcc`, `opencl-headers`,
  `Mesa-libGL-devel`, `gnutls-devel`, `libxslt-devel`, `alsa-devel`,
  `libpulse-devel`, `pipewire-devel`, `libSDL2-devel`, `cups-devel`.

> `dnf builddep` / `apt build-dep` can fail on minimal installs (missing
> source repos). The installer warns rather than forcing `--allowerasing`
> (which can remove packages you want). Enable the source repo, or install
> the listed packages manually.

## Manual dependency install

If you prefer to install dependencies yourself before running the installer:

**Debian/Ubuntu**
```bash
sudo apt update
sudo apt install wine winetricks curl cabextract
```

**Fedora**
```bash
sudo dnf install wine winetricks curl cabextract
```

**Arch**
```bash
sudo pacman -S wine winetricks curl cabextract
```

**openSUSE**
```bash
sudo zypper install wine winetricks curl cabextract
```

> Prefer `wine-staging` where available (better compatibility with DXVK and
> many games/apps); stock `wine` also works for Cavalry.

## Arch: AUR packages

Two packages are provided under `aur/`:

- **cavalry-wine** — builds the patched Wine 11.13 into `/opt/cavalry-wine`.
  Install with your favorite AUR helper (or `makepkg -si` inside
  `aur/cavalry-wine/`). Requires the `mingw-w64-gcc` group.
- **cavalry** — depends on `wine`, `winetricks`, `curl`; downloads the
  official Cavalry.msi from cavalry.studio at build time (never
  redistributed); installs scripts, the launcher, and desktop files. Run
  `cavalry` after install to set up your prefix and launch.

Both are in this repo for review; submitting them to the AUR is a separate
step (see `aur/README.md`).
