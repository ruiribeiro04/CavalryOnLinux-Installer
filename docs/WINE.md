# Wine guide

Everything about the Wine side of running Cavalry on Linux.

## What Cavalry needs

- Windows 10+ (Cavalry itself; under Wine this is emulated).
- A GPU with **OpenGL 4.1 Core Profile** support. Intel iGPUs need Gen 12
  (Alder Lake or newer); most AMD and NVIDIA discrete GPUs work. 512 MB RAM
  is the vendor minimum (realistically you want a lot more).
- Internet access on first launch (sign-in with a Canva account).

Cavalry is a **Qt6 / OpenGL 4.1** application. This matters because:

- It runs on **plain stock Wine 11+** — no game-specific Wine builds needed.
- **DXVK does not accelerate OpenGL.** DXVK only translates Direct3D→Vulkan.
  We still install it (community-tested combo via winetricks) but the OpenGL
  viewport is handled by Wine's own `wined3d`/`opengl32`.

## Engine selection (in priority order)

1. `$CALVARY_WINE` — explicit path, if you set it.
2. Patched Wine at `~/.local/share/cavalry-wine/bin/wine` — built by
   `./install.sh --build-wine`.
3. System Wine (`wine-staging`, `wine`, or `wine64`).

To see which one you have: `./cavalry-launcher` prints the path at launch.

## The patched Wine build (why you might want it)

The community discovered that dragging node connections in Cavalry fails
under unpatched Wine (the connection "noodle" doesn't follow the cursor).
[cavalry-connection-fix](https://github.com/ruiribeiro04/cavalry-connection-fix)
ships a small patch against Wine 11.13 that fixes:

- connection-drag behavior,
- the click-through popup that appears on zoom (Ctrl+drag),
- black opaque Qt popups on layered surfaces (DCE clearing).

`./install.sh --build-wine` will:

1. Install build dependencies (distro-specific, requires sudo).
2. Clone Wine 11.13 (shallow).
3. Apply the patch (idempotent — safe to re-run).
4. Configure `--enable-archs=x86_64`, build with all cores.
5. Install to `~/.local/share/cavalry-wine` (self-contained).

**This takes 20–60 minutes.** It is optional: if you don't need connection
dragging to work, stock Wine is fine.

### Rebuilding / cleaning up

- The source lives at `~/.local/share/cavalry-wine-src`, the build dir at
  `~/.local/share/cavalry-wine-build`. Delete them to reclaim disk; the
  installed wine at `~/.local/share/cavalry-wine` is self-contained.
- To force a clean rebuild: `rm -rf ~/.local/share/cavalry-wine*` then
  re-run `./install.sh --build-wine`.

## Prefix setup (`~/.cavalry`)

The installer creates a 64-bit WINEPREFIX at `~/.cavalry` (override with
`--prefix` or `CALVARY_PREFIX`). It applies the community-tested recipe:

1. `wineboot -u` — create the prefix.
2. `winetricks -q dxvk corefonts fontsmooth=rgb` — DXVK (limited value for
   OpenGL, kept for compatibility), core fonts for correct UI text, and
   RGB font smoothing.
3. Registry tweaks:
   - `HKCU\Software\Wine\Drivers → Graphics = x11,wayland` — force X11 first.
     Wine's native Wayland driver can fail on NVIDIA with OpenGL apps.
   - `HKCU\Software\Wine\DllOverrides → icuuc = native,builtin`
   - `HKCU\Software\Wine\DllOverrides → icuin = native,builtin`

## Canva sign-in and the cavalry:// handler

Cavalry 2.7+ signs in through a browser flow: the app asks Canva, the browser
logs you in, and Canva redirects to a `cavalry://auth/callback?...` URL carrying
a one-time code. Linux hands that URL to a registered handler, which must
deliver it to the **already-running** Cavalry instance.

The installer writes `~/.local/share/applications/cavalry-handler.desktop`
with `MimeType=x-scheme-handler/cavalry`, `Exec=... Cavalry.exe %u`, and a
`Path=` pointing at the Cavalry install dir, then registers it via
`xdg-settings set default-url-scheme-handler cavalry cavalry-handler.desktop`
**and** a direct self-healing write to `mimeapps.list` (older installers passed
the full path to xdg-settings, which silently failed and left the scheme
unbound).

### Why `Path=` matters (the working-directory IPC fix)

The handler spawns a *second* Wine instance. Wine instances in the same prefix
communicate over IPC that is keyed on the working directory, so the second
instance only finds the first if both share the same cwd. The `.desktop`
`Path=` sets the handler's cwd, and `cavalry-launcher` now `cd`s into the
Cavalry install dir before exec, so the two instances match. Community-verified
(dezuhan gist a6e50a2c3e0432d270d28b0521236efb, micahlt CavalryOnLinux.md
3c97f834adaf688fe18344c0f546466c).

If the callback does not reach the running app you get a fresh window (or
nothing). Verified on this project: with the fix, firing
`xdg-open cavalry://auth/callback?...` against a running instance keeps a single
Cavalry process whose cwd equals the handler's cwd; the app logs
`Canva auth failed: State mismatch` only when the test uses a fake state token
(expected — a real Canva redirect carries a matching state).

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Connection dragging doesn't work | Unpatched Wine | `./install.sh --build-wine` |
| Sign-in opens a blank/new window | Handler or working-dir mismatch | Ensure Cavalry is running, then retry sign-in; reinstall launcher `./install.sh`; check `Path=` in `cavalry-handler.desktop` and cwd of the running Cavalry.exe (`readlink /proc/<pid>/cwd`) |
| Sign-in logs `State mismatch` | Stale/fake callback URL | Use the real Canva redirect (each code/state pair is one-time); retry sign-in from inside Cavalry |
| Black/white viewport | GPU/driver below OpenGL 4.1, or Mesa bug | Update drivers/Mesa; try `MESA_GL_VERSION_OVERRIDE=4.1` (unsupported workaround) |
| Wayland + NVIDIA artifacts | Wine Wayland driver | Graphics driver is already forced to `x11,wayland`; restart Wine after edits |
| `icuuc`/`icuin` override errors | Newer Wine built them in | Harmless; remove the overrides if they cause errors |
| Zoom Ctrl+drag popup click-through | Patched behavior | By design in the patch (click-through disabled) |
| Lines slip under OpenGL panels | Compositor quirk | Try X11 session; disable compositor effects for the window |

## Manual steps (if you prefer to do it by hand)

```bash
export WINEPREFIX="$HOME/.cavalry" WINEARCH=win64
wineboot -u
winetricks -q dxvk corefonts fontsmooth=rgb
wine reg add 'HKCU\Software\Wine\Drivers' /v Graphics /t REG_SZ /d 'x11,wayland' /f
wine reg add 'HKCU\Software\Wine\DllOverrides' /v icuuc /d 'native,builtin' /f
wine reg add 'HKCU\Software\Wine\DllOverrides' /v icuin /d 'native,builtin' /f
curl -fL -o Cavalry.msi https://cavalry.studio/downloads/latest/Cavalry.msi
wine msiexec //i Cavalry.msi //quiet //norestart
```

Then create `~/.local/share/applications/cavalry-handler.desktop` as
described above and register it with `xdg-settings`.
