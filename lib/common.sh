#!/bin/bash
# common.sh — shared helpers and constants for the Cavalry-on-Linux installer.
# Part of CavalryOnLinux-Installer (GPL-3.0). Sources lib/distro.sh and exports
# the global configuration used by every other module.

# ---------------------------------------------------------------------------
# Strict mode + paths
# ---------------------------------------------------------------------------
set -euo pipefail

# Directory that contains the lib/ folder (repo root or /usr/share/cavalry-on-linux).
INSTALLER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="$INSTALLER_ROOT/lib"
PATCH_DIR="$INSTALLER_ROOT/patch"
ASSETS_DIR="$INSTALLER_ROOT/assets"
GUI_SCRIPT="$INSTALLER_ROOT/gui/cavalry-gui.py"

# User-level installation locations.
DATA_DIR="${CALVARY_DATA_DIR:-$HOME/.local/share/cavalry-on-linux}"
CACHE_DIR="${CALVARY_CACHE_DIR:-$HOME/.cache/cavalry-on-linux}"
LOG_DIR="$DATA_DIR/logs"

# ---------------------------------------------------------------------------
# Application constants (official upstream values — keep in sync manually).
# ---------------------------------------------------------------------------
MSI_URL="${CALVARY_MSI_URL:-https://cavalry.studio/downloads/latest/Cavalry.msi}"
WINE_TAG="${WINE_TAG:-wine-11.13}"
WINE_REPO="https://gitlab.winehq.org/wine/wine.git"
# Default WINEPREFIX, matching the community CavalryOnLinux guide (~/.cavalry).
DEFAULT_PREFIX="$HOME/.cavalry"

# Patched-Wine install location (from cavalry-connection-fix convention).
PATCHED_WINE_PREFIX="$HOME/.local/share/cavalry-wine"

# ---------------------------------------------------------------------------
# Output helpers (say/ok/warn/err with colors; honored by GUI log view).
# ---------------------------------------------------------------------------
if [[ -t 1 ]] && [[ "${NO_COLOR:-}" != "1" ]]; then
  C_CYAN=$'\033[1;36m'; C_GREEN=$'\033[1;32m'; C_YELLOW=$'\033[1;33m'
  C_RED=$'\033[1;31m'; C_DIM=$'\033[2m'; C_RESET=$'\033[0m'
else
  C_CYAN=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_DIM=""; C_RESET=""
fi

say()  { printf '\n%s%s%s\n' "$C_CYAN" "$*" "$C_RESET"; }
ok()   { printf '%s✔ %s%s\n' "$C_GREEN" "$*" "$C_RESET"; }
warn() { printf '%s! %s%s\n' "$C_YELLOW" "$*" "$C_RESET"; }
err()  { printf '%s✗ %s%s\n' "$C_RED" "$*" "$C_RESET" >&2; }
dim()  { printf '%s%s%s\n' "$C_DIM" "$*" "$C_RESET"; }

die() {
  err "$*"
  exit 1
}

# Confirm a yes/no prompt. Returns 0 for yes, 1 for no. Default no.
confirm() {
  local prompt="${1:-Continue?}" answer
  read -r -p "$prompt (y/N): " answer
  [[ "${answer,,}" == "y" || "${answer,,}" == "yes" ]]
}

# ---------------------------------------------------------------------------
# Misc helpers
# ---------------------------------------------------------------------------
have() { command -v "$1" >/dev/null 2>&1; }

need_cmd() {
  local cmd="$1" hint="${2:-}"
  if ! have "$cmd"; then
    err "Required command not found: $cmd"
    [[ -n "$hint" ]] && err "$hint"
    exit 1
  fi
}

is_root() { [[ "$(id -u)" -eq 0 ]]; }

# Resolve an absolute Windows-style path inside the prefix (e.g. C:\...) to a
# filesystem path under $WINEPREFIX/drive_c.
wine_path() {
  # winepath may live next to wine; fall back to direct expansion.
  if have winepath && [[ -n "${WINEPREFIX:-}" ]]; then
    WINEPREFIX="$WINEPREFIX" winepath -u "$1" 2>/dev/null || true
  fi
}

# Choose the default "cavalry" WINEPREFIX: $CALVARY_PREFIX if set, else
# ~/.cavalry (community standard).
default_prefix() {
  printf '%s' "${CALVARY_PREFIX:-$DEFAULT_PREFIX}"
}

# Location where the patched wine binary is installed (respects CALVARY_WINE).
patched_wine_bin() {
  printf '%s' "${CALVARY_WINE:-$PATCHED_WINE_PREFIX/bin/wine}"
}

# Ensure a directory exists.
ensure_dir() {
  mkdir -p "$1"
}

# Rotate + create the log file for the current run; print its path.
start_log() {
  ensure_dir "$LOG_DIR"
  local log_file="$LOG_DIR/cavalry-$(date +%Y%m%d-%H%M%S).log"
  touch "$log_file"
  printf '%s' "$log_file"
}
