#!/bin/bash
# Testes do tema de boot (scripts/install-limine-theme.sh) com um /boot FALSO.
#
# Nada toca no /boot real nem usa sudo: TS_BOOT_DIR aponta para um diretório
# temporário com tests/fixtures/limine.conf (cabeçalho do modelo do Omarchy +
# entradas no formato do limine-entry-tool), TS_SUDO="" e HOME/XDG isolados.
# limine-update e limine-snapper-sync são substituídos por stubs que só registram
# a chamada (e o script não deve chamá-los fora da ESP real).
# Rede: o fundo usa LIMINE_ORIGEM=zero (sem download); o cenário "arte" reaproveita
# o cache do usuário, ou baixa se houver rede, ou é PULADO.
set -uo pipefail
source "$(dirname "$0")/lib.sh"
REAL_HOME=$HOME
W=$(mktemp -d "${TMPDIR:-/tmp}/ts-limine-test.XXXXXX")
trap 'rm -rf "$W"' EXIT
FIX="$ROOT/tests/fixtures/limine.conf"
SCRIPT="$ROOT/scripts/install-limine-theme.sh"
MARK="# >>> terminal-soviet limine >>>"

# Stubs: limine (versão configurável) e as ferramentas que agem na ESP real.
mkdir -p "$W/stub"
cat > "$W/stub/limine" <<'EOF'
#!/bin/bash
echo "Limine ${STUB_LIMINE_VERSAO:-12.8.0}"
EOF
for c in limine-update limine-snapper-sync; do
  printf '#!/bin/bash\necho %s >> "%s/chamadas"\n' "$c" "$W" > "$W/stub/$c"
done
chmod +x "$W/stub/"*

# conf de teste: o versionado com LIMINE_* trocados (chave=valor …).
conf() {
  local f="$W/conf.$RANDOM" kv
  cp "$ROOT/config/terminal-soviet.conf" "$f"
  sed -i 's/^LIMINE_ORIGEM=.*/LIMINE_ORIGEM="zero"/' "$f"
  local d=$'\x01'   # delimitador do sed: valores podem ter "|" (linhas do título)
  for kv in "$@"; do sed -i "s${d}^${kv%%=*}=.*${d}${kv%%=*}=\"${kv#*=}\"${d}" "$f"; done
  printf '%s\n' "$f"
}

novo_boot() {  # novo_boot <nome>: /boot falso com o fixture
  local b="$W/$1"
  mkdir -p "$b/boot" "$b/home"
  cp "$FIX" "$b/boot/limine.conf"
  printf '%s\n' "$b"
}

tema() {  # tema <dir do cenário> <conf> <args…>
  local b=$1 c=$2; shift 2
  env -u XDG_CACHE_HOME -u XDG_STATE_HOME HOME="$b/home" PATH="$W/stub:$PATH" \
      TS_BOOT_DIR="$b/boot" TS_SUDO= TS_CONF_FILE="$c" "$SCRIPT" "$@"
}

entradas() { awk 'f || /^[[:space:]]*\//{ f = 1; print }' "$1"; }
cabecalho() { awk '/^[[:space:]]*\//{ exit } { print }' "$1"; }
snap() { (cd "$1" && find . -type f -exec sha256sum {} + | sort); }

C=$(conf)

section "Plano: não escreve nada"
B=$(novo_boot plano)
antes=$(snap "$B/boot")
tema "$B" "$C" --plan > "$B/saida" 2>&1; rc=$?
check "--plan termina sem erro" test "$rc" = 0
check "--plan mostra o diff do limine.conf" grep -q "^+$MARK" "$B/saida"
check "--plan não altera o /boot" test "$(snap "$B/boot")" = "$antes"
check "--plan: só limine.conf no /boot falso" bash -c '[[ $(ls "$1/boot") == limine.conf ]]' _ "$B"

