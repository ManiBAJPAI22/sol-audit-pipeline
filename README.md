# sol-audit-pipeline

Reusable smart contract audit pipeline for Foundry projects. Drop-in CI/CD with
Slither, Aderyn, Solhint, coverage, and gas reports. Consolidated audit summary
posted as a sticky PR comment.

## Quick start

### One-time setup per machine

    curl -fsSL https://raw.githubusercontent.com/ManiBAJPAI22/sol-audit-pipeline/main/scripts/install-tools.sh | bash

Installs: foundry, slither, aderyn, medusa, halmos, solhint, solc-select.

### Per-project setup

Inside any Foundry project root:

    curl -fsSL https://raw.githubusercontent.com/ManiBAJPAI22/sol-audit-pipeline/main/install.sh | bash

The installer detects your solc version, asks before overwriting existing files,
and offers sensible defaults.

Then:

    make audit

## What you get

| Target | Does |
|---|---|
| make fmt | forge fmt |
| make lint | solhint |
| make test | forge test |
| make slither | static analysis, SARIF |
| make aderyn | static analysis, markdown |
| make cov | coverage, LCOV |
| make gas | gas report |
| make fuzz | medusa (opt-in) |
| make symbolic | halmos |
| make summary | aggregates all into reports/summary.md |
| make audit | fmt + lint + test + aderyn + cov + gas + summary |

## CI

The workflow runs on every PR, uploads a full audit-reports artifact, and posts
a sticky PR comment with the consolidated summary. Nightly job runs medusa at
02:00 UTC (requires medusa.json + property tests).

## License

MIT
