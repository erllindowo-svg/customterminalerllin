# shellcheck shell=bash
# Terminal Soviético — utilitários dos testes. Cada teste termina como
# PASSOU, FALHOU ou PULADO (com motivo); nada é dado como aprovado sem rodar.
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
N_PASS=0 N_FAIL=0 N_SKIP=0
FAILED=()
pass() { (( ++N_PASS )); printf '  \e[32mPASSOU\e[0m  %s\n' "$1"; }
fail() { (( ++N_FAIL )); FAILED+=("$1"); printf '  \e[31mFALHOU\e[0m  %s%s\n' "$1" "${2:+ — $2}"; }
skip() { (( ++N_SKIP )); printf '  \e[33mPULADO\e[0m  %s — %s\n' "$1" "$2"; }
check() {  # check "<descrição>" <comando...>
  local d=$1; shift
  if "$@" >/dev/null 2>&1; then pass "$d"; else fail "$d"; fi
}
section() { printf '\n\e[1m== %s\e[0m\n' "$1"; }
summary() {
  printf '\n%d passaram, %d falharam, %d pulados\n' "$N_PASS" "$N_FAIL" "$N_SKIP"
  (( N_FAIL == 0 )) || { printf '  falhas: %s\n' "${FAILED[@]}"; return 1; }
}
