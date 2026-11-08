#!/bin/bash
# Terminal Soviético — desktop id (nome do .desktop sem extensão) de uma classe de
# janela. Usado pelo service das tarefas para fixar um app aberto e abrir uma
# nova janela dele. Ordem: arquivo <classe>.desktop (como está ou em minúsculas)
# e depois StartupWMClass=<classe>, nos diretórios XDG de aplicativos (usuário
# primeiro). Sem resultado, imprime a própria classe.
# Uso: desktop-id.sh <classe>
class=${1:?uso: desktop-id.sh <classe>}
lc=${class,,}
IFS=: read -r -a dirs <<< "${XDG_DATA_HOME:-$HOME/.local/share}:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
apps=()
for d in "${dirs[@]}"; do [[ -d $d/applications ]] && apps+=("$d/applications"); done
for d in "${apps[@]}"; do
  for n in "$class" "$lc"; do
    [[ -f $d/$n.desktop ]] && { echo "$n"; exit 0; }
  done
done
for d in "${apps[@]}"; do
  f=$(grep -ilxF -m1 "StartupWMClass=$class" "$d"/*.desktop 2>/dev/null | head -1)
  [[ -n $f ]] && { f=${f##*/}; echo "${f%.desktop}"; exit 0; }
done
# Por último: arquivo cujo nome começa pela classe sem símbolos ("osu!" -> osu-lazer),
# visível no menu; o nome mais curto vence (osu-lazer, não osu-lazer-uri-handler).
stem=${lc//[^a-z0-9]/}
if [[ -n $stem ]]; then
  best=""
  for d in "${apps[@]}"; do
    for f in "$d/$stem"*.desktop; do
      [[ -f $f ]] && ! grep -qix 'NoDisplay=true' "$f" || continue
      f=${f##*/}; f=${f%.desktop}
      [[ -z $best || ${#f} -lt ${#best} ]] && best=$f
    done
  done
  [[ -n $best ]] && { echo "$best"; exit 0; }
fi
echo "$class"
