#!/usr/bin/env bash
set -e

bold() { printf "\033[1m%s\033[0m\n" "$*"; }
green() { printf "\033[32m%s\033[0m\n" "$*"; }
cyan() { printf "\033[36m%s\033[0m\n" "$*"; }

bold "sol-audit-pipeline: local tool installer"
echo ""

if [[ "$OSTYPE" != "darwin"* ]]; then
  echo "note: this script targets macOS."
fi

if ! command -v brew &>/dev/null; then
  echo "error: Homebrew required. install from https://brew.sh"
  exit 1
fi

cyan "-> base tooling"
brew install pipx rust yarn go node 2>/dev/null || true
pipx ensurepath

cyan "-> slither + halmos + solc-select"
# Versions match the CI workflow — keep these two files in sync when bumping.
pipx install 'slither-analyzer==0.10.4' 2>/dev/null || pipx upgrade slither-analyzer
pipx install halmos 2>/dev/null || pipx upgrade halmos
pipx install 'solc-select==1.0.4' 2>/dev/null || true

cyan "-> default solc 0.8.28"
solc-select install 0.8.28 && solc-select use 0.8.28

cyan "-> aderyn"
npm i -g '@cyfrin/aderyn@0.1.9'

cyan "-> solhint"
npm i -g 'solhint@5.0.3'

cyan "-> medusa"
go install github.com/crytic/medusa@v0.1.5

echo ""
green "all tools installed."
echo ""
echo "verify: forge --version && slither --version && aderyn --version"
