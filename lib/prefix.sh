#!/bin/bash
# prefix.sh — create and configure the Wine prefix for Cavalry.
# Part of CavalryOnLinux-Installer (GPL-3.0).
#
# Configures a 64-bit WINEPREFIX (default ~/.cavalry, matching the community
# guide), installs community-tested winetricks components, and applies the
# Wine registry tweaks needed for Cavalry + Canva sign-in.

# shellcheck source=lib/common.sh
: "${LIB_DIR:=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib}"
source "$LIB_DIR/common.sh"

# Pick the wine binary if not already chosen (wine.sh defines select_wine;
# install.sh sources it before us, standalone callers get a guard).
if [[ -z "${WINE_BIN:-}" ]]; then
  if declare -F select_wine >/dev/null; then
    select_wine
  else
    for cand in wine-staging wine wine64; do
      if have "$cand"; then WINE_BIN="$(command -v "$cand")"; break; fi
    done
    [[ -n "${WINE_BIN:-}" ]] || die "No Wine found. Install Wine or run install.sh --build-wine."
  fi
fi

# Name of the wine executable (used to spawn wineboot/winecfg).
WINE_EXE="$(basename "${WINE_BIN:-wine}")"

# ---------------------------------------------------------------------------
# Core
# ---------------------------------------------------------------------------
# Create the prefix if missing, then run winetricks + registry tweaks.
setup_prefix() {
  local prefix="$(default_prefix)"
  say "Setting up the Cavalry Wine prefix at: $prefix"

  ensure_wine_boot "$prefix"

  # winetricks components (community-tested combo for Cavalry on Wine).
  setup_winetricks "$prefix"

  # Registry tweaks: graphics driver + DLL overrides.
  apply_registry_tweaks "$prefix"

  ok "Wine prefix ready: $prefix"
}

# Run wineboot to create the prefix (idempotent, quiet).
ensure_wine_boot() {
  local prefix="$1"
  if [[ -f "$prefix/system.reg" ]]; then
    ok "Prefix already exists — skipping wineboot."
    return 0
  fi
  say "Initializing the Wine prefix (first run)..."
  WINEPREFIX="$prefix" WINEARCH=win64 "$WINE_EXE" wineboot -u 2>/dev/null || true
  if [[ ! -f "$prefix/system.reg" ]]; then
    warn "wineboot did not fully initialize the prefix."
    warn "The installer will continue; Cavalry may not launch until this is resolved."
  fi
}

# ---------------------------------------------------------------------------
# winetricks
# ---------------------------------------------------------------------------
setup_winetricks() {
  local prefix="$1"
  if ! have winetricks; then
    warn "winetricks not found — skipping DXVK/corefonts setup."
    warn "Cavalry may still run, but rendering quality will be lower."
    return 0
  fi
  say "Installing winetricks components (dxvk, corefonts, fontsmooth=rgb)..."
  WINEPREFIX="$prefix" WINEARCH=win64 winetricks -q dxvk corefonts fontsmooth=rgb \
    >/dev/null 2>&1 || warn "winetricks reported issues — check the log for details."
  ok "winetricks components installed."
}

# ---------------------------------------------------------------------------
# Registry tweaks
# ---------------------------------------------------------------------------
apply_registry_tweaks() {
  local prefix="$1"
  say "Applying Cavalry-specific registry tweaks..."

  # Force the Wine graphics driver to X11 (XWayland) first, falling back to
  # Wayland. Wine's native Wayland driver can break NVIDIA + OpenGL apps.
  #   HKCU\Software\Wine\Drivers → Graphics = x11,wayland
  WINEPREFIX="$prefix" "$WINE_EXE" reg add \
    "HKCU\\Software\\Wine\\Drivers" /v Graphics /t REG_SZ /d "x11,wayland" /f \
    >/dev/null 2>&1 || warn "Could not set the Wine graphics driver."

  # DLL overrides recommended by the community guide:
  #   icuuc / icuin → Native, Builtin
  WINEPREFIX="$prefix" "$WINE_EXE" reg add \
    "HKCU\\Software\\Wine\\DllOverrides" /v "icuuc" /d "native,builtin" /f \
    >/dev/null 2>&1 || true
  WINEPREFIX="$prefix" "$WINE_EXE" reg add \
    "HKCU\\Software\\Wine\\DllOverrides" /v "icuin" /d "native,builtin" /f \
    >/dev/null 2>&1 || true

  ok "Registry tweaks applied."
}

# ---------------------------------------------------------------------------
# Info
# ---------------------------------------------------------------------------
prefix_info() {
  printf 'WINEPREFIX: %s\n' "$(default_prefix)"
  printf 'WINE_BIN:   %s\n' "${WINE_BIN:-<none>}"
}