section "Instalar"
B=$(novo_boot inst)
tema "$B" "$C" --install --yes > "$B/saida" 2>&1; rc=$?
check "--install termina sem erro" test "$rc" = 0
check "um único bloco do tema" test "$(grep -cxF "$MARK" "$B/boot/limine.conf")" = 1
check "entradas de boot byte a byte iguais" cmp -s <(entradas "$B/boot/limine.conf") <(entradas "$FIX")
check "default_entry mantido" grep -qx 'default_entry: 2' "$B/boot/limine.conf"
check "hash_mismatch_panic: no (dentro do bloco)" grep -qx 'hash_mismatch_panic: no' "$B/boot/limine.conf"
check "chaves do Omarchy fora do cabeçalho (branding, cores, backdrop)" \
  bash -c '! grep -qE "^(interface_branding: Omarchy|term_background: 1a1b26|backdrop: 1a1b26|interface_help_color: 9ece6a)" "$1"' _ "$B/boot/limine.conf"
check "nenhuma chave repetida no cabeçalho" \
  bash -c '[[ -z $(awk "/^[[:space:]]*\\//{exit} {print}" "$1" | grep -oE "^[a-z_]+:" | sort | uniq -d) ]]' _ "$B/boot/limine.conf"
for k in wallpaper term_font; do
  arq=$(sed -n "s|^$k: boot():/\([^#]*\)#.*|\1|p" "$B/boot/limine.conf")
  h=$(sed -n "s|^$k: boot():/[^#]*#\(.*\)|\1|p" "$B/boot/limine.conf")
  check "$k: arquivo no /boot e b2sum na linha confere" \
    bash -c '[[ -n $2 && $(b2sum "$1/$2" | cut -d" " -f1) == "$3" ]]' _ "$B/boot" "$arq" "$h"
done
check "todas as chaves do Fallout presentes" bash -c 'for k in wallpaper term_font term_font_size term_font_scale term_background term_margin term_foreground term_palette term_palette_bright interface_branding interface_help_hidden timeout remember_last_entry; do grep -qE "^$k:" "$1" || exit 1; done' _ "$B/boot/limine.conf"
check "term_font_size 8x14 (fonte de 3584 bytes)" bash -c 'grep -qx "term_font_size: 8x14" "$1/limine.conf" && [[ $(stat -c %s "$1/ts-limine-fonte.f14") == 3584 ]]' _ "$B/boot"
check "term_font_scale 2x2 em 1920x1080" grep -qx 'term_font_scale: 2x2' "$B/boot/limine.conf"
check "timeout 15" grep -qx 'timeout: 15' "$B/boot/limine.conf"
check "backup datado ao lado do limine.conf, igual ao original" bash -c 'cmp -s "$1"/limine.conf.terminal-soviet-*.bak "$2"' _ "$B/boot" "$FIX"
check "cópia do backup fora da ESP" bash -c 'cmp -s "$1"/home/.local/state/terminal-soviet/limine/backups/limine.conf.* "$2"' _ "$B" "$FIX"
check "limine-update/limine-snapper-sync NÃO chamados fora da ESP real" test ! -e "$W/chamadas"
check "nada escrito fora do /boot falso e do HOME isolado" \
  bash -c '[[ -z $(find "$1" -newer "$2" -type f ! -path "$1/boot/*" ! -path "$1/home/*" ! -name saida) ]]' _ "$B" "$FIX"

