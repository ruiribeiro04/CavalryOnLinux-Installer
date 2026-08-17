#!/bin/bash
# uninstall.sh — remove the Cavalry launcher + app files, and optionally the
# Wine prefix. Part of CavalryOnLinux-Installer (GPL-3.0).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
source "$ROOT/lib/common.sh"
source "$ROOT/lib/cavalry-install.sh"
source "$ROOT/lib/launcher.sh"

say "Cavalry uninstall"

# 1. Launcher + protocol handler.
remove_launcher

# 2. App files inside the prefix.
uninstall_cavalry

# 3. Optionally delete the whole prefix (all data).
if confirm "Delete the entire Wine prefix ($(default_prefix))? This removes all your Cavalry data and settings."; then
  rm -rf "$(default_prefix)"
  ok "Prefix removed."
else
  dim "Prefix kept: $(default_prefix)"
fi

# 4. Optionally delete the cached installer.
if confirm "Delete the cached installer (~$CACHE_DIR)?"; then
  rm -rf "$CACHE_DIR"
  ok "Cache removed."
else
  dim "Cache kept: $CACHE_DIR"
fi

# 5. Optionally remove the patched Wine build.
if [[ -x "$(patched_wine_bin)" ]] && confirm "Remove the patched Wine build too ($(patched_wine_bin))?"; then
  rm -rf "$(dirname "$(dirname "$(patched_wine_bin)")")"
  ok "Patched Wine removed."
fi

ok "Uninstall finished."
