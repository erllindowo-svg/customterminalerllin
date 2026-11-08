#!/bin/bash
# Terminal Soviético — executa os testes e guarda o relatório em tests/results/.
#
#   tests/run.sh                 estáticos + instalador em HOME isolado (não altera o sistema)
#   tests/run.sh --live          + testes ao vivo sem abrir janelas
#   tests/run.sh --disruptive    + testes ao vivo que abrem janelas e trocam de workspace
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p tests/results
OUT="tests/results/$(date +%Y%m%d-%H%M%S).log"
rc=0
run() { echo "### $*" | tee -a "$OUT"; "$@" 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | tee -a "$OUT"; (( PIPESTATUS[0] == 0 )) || rc=1; }
run tests/static.sh
run tests/sandbox.sh
run tests/limine.sh
case ${1:-} in
  --live) run tests/live.sh ;;
  --disruptive) run tests/live.sh --disruptive ;;
esac
echo "relatório: $OUT"
exit $rc
