#!/bin/bash
# Terminal Soviético — espera UMA mudança de volume/mudo e sai (usado pelo popup
# de volume só enquanto ele está aberto; nada fica rodando com o popup fechado).
# Sai 0 no primeiro evento de sink/servidor do PipeWire (via pactl subscribe),
# 2 depois de 55 s sem evento, 1 se o pactl terminar. Sempre encerra o pactl.
coproc P { exec pactl subscribe 2>/dev/null; }
trap 'kill "$P_PID" 2>/dev/null' EXIT
end=$((SECONDS + 55))
while (( SECONDS < end )); do
  if read -r -t 1 line <&"${P[0]}"; then
    case $line in *"on sink #"*|*"on server"*) exit 0 ;; esac
  elif (( $? <= 128 )); then
    exit 1
  fi
done
exit 2
