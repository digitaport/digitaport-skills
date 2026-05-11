#!/usr/bin/env bash
set -euo pipefail

DEFAULT_REPO_URL="https://github.com/digitaport/digitaport-skills.git"
DEFAULT_REF="main"

REPO_URL="${DIGITAPORT_SKILLS_REPO_URL:-}"
REF="${DIGITAPORT_SKILLS_REF:-}"
INSTALL_ROOT="${DIGITAPORT_SKILLS_INSTALL_ROOT:-$HOME/.digitaport/skills/digitaport-skills}"
AGENTS_DIR="${DIGITAPORT_AGENTS_SKILLS_DIR:-$HOME/.agents/skills}"
STATE_DIR="${DIGITAPORT_SKILLS_STATE_DIR:-$HOME/.agents/.digitaport-skills}"
FORCE=0
REPO_URL_SET=0
REF_SET=0

if [ -n "$REPO_URL" ]; then
  REPO_URL_SET=1
fi

if [ -n "$REF" ]; then
  REF_SET=1
fi

usage() {
  cat <<EOF
Install or update Digitaport Copilot skills.

Usage:
  ./scripts/install.sh [options]

Options:
  --repo-url URL       Git repository to install from.
  --ref REF            Branch, tag, or commit to install. Defaults to: $DEFAULT_REF
  --install-root PATH  Managed clone location.
  --agents-dir PATH    Target skills directory. Defaults to: ~/.agents/skills
  --force              Replace conflicting existing symlinks or directories.
  --help               Show this help.

Environment overrides:
  DIGITAPORT_SKILLS_REPO_URL
  DIGITAPORT_SKILLS_REF
  DIGITAPORT_SKILLS_INSTALL_ROOT
  DIGITAPORT_AGENTS_SKILLS_DIR
  DIGITAPORT_SKILLS_STATE_DIR

Examples:
  ./scripts/install.sh
  ./scripts/install.sh --ref v1.2.0
  ./scripts/install.sh --repo-url git@github.com:digitaport/digitaport-skills.git
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo-url)
      REPO_URL="$2"
      REPO_URL_SET=1
      shift 2
      ;;
    --ref)
      REF="$2"
      REF_SET=1
      shift 2
      ;;
    --install-root)
      INSTALL_ROOT="$2"
      shift 2
      ;;
    --agents-dir)
      AGENTS_DIR="$2"
      shift 2
      ;;
    --force)
      FORCE=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: required command not found: $1" >&2
    exit 1
  fi
}

load_state_defaults() {
  local metadata_file
  metadata_file="$STATE_DIR/metadata.env"

  if [ ! -f "$metadata_file" ]; then
    return 0
  fi

  if [ "$REPO_URL_SET" -eq 0 ]; then
    REPO_URL="$(grep '^REPO_URL=' "$metadata_file" | sed 's/^REPO_URL=//')"
  fi

  if [ "$REF_SET" -eq 0 ]; then
    REF="$(grep '^REF=' "$metadata_file" | sed 's/^REF=//')"
  fi
}

load_repo_default() {
  local script_dir repo_root detected_url
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  if ! repo_root="$(git -C "$script_dir/.." rev-parse --show-toplevel 2>/dev/null)"; then
    return 0
  fi

  if [ "$REPO_URL_SET" -eq 1 ]; then
    return 0
  fi

  detected_url="$(git -C "$repo_root" remote get-url origin 2>/dev/null || true)"
  if [ -n "$detected_url" ]; then
    REPO_URL="$detected_url"
  fi
}

apply_fallback_defaults() {
  if [ -z "$REPO_URL" ]; then
    REPO_URL="$DEFAULT_REPO_URL"
  fi

  if [ -z "$REF" ]; then
    REF="$DEFAULT_REF"
  fi
}

ensure_parent_dir() {
  local path
  path="$1"
  mkdir -p "$(dirname "$path")"
}

backup_path() {
  local path backup
  path="$1"
  backup="$path.backup.$(date +%Y%m%d%H%M%S)"
  mv "$path" "$backup"
  echo "backed up existing path: $path -> $backup"
}

