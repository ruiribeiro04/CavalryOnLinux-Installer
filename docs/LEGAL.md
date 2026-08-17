# Legal notes

This document explains the licensing and compliance posture of the
Cavalry-on-Linux installer. It is not legal advice.

## Cavalry (the application) — proprietary

Cavalry is a proprietary application ("Cavalry by Canva"). Its use is governed
by:

- Canva's [Terms of Use](https://www.canva.com/policies/terms-of-use/)
- Cavalry's [Additional Terms](https://www.canva.com/policies/cavalry-additional-terms/)

Relevant restrictions (paraphrased): you may not rent, lease, sell,
distribute, sublicense, or otherwise make the Service available to third
parties; you may not copy, replicate, decompile, reverse-engineer, modify, or
create derivative works of the software.

**What this installer does — and does not do:**

| Action | Status |
|---|---|
| Download Cavalry.msi from the official cavalry.studio URL at install time | ✅ Allowed (obtaining a copy from the vendor) |
| Bundle/redistribute Cavalry.msi inside this repository or AUR packages | ❌ Not done — would violate ToS |
| Patch/modify Cavalry binaries (e.g. licensing, EXE/DLL patching) | ❌ Not done — would violate ToS |
| Patch Wine (open-source, LGPL) to fix rendering bugs | ✅ Allowed |
| Sign in with the user's own free Canva (Starter) account | ✅ Allowed — this is the intended usage model |

**What we never do:** crack licenses, bypass sign-in, patch the app, or ship
the installer. Users must sign in with their own account. The free Starter
plan covers most motion-design work (exports capped at 1920×1080; some
Professional features are locked).

> Note: an older project (Linux-Affinity-Installer) patches Affinity binaries
> with Mono.Cecil. That approach is **not** copied here — patching proprietary
> application binaries is a ToS risk we deliberately avoid.

## The Wine patch — LGPL-2.1-or-later

`patch/cavalry-connection-noodle-park-and-overlay.patch` comes from the
[cavalry-connection-fix](https://github.com/ruiribeiro04/cavalry-connection-fix)
project. It is a modification of Wine, which is licensed under
LGPL-2.1-or-later. The patch is applied to unmodified Wine source at build
time; no part of Cavalry is modified.

- Wine: Copyright © the Wine Project contributors, LGPL-2.1-or-later.
- Patch origin: cavalry-connection-fix project (no explicit license file;
  it derives from Wine and is used here unmodified and attributed).

## This installer — GPL-3.0

All installer code (scripts, GUI, launcher, PKGBUILDs) is licensed under
GPL-3.0-or-later (see `LICENSE`).

## Trademarks

"Cavalry" and "Canva" are trademarks of their respective owners. This project
is not affiliated with, endorsed by, or sponsored by Canva or Scene Group.
