#!/bin/bash
# wine.sh — locate and (optionally) build the patched Wine for Cavalry.
# Part of CavalryOnLinux-Installer (GPL-3.0).
#
# Wine engine resolution priority:
#   1. $CALVARY_WINE (explicit path, e.g. patched build)
#   2. ~/.local/share/cavalry-wine/bin/wine (patched wine built by this installer)
#   3. system wine / wine-staging / wine (whatever the distro ships)
# The chosen binary is exported as WINE_BIN; the WINEPREFIX is configured in
# prefix.sh.

# Re-source common.sh in case this file is sourced standalone.
# shellcheck source=lib/common.sh
: "${LIB_DIR:=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib}"
source "$LIB_DIR/common.sh"

# Select the wine binary to use, in priority order. Sets WINE_BIN.
select_wine() {
  # 1. Explicit override.
  if [[ -n "${CALVARY_WINE:-}" ]]; then
    if [[ -x "$CALVARY_WINE" ]]; then
      WINE_BIN="$CALVARY_WINE"
      ok "Using explicit Wine: $WINE_BIN"
      return 0
    fi
    warn "CALVARY_WINE points to a missing binary: $CALVARY_WINE"
  fi

  # 2. Patched wine previously built by this installer.
  local patched="$(patched_wine_bin)"
  if [[ -x "$patched" ]]; then
    WINE_BIN="$patched"
    ok "Using patched Wine (Cavalry connection fix): $WINE_BIN"
    return 0
  fi

  # 3. System wine, preferring staging builds.
  for cand in wine-staging wine wine64; do
    if have "$cand"; then
      WINE_BIN="$(command -v "$cand")"
      ok "Using system Wine: $WINE_BIN"
      if [[ "$cand" != "wine-staging" ]]; then
        dim "Tip: install wine-staging for better DXVK compatibility."
      fi
      return 0
    fi
  done

  # 4. Nothing found.
  err "No Wine installation found."
  err "Install Wine (see docs/DISTROS.md) or build the patched one with:"
  err "  $0 --build-wine"
  return 1
}

# Ensure wine is runnable at all (any build). Returns the found binary or fails.
ensure_wine() {
  if ! select_wine; then
    return 1
  fi
  if ! have winepath; then
    warn "winepath not found — Windows→Unix path conversion will be limited."
  fi
}

# Build the patched Wine (wine-11.13 + cavalry-connection-fix patch) into
# $PATCHED_WINE_PREFIX. Requires build dependencies; prompts to install them.
# This is the slow path (20–60 min).
build_patched_wine() {
  local src_dir build_dir patch_file prefix

  src_dir="$PATCHED_WINE_PREFIX-src"
  build_dir="$PATCHED_WINE_PREFIX-build"
  prefix="$PATCHED_WINE_PREFIX"
  patch_file="$PATCH_DIR/cavalry-connection-noodle-park-and-overlay.patch"

  if [[ ! -f "$patch_file" ]]; then
    die "Patch file missing: $patch_file"
  fi

  say "Building patched Wine $WINE_TAG (Cavalry connection-drag fix)"
  warn "This downloads a few hundred MB and builds for 20–60 minutes. Fans may spin."

  # Ensure git exists (needed for the source clone).
  if ! have git; then
    warn "git is required to fetch the Wine source."
    if confirm "Install git now?"; then
      ensure_packages git || die "Could not install git."
    else
      die "git is required."
    fi
  fi

  # Build dependencies are distro-specific — see docs/DISTROS.md for details.
  install_wine_build_deps

  # 1. Clone the Wine source (once).
  if [[ -d "$src_dir/.git" ]]; then
    ok "Wine source already present at $src_dir — reusing."
  else
    say "Cloning Wine $WINE_TAG (this downloads a few hundred MB)..."
    git clone --depth 1 --branch "$WINE_TAG" "$WINE_REPO" "$src_dir"
  fi

  # 2. Apply the Cavalry patch (idempotent).
  say "Applying the Cavalry connection-drag patch"
  (
    cd "$src_dir"
    if git apply --reverse --check "$patch_file" >/dev/null 2>&1; then
      ok "Patch already applied — skipping."
    elif git apply --check "$patch_file" >/dev/null 2>&1; then
      git apply "$patch_file"
      ok "Patch applied cleanly."
    else
      # Fall back to plain patch with fuzz for small upstream drift.
      dim "Clean apply failed; retrying with patch --fuzz..."
      if patch -p1 --forward --fuzz=3 <"$patch_file"; then
        ok "Patch applied with fuzz."
      else
        die "The patch did not apply to Wine $WINE_TAG. See docs/WINE.md."
      fi
    fi
  )

  # 3. Configure + build (x86_64 only — Cavalry is 64-bit).
  say "Configuring and building (x86_64 only — Cavalry is 64-bit)"
  ensure_dir "$build_dir"
  (
    cd "$build_dir"
    "$src_dir/configure" --prefix="$prefix" --enable-archs=x86_64
    make -j"$(nproc)"
  )
  make -C "$build_dir" install

  if [[ ! -x "$prefix/bin/wine" ]]; then
    die "Build finished but $prefix/bin/wine is missing — something went wrong."
  fi
  ok "Patched Wine ready at: $prefix/bin/wine"
}

