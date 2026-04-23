#!/usr/bin/env bash
# sol-audit-pipeline installer
# Usage: curl -fsSL <raw-url>/install.sh | bash

set -euo pipefail

REPO_RAW="${AUDIT_PIPELINE_REPO:-https://raw.githubusercontent.com/ManiBAJPAI22/sol-audit-pipeline/main}"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

bold() { printf "\033[1m%s\033[0m\n" "$*"; }
cyan() { printf "\033[36m%s\033[0m\n" "$*"; }
yellow() { printf "\033[33m%s\033[0m\n" "$*"; }
red() { printf "\033[31m%s\033[0m\n" "$*"; }
green() { printf "\033[32m%s\033[0m\n" "$*"; }

if [[ ! -f foundry.toml ]]; then
  red "error: no foundry.toml in current directory"
  echo "run this inside a Foundry project root"
  exit 1
fi

bold "sol-audit-pipeline installer"
echo "target: $(pwd)"
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
    yellow "exists: $dst"
    read -r -p "  overwrite? [y/N/d(iff)] " ans </dev/tty
    case "$ans" in
      y|Y) cp "$src" "$dst" && green "  overwritten" ;;
      d|D)
        diff -u "$dst" "$src" || true
        read -r -p "  overwrite after diff? [y/N] " ans2 </dev/tty
        [[ "$ans2" =~ ^[yY]$ ]] && cp "$src" "$dst" && green "  overwritten" || yellow "  skipped"
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
  read -r -p "  add evm_version = cancun to [profile.default]? [Y/n] " ans </dev/tty
  if [[ ! "$ans" =~ ^[nN]$ ]]; then
    awk '/^\[profile\.default\]/ { print; print "evm_version = \"cancun\""; next } { print }' foundry.toml > foundry.toml.tmp
    mv foundry.toml.tmp foundry.toml
    green "  added evm_version = cancun"
  fi
fi

if [[ -f .gitignore ]] && ! grep -qxF 'reports/' .gitignore; then
  echo ""
  read -r -p "add reports/ to .gitignore? [Y/n] " ans </dev/tty
  if [[ ! "$ans" =~ ^[nN]$ ]]; then
    echo 'reports/' >> .gitignore
    green "  added"
  fi
fi

echo ""
bold "done."
echo ""
echo "next steps:"
echo "  1. install local audit tools (once per machine):"
echo "     curl -fsSL $REPO_RAW/scripts/install-tools.sh | bash"
echo "  2. run the pipeline:"
echo "     make audit"
