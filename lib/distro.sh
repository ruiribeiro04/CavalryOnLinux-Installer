#!/bin/bash
# distro.sh — detect the Linux distribution and package manager.
# Part of CavalryOnLinux-Installer (GPL-3.0).

# ---------------------------------------------------------------------------
# Detection
# ---------------------------------------------------------------------------
# Reads /etc/os-release (present on every modern distro) and sets:
#   DISTRO_ID, DISTRO_LIKE, DISTRO_VERSION, PM (package manager)
# Export the variables so callers and subprocesses can use them.
detect_distro() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    DISTRO_ID="${ID:-unknown}"
    DISTRO_LIKE="${ID_LIKE:-}"
    DISTRO_VERSION="${VERSION_ID:-}"
  else
    # Very old fallback (no /etc/os-release).
    if [[ -f /etc/debian_version ]]; then
      DISTRO_ID="debian"; DISTRO_LIKE="debian"; DISTRO_VERSION=""
    elif [[ -f /etc/redhat-release ]]; then
      DISTRO_ID="rhel"; DISTRO_LIKE="rhel fedora"; DISTRO_VERSION=""
    elif [[ -f /etc/arch-release ]]; then
      DISTRO_ID="arch"; DISTRO_LIKE="arch"; DISTRO_VERSION=""
    else
      DISTRO_ID="unknown"; DISTRO_LIKE=""; DISTRO_VERSION=""
    fi
  fi
  PM="$(detect_pm)"
  export DISTRO_ID DISTRO_LIKE DISTRO_VERSION PM
}

# Pick the package manager based on the distro id / like fields.
detect_pm() {
  case "$DISTRO_ID" in
    debian|ubuntu|linuxmint|pop|zorin|elementary|pikaos|kali|raspbian|neon)
      echo "apt" ;;
    fedora|rhel|centos|nobara|rocky|almalinux|mageia|openmandriva)
      echo "dnf" ;;
    arch|endeavouros|manjaro|cachyos|garuda|artix|arcolinux|archlinux|chaotic|blackarch|xerolinux|biglinux|rebornos)
      echo "pacman" ;;
    opensuse*|suse|tumbleweed|leap)
      echo "zypper" ;;
    *)
      # Fall back to whatever binary exists.
      for pm in pacman dnf apt-get zypper; do
        if command -v "$pm" >/dev/null 2>&1; then
          echo "$pm"
          return
        fi
      done
      echo "unknown" ;;
  esac
}

# Human-readable label for messages.
distro_label() {
  [[ -n "$DISTRO_VERSION" ]] && printf '%s %s' "$DISTRO_ID" "$DISTRO_VERSION" || printf '%s' "$DISTRO_ID"
}

# ---------------------------------------------------------------------------
# Package-manager helpers
# ---------------------------------------------------------------------------
# Run a package manager command with sudo when needed (never assume root).
pm_install() {
  local pkg
  case "$PM" in
    apt)
      if ! is_root; then sudo apt-get update -qq && sudo apt-get install -y "$@"; else apt-get update -qq && apt-get install -y "$@"; fi
      ;;
    dnf)
      if ! is_root; then sudo dnf install -y "$@"; else dnf install -y "$@"; fi
      ;;
    pacman)
      if ! is_root; then sudo pacman -S --needed --noconfirm "$@"; else pacman -S --needed --noconfirm "$@"; fi
      ;;
    zypper)
      if ! is_root; then sudo zypper --non-interactive install "$@"; else zypper --non-interactive install "$@"; fi
      ;;
    *)
      warn "Unsupported package manager ($PM) — please install packages manually: $*"
      return 1
      ;;
  esac
}

pm_query_installed() {
  case "$PM" in
    apt)    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed" ;;
    dnf)    rpm -q "$1" >/dev/null 2>&1 ;;
    pacman) pacman -Qi "$1" >/dev/null 2>&1 ;;
    zypper) rpm -q "$1" >/dev/null 2>&1 ;;
    *)      return 1 ;;
  esac
}

# Ensure a list of packages is installed (best-effort; warns instead of failing
# when the user may not have permission / packages differ).
ensure_packages() {
  local missing=() pkg
  for pkg in "$@"; do
    if ! pm_query_installed "$pkg"; then
      missing+=("$pkg")
    fi
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    say "Installing missing packages: ${missing[*]}"
    if ! pm_install "${missing[@]}"; then
      warn "Some packages could not be installed automatically."
      return 1
    fi
  fi
  ok "All required packages are present."
}