# Install the distro-specific Wine build dependencies (from cavalry-connection-fix).
install_wine_build_deps() {
  local pkgs=()
  case "$PM" in
    dnf)
      pkgs=(mingw64-gcc mingw32-gcc opencl-headers mesa-libGL-devel
            mesa-libEGL-devel vulkan-loader-devel gnutls-devel libxslt-devel
            alsa-lib-devel pulseaudio-libs-devel pipewire-devel SDL2-devel cups-devel)
      say "Installing Wine build dependencies (dnf)"
      if ! is_root; then
        sudo dnf builddep -y wine 2>/dev/null || \
          warn "dnf builddep failed — install the listed packages manually."
      else
        dnf builddep -y wine 2>/dev/null || warn "dnf builddep failed."
      fi
      ;;
    apt)
      pkgs=(gcc-mingw-w64 opencl-headers libgl1-mesa-dev libegl1-mesa-dev
            libvulkan-dev libgnutls28-dev libxslt1-dev libasound2-dev
            libpulse-dev libpipewire-0.3-dev libsdl2-dev libcups2-dev)
      say "Installing Wine build dependencies (apt)"
      if ! is_root; then
        sudo apt-get update -qq
        sudo apt-get build-dep -y wine 2>/dev/null || \
          warn "apt build-dep failed — enable Sources and retry, or install manually."
      else
        apt-get update -qq
        apt-get build-dep -y wine 2>/dev/null || warn "apt build-dep failed."
      fi
      ;;
    pacman)
      pkgs=(mingw-w64-gcc opencl-headers mesa vulkan-icd-loader gnutls libxslt
            alsa-lib libpulse pipewire sdl2 cups base-devel)
      say "Installing Wine build dependencies (pacman)"
      ;;
    zypper)
      pkgs=(gcc opencl-headers Mesa-libGL-devel gnutls-devel libxslt-devel
            alsa-devel libpulse-devel pipewire-devel libSDL2-devel cups-devel)
      say "Installing Wine build dependencies (zypper)"
      if ! is_root; then
        sudo zypper --non-interactive install -t pattern devel_basis 2>/dev/null || true
      else
        zypper --non-interactive install -t pattern devel_basis 2>/dev/null || true
      fi
      ;;
    *)
      warn "Unknown package manager — please install Wine's build dependencies manually."
      return 1
      ;;
  esac
  [[ ${#pkgs[@]} -gt 0 ]] && ensure_packages "${pkgs[@]}" || true
}
