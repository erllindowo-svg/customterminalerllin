#!/bin/bash
# Terminal Soviético — webapps que abrem no Firefox em vez do navegador padrão do Omarchy.
# Sobrescreve os .desktop que o Omarchy cria (eles abririam no Chromium) e instala os
# dois lançadores que tratam links mailto:/zoommtg:.
set -euo pipefail
DIR=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)/webapps
APPS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
mkdir -p "$APPS" "$HOME/.local/bin"
for f in "$DIR"/*.desktop; do
  sed "s|__HOME__|$HOME|g" "$f" > "$APPS/${f##*/}"
done
install -m 755 "$DIR"/firefox-webapp-* "$HOME/.local/bin/"
command -v xdg-mime >/dev/null && xdg-mime default HEY.desktop x-scheme-handler/mailto
command -v update-desktop-database >/dev/null && update-desktop-database "$APPS" 2>/dev/null
exit 0
