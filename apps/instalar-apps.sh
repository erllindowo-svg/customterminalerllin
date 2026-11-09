#!/bin/bash
# Terminal Soviético — instala os apps de apps/lista.sh, por prioridade.
#
#   apps/instalar-apps.sh              P0 a P3 (atualiza o sistema antes)
#   apps/instalar-apps.sh --ate 1      só P0 e P1
#   apps/instalar-apps.sh --so 2       só P2
#   apps/instalar-apps.sh --base       inclui P4 (o que já vem no Omarchy)
#   apps/instalar-apps.sh --listar     mostra a lista
#   apps/instalar-apps.sh --dry-run    mostra os comandos, sem executar
#   apps/instalar-apps.sh --sem-atualizar   não roda pacman -Syu antes
#
# Um app que falha não para os outros: tudo é resumido no final (saída 1 se algum falhou).
# Idempotente: --needed e `mise install` não refazem o que já está instalado.
set -uo pipefail
DIR=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
cd "$DIR/.."

ATE=3 SO="" BASE=0 LISTAR=0 DRY=0 ATUALIZAR=1
while (( $# )); do
  case $1 in
    --ate) ATE=${2:?}; shift ;;
    --so) SO=${2:?}; shift ;;
    --base) BASE=1 ;;
    --listar) LISTAR=1 ;;
    --dry-run) DRY=1 ;;
    --sem-atualizar) ATUALIZAR=0 ;;
    *) sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
  esac
  shift
done

ITENS=() MANUAIS=() FALHAS=()
registrar() { local p=$1 d=$2; shift 2; ITENS+=("$p"$'\t'"$d"$'\t'"$(printf '%q ' "$@")"); }
p0() { registrar 0 "$@"; }
p1() { registrar 1 "$@"; }
p2() { registrar 2 "$@"; }
p3() { registrar 3 "$@"; }
p4() { registrar 4 "$@"; }
manual() { MANUAIS+=("$1"); }
# shellcheck source=apps/lista.sh
source "$DIR/lista.sh"

vale() {  # esta prioridade entra nesta execução?
  [[ -n $SO ]] && { [[ $1 == "$SO" ]]; return; }
  (( $1 <= ATE )) || { (( BASE )) && [[ $1 == 4 ]]; }
}

if (( LISTAR )); then
  for item in "${ITENS[@]}"; do
    IFS=$'\t' read -r p d _ <<< "$item"
    vale "$p" && printf 'P%s  %s\n' "$p" "$d"
  done
  for m in "${MANUAIS[@]}"; do printf 'MANUAL  %s\n' "$m"; done
  exit 0
fi

executar() {  # executar <comando já com aspas>
  if (( DRY )); then printf '  %s\n' "$1"; return 0; fi
  eval "$1"
}

if (( ! DRY )); then
  sudo -v || { echo "sem sudo não dá para instalar" >&2; exit 1; }
fi
if (( ATUALIZAR )); then
  echo "== Atualizando o sistema antes (evita atualização parcial)"
  executar "sudo pacman -Syu --noconfirm" || FALHAS+=("atualização do sistema")
fi

atual=""
for item in "${ITENS[@]}"; do
  IFS=$'\t' read -r p d cmd <<< "$item"
  vale "$p" || continue
  [[ $p == "$atual" ]] || { atual=$p; printf '\n== P%s\n' "$p"; }
  printf '→ %s\n' "$d"
  executar "$cmd" || FALHAS+=("P$p: $d")
done

if (( ${#MANUAIS[@]} )) && vale 3; then
  printf '\n== Passos manuais\n'
  for m in "${MANUAIS[@]}"; do printf '  • %s\n' "$m"; done
fi
if (( ${#FALHAS[@]} )); then
  printf '\n== Falharam (%d)\n' "${#FALHAS[@]}"
  for f in "${FALHAS[@]}"; do printf '  ✗ %s\n' "$f"; done
  exit 1
fi
printf '\n✓ concluído\n'
