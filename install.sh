#!/bin/bash
# install.sh — one-command installer for Cavalry (the animation app) on Linux
# via Wine. Part of CavalryOnLinux-Installer (GPL-3.0).
#
# Usage:
#   ./install.sh                 install Cavalry (defaults: system Wine, ~/.cavalry)
#   ./install.sh --build-wine    also build the patched Wine (connection-drag fix)
#   ./install.sh --wine PATH     use a specific wine binary
#   ./install.sh --prefix PATH   use a specific WINEPREFIX
#   ./install.sh --msi-url URL   override the official installer URL
#   ./install.sh --uninstall     remove the launcher + prefix (keep cache)
#   ./install.sh --help

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
source "$ROOT/lib/common.sh"
source "$ROOT/lib/distro.sh"

# ---------------------------------------------------------------------------
# Arguments
# ---------------------------------------------------------------------------
BUILD_WINE=0
DO_UNINSTALL=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --build-wine)  BUILD_WINE=1; shift ;;
    --wine)        CALVARY_WINE="$2"; shift 2 ;;
    --prefix)      CALVARY_PREFIX="$2"; shift 2 ;;
    --msi-url)     MSI_URL="$2"; shift 2 ;;
    --uninstall)   DO_UNINSTALL=1; shift ;;
    --help|-h)     cat <<'EOF'
Cavalry-on-Linux installer

Usage:
  ./install.sh                   standard install (system Wine, prefix ~/.cavalry)
  ./install.sh --build-wine      also build patched Wine (fixes connection drag; 20-60 min)
  ./install.sh --wine PATH       use a specific Wine binary
  ./install.sh --prefix DIR      use a custom WINEPREFIX
  ./install.sh --msi-url URL     override the official installer URL
  ./install.sh --uninstall       remove launchers + app files (keep prefix/data)

Docs: docs/WINE.md, docs/DISTROS.md, docs/LEGAL.md
EOF
             exit 0 ;;
    *)             err "Unknown argument: $1"; exit 1 ;;
  esac
done

detect_distro

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  local log_file
  log_file="$(start_log)"
  dim "Log: $log_file"

  if [[ "$DO_UNINSTALL" == "1" ]]; then
    source "$ROOT/lib/cavalry-install.sh"
    source "$ROOT/lib/launcher.sh"
    remove_launcher
    uninstall_cavalry
    ok "Uninstall finished. The Wine prefix (data) was kept: $(default_prefix)"
    ok "To delete everything including your prefix: rm -rf $(default_prefix)"
    return 0
  fi

  say "Cavalry-on-Linux installer"
  dim "Detected: $(distro_label) (package manager: $PM)"

  # 1. Wine engine.
  source "$ROOT/lib/wine.sh"
  if [[ "$BUILD_WINE" == "1" ]]; then
    build_patched_wine
  fi
  ensure_wine || die "No usable Wine found. See docs/DISTROS.md."

  # 2. Prefix setup (wineboot + winetricks + registry tweaks).
  source "$ROOT/lib/prefix.sh"
  setup_prefix

  # 3. Download + install Cavalry.
  source "$ROOT/lib/cavalry-install.sh"
  local msi
  msi="$(download_msi)"
  install_msi "$msi"

  # 4. Launcher + protocol handler (Canva sign-in).
  source "$ROOT/lib/launcher.sh"
  install_launcher
  install_protocol_handler

  say "Installation complete!"
  cat <<DONE

  Next steps:
    1. Launch Cavalry from your application menu (or run: cavalry)
    2. Sign in with your Canva account (free Starter plan) — or your Scene
       Group account if you use an older Cavalry version.
    3. If the sign-in window opens as a blank page, close it and re-open the
       app; the cavalry:// handler should now route it correctly.

  Troubleshooting:  docs/WINE.md
  Legal / ToS:      docs/LEGAL.md
  Uninstall:        ./uninstall.sh   (or ./install.sh --uninstall)
DONE
}

main "$@"
