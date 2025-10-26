#!/usr/bin/env bash
set -euo pipefail

# ── Set Project ROOT Folder ────────────────────────────────────────────────────────────────────
# find_root: find project / repo root from anywhere

find_root() {
  local cwd="$PWD"
  local markers=( \
    ".git" ".gitignore" "package.json" "pyproject.toml" "setup.cfg" "requirements.txt" \
    "Makefile" "Dockerfile" "ansible.cfg" "ansible" "scripts" "menus" "README.md" \
    ".projectroot" ".repo" \
  )
  # allow caller to add more markers
  if [ "$#" -gt 0 ]; then
    markers=("$@" "${markers[@]}")
  fi

  # 1) If inside git repo prefer git top-level (fast & reliable)
  if command -v git >/dev/null 2>&1; then
    if git_root=$(git rev-parse --show-toplevel 2>/dev/null); then
      printf '%s\n' "$git_root"
      return 0
    fi
  fi

  # 2) Walk up looking for markers
  local dir="$cwd"
  while true; do
    for m in "${markers[@]}"; do
      if [ -e "$dir/$m" ]; then
        printf '%s\n' "$dir"
        return 0
      fi
    done

    # stop at filesystem root
    if [ "$dir" = "/" ] || [ -z "$dir" ]; then
      break
    fi

    # move up
    dir=$(dirname "$dir")
  done

  # 3) Not found - fallback (echo / and non-zero return so caller can tell)
  printf '/\n'
  return 1
}


# Ensure $ROOT_DIR is defined even under 'set -u'
: "${ROOT_DIR:=}"

if [ -z "$ROOT_DIR" ] || [ "$ROOT_DIR" = "/" ]; then
    if ROOT_DIR=$(find_root homelab menus ansible scripts 2>/dev/null); then
        :
    else
        ROOT_DIR="/"
        echo "project root not found, using $ROOT_DIR (fallback)"
        # handle fallback...
    fi
fi

# ── Main logic ───────────────────────────────────────────────────────
make_exec() {
  local target="${1:-}"
  [[ -n "$target" ]] || die "Usage: $0 <file-or-directory>"

  if [[ -d "$target" ]]; then
    echo "Directory selected: $target"
    mapfile -d '' files < <(find "$target" -type f -name '*.sh' -print0)
    if (( ${#files[@]} == 0 )); then
      warn "No *.sh files found under: $target"
      return 0
    fi
    printf '%s\0' "${files[@]}" | xargs -0 chmod +x
    echo "Marked ${#files[@]} shell script(s) executable."
  elif [[ -f "$target" ]]; then
    echo "File selected: $target"
    chmod +x -- "$target"
    [[ "$target" == *.sh ]] || warn "File does not end with .sh; made it executable anyway."
    echo "Marked 1 file executable."
  else
    echo "Selection is neither a regular file nor a directory: $target"
  fi
}

main() {
  local selection="${1:-${ROOT_DIR:-$PWD}}"
  make_exec "$selection"
}
main "$@"