section "Reinstalar (idempotência)"
cp "$B/boot/limine.conf" "$W/conf-1"
tema "$B" "$C" --install --yes > "$B/saida" 2>&1
check "reinstalar com a mesma config não muda nada" cmp -s "$B/boot/limine.conf" "$W/conf-1"
check "reinstalar não cria outro backup" test "$(ls "$B/boot"/limine.conf.terminal-soviet-*.bak | wc -l)" = 1
check "reinstalar avisa que já está aplicado" grep -q "já aplicado" "$B/saida"
CA=$(conf LIMINE_THEME=ambar LIMINE_TIMEOUT=7)
sleep 1
tema "$B" "$CA" --install --yes > "$B/saida" 2>&1
check "trocar a variante (âmbar): ainda um bloco só" test "$(grep -cxF "$MARK" "$B/boot/limine.conf")" = 1
check "trocar a variante: cores e timeout novos" bash -c 'grep -qx "term_foreground: C9B26B" "$1" && grep -qx "timeout: 7" "$1"' _ "$B/boot/limine.conf"
check "trocar a variante: entradas intactas" cmp -s <(entradas "$B/boot/limine.conf") <(entradas "$FIX")
tema "$B" "$CA" --status > "$B/saida" 2>&1; rc=$?
check "--status: aplicado, hashes batem (rc 0)" test "$rc" = 0
tema "$B" "$C" --status > "$B/saida" 2>&1; rc=$?
check "--status: config mudou desde a aplicação (rc 3)" bash -c '[[ $1 == 3 ]] && grep -q "mudou desde a aplicação" "$2"' _ "$rc" "$B/saida"

section "Omarchy sobrescreve"
B=$(novo_boot omarchy)
tema "$B" "$C" --install --yes > /dev/null 2>&1
# omarchy-refresh-limine: mv limine.conf limine.conf.bak + modelo do Omarchy.
mv "$B/boot/limine.conf" "$B/boot/limine.conf.bak"; cp "$FIX" "$B/boot/limine.conf"
tema "$B" "$C" --status > "$B/saida" 2>&1; rc=$?
check "--status detecta o refresh do Omarchy (SOBRESCRITO, rc 3)" bash -c '[[ $1 == 3 ]] && grep -q SOBRESCRITO "$2"' _ "$rc" "$B/saida"
tema "$B" "$C" --install --yes > /dev/null 2>&1
check "--install reaplica depois do refresh" test "$(grep -cxF "$MARK" "$B/boot/limine.conf")" = 1
# Upgrade do Omarchy: sed reinsere interface_help_color depois de interface_branding_color… fora do bloco.
sed -i 's/^default_entry: 2$/default_entry: 2\ninterface_help_color: 9ece6a/' "$B/boot/limine.conf"
tema "$B" "$C" --status > "$B/saida" 2>&1; rc=$?
check "--status detecta chave do Omarchy reinserida fora do bloco (rc 3)" bash -c '[[ $1 == 3 ]] && grep -q "fora do bloco" "$2"' _ "$rc" "$B/saida"
tema "$B" "$C" --install --yes > /dev/null 2>&1
check "--install tira a chave reinserida" bash -c '! grep -qx "interface_help_color: 9ece6a" "$1"' _ "$B/boot/limine.conf"

section "Hash errado e fonte ausente"
B=$(novo_boot hash)
tema "$B" "$C" --install --yes > /dev/null 2>&1
printf 'x' >> "$B/boot/ts-limine-fonte.f14"
tema "$B" "$C" --status > "$B/saida" 2>&1; rc=$?
check "--status: fonte alterada → hash não confere (rc 2)" bash -c '[[ $1 == 2 ]] && grep -q "hash não confere" "$2"' _ "$rc" "$B/saida"
rm "$B/boot/ts-limine-fundo.png"
tema "$B" "$C" --status > "$B/saida" 2>&1; rc=$?
check "--status: papel de parede ausente (rc 2)" bash -c '[[ $1 == 2 ]] && grep -q "ausente" "$2"' _ "$rc" "$B/saida"
tema "$B" "$C" --install --yes > /dev/null 2>&1
tema "$B" "$C" --status > /dev/null 2>&1; rc=$?
check "--install recupera fonte e papel de parede" test "$rc" = 0

