#!/bin/bash
# Terminal Soviético — instala o arttime numa versão fixada (método manual oficial).
#
# Uso: scripts/install-arttime.sh [url] [commit]
#
# 1. clona (ou reaproveita) ~/.local/src/arttime e faz checkout do commit fixado;
# 2. confere que HEAD é exatamente o commit esperado (nada de "última versão");
# 3. roda o install.sh DO PRÓPRIO arttime, já inspecionado nesse commit:
#      ./install.sh --local --noupdaterc --zcompdir -
#    -> ~/.local/bin/{arttime,artprint}, ~/.local/share/arttime/{src,textart,keypoems,doc},
#       ~/.local/share/man/man1; não edita .bashrc/.zshrc nem instala completions.
# Requer zsh >= 5.7 (dependência do arttime) e git. Não usa sudo.
set -euo pipefail
URL=${1:-https://github.com/poetaman/arttime.git}
COMMIT=${2:-38c2955a7c16d6900cc121265595347266b18af8}
SRC="$HOME/.local/src/arttime"

command -v zsh >/dev/null || { echo "zsh ausente: omarchy pkg add zsh" >&2; exit 1; }
command -v git >/dev/null || { echo "git ausente" >&2; exit 1; }

if [[ -d $SRC/.git ]]; then
  [[ -z $(git -C "$SRC" status --porcelain) ]] || { echo "$SRC tem alterações locais; não mexo" >&2; exit 1; }
  git -C "$SRC" cat-file -e "$COMMIT^{commit}" 2>/dev/null || git -C "$SRC" fetch -q origin
else
  mkdir -p "$(dirname "$SRC")"
  git clone -q "$URL" "$SRC"
fi
git -C "$SRC" checkout -q "$COMMIT"
[[ $(git -C "$SRC" rev-parse HEAD) == "$COMMIT" ]] || { echo "commit inesperado em $SRC" >&2; exit 1; }

(cd "$SRC" && ./install.sh --local --noupdaterc --zcompdir - >/dev/null)
v=$("$HOME/.local/bin/arttime" --version)
n=$(find "$HOME/.local/share/arttime/textart" -maxdepth 1 -type f | wc -l)
echo "✓ arttime $v @ ${COMMIT:0:7} ($n arquivos de arte em ~/.local/share/arttime/textart)"
