#!/bin/bash
# Testes da lista de apps e da transposição para outro Omarchy. Nada é instalado:
# pacman e yay reais só são consultados; a execução usa comandos simulados.
#   TS_APPS_INVENTARIO=1 tests/apps.sh   confere também se ESTA máquina está toda na lista
set -uo pipefail
source "$(dirname "$0")/lib.sh"
cd "$ROOT"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# Lista em TSV: prioridade, descrição, comando.
enumerar() (
  registrar() { local p=$1 d=$2; shift 2; printf '%s\t%s\t%s\n' "$p" "$d" "$*"; }
  p0() { registrar 0 "$@"; }; p1() { registrar 1 "$@"; }; p2() { registrar 2 "$@"; }
  p3() { registrar 3 "$@"; }; p4() { registrar 4 "$@"; }; manual() { :; }
  source apps/lista.sh
)
enumerar > "$TMP/lista.tsv"
pacotes() {  # pacotes <regex do gerenciador> <prioridades em regex>: nomes, um por linha
  awk -F'\t' -v g="^(sudo )?($1) -S" -v p="^($2)$" '$1 ~ p && $3 ~ g' "$TMP/lista.tsv" | cut -f3 \
    | sed -E 's/^(sudo pacman|yay) -S --needed --noconfirm //' | tr ' ' '\n' | grep -v '^$'
}

section "Formato da lista"
for p in 0 1 2 3 4; do
  n=$(awk -F'\t' -v p="$p" '$1 == p' "$TMP/lista.tsv" | wc -l)
  (( n > 0 )) && pass "P$p tem $n linha(s)" || fail "P$p vazia"
done
ruins=$(cut -f3 "$TMP/lista.tsv" | grep -vE '^(sudo pacman -S --needed --noconfirm|yay -S --needed --noconfirm|mise install|mise use -g|apps/webapps\.sh)( |$)')
[[ -z $ruins ]] && pass "toda linha é um comando de instalação idempotente" || fail "comando fora do padrão" "$ruins"
dup=$( { pacotes 'pacman|yay' '0|1|2|3'; pacotes 'pacman|yay' '4'; } | sort | uniq -d)
[[ -z $dup ]] && pass "nenhum pacote repetido entre as prioridades" || fail "pacotes repetidos" "$dup"
if awk -F'\t' '$2 == ""' "$TMP/lista.tsv" | grep -q .; then fail "linha sem descrição"; else pass "toda linha explica para que serve"; fi

section "O que o projeto precisa está na P0"
faltam=""
while read -r _ pkg req _; do
  [[ $req == [01] && $pkg != omarchy ]] || continue
  grep -qx "$pkg" <(pacotes 'pacman|yay' '0') || faltam+=" $pkg"
done < <(sed -n '/^DEPS=/,/)$/p' lib/compat.sh | sed -E 's/^(DEPS=\()?[[:space:]]*"//; s/"[[:space:])]*$//')
[[ -z $faltam ]] && pass "toda dependência declarada em lib/compat.sh está na P0" || fail "fora da P0" "$faltam"
grep -qx spotify <(pacotes 'pacman|yay' '0') && pass "Spotify na P0 (a barra é o player)" || fail "Spotify fora da P0"
declare -A MAPA=([foot]=foot [chromium]=chromium [org.gnome.Nautilus]=nautilus [cursor]=cursor-bin [obsidian]=obsidian [firefox]=firefox [osu-lazer]=osu-lazer-bin)
source <(grep -E '^FAVORITES=' config/terminal-soviet.conf)
faltam=""
for fav in $FAVORITES; do
  id=${fav%%:*}; pkg=${MAPA[$id]:-}
  [[ -n $pkg ]] || { faltam+=" $id(sem-mapa)"; continue; }
  grep -qx "$pkg" <(pacotes 'pacman|yay' '0|1|2|3') || faltam+=" $pkg"
done
[[ -z $faltam ]] && pass "todo app fixado na barra está na lista" || fail "fixados fora da lista" "$faltam"
grep -q steam <(pacotes 'pacman' '2') && pass "Steam presente para o botão de jogo da barra" || fail "Steam ausente"

section "Instalável num sistema limpo"
mkdir -p "$TMP/db/local"; cp -r /var/lib/pacman/sync "$TMP/db/sync"
mapfile -t REPO < <(pacotes 'pacman' '0|1|2|3|4')
if out=$(pacman -Sp --print-format '%n' --dbpath "$TMP/db" --noconfirm "${REPO[@]}" 2>&1); then
  pass "${#REPO[@]} pacotes resolvem juntos a partir de um banco vazio ($(wc -l <<< "$out") com dependências)"
else
  fail "pacotes não resolvem num sistema limpo" "$(tail -5 <<< "$out")"
