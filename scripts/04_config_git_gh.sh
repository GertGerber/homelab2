#!/usr/bin/env bash
# dev-auth.sh
# Standalone helper to configure global Git identity and authenticate GitHub CLI.
# Supports interactive and non-interactive (CI) usage.

set -Eeuo pipefail

# =========================
# Config / Defaults
# =========================
: "${NONINTERACTIVE:=0}"           # 1 to disable prompts; require env vars
: "${GIT_USER_NAME:=}"             # e.g., "Jane Doe"
: "${GIT_USER_EMAIL:=}"            # e.g., "jane@example.com"
: "${GITHUB_TOKEN:=}"              # classic/gh-token with appropriate scopes
: "${GH_HOST:=github.com}"         # override for GH Enterprise

SCRIPT_NAME="${BASH_SOURCE[0]##*/}"

# =========================
# Logging
# =========================
if [[ -t 1 ]]; then
  _c_reset=$'\033[0m'; _c_dim=$'\033[2m'; _c_red=$'\033[31m'; _c_yel=$'\033[33m'
  _c_grn=$'\033[32m'; _c_cya=$'\033[36m'
else
  _c_reset=""; _c_dim=""; _c_red=""; _c_yel=""; _c_grn=""; _c_cya=""
fi

log_info()    { printf "%s[i]%s %s\n"  "$_c_cya" "$_c_reset" "$*"; }
log_warn()    { printf "%s[!]%s %s\n"  "$_c_yel" "$_c_reset" "$*"; }
log_error()   { printf "%s[x]%s %s\n"  "$_c_red" "$_c_reset" "$*" >&2; }
log_success() { printf "%s[✓]%s %s\n"  "$_c_grn" "$_c_reset" "$*"; }
log_debug()   { printf "%s[·]%s %s\n"  "$_c_dim" "$_c_reset" "$*"; }

trap 'log_error "An error occurred (line $LINENO)."; exit 1' ERR

# =========================
# Helpers
# =========================
usage() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [git|gh|all|help]

Handles developer logins and identity setup.

Subcommands:
  git   Configure global Git identity (user.name, user.email) if not already set
  gh    Authenticate GitHub CLI via personal access token if not already authenticated
  all   Run both steps (default)

Environment (optional):
  NONINTERACTIVE   If 1, never prompt; require env vars (default: 0)
  GIT_USER_NAME    Preseed for Git user.name
  GIT_USER_EMAIL   Preseed for Git user.email
  GITHUB_TOKEN     Preseed for gh auth (only used when not already authenticated)
  GH_HOST          GitHub hostname (default: github.com)

Examples:
  ${SCRIPT_NAME} all
  NONINTERACTIVE=1 GIT_USER_NAME="Jane" GIT_USER_EMAIL="jane@ex.com" ${SCRIPT_NAME} git
  GITHUB_TOKEN=\$(pass show gh/token) ${SCRIPT_NAME} gh
EOF
}

have_cmd() { command -v "$1" >/dev/null 2>&1; }

pm_detect() {
  # Echo the installer command to stdout (to be eval'ed with a package name)
  if have_cmd apt-get; then        echo "sudo apt-get update -y && sudo apt-get install -y"
  elif have_cmd apt; then          echo "sudo apt update -y && sudo apt install -y"
  elif have_cmd dnf; then          echo "sudo dnf install -y"
  elif have_cmd yum; then          echo "sudo yum install -y"
  elif have_cmd zypper; then       echo "sudo zypper install -y"
  elif have_cmd pacman; then       echo "sudo pacman -Sy --noconfirm"
  elif have_cmd brew; then         echo "brew install"
  else                             echo ""; return 1
  fi
}

pm_install() {
  local pkg="$1"
  local installer
  if ! installer="$(pm_detect)"; then
    log_warn "No known package manager found. Please install '${pkg}' manually."
    return 1
  fi
  log_info "Installing '${pkg}' via package manager..."
  # shellcheck disable=SC2086
  eval "${installer} ${pkg}"
}

ensure_tool() {
  local bin="$1"
  local pkg="${2:-$1}"
  if ! have_cmd "$bin"; then
    log_warn "'$bin' not found; attempting install ($pkg)"
    pm_install "$pkg" || { log_error "Failed to install $pkg"; return 1; }
  fi
}

is_tty() { [[ -t 0 && -t 1 ]]; }

already_has_git_identity() {
  git config --global user.name >/dev/null 2>&1 && \
  git config --global user.email >/dev/null 2>&1
}

