#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/.."

echo "# Audit Summary"
echo ""
echo "_Generated: $(date -u +"%Y-%m-%d %H:%M UTC")_"
echo ""

echo "## Tests & Coverage"
echo ""
if [[ -f reports/coverage.txt ]]; then
  echo '```'
  grep -E "^\| (src/|Total)" reports/coverage.txt || echo "(no coverage data)"
  echo '```'
else
  echo "_No coverage report found._"
fi
echo ""

echo "## Aderyn Static Analysis"
echo ""
if [[ -f reports/aderyn.md ]]; then
  HIGHS=$(grep -c '^## H-' reports/aderyn.md || echo 0)
  LOWS=$(grep -c '^## L-' reports/aderyn.md || echo 0)
  echo "**Findings:** $HIGHS high, $LOWS low"
  echo ""
  echo "<details><summary>High severity details</summary>"
  echo ""
  awk '/^# High Issues/,/^# Low Issues/' reports/aderyn.md | sed '$d'
  echo "</details>"
  echo ""
  echo "<details><summary>Low severity details</summary>"
  echo ""
  awk '/^# Low Issues/,0' reports/aderyn.md
  echo "</details>"
else
  echo "_No aderyn report found._"
fi
echo ""

echo "## Slither Static Analysis"
echo ""
if [[ -f reports/slither.sarif ]]; then
  RESULTS=$(grep -c '"ruleId"' reports/slither.sarif || echo 0)
  echo "**Findings:** $RESULTS total"
  echo ""
  if command -v jq &>/dev/null; then
    echo "<details><summary>Slither findings breakdown</summary>"
    echo ""
    echo '```'
    jq -r '.runs[0].results[] | "- \(.ruleId): \(.message.text)"' reports/slither.sarif 2>/dev/null | sort | uniq -c | sort -rn | head -20 || echo "(jq parse failed)"
    echo '```'
    echo "</details>"
  fi
else
  echo "_No slither report found._"
fi
echo ""

echo "## Gas Report"
echo ""
if [[ -f reports/gas.txt ]]; then
  echo "<details><summary>Full gas report</summary>"
  echo ""
  echo '```'
  cat reports/gas.txt
  echo '```'
  echo "</details>"
else
  echo "_No gas report found._"
fi
echo ""

echo "---"
echo "_Full artifacts available in the run's Artifacts section._"
