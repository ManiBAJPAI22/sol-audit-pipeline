#!/usr/bin/env bash
# sol-audit-pipeline installer
# Usage: curl -fsSL <raw-url>/install.sh | bash
#        curl -fsSL <raw-url>/install.sh | bash -s -- --yes

set -euo pipefail

REPO_RAW="${AUDIT_PIPELINE_REPO:-https://raw.githubusercontent.com/ManiBAJPAI22/sol-audit-pipeline/main}"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

bold() { printf "\033[1m%s\033[0m\n" "$*"; }
cyan() { printf "\033[36m%s\033[0m\n" "$*"; }
yellow() { printf "\033[33m%s\033[0m\n" "$*"; }
red() { printf "\033[31m%s\033[0m\n" "$*"; }
green() { printf "\033[32m%s\033[0m\n" "$*"; }

# Detect non-interactive mode: CI env, explicit --yes/-y flag, or no TTY.
NONINTERACTIVE=0
if [[ "${CI:-}" == "true" ]] || [[ "${1:-}" == "--yes" ]] || [[ "${1:-}" == "-y" ]] || [[ ! -t 0 && ! -r /dev/tty ]]; then
  NONINTERACTIVE=1
fi

# Wrapper around `read` so every prompt honours NONINTERACTIVE. In non-interactive
# mode the default answer is returned without blocking on /dev/tty.
ask() {
  local prompt="$1" default="$2" var
  if (( NONINTERACTIVE == 1 )); then
    echo "  [non-interactive] $prompt — using default: $default"
    REPLY="$default"; return
  fi
  read -r -p "$prompt" var </dev/tty
  REPLY="${var:-$default}"
}

if [[ ! -f foundry.toml ]]; then
  red "error: no foundry.toml in current directory"
  echo "run this inside a Foundry project root"
  exit 1
fi

bold "sol-audit-pipeline installer"
echo "target: $(pwd)"
if (( NONINTERACTIVE == 1 )); then yellow "mode: non-interactive (CI or --yes)"; fi
echo ""

cyan "fetching templates..."
FILES=(
  "templates/Makefile:Makefile"
  "templates/slither.config.json:slither.config.json"
  "templates/.solhint.json:.solhint.json"
  "templates/tools/summary.sh:tools/summary.sh"
  "templates/.github/workflows/audit.yml:.github/workflows/audit.yml"
)

for pair in "${FILES[@]}"; do
  src="${pair%%:*}"
  dst="${pair##*:}"
  mkdir -p "$TMPDIR/$(dirname "$dst")"
  curl -fsSL "$REPO_RAW/$src" -o "$TMPDIR/$dst"
done

SOLC=$(grep -E '^\s*solc\s*=' foundry.toml | sed -E 's/.*"([0-9.]+)".*/\1/' | head -1 || echo "")
SOLC="${SOLC:-0.8.28}"
cyan "detected solc version: $SOLC"

find "$TMPDIR" -type f \( -name "*.yml" -o -name "*.json" -o -name "*.sh" -o -name "Makefile" \) \
  -exec sed -i.bak "s/{{SOLC_VERSION}}/$SOLC/g" {} \;
find "$TMPDIR" -name "*.bak" -delete

copy_file() {
  local src="$1"
  local dst="$2"

  if [[ -e "$dst" ]]; then
    if (( NONINTERACTIVE == 1 )); then
      yellow "exists: $dst — skipped (re-run interactively to overwrite)"
      return
    fi
    yellow "exists: $dst"
    ask "  overwrite? [y/N/d(iff)] " "n"
    case "$REPLY" in
      y|Y) cp "$src" "$dst" && green "  overwritten" ;;
      d|D)
        diff -u "$dst" "$src" || true
        ask "  overwrite after diff? [y/N] " "n"
        [[ "$REPLY" =~ ^[yY]$ ]] && cp "$src" "$dst" && green "  overwritten" || yellow "  skipped"
        ;;
      *) yellow "  skipped" ;;
    esac
  else
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    green "new:   $dst"
  fi
}

for pair in "${FILES[@]}"; do
  dst="${pair##*:}"
  copy_file "$TMPDIR/$dst" "$dst"
done

chmod +x tools/summary.sh 2>/dev/null || true

if ! grep -q 'evm_version' foundry.toml; then
  echo ""
  yellow "foundry.toml has no evm_version set."
  echo "  aderyn 0.1.x cant parse osaka. recommend pinning to cancun."
  ask "  add evm_version = cancun to [profile.default]? [Y/n] " "y"
  if [[ ! "$REPLY" =~ ^[nN]$ ]]; then
    awk '/^\[profile\.default\]/ { print; print "evm_version = \"cancun\""; next } { print }' foundry.toml > foundry.toml.tmp
    mv foundry.toml.tmp foundry.toml
    green "  added evm_version = cancun"
  fi
fi

# .gitignore additions — reports/, Medusa corpus, crytic-compile exports.
append_gitignore_entry() {
  local entry="$1" prompt="$2"
  if [[ ! -f .gitignore ]] || grep -qxF "$entry" .gitignore; then return; fi
  echo ""
  ask "$prompt [Y/n] " "y"
  if [[ ! "$REPLY" =~ ^[nN]$ ]]; then
    echo "$entry" >> .gitignore
    green "  added $entry"
  fi
}

append_gitignore_entry "reports/"        "add reports/ to .gitignore?"
append_gitignore_entry "corpus/"         "add corpus/ to .gitignore (Medusa runtime output)?"
append_gitignore_entry "crytic-export/"  "add crytic-export/ to .gitignore (Slither/Medusa compile cache)?"

echo ""
bold "done."
echo ""
echo "next steps:"
echo "  1. install local audit tools (once per machine):"
echo "     curl -fsSL $REPO_RAW/scripts/install-tools.sh | bash"
echo "  2. run the pipeline:"
echo "     make audit"
echo "  3. (optional) enable Medusa fuzzing — see README section 'Enabling Medusa fuzzing'"