fi
mapfile -t AUR_ < <(pacotes 'yay' '0|1|2|3|4')
if r=$(curl -fsS --max-time 15 -G https://aur.archlinux.org/rpc/v5/info $(printf -- '--data-urlencode arg[]=%s ' "${AUR_[@]}") 2>/dev/null); then
  achados=$(jq -r '.results[].Name' <<< "$r" | sort | tr '\n' ' ')
  [[ $achados == "$(printf '%s\n' "${AUR_[@]}" | sort | tr '\n' ' ')" ]] && pass "${#AUR_[@]} pacotes existem no AUR" || fail "faltam no AUR" "$achados"
else
  skip "pacotes do AUR" "sem rede"
fi
faltam=""
for t in $(awk -F'\t' '$3 ~ /^mise install/' "$TMP/lista.tsv" | cut -f3 | awk '{print $3}'); do
  grep -qE "^\"?$t\"?[[:space:]]*=" /etc/mise/conf.d/omarchy-tools.toml 2>/dev/null || faltam+=" $t"
done
[[ -z $faltam ]] && pass "ferramentas do mise vêm da configuração do Omarchy" || fail "mise sem essas ferramentas" "$faltam"

section "Execução (comandos simulados)"
mkdir -p "$TMP/bin"
for c in pacman yay mise; do
  cat > "$TMP/bin/$c" <<STUB
#!/bin/bash
echo "$c \$*" >> "\$LOG"
[[ -n \${FALHAR:-} && "\$*" == *"\$FALHAR"* ]] && exit 1
exit 0
STUB
done
cat > "$TMP/bin/sudo" <<'STUB'
#!/bin/bash
[[ $1 == -v ]] && exit 0
exec "$@"
STUB
chmod +x "$TMP"/bin/*
roda() { LOG="$TMP/log" PATH="$TMP/bin:$PATH" HOME="$TMP/h" apps/instalar-apps.sh "$@"; }
mkdir -p "$TMP/h"
rm -f "$TMP/log"; roda --ate 1 >/dev/null; rc=$?
[[ $rc == 0 ]] && pass "--ate 1 termina com sucesso" || fail "--ate 1" "rc=$rc"
[[ $(head -1 "$TMP/log") == "pacman -Syu --noconfirm" ]] && pass "atualiza o sistema antes de tudo" || fail "ordem da atualização" "$(head -1 "$TMP/log")"
[[ $(sed -n 2p "$TMP/log") == *hyprland ]] && pass "começa pela P0" || fail "prioridade" "$(sed -n 2p "$TMP/log")"
grep -q stably-orca-bin "$TMP/log" && ! grep -q kdenlive "$TMP/log" && pass "--ate 1 inclui trabalho e não inclui subutilizados" || fail "corte de prioridade"
rm -f "$TMP/log"; FALHAR=bruno-bin roda --so 1 --sem-atualizar > "$TMP/saida"; rc=$?
[[ $rc == 1 ]] && pass "app que falha faz a saída ser 1" || fail "saída com falha" "rc=$rc"
grep -q postman-bin "$TMP/log" && pass "um app que falha não impede os seguintes" || fail "parou na falha"
grep -q '✗ P1: Bruno' "$TMP/saida" && pass "o resumo diz qual falhou" || fail "resumo"
! grep -q -- '-Syu' "$TMP/log" && pass "--sem-atualizar respeitado" || fail "--sem-atualizar"
rm -f "$TMP/log"; roda --so 4 --sem-atualizar >/dev/null; grep -q ' sddm ' "$TMP/log" && pass "--so 4 instala a base" || fail "--so 4"
rm -f "$TMP/log"; roda --dry-run >/dev/null; [[ ! -e $TMP/log ]] && pass "--dry-run não executa nada" || fail "--dry-run executou"
roda --listar | grep -q '^MANUAL  Deadlock' && pass "passos manuais aparecem na lista" || fail "manuais"

section "Webapps"
env HOME="$TMP/w" XDG_DATA_HOME="$TMP/w/.local/share" PATH="$TMP/bin:$PATH" apps/webapps.sh; rc=$?
[[ $rc == 0 && -x $TMP/w/.local/bin/firefox-webapp-zoom ]] && pass "webapps instalados" || fail "webapps" "rc=$rc"
grep -q "Exec=$TMP/w/.local/bin/firefox-webapp-zoom" "$TMP/w/.local/share/applications/Zoom.desktop" && pass "caminho do HOME da máquina nova" || fail "HOME no .desktop"
if grep -rq __HOME__ "$TMP/w/.local/share/applications"; then fail "marcador sobrou"; else pass "sem marcador sobrando"; fi

section "Transposição"
out=$(./bootstrap.sh --dry-run 2>&1); rc=$?
[[ $rc == 0 ]] && pass "bootstrap --dry-run termina com sucesso" || fail "bootstrap" "rc=$rc: $(tail -3 <<< "$out")"
ordem=$(grep -oE '^######## [1-4]/4' <<< "$out" | tr '\n' ' ')
[[ $ordem == '######## 1/4 ######## 2/4 ######## 3/4 ######## 4/4 ' ]] && pass "ordem: P0, projeto, tema, resto" || fail "ordem do bootstrap" "$ordem"

if [[ ${TS_APPS_INVENTARIO:-} == 1 ]]; then
  section "Inventário desta máquina"
  source <(grep -E '^HARDWARE=' apps/lista.sh)
  fora=$(comm -23 <(pacman -Qqe | sort) <({ pacotes 'pacman|yay' '0|1|2|3|4'; tr ' ' '\n' <<< "$HARDWARE"; } | sort -u))
  [[ -z $fora ]] && pass "todo pacote explícito de pacman -Qqe está na lista ($(pacman -Qqe | wc -l))" || fail "fora da lista" "$fora"
  nao=$(comm -13 <(pacman -Qq | sort) <(pacotes 'pacman|yay' '0|1|2|3|4' | sort -u))
  [[ -z $nao ]] && pass "tudo da lista está instalado aqui" || fail "na lista e não instalado" "$nao"
  mudaria=$(pacman -Sp --needed --print-format '%n' "${REPO[@]}" 2>/dev/null)
  [[ -z $mudaria ]] && pass "rodar a lista aqui não mudaria nada (--needed)" || fail "mudaria" "$mudaria"
fi

summary