section "Remover"
B=$(novo_boot rem)
tema "$B" "$C" --install --yes > /dev/null 2>&1
tema "$B" "$C" --remove --yes > /dev/null 2>&1
check "--remove volta ao limine.conf original (byte a byte)" cmp -s "$B/boot/limine.conf" "$FIX"
check "--remove apaga fonte e papel de parede" bash -c '[[ ! -e $1/ts-limine-fonte.f14 && ! -e $1/ts-limine-fundo.png ]]' _ "$B/boot"
tema "$B" "$C" --remove --yes > "$B/saida" 2>&1; rc=$?
check "--remove sem tema aplicado: nada a fazer" bash -c '[[ $1 == 0 ]] && grep -q "nada a remover" "$2"' _ "$rc" "$B/saida"
# Entradas mudaram depois da instalação (kernel novo): não volta ao backup velho.
B=$(novo_boot rem2)
tema "$B" "$C" --install --yes > /dev/null 2>&1
printf '\n  //linux-omarchy-6.18\n  protocol: efi\n  path: boot():/EFI/Linux/novo.efi\n' >> "$B/boot/limine.conf"
tema "$B" "$C" --remove --yes > /dev/null 2>&1
check "--remove com entradas novas: mantém as entradas atuais" grep -q 'novo.efi' "$B/boot/limine.conf"
check "--remove com entradas novas: devolve as chaves originais do Omarchy" \
  bash -c 'grep -qx "interface_branding: Omarchy Bootloader" "$1" && grep -qx "term_background: 1a1b26" "$1"' _ "$B/boot/limine.conf"
check "--remove com entradas novas: sem bloco" bash -c '! grep -qxF "$2" "$1"' _ "$B/boot/limine.conf" "$MARK"

section "Recusas (nada é escrito)"
B=$(novo_boot legado)
mkdir -p "$B/boot/EFI/limine"; cp "$FIX" "$B/boot/EFI/limine/limine.conf"
tema "$B" "$C" --install --yes > "$B/saida" 2>&1; rc=$?
check "config legada em EFI/limine: recusa" bash -c '[[ $1 != 0 ]] && grep -q "legadas" "$2" && cmp -s "$3/limine.conf" "$4"' _ "$rc" "$B/saida" "$B/boot" "$FIX"
B=$(novo_boot versao)
STUB_LIMINE_VERSAO=11.4.1 tema "$B" "$C" --install --yes > "$B/saida" 2>&1; rc=$?
check "Limine 11.x: recusa" bash -c '[[ $1 != 0 ]] && grep -q "fora da série" "$2" && cmp -s "$3/limine.conf" "$4"' _ "$rc" "$B/saida" "$B/boot" "$FIX"
B=$(novo_boot semconf); rm "$B/boot/limine.conf"
tema "$B" "$C" --install --yes > "$B/saida" 2>&1; rc=$?
check "sem limine.conf: recusa" bash -c '[[ $1 != 0 ]] && grep -q "não existe" "$2" && [[ -z $(ls "$3") ]]' _ "$rc" "$B/saida" "$B/boot"

section "Variantes e fundos"
for v in robco fosforo ambar fallout; do
  B=$(novo_boot "var-$v")
  tema "$B" "$(conf LIMINE_THEME=$v)" --install --yes > /dev/null 2>&1; rc=$?
  check "variante $v instala" bash -c '[[ $1 == 0 ]] && grep -q "variante: $2" "$3"' _ "$rc" "$v" "$B/boot/limine.conf"
done
check "fallout usa term_background do upstream (9935453b)" grep -qx 'term_background: 9935453b' "$W/var-fallout/boot/limine.conf"
B=$(novo_boot arte)
mkdir -p "$B/home/.cache/terminal-soviet/limine"
[[ -d $REAL_HOME/.cache/terminal-soviet/limine/upstream ]] && cp -r "$REAL_HOME/.cache/terminal-soviet/limine/upstream" "$B/home/.cache/terminal-soviet/limine/"
if tema "$B" "$(conf LIMINE_ORIGEM=arte)" --install --yes > "$B/saida" 2>&1; then
  pass "fundo a partir da arte (SHA-256 conferido)"
elif grep -q "download falhou" "$B/saida"; then
  skip "fundo a partir da arte" "sem rede e sem cache"
else
  fail "fundo a partir da arte" "$(tail -1 "$B/saida")"
fi

summary
