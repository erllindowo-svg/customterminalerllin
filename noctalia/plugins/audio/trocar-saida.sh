#!/bin/bash
# Terminal Soviético — torna <sink> a saída padrão e move para ela os fluxos que
# estão tocando. Usado pelo service do plugin erllan/audio.
# Uso: trocar-saida.sh <object.id> <nome do sink>
id=${1:?uso: trocar-saida.sh <object.id> <nome>} sink=${2:?uso: trocar-saida.sh <object.id> <nome>}
wpctl set-default "$id" || exit 1
pactl list short sink-inputs | cut -f1 | while read -r input; do
  pactl move-sink-input "$input" "$sink" 2>/dev/null
done
exit 0