is_owned_symlink() {
  local target resolved
  target="$1"

  if [ ! -L "$target" ]; then
    return 1
  fi

  resolved="$(readlink "$target")"
  case "$resolved" in
    "$INSTALL_ROOT"/*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

sync_repo() {
  ensure_parent_dir "$INSTALL_ROOT"

  if [ -d "$INSTALL_ROOT/.git" ]; then
    git -C "$INSTALL_ROOT" remote set-url origin "$REPO_URL"
    git -C "$INSTALL_ROOT" fetch --tags --prune origin "$REF"
  else
    if [ -e "$INSTALL_ROOT" ]; then
      if [ "$FORCE" -eq 1 ]; then
        backup_path "$INSTALL_ROOT"
      else
        echo "error: install root exists and is not a git repository: $INSTALL_ROOT" >&2
        echo "Re-run with --force to back it up and continue." >&2
        exit 1
      fi
    fi
    git clone --filter=blob:none "$REPO_URL" "$INSTALL_ROOT"
    git -C "$INSTALL_ROOT" fetch --tags --prune origin "$REF"
  fi

  git -C "$INSTALL_ROOT" checkout --detach --force FETCH_HEAD >/dev/null 2>&1
}

write_state() {
  local commit installed_file metadata_file
  commit="$1"
  installed_file="$STATE_DIR/installed-skills.txt"
  metadata_file="$STATE_DIR/metadata.env"

  mkdir -p "$STATE_DIR"
  printf '%s\n' "$@" | tail -n +2 > "$installed_file"

  cat > "$metadata_file" <<EOF
REPO_URL=$REPO_URL
REF=$REF
INSTALL_ROOT=$INSTALL_ROOT
AGENTS_DIR=$AGENTS_DIR
COMMIT=$commit
UPDATED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
}

cleanup_stale_links() {
  local installed_file name target
  installed_file="$STATE_DIR/installed-skills.txt"

  if [ ! -f "$installed_file" ]; then
    return 0
  fi

  while IFS= read -r name; do
    [ -n "$name" ] || continue
    target="$AGENTS_DIR/$name"
    if grep -Fxq "$name" "$STATE_DIR/.current-skills.txt"; then
      continue
    fi
    if is_owned_symlink "$target"; then
      rm -f "$target"
      echo "removed stale link: $target"
    fi
  done < "$installed_file"
}

require_command git
require_command find
require_command readlink

load_state_defaults
load_repo_default
apply_fallback_defaults

mkdir -p "$AGENTS_DIR"
sync_repo

current_commit="$(git -C "$INSTALL_ROOT" rev-parse HEAD)"
tmp_current_skills="$STATE_DIR/.current-skills.txt"
mkdir -p "$STATE_DIR"
rm -f "$tmp_current_skills"
touch "$tmp_current_skills"

conflicts=()
installed=()

while IFS= read -r skill_md; do
  [ -n "$skill_md" ] || continue

  src="$(dirname "$skill_md")"
  name="$(basename "$src")"
  target="$AGENTS_DIR/$name"

  printf '%s\n' "$name" >> "$tmp_current_skills"

  if [ -e "$target" ] || [ -L "$target" ]; then
    if is_owned_symlink "$target"; then
      :
    elif [ "$FORCE" -eq 1 ]; then
      backup_path "$target"
    else
      conflicts+=("$name")
      continue
    fi
  fi

  ln -sfn "$src" "$target"
  installed+=("$name")
  echo "linked $name -> $src"
done <<EOF
$(find "$INSTALL_ROOT/skills" -name SKILL.md -not -path '*/node_modules/*' -not -path '*/deprecated/*' | LC_ALL=C sort)
EOF

cleanup_stale_links
write_state "$current_commit" "${installed[@]}"
rm -f "$tmp_current_skills"

echo
echo "Digitaport skills are installed in: $AGENTS_DIR"
echo "Managed clone: $INSTALL_ROOT"
echo "Installed commit: $current_commit"

if [ "${#conflicts[@]}" -gt 0 ]; then
  echo
  echo "Skipped conflicting skill names:" >&2
  printf '  - %s\n' "${conflicts[@]}" >&2
  echo "Re-run with --force to replace them." >&2
  exit 2
fi

echo
echo "To update later, run: $INSTALL_ROOT/scripts/install.sh"