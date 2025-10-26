#!/usr/bin/env bash
set -euo pipefail

# ╭──────────────────────────────────────────────────────────────╮
# │  Ansible / Python bootstrap (nala preferred, apt fallback)   │
# ╰──────────────────────────────────────────────────────────────╯

require_debian_like() {
  if [ ! -f /etc/debian_version ]; then
    echo "This script targets Debian/Ubuntu. Detected non-Debian system."
    echo "Aborting to avoid breaking your setup."
    exit 1
  fi
}

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    echo "sudo not found and you are not root. Please run as root or install sudo."
    exit 1
  fi
fi

# Always run APT non-interactively
APT_ENV=(env DEBIAN_FRONTEND=noninteractive APT_LISTCHANGES_FRONTEND=none)


PM="apt-get"   # default
pm_update() {
  if [ "$PM" = "nala" ]; then
    $SUDO "${APT_ENV[@]}" nala update
  else
    $SUDO "${APT_ENV[@]}" apt-get update
  fi
}
pm_install() {
  if [ "$PM" = "nala" ]; then
    $SUDO "${APT_ENV[@]}" nala install -y "$@"
  else
    $SUDO "${APT_ENV[@]}" apt-get install -y "$@"
  fi
}
pkg_available() {
  # returns 0 if package exists in apt cache
  apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/ {print $2}' | grep -vq '(none)'
}

ensure_nala_or_apt() {
  if command -v nala >/dev/null 2>&1; then
    PM="nala"
    return
  fi
  # Try to install nala, then prefer it; otherwise stick with apt-get
  pm_update || true
  if pkg_available "nala"; then
    $SUDO "${APT_ENV[@]}" apt-get install -y nala || true
  fi
  if command -v nala >/dev/null 2>&1; then
    PM="nala"
  else
    PM="apt-get"
  fi
}

ensure_sys_packages() {
  pm_update
  pm_install ca-certificates curl gnupg lsb-release apt-transport-https \
    build-essential unzip zip tar jq bash-completion software-properties-common \
    git gh sshpass >/dev/null 2>&1 || true
  pm_install python3 python3-venv python3-pip
}

# Prefer distro pipx; fallback to pipx via pip.
ensure_pipx() {
  if command -v pipx >/dev/null 2>&1; then return; fi

  # Try distro packages first (both names used across distros)
  if pkg_available "pipx"; then
    pm_install pipx && return
  fi
  if pkg_available "python3-pipx"; then
    pm_install python3-pipx && return
  fi

  # Fallback: install via pip. Use global dirs if running as root.
  if command -v python3 >/dev/null 2>&1 && python3 -m pip --version >/dev/null 2>&1; then
    if [ "$(id -u)" -eq 0 ]; then
      export PIPX_HOME="${PIPX_HOME:-/opt/pipx}"
      export PIPX_BIN_DIR="${PIPX_BIN_DIR:-/usr/local/bin}"
      mkdir -p "$PIPX_HOME" "$PIPX_BIN_DIR"
      python3 -m pip install --upgrade pip setuptools wheel >/dev/null
      python3 -m pip install pipx
    else
    python3 -m pip install --user --upgrade pip setuptools wheel >/dev/null
    python3 -m pip install --user pipx
    fi
  else
    echo "python3/pip missing; expected to be installed earlier."
    exit 1
  fi
}

ensure_path_for_pipx() {
  if [ "$(id -u)" -eq 0 ]; then
    # root: prefer global bin dir
    local bin="${PIPX_BIN_DIR:-/usr/local/bin}"
    case ":$PATH:" in *":$bin:"*) : ;; *) export PATH="$bin:$PATH" ;; esac
  else
    # user
    if command -v pipx >/dev/null 2>&1; then
    pipx ensurepath >/dev/null 2>&1 || true
  else
      python3 -m pipx ensurepath >/dev/null 2>&1 || true
  fi

  # Add to current session PATH if needed
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) : ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
    esac
  fi
}

pipx_install_if_absent() {
  local pkg="$1"
  # pipx is idempotent: will no-op if already installed
  pipx install "$pkg" >/dev/null 2>&1 || pipx install "$pkg"
}

ensure_molecule_plugins() {
  # Install molecule itself (if absent), then inject the docker driver plugin.
  pipx_install_if_absent molecule
  # Inject plugin library into molecule's venv (safe to repeat)
  pipx inject molecule 'molecule-plugins[docker]' >/dev/null 2>&1 || pipx inject molecule 'molecule-plugins[docker]'
}

main() {
  require_debian_like
  ensure_nala_or_apt
  echo "Using package manager: $PM"

  ensure_sys_packages
  ensure_pipx
  ensure_path_for_pipx

  # Install CLI tools into isolated pipx venvs
  echo "Installing Ansible CLI tooling with pipx (idempotent)…"
  pipx_install_if_absent ansible
  pipx_install_if_absent ansible-lint
  pipx_install_if_absent yamllint
  pipx_install_if_absent pre-commit
  ensure_molecule_plugins
  # pipx_install_if_absent molecule
  # pipx_install_if_absent 'molecule-plugins[docker]'

  echo
  echo "✅ Done."
  echo "   - System: python3, python3-venv, python3-pip"
  if command -v pipx >/dev/null 2>&1; then
    echo "   - pipx: $(pipx --version 2>/dev/null || echo installed)"
    echo "   - Installed apps via pipx:"
    pipx list | sed 's/^/     /'
  else
    echo "   - pipx installed (ensure your shell PATH includes ~/.local/bin)"
  fi
  echo
  echo "Tip: open a new shell or run 'hash -r' so your shell picks up any new commands."
}

main "$@"
