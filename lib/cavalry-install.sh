#!/bin/bash
# cavalry-install.sh — download and install the official Cavalry MSI into the
# Wine prefix. Part of CavalryOnLinux-Installer (GPL-3.0).
#
# COMPLIANCE: the Cavalry.msi installer is proprietary (Canva). This script
# always downloads it from the official cavalry.studio URL at install time.
# It is never bundled, cached for redistribution, or modified.

# shellcheck source=lib/common.sh
: "${LIB_DIR:=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib}"
source "$LIB_DIR/common.sh"

# ---------------------------------------------------------------------------
# Download
# ---------------------------------------------------------------------------
# Download the official installer to the cache dir (idempotent via size check).
download_msi() {
  local dest="$CACHE_DIR/Cavalry.msi"
  ensure_dir "$CACHE_DIR"

  if [[ -f "$dest" ]]; then
    local cur_size want_size
    cur_size="$(stat -c%s "$dest" 2>/dev/null || echo 0)"
    # Official installer is ~89.7 MB; verify a sane lower bound and allow re-download.
    if [[ "$cur_size" -gt 50000000 ]]; then
      ok "Using cached installer ($(du -h "$dest" | cut -f1))." >&2
      printf '%s' "$dest"
      return 0
    fi
    warn "Cached installer looks incomplete ($cur_size bytes) — re-downloading."
    rm -f "$dest"
  fi

  say "Downloading the official Cavalry installer from cavalry.studio..." >&2
  if ! have curl && ! have wget; then
    die "Neither curl nor wget is installed — install one of them first."
  fi

  if have curl; then
    curl -fL --retry 3 -o "$dest" "$MSI_URL"
  else
    wget -O "$dest" "$MSI_URL"
  fi

  if [[ ! -s "$dest" ]]; then
    die "Download failed — check your internet connection and try again."
  fi
  ok "Installer downloaded ($(du -h "$dest" | cut -f1))." >&2
  printf '%s' "$dest"
}

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------
# Run msiexec inside the prefix to install Cavalry silently.
install_msi() {
  local prefix="$(default_prefix)" msi="$1"
  local drive_c="$prefix/drive_c"

  say "Installing Cavalry into the Wine prefix (silent)..."
  # msiexec lives inside Wine; run it through the wine binary.
  # NB: use a Windows-style path for the MSI.
  local win_msi
  win_msi="$(win_path_of "$msi")"

  if ! WINEPREFIX="$prefix" "$WINE_BIN" msiexec /i "$win_msi" /qn /norestart \
    >/dev/null 2>&1; then
    warn "Silent MSI install reported a non-zero exit — Cavalry may still be installed."
  fi

  # Verify the install produced the expected program directory.
  local exe="$drive_c/Program Files/Cavalry/Cavalry.exe"
  if [[ -f "$exe" ]]; then
    ok "Cavalry installed at $exe"
  else
    warn "Could not find Cavalry.exe after install — check the log for MSI errors."
    return 1
  fi
}

# Convert a Unix path to a Windows path under the prefix (best-effort).
win_path_of() {
  local unix="$1" prefix="$(default_prefix)"
  # Replace $prefix/drive_c/ with C:/
  if [[ "$unix" == "$prefix/drive_c/"* ]]; then
    printf 'C:\\%s' "${unix#"$prefix/drive_c/"}"
    return 0
  fi
  # Fallback: copy the file into the prefix temp and use that path.
  local tmp="$prefix/drive_c/users/$(whoami)/Temp"
  ensure_dir "$tmp"
  cp -f "$unix" "$tmp/$(basename "$unix")"
  printf 'C:\\users\\%s\\Temp\\%s' "$(whoami)" "$(basename "$unix")"
}

# ---------------------------------------------------------------------------
# Status
# ---------------------------------------------------------------------------
# Detect whether Cavalry is installed in the prefix.
cavalry_installed() {
  local prefix="$(default_prefix)"
  [[ -f "$prefix/drive_c/Program Files/Cavalry/Cavalry.exe" ]]
}

# Remove Cavalry from the prefix (files only; the prefix itself stays).
uninstall_cavalry() {
  local prefix="$(default_prefix)"
  local dir="$prefix/drive_c/Program Files/Cavalry"
  if [[ -d "$dir" ]]; then
    say "Removing Cavalry from the prefix..."
    rm -rf "$dir"
    ok "Cavalry removed."
  else
    warn "Cavalry is not installed in this prefix — nothing to remove."
  fi
}
