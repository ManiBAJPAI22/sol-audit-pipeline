.PHONY: fmt lint test slither aderyn cov gas fuzz symbolic audit ci reports summary

reports: ; @mkdir -p reports

fmt:      ; forge fmt
lint:     ; solhint 'src/**/*.sol'
test:     ; forge test -vvv
slither:  reports ; rm -f reports/slither.sarif && slither . --config-file slither.config.json
aderyn:   reports ; aderyn --src src --path-excludes lib,test,script -o reports/aderyn.md . || true
cov:      reports ; forge coverage --report lcov --report summary --report-file reports/lcov.info --no-match-coverage "(script|test/mocks|Mock)" > reports/coverage.txt
gas:      reports ; forge test --gas-report > reports/gas.txt
fuzz:     ; medusa fuzz --config medusa.json
symbolic: ; halmos

summary: reports ; @bash tools/summary.sh > reports/summary.md

audit: fmt lint test aderyn cov gas summary
ci:    audit slither fuzz symbolic
