#!/bin/bash
# Terminal Soviético — webapps que abrem no Firefox em vez do navegador padrão do Omarchy.
# Sobrescreve os .desktop que o Omarchy cria (eles abririam no Chromium) e instala os
# dois lançadores que tratam links mailto:/zoommtg:. ClickUp, Intercom e GitHub seguem o padrão
# do Omarchy (Chromium --app), com StartupWMClass para a barra achar a janela aberta.
set -euo pipefail
DIR=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)/webapps
APPS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
mkdir -p "$APPS" "$HOME/.local/bin"
for f in "$DIR"/*.desktop; do
  sed "s|__HOME__|$HOME|g" "$f" > "$APPS/${f##*/}"
done
install -m 755 "$DIR"/firefox-webapp-* "$HOME/.local/bin/"

# Logos de terceiros não são versionados. Sem rede, o app só fica sem ícone.
ICONS="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/256x256/apps"
baixar_icone() {  # baixar_icone <nome> <url>
  [[ -s $ICONS/$1.png ]] && return 0
  mkdir -p "$ICONS"
  curl -fsSL -m 10 -o "$ICONS/$1.png" "$2" || rm -f "$ICONS/$1.png"
}
baixar_icone clickup "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/clickup.png"
baixar_icone intercom "https://www.google.com/s2/favicons?domain=intercom.com&sz=256"
# Versão clara do logo: a preta some na barra escura.
baixar_icone github "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/github-light.png"
command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache "${ICONS%/256x256/apps}" >/dev/null 2>&1 || true

command -v xdg-mime >/dev/null && xdg-mime default HEY.desktop x-scheme-handler/mailto
command -v update-desktop-database >/dev/null && update-desktop-database "$APPS" 2>/dev/null
exit 0