configure_git_identity() {
  ensure_tool git git || return 1

  if already_has_git_identity; then
    local name email
    name="$(git config --global user.name || true)"
    email="$(git config --global user.email || true)"
    log_info "Git identity already configured: ${name:-<unset>} <${email:-unset}>"
    return 0
  fi

  local name="${GIT_USER_NAME:-}"
  local email="${GIT_USER_EMAIL:-}"

  if [[ "$NONINTERACTIVE" -eq 1 || ! -t 0 ]]; then
    if [[ -z "$name" || -z "$email" ]]; then
      log_error "NONINTERACTIVE=1 but GIT_USER_NAME/GIT_USER_EMAIL not provided."
      return 1
    fi
  else
    if [[ -z "$name" ]]; then
      read -r -p "Enter Git user.name: " name
    fi
    if [[ -z "$email" ]]; then
      read -r -p "Enter Git user.email: " email
    fi
  fi

  if [[ -z "$name" || -z "$email" ]]; then
    log_error "Git identity not set (name or email empty)."
    return 1
  fi

  log_info "Configuring global Git identity"
  git config --global user.name "$name"
  git config --global user.email "$email"
  log_success "Git identity set to: $name <$email>"
}

is_gh_authenticated() {
  have_cmd gh && gh auth status -h "$GH_HOST" >/dev/null 2>&1
}

authenticate_gh() {
  ensure_tool gh gh || {
    log_error "GitHub CLI (gh) not installed or not on PATH."
    return 1
  }

  if gh auth status -h "$GH_HOST" >/dev/null 2>&1; then
    # Try to extract account from status output
    local acct
    acct="$(
      gh auth status -h "$GH_HOST" 2>/dev/null \
        | awk -F 'account ' '/Logged in to/ {print $2}' \
        | awk '{print $1}'
    )"
    if [[ -n "${acct:-}" ]]; then
      log_info "Already logged in to $GH_HOST (account: ${acct})."
    else
      log_info "Already logged in to $GH_HOST."
    fi
    return 0
  fi

  log_info "GitHub CLI is not authenticated for $GH_HOST."

  # Prefer token-based auth first (env or prompt if interactive)
  local _tkn="${GITHUB_TOKEN:-}"
  if [[ -z "${_tkn}" && -z "${CI:-}" && is_tty ]]; then
    read -rsp "Paste your GitHub Personal Access Token (input hidden) or press Enter to skip: " _tkn || true
    echo
  fi

  if [[ -n "${_tkn}" ]]; then
    if (( ${#_tkn} < 20 )); then
      log_warn "Token looks unusually short; double-check if login fails."
    fi
    if printf '%s' "${_tkn}" | gh auth login \
          --hostname "$GH_HOST" \
          --git-protocol https \
          --with-token >/dev/null; then
      _tkn="" # clear
      gh auth setup-git --hostname "$GH_HOST" >/dev/null 2>&1 || true
      if gh auth status -h "$GH_HOST" >/dev/null 2>&1; then
        log_success "GitHub CLI authentication successful (token)."
        return 0
      fi
    else
      log_warn "Token-based login failed."
    fi
  else
    log_info "No token provided; will try manual login if possible."
  fi

  # Fallback: interactive wizard if possible
  if is_tty && [[ -z "${CI:-}" ]]; then
    log_info "Starting interactive 'gh auth login' wizard…"
    if gh auth login --hostname "$GH_HOST" --git-protocol https; then
      gh auth setup-git --hostname "$GH_HOST" >/devnull 2>&1 || true
      if gh auth status -h "$GH_HOST" >/dev/null 2>&1; then
        log_success "GitHub CLI authentication successful (manual)."
        return 0
      fi
    fi
    log_error "Interactive login did not complete successfully."
    return 1
  fi

  # Non-interactive and no token
  log_error "Cannot start manual login in a non-interactive environment."
  log_info  "Provide a token in \$GITHUB_TOKEN or run locally with a TTY:"
  log_info  "  export GITHUB_TOKEN=YOUR_TOKEN && ./${SCRIPT_NAME} gh"
  log_info  "  gh auth login --hostname $GH_HOST --with-token < <(printf '%s' \"\$GITHUB_TOKEN\")"
  return 1
}

main() {
  local cmd="${1:-all}"
  case "$cmd" in
    git) configure_git_identity ;;
    gh)  authenticate_gh ;;
    all) configure_git_identity; authenticate_gh ;;
    -h|--help|help) usage; exit 0 ;;
    *)   log_error "Unknown subcommand: $cmd"; echo; usage; exit 1 ;;
  esac
}

main "$@"
