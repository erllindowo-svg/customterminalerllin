#!/bin/bash
# Terminal Soviético — garante o Spotify aberto SEM mostrar a janela e toca <uri>.
# Usado pelo player da barra (fork erllan/spotify-media).
#   tocar.sh [spotify:track:ID | spotify:search:...]   sem argumento: só "play"
#   tocar.sh --ocultar                                  só esconde a janela
#
# A janela vai para o workspace especial "musica" (silencioso). A regra do
# Hyprland (terminal_soviet.lua) já faz isso ao abrir; a mudança aqui cobre o
# Spotify que define a classe tarde e o que já estava aberto em outro lugar.
# Espera o player MPRIS por até 30 s (tentativas limitadas, sem laço infinito).
set -uo pipefail
WS="special:musica"

ocultar() {
  local a
  for a in $(hyprctl clients -j | jq -r --arg ws "$WS" \
      '.[] | select((.class | test("^[Ss]potify$")) and .workspace.name != $ws) | .address'); do
    hyprctl dispatch "hl.dsp.window.move({ workspace = \"$WS\", follow = false, window = \"address:$a\" })" >/dev/null
  done
}

[[ ${1:-} == --ocultar ]] && { ocultar; exit 0; }
uri=${1:-}

if ! playerctl -p spotify status >/dev/null 2>&1; then
  pgrep -x spotify >/dev/null || setsid -f uwsm-app -- spotify >/dev/null 2>&1
  for _ in $(seq 60); do
    playerctl -p spotify status >/dev/null 2>&1 && break
    sleep 0.5
  done
  playerctl -p spotify status >/dev/null 2>&1 || { echo "spotify não respondeu no MPRIS" >&2; exit 1; }
  sleep 1   # o MPRIS responde antes de o cliente aceitar OpenUri
fi
ocultar
if [[ -n $uri ]]; then
  playerctl -p spotify open "$uri"
else
  playerctl -p spotify play
fi
