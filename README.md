# sol-audit-pipeline  
v0.1.0

Drop-in smart contract audit pipeline for Foundry projects. One command scaffolds a complete CI/CD setup with static analysis, coverage, gas reporting, and consolidated audit summaries posted as PR comments.

## Support

If this saved you time, consider:

- ⭐ **[Starring the repo](https://github.com/ManiBAJPAI22/sol-audit-pipeline)** — helps others find it
- 🍴 **[Forking](https://github.com/ManiBAJPAI22/sol-audit-pipeline/fork)** — customize the templates for your team's conventions and point your projects at your fork via `AUDIT_PIPELINE_REPO` env var:
```bash
  AUDIT_PIPELINE_REPO=https://raw.githubusercontent.com/YourUser/sol-audit-pipeline/main \
    curl -fsSL $AUDIT_PIPELINE_REPO/install.sh | bash
```
- 🐛 **[Opening an issue](https://github.com/ManiBAJPAI22/sol-audit-pipeline/issues/new)** — bug reports and feature requests welcome
- 📣 **Sharing** — if you use this on a project, a mention in your repo's README helps the tool grow

---

## What you get

**Local pipeline** (`make audit`):
- Formatting (`forge fmt`)
- Linting (`solhint`)
- Tests (`forge test`)
- Static analysis (`aderyn`)
- Coverage (`forge coverage` with LCOV output)
- Gas report
- Consolidated markdown summary

**On-demand extras:**
- Slither (`make slither`) — SARIF output
- Medusa property-based fuzzing (`make fuzz`) — requires `medusa.json`
- Halmos symbolic execution (`make symbolic`)

**GitHub Actions workflow:**
- Runs on every pull request
- Uploads full audit report as a downloadable artifact
- Posts consolidated summary as a sticky PR comment (auto-updates on push)
- Nightly medusa fuzzing at 02:00 UTC (opt-in)

## Quick start

### 1. Install audit tools (once per machine)

```bash
curl -fsSL https://raw.githubusercontent.com/ManiBAJPAI22/sol-audit-pipeline/main/scripts/install-tools.sh | bash
```

Installs via Homebrew, pipx, npm, cargo, and go:
- `foundry` (forge, cast, anvil, chisel)
- `slither-analyzer`
- `@cyfrin/aderyn`
- `medusa`
- `halmos`
- `solhint`
- `solc-select` (with 0.8.28 as default)

> Requires macOS with Homebrew. Linux users: adapt the `brew` calls to your package manager (apt/dnf/pacman).

### 2. Install the pipeline in a project (once per repo)

Inside any Foundry project root:

```bash
curl -fsSL https://raw.githubusercontent.com/ManiBAJPAI22/sol-audit-pipeline/main/install.sh | bash
```

The installer:
- Fetches the latest templates from this repo
- Auto-detects your `solc` version from `foundry.toml`
- Asks before overwriting existing files (with diff option)
- Offers to pin `evm_version = "cancun"` if unset (aderyn compatibility)
- Offers to add `reports/` to `.gitignore`

### 3. Run the audit

```bash
make audit
```

Outputs land in `reports/`:
- `aderyn.md` — static analysis findings
- `lcov.info` — coverage data
- `coverage.txt` — coverage summary table
- `gas.txt` — gas usage report
- `summary.md` — consolidated markdown (aggregates all of the above)

## Enabling Medusa fuzzing

`make fuzz` (and the nightly CI job) are opt-in. With no config present, the Makefile prints `skipping fuzz: …` and exits cleanly. To activate fuzzing, add two files to your project:

**1. `medusa.json`** — Medusa runtime config. Minimal shape:

```json
{
  "fuzzing": {
    "workers": 6,
    "timeout": 600,
    "testLimit": 50000,
    "callSequenceLength": 100,
    "corpusDirectory": "corpus",
    "coverageEnabled": true,
    "targetContracts": ["YourInvariants"],
    "deployerAddress": "0x30000",
    "senderAddresses": ["0x10000", "0x20000", "0x30000"],
    "testing": {
      "assertionTesting": { "enabled": true, "testViewMethods": false },
      "propertyTesting": {
        "enabled": true,
        "testPrefixes": ["invariant_", "property_"]
      }
    },
    "chainConfig": {
      "codeSizeCheckDisabled": true,
      "cheatCodes": { "cheatCodesEnabled": true, "enableFFI": false }
    }
  },
  "compilation": {
    "platform": "crytic-compile",
    "platformConfig": {
      "target": ".",
      "solcVersion": "",
      "args": ["--foundry-compile-all"]
    }
  },
  "logging": { "level": "info", "logDirectory": "" }
}
```

Key knobs: `targetContracts` (the harness Medusa drives), `testLimit` / `timeout` (stopping conditions), `workers` (parallelism), `testPrefixes` (function-name prefixes Medusa treats as invariants).

**2. `test/invariants/YourInvariants.sol`** — harness contract. Deploys your system in its constructor, exposes `handler_*` functions Medusa calls with random args, and `invariant_*` / `property_*` predicates that must hold between every call.

Skeleton:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Vm } from "forge-std/Vm.sol";
import { YourToken } from "../../src/YourToken.sol";

contract YourInvariants {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    YourToken internal token;
    uint256 internal initialSupply;

    constructor() {
        token = new YourToken();
        initialSupply = token.totalSupply();
    }

    // Medusa calls handlers with random args — bound them to sensible ranges.
    function handler_transfer(address to, uint256 amount) public {
        amount = amount % token.balanceOf(address(this));
        if (amount == 0 || to == address(0)) return;
        token.transfer(to, amount);
    }

    // Predicates checked between every handler call. Return false = invariant broken.
    function invariant_totalSupplyConstant() public view returns (bool) {
        return token.totalSupply() == initialSupply;
    }
}
```

Cheatcodes available under `vm.*` include `sign`, `prank`, `warp`, `addr` — enough to fuzz EIP-712 signed flows, time-based logic, and multi-caller scenarios.

Once both files exist, `make fuzz` runs Medusa; otherwise it skips.

## Make targets

| Target | What it does |
|--------|--------------|
| `make fmt` | `forge fmt` |
| `make lint` | Run solhint on `src/**/*.sol` |
| `make test` | `forge test -vvv` |
| `make slither` | Slither static analysis → SARIF |
| `make aderyn` | Aderyn static analysis → markdown |
| `make cov` | Coverage report (excludes scripts/mocks) |
| `make gas` | Gas report |
| `make fuzz` | Medusa property-based fuzzing |
| `make symbolic` | Halmos symbolic execution |
| `make summary` | Aggregate all reports into `reports/summary.md` |
| `make audit` | fmt + lint + test + aderyn + cov + gas + summary |
| `make ci` | audit + slither + fuzz + symbolic (heavy, for scheduled jobs) |

## CI behavior

The generated workflow (`.github/workflows/audit.yml`) runs on:
- **Every PR** — full audit + slither, posts sticky comment with summary
- **Nightly at 02:00 UTC** — runs `make fuzz` (skipped if no property tests)
- **Manual trigger** — via Actions tab → "Run workflow"

It does not run on pushes to `main` to avoid duplicate runs after merge.

### Example PR comment

The bot comment includes:
- Coverage table for contracts under `src/`
- Aderyn finding counts (high/low) with collapsible details
- Slither finding breakdown (top 20)
- Full gas report (collapsible)
- Link to the full artifact for deeper inspection

## Customization

All files land in your project and are yours to edit:

### Stricter static analysis gates

`slither.config.json`:

```json
{ "fail_on": "high" }
```

(Default is `"medium"`.)

### Different solc version

```bash
solc-select install 0.8.29 && solc-select use 0.8.29
```

Also update `foundry.toml` and `.github/workflows/audit.yml` to match.

### Disable slither in CI

Remove the `Run slither` and `Rebuild summary with slither findings` steps from `.github/workflows/audit.yml`.

### Custom coverage exclusions

In `Makefile`:

```makefile
cov: reports ; forge coverage ... --no-match-coverage "(script|test/mocks|Mock|YourPattern)"
```

## Requirements

- **macOS** (Linux works with adapted `install-tools.sh`)
- **Homebrew**
- **Node.js ≥ 18** (for aderyn + solhint via npm)
- **Python ≥ 3.8** (for slither + halmos via pipx)
- **Foundry** (will be installed by `install-tools.sh` if missing)

## Troubleshooting

### `aderyn` panics with `Unknown evm version: osaka`

Your `foundry.toml` or a submodule's `foundry.toml` is using EVM version `osaka`, which older aderyn versions can't parse. The installer offers to pin `evm_version = "cancun"` — accept this.

For submodule configs (e.g. OpenZeppelin's `foundry.toml`), the Makefile's `aderyn` target uses `--path-excludes lib,test,script` which should bypass them.

### `JSON Error in .solhint.json`

Check the file didn't get corrupted by an editor (e.g. TextEdit's smart quotes). Re-fetch cleanly:

```bash
curl -fsSL https://raw.githubusercontent.com/ManiBAJPAI22/sol-audit-pipeline/main/templates/.solhint.json -o .solhint.json
```

### `make audit` fails on `cov` with stack-too-deep

Heavy contracts with `via_ir = false` can hit this under coverage instrumentation. Add `--ir-minimum`:

```makefile
cov: reports ; forge coverage --ir-minimum ...
```

### Slither finds too many false positives

AA/upgradeable patterns trigger Slither's `arbitrary-send-erc20` and `timestamp` detectors. Either:
1. Add inline `// slither-disable-next-line <detector>` with a justification comment
2. Lower the `fail_on` threshold in `slither.config.json`
3. Remove Slither from the critical path (`make audit`), run it on-demand with `make slither`

### PR comment not appearing

The `sticky-pull-request-comment` action needs `pull-requests: write` permission. The workflow declares this at the top:

```yaml
permissions:
  contents: read
  pull-requests: write
```

If you're on a fork or restricted runner, the comment may be skipped silently. Check the action logs for permission errors.

## Roadmap

Future improvements being considered:

- **Composite GitHub Action** — consolidate workflow logic so project workflows become 6 lines instead of a full copy
- **Foundry template repo** — scaffold a new project with `npx degit` including pipeline pre-installed
- **Auto-install in Makefile** — `make audit` bootstraps missing tools (trade-off: more Makefile complexity)
- **Report diffing** — compare findings between commits, flag only *new* issues

## Project structure

```
sol-audit-pipeline/
├── install.sh                          # per-project installer
├── scripts/
│   └── install-tools.sh                # per-machine tool installer
├── templates/
│   ├── Makefile                        # audit targets
│   ├── slither.config.json             # Slither config
│   ├── .solhint.json                   # Solhint rules
│   ├── tools/
│   │   └── summary.sh                  # consolidated report generator
│   └── .github/
│       └── workflows/
│           └── audit.yml               # CI workflow
└── README.md
```

## Contributing

This is a personal tooling repo, but fixes are welcome:

1. Fork and clone
2. Make changes in `templates/` or scripts
3. Test end-to-end:

   ```bash
   cd ~/Desktop
   forge init --no-git test-project
   cd test-project
   AUDIT_PIPELINE_REPO=https://raw.githubusercontent.com/YourFork/sol-audit-pipeline/your-branch \
     curl -fsSL $AUDIT_PIPELINE_REPO/install.sh | bash
   make audit
   ```

4. Open PR

## License

MIT

## Credits

Built on top of excellent work from:
- [Foundry](https://github.com/foundry-rs/foundry) — the testing framework
- [Slither](https://github.com/crytic/slither) & [Medusa](https://github.com/crytic/medusa) — Trail of Bits
- [Aderyn](https://github.com/Cyfrin/aderyn) & [Halmos](https://github.com/a16z/halmos) — static & symbolic analysis
- [Solhint](https://github.com/protofire/solhint) — linting
- [sticky-pull-request-comment](https://github.com/marocchino/sticky-pull-request-comment) — PR comment management
