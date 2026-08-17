# CavalryOnLinux-Installer — AUR package sources

This directory contains two AUR-style packages for Arch-based systems.

## Packages

### `cavalry-wine`

Patched Wine 11.13 for Cavalry (stock Wine + the connection-drag patch).
Installs a self-contained tree into `/opt/cavalry-wine` and `provides=wine`.

- Sources: Wine git (tag `wine-11.13`) + this repo's patch file.
- License: LGPL-2.1-or-later.
- Build time: 20–60 minutes (same as any Wine build).

### `cavalry`

Cavalry itself. Downloads the **official** installer from cavalry.studio at
build time and ships scripts, launcher, desktop files, and the `cavalry://`
handler. Depends on `wine` (or you can use `cavalry-wine`).

- License: `custom:Canva-ToU` (the app) + GPL-3.0-or-later (the scripts).
- The MSI checksum is `SKIP` because the URL serves "latest" — the file
  size is verified during build instead.

## Submitting to the AUR

These PKGBUILDs are provided for review and local use. To submit:

1. Replace the `Maintainer:` line (AUR requires a real maintainer email) and
   remove the `Contributor:` line or fill it in.
2. Bump `pkgver` for the current Cavalry version (check cavalry.studio or
   microsoft/winget-pkgs#379466 for the latest; the URL is "latest").
3. The `installer` git source pins a tag `v${pkgver}` — create matching tags
   in the CavalryOnLinux-Installer repo, or switch to a commit hash.
4. Run `makepkg -si` locally to verify both packages build and install.
5. Register an account on aur.archlinux.org and use
   `ssh aur@aur.archlinux.org` to push each repo:
   ```
   git push aur master
   ```
   after setting up the remote:
   ```
   git remote add aur ssh://aur@aur.archlinux.org/cavalry.git
   ```

AUR submission guidelines (non-free software, download-at-build-time): both
packages comply — neither redistributes the MSI, and `cavalry` uses the
official source URL.

## Testing locally

```bash
cd aur/cavalry-wine && makepkg -si
cd ../cavalry && makepkg -si
cavalry            # first-run: sets up ~/.cavalry prefix and launches
```
