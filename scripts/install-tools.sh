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
pipx install slither-analyzer 2>/dev/null || pipx upgrade slither-analyzer
pipx install halmos 2>/dev/null || pipx upgrade halmos
pipx install solc-select 2>/dev/null || true

cyan "-> default solc 0.8.28"
solc-select install 0.8.28 && solc-select use 0.8.28

cyan "-> aderyn"
npm i -g @cyfrin/aderyn

cyan "-> solhint"
npm i -g solhint

cyan "-> medusa"
go install github.com/crytic/medusa@latest

echo ""
green "all tools installed."
echo ""
echo "verify: forge --version && slither --version && aderyn --version"
