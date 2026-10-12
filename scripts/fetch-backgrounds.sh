#!/bin/bash
# Terminal Soviético — baixa os papéis de parede do tema soviet-terminal.
#
# As fotos NÃO são versionadas (CC BY / CC BY-SA com atribuição; esculturas
# podem ter direitos próprios no país de origem — ver omarchy/themes/
# soviet-terminal/SOURCES.md e THIRD_PARTY.md). Este script as baixa do
# Wikimedia Commons, confere o SHA-1 publicado e gera o preview.png do seletor
# de temas (requer ImageMagick para o preview; sem ele, o preview é omitido).
#
# Uso: scripts/fetch-backgrounds.sh [diretório do tema]
#      (padrão: ~/.config/omarchy/themes/soviet-terminal)
set -euo pipefail
THEME=${1:-$HOME/.config/omarchy/themes/soviet-terminal}
DIR="$THEME/backgrounds"
mkdir -p "$DIR"
# arquivo-local|nome no Commons|sha1
FILES=(
  "1-brest-monument-of-courage.jpg|Brest_Fortress_Monument_of_Courage_2023-02-18_2760.jpg|a5de725296806dbec656d2b7cc9742bf870aaffa"
  "2-mamayev-kurgan-motherland-calls.jpg|Volgograd_Russia.jpg|e5232f1b79c385420a717f65967ba4106e694bde"
  "3-worker-and-kolkhoz-woman.jpg|Moscow,_Worker_and_Kolkhoz_Woman_from_the_Main_Gate_(10656844163).jpg|a9caf76b4900868e40ceaa30555597cea10c223a"
  "4-conquerors-of-space.jpg|Monument_to_the_Conquerors_of_Space_20241022_104412_MP.jpg|ab8204e7fa4f1b44846582890a320ddbef6d1092"
  "5-treptower-park-memorial.jpg|Treptower_Park_Soviet_War_Memorial.jpg|65dbac6ef27fa8bb4b92c3be819cfe326ff059d3"
)
for e in "${FILES[@]}"; do
  IFS='|' read -r local name sum <<< "$e"
  if [[ -f $DIR/$local && $(sha1sum "$DIR/$local" | cut -d' ' -f1) == "$sum" ]]; then
    echo "✓ $local (já presente)"; continue
  fi
  curl -fsSL -A "terminal-soviet-fetch/1.0 (uso pessoal)" -o "$DIR/$local.part" \
    "https://commons.wikimedia.org/wiki/Special:FilePath/$(printf '%s' "$name" | sed 's/(/%28/g; s/)/%29/g; s/,/%2C/g')"
  got=$(sha1sum "$DIR/$local.part" | cut -d' ' -f1)
  [[ $got == "$sum" ]] || { rm -f "$DIR/$local.part"; echo "✗ $local: SHA-1 $got ≠ $sum" >&2; exit 1; }
  mv "$DIR/$local.part" "$DIR/$local"; echo "✓ $local"
done
if [[ ! -f $THEME/preview.png ]] && command -v magick >/dev/null; then
  magick "$DIR/1-brest-monument-of-courage.jpg" -resize 1920x1080^ -gravity center -extent 1920x1080 "$THEME/preview.png"
  echo "✓ preview.png"
fi
