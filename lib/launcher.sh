#!/bin/bash
# launcher.sh — install the .desktop launcher and the cavalry:// protocol
# handler (needed for Canva sign-in to open Cavalry). Part of
# CavalryOnLinux-Installer (GPL-3.0).

# shellcheck source=lib/common.sh
: "${LIB_DIR:=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib}"
source "$LIB_DIR/common.sh"

APPS_DIR="$HOME/.local/share/applications"

# ---------------------------------------------------------------------------
# Launcher entry
# ---------------------------------------------------------------------------
# Write Cavalry.desktop so the app appears in the application menu.
install_launcher() {
  ensure_dir "$APPS_DIR"
  local prefix="$(default_prefix)" wine_bin="${WINE_BIN:-wine}" p

  # Absolute path to wine (needed in Exec lines).
  p="$(command -v "$wine_bin" 2>/dev/null || printf '%s' "$wine_bin")"

  # Windows path to the Cavalry exe.
  local win_exe='C:\Program Files\Cavalry\Cavalry.exe'
  # Working directory must match the Cavalry install dir (sign-in IPC between
  # Wine instances depends on it — see docs/WINE.md).
  local cav_dir="$prefix/drive_c/Program Files/Cavalry"

  cat > "$APPS_DIR/Cavalry.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Cavalry
Comment=Procedural animation for motion designers (Wine)
Exec=env WINEPREFIX="$prefix" WINE="$p" "$p" "$win_exe" %U
Path=$cav_dir
Icon=cavalry
Terminal=false
Categories=Graphics;2DGraphics;Video;
StartupNotify=true
EOF
  chmod +x "$APPS_DIR/Cavalry.desktop"
  ok "Launcher installed: $APPS_DIR/Cavalry.desktop"
}

# ---------------------------------------------------------------------------
# Protocol handler
# ---------------------------------------------------------------------------
# Register Cavalry as the handler for cavalry:// URLs (Canva sign-in).
install_protocol_handler() {
  ensure_dir "$APPS_DIR"
  local prefix="$(default_prefix)" wine_bin="${WINE_BIN:-wine}" p
  p="$(command -v "$wine_bin" 2>/dev/null || printf '%s' "$wine_bin")"

  # Handler must pass the URL as an argument (canva sign-in flow).
  local handler="$APPS_DIR/cavalry-handler.desktop"
  local cav_dir="$prefix/drive_c/Program Files/Cavalry"
  cat > "$handler" <<EOF
[Desktop Entry]
Type=Application
Name=Cavalry (URL handler)
Comment=Open cavalry:// links with Cavalry
Exec=env WINEPREFIX="$prefix" WINE="$p" "$p" "C:\\Program Files\\Cavalry\\Cavalry.exe" %u
Path=$cav_dir
Icon=cavalry
Terminal=false
MimeType=x-scheme-handler/cavalry;
NoDisplay=true
EOF
  chmod +x "$handler"

  # Register with the desktop environment.
  # NB: xdg-settings wants the desktop-file *ID* (basename), NOT the full
  # path — passing the full path silently fails and mimeapps.list never
  # gets the binding (verified in the field). We do both: xdg-settings
  # (DE-native) plus a direct mimeapps.list write (belt & braces).
  local handler_id
  handler_id="$(basename "$handler")"
  if have update-desktop-database; then
    update-desktop-database "$APPS_DIR" >/dev/null 2>&1 || true
  fi
  if have xdg-settings; then
    xdg-settings set default-url-scheme-handler cavalry "$handler_id" >/dev/null 2>&1 || true
  fi
  register_mime_handler "$handler_id"
  ok "Protocol handler registered (cavalry:// → Cavalry)."
}

# ---------------------------------------------------------------------------
# Mime registration (self-healing)
# ---------------------------------------------------------------------------
# Write the cavalry:// binding directly into mimeapps.list (idempotent):
# strips any previous cavalry scheme binding (including stale entries left
# by older installers or tests) and rewrites the correct one.
register_mime_handler() {
  local list="${XDG_CONFIG_HOME:-$HOME/.config}/mimeapps.list"
  local id="$1"
  ensure_dir "$(dirname "$list")"
  [[ -f "$list" ]] || : > "$list"
  # Remove every existing x-scheme-handler/cavalry line (any section).
  grep -v '^x-scheme-handler/cavalry=' "$list" > "$list.tmp" && mv "$list.tmp" "$list"
  # [Default Applications] is the authoritative section for routing.
  if ! grep -q '^\[Default Applications\]' "$list"; then
    printf '\n[Default Applications]\n' >> "$list"
  fi
  sed -i "/^\[Default Applications\]/a x-scheme-handler/cavalry=$id;" "$list"
  # Also list it as an added association (harmless, helps some DEs).
  if ! grep -q '^\[Added Associations\]' "$list"; then
    printf '\n[Added Associations]\n' >> "$list"
  fi
  sed -i "/^\[Added Associations\]/a x-scheme-handler/cavalry=$id;" "$list"
}

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------
remove_launcher() {
  rm -f "$APPS_DIR/Cavalry.desktop" "$APPS_DIR/cavalry-handler.desktop"
  local list="${XDG_CONFIG_HOME:-$HOME/.config}/mimeapps.list"
  if [[ -f "$list" ]]; then
    grep -v '^x-scheme-handler/cavalry=' "$list" > "$list.tmp" && mv "$list.tmp" "$list"
  fi
  if have update-desktop-database; then
    update-desktop-database "$APPS_DIR" >/dev/null 2>&1 || true
  fi
  ok "Launcher and protocol handler removed."
}
