#!/bin/bash
# Terminal Soviético — migração da instalação manual da Fase 1 (2026-10-12).
#
# Na Fase 1 os atalhos, regras de janela e o autostart do projeto foram escritos
# à mão no FIM de ~/.config/hypr/{hyprland,bindings,autostart}.lua. O instalador
# agora usa um módulo próprio (~/.config/hypr/terminal_soviet.lua) e recusa
# instalar enquanto esses trechos existirem (duplicariam atalhos).
#
# Este script remove SOMENTE esses trechos e SOMENTE se forem byte a byte iguais
# ao que a Fase 1 escreveu (SHA-256 do trecho final de cada arquivo). Se algo
# foi editado depois, ele para sem tocar em nada e mostra o trecho para revisão
# manual. Backup em ~/.local/state/terminal-soviet/install/backups/migrate-<data>.
#
# Uso: migrate/phase1-inline.sh [--dry-run]
#
# Depois: ./install.sh --dry-run  (mostra o restante como ATUALIZAR/CONFLITO)
#         ./install.sh --force    (sobrescreve com backup) — o módulo novo entra
#                                 no lugar dos trechos removidos.
set -euo pipefail
DRY=0; [[ ${1:-} == --dry-run ]] && DRY=1
H="$HOME/.config/hypr"
BK="${XDG_STATE_HOME:-$HOME/.local/state}/terminal-soviet/install/backups/migrate-$(date +%Y%m%d-%H%M%S)"

# arquivo | regex da 1ª linha do trecho | sha256 do trecho (da linha até o fim) | linhas
BLOCKS=(
  "hyprland.lua|^-- Terminal Soviético — documentação|be6260645d13f74eb19ff1ab53ea619349daf6260991b5ddfbc5bb52d8a247e4|29"
  "bindings.lua|^-- -{10,}\$|00de782159e33c8dcd2dd7de6e5ed6795adf04828cbb03bd72576ea9b2199cb8|41"
  "autostart.lua|^-- Terminal Soviético: central|dc5fdcce4674529a64b54108961aaa845c6840eac44f424f109fa7472f912af7|7"
)

todo=() bad=0
for b in "${BLOCKS[@]}"; do
  IFS='|' read -r f re sum lines <<< "$b"
  [[ -f $H/$f ]] || { echo "  $f: ausente, nada a fazer"; continue; }
  n=$(grep -nE "$re" "$H/$f" | head -1 | cut -d: -f1 || true)
  if [[ -z $n ]]; then echo "  $f: sem trecho da Fase 1, nada a fazer"; continue; fi
  got=$(tail -n +"$n" "$H/$f" | sha256sum | cut -d' ' -f1)
  if [[ $got != "$sum" ]]; then
    echo "✗ $f: o trecho a partir da linha $n difere do instalado na Fase 1 (editado depois)."
    echo "  Revise e remova à mão o que for do projeto (soviet-*, noctalia msg, soviet_bin):"
    tail -n +"$n" "$H/$f" | sed 's/^/    | /'
    bad=1; continue
  fi
  echo "  $f: remover linhas $n–$(( n + lines - 1 )) (trecho idêntico ao da Fase 1)"
  todo+=("$f|$n")
done
(( bad )) && { echo "nada foi alterado"; exit 1; }
(( ${#todo[@]} )) || { echo "nada a migrar"; exit 0; }
(( DRY )) && { echo "(--dry-run: nada foi alterado)"; exit 0; }

mkdir -p "$BK"
for t in "${todo[@]}"; do
  IFS='|' read -r f n <<< "$t"
  cp -a "$H/$f" "$BK/$f"
  head -n $(( n - 1 )) "$BK/$f" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' > "$H/$f"
  echo "✓ $f migrado"
done
echo "backup: $BK"
echo "Próximo passo: ./install.sh --dry-run"
