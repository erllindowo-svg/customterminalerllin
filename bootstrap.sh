#!/bin/bash
# Terminal Soviético — de um Omarchy recém-instalado até o ambiente completo.
#
#   git clone https://github.com/erllindowo-svg/customterminalerllin ~/www/customterminalerllin
#   ~/www/customterminalerllin/bootstrap.sh            [--dry-run] [--accept-untested]
#
# Ordem: 1) P0 de apps/lista.sh, sem o qual o instalador recusa;  2) ./install.sh;
# 3) papéis de parede e tema;  4) o restante dos apps, por prioridade.
set -uo pipefail
cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

DRY=0 INST=()
for a in "$@"; do
  case $a in
    --dry-run) DRY=1; INST+=(--dry-run) ;;
    *) INST+=("$a") ;;
  esac
done
OPTS=(); (( DRY )) && OPTS+=(--dry-run)

etapa() { printf '\n######## %s\n' "$1"; }
falhou=0

etapa "1/4 Apps essenciais (P0)"
apps/instalar-apps.sh --ate 0 "${OPTS[@]}" || { echo "P0 incompleto: corrija antes de seguir." >&2; exit 1; }

etapa "2/4 Terminal Soviético"
./install.sh "${INST[@]}" || { echo "install.sh falhou: veja docs/installation-omarchy.md" >&2; exit 1; }

etapa "3/4 Papéis de parede e tema"
if (( DRY )); then
  echo "  scripts/fetch-backgrounds.sh && omarchy theme set erllinsapin"
else
  { scripts/fetch-backgrounds.sh && omarchy theme set erllinsapin; } || { echo "tema não aplicado (não impede o resto)" >&2; falhou=1; }
fi

etapa "4/4 Demais apps (P1 a P3)"
for p in 1 2 3; do apps/instalar-apps.sh --so "$p" --sem-atualizar "${OPTS[@]}" || falhou=1; done

(( falhou )) && { printf '\nConcluído com pendências: veja as falhas acima.\n'; exit 1; }
printf '\n✓ Ambiente pronto. Entre de novo na sessão se a barra não aparecer.\n'
