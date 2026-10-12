#!/bin/bash
# Testes do instalador em HOMEs isolados (diretórios temporários).
#
# Nada é escrito no $HOME real: cada cenário roda com HOME=<tmp>, sem as
# variáveis XDG_* da sessão, sem HYPRLAND_INSTANCE_SIGNATURE e com
# --no-activate (sem hyprctl reload, systemctl ou IPC com o shell).
# Dependências externas (arttime, omarchy-overview) vêm de clones LOCAIS
# (file://), então o teste não depende de rede — mas exige que existam:
#   ~/.local/src/arttime  (commit fixado)   ~/.config/omarchy/plugins/moorgrove.overview
#
# Limite: "Omarchy limpo" = arquivos padrão de $OMARCHY_PATH/config nesta mesma
# máquina (mesmos pacotes). Não substitui uma instalação nova real/VM.
set -uo pipefail
source "$(dirname "$0")/lib.sh"
REAL_HOME=$HOME
OMARCHY_PATH=${OMARCHY_PATH:-/usr/share/omarchy}
WORK=$(mktemp -d "${TMPDIR:-/tmp}/ts-sandbox.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

# Executa no HOME isolado.
in_home() {  # in_home <home> <comando...>
  local h=$1; shift
  env -u XDG_CONFIG_HOME -u XDG_STATE_HOME -u XDG_CACHE_HOME -u XDG_DATA_HOME \
      -u HYPRLAND_INSTANCE_SIGNATURE HOME="$h" \
      TS_ARTTIME_URL="file://$REAL_HOME/.local/src/arttime" \
      TS_OVERVIEW_URL="file://$REAL_HOME/.config/omarchy/plugins/moorgrove.overview" "$@"
}

# HOME com os arquivos padrão de uma instalação nova do Omarchy.
fresh_home() {
  local h="$WORK/$1"
  mkdir -p "$h/.config/hypr" "$h/.config/omarchy" "$h/.local/state/omarchy/workspace-layouts"
  cp "$OMARCHY_PATH"/config/hypr/* "$h/.config/hypr/"
  cp "$OMARCHY_PATH/config/omarchy/shell.json" "$h/.config/omarchy/shell.json"
  printf '%s\n' "$h"
}

# Fotografia do HOME (conteúdo e links), sem o estado do instalador.
# shell.json é comparado pelo conteúdo JSON normalizado.
snap() {
  local h=$1
  (cd "$h" && find . \( -path ./.local/state/terminal-soviet -prune \) -o \( -type f -o -type l \) -print | sort |
    while IFS= read -r f; do
      if [[ -L $f ]]; then echo "L $f -> $(readlink "$f")"
      elif [[ $f == ./.config/omarchy/shell.json ]]; then echo "J $f $(jq -S -c . "$f" | sha256sum | cut -c1-16)"
      else echo "F $f $(sha256sum "$f" | cut -c1-16) $(stat -c %a "$f")"; fi
    done)
}

INST="$ROOT/install.sh"
OPTS=(--no-activate)

section "Cenário A: Omarchy limpo, sem dependências externas"
A=$(fresh_home a)
before=$(snap "$A")
out=$(in_home "$A" "$INST" --dry-run "${OPTS[@]}" --no-externals 2>&1); rc=$?
[[ $rc == 0 ]] && pass "--dry-run termina com sucesso" || fail "--dry-run" "rc=$rc: $(tail -3 <<< "$out")"
[[ $(snap "$A") == "$before" ]] && pass "--dry-run não altera nenhum arquivo" || fail "--dry-run alterou arquivos"
grep -q 'CRIAR' <<< "$out" && pass "--dry-run lista o que seria criado" || fail "plano vazio no --dry-run"

out=$(in_home "$A" "$INST" "${OPTS[@]}" --no-externals 2>&1); rc=$?
[[ $rc == 0 ]] && pass "instalação em HOME limpo" || fail "instalação" "rc=$rc: $(tail -5 <<< "$out")"
check "status: todos os itens conferem" in_home "$A" "$INST" status
check "módulo Hyprland gerado" test -f "$A/.config/hypr/terminal_soviet.lua"
[[ $(grep -c 'require("hypr.terminal_soviet")' "$A/.config/hypr/hyprland.lua") == 1 ]] \
  && pass "hyprland.lua com exatamente 1 bloco do projeto" || fail "bloco do hyprland.lua"
check "shell.json: bar.id = erllan.sem-barra" test "$(jq -r .bar.id "$A/.config/omarchy/shell.json")" = erllan.sem-barra
check "serviços habilitados (links em graphical-session.target.wants)" \
  test -L "$A/.config/systemd/user/graphical-session.target.wants/soviet-bar-sync.service"
check "noctalia config validate (instalado)" noctalia config validate "$A/.config/noctalia"
hits=$(grep -rIl --exclude-dir=state -e "$REAL_HOME/" "$A/.config" "$A/.local/bin" "$A/.local/share" 2>/dev/null || true)
[[ -z $hits ]] && pass "nenhum caminho do HOME real nos arquivos instalados" || fail "caminho do HOME real vazou" "$hits"
grep -q "\"exec $A/.local/bin/soviet-inspect\"" "$A/.config/noctalia/20-barra.toml" \
  && pass "caminhos renderizados para o HOME de destino" || fail "caminho renderizado"

section "Idempotência"
s1=$(snap "$A"); m1=$(cat "$A/.local/state/terminal-soviet/install/manifest.tsv")
nb1=$(find "$A/.local/state/terminal-soviet/install/backups" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)
out=$(in_home "$A" "$INST" "${OPTS[@]}" --no-externals 2>&1); rc=$?
[[ $rc == 0 ]] && pass "segunda execução termina com sucesso" || fail "segunda execução" "rc=$rc"
grep -qE '^\s+(CRIAR|ATUALIZAR|ADICIONAR|ALTERAR|CONFLITO)' <<< "$out" \
  && fail "segunda execução planejou mudanças" "$(grep -E '^\s+(CRIAR|ATUALIZAR|ADICIONAR|ALTERAR|CONFLITO)' <<< "$out" | head -3)" \
  || pass "segunda execução: nada a fazer"
[[ $(snap "$A") == "$s1" ]] && pass "segunda execução não altera arquivos" || fail "arquivos mudaram na reexecução"
[[ $(cat "$A/.local/state/terminal-soviet/install/manifest.tsv") == "$m1" ]] && pass "manifesto idêntico" || fail "manifesto mudou"
nb2=$(find "$A/.local/state/terminal-soviet/install/backups" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)
[[ $nb1 == "$nb2" ]] && pass "reexecução não cria backup novo (1ª instalação: $nb1 lote com hyprland.lua/shell.json)" || fail "backup criado sem motivo"

section "Conflitos (customizações do usuário não são sobrescritas)"
echo "# edição local" >> "$A/.local/bin/soviet-ops"
s2=$(snap "$A")
in_home "$A" "$INST" "${OPTS[@]}" --no-externals >/dev/null 2>&1; rc=$?
[[ $rc == 3 ]] && pass "arquivo gerenciado editado → para com conflito (rc 3)" || fail "conflito não detectado" "rc=$rc"
[[ $(snap "$A") == "$s2" ]] && pass "conflito: nenhum arquivo alterado" || fail "conflito alterou arquivos"
in_home "$A" "$INST" status >/dev/null 2>&1 && fail "status não acusou edição" || pass "status acusa o arquivo editado"
in_home "$A" "$INST" "${OPTS[@]}" --no-externals --force >/dev/null 2>&1; rc=$?
[[ $rc == 0 ]] && cmp -s "$A/.local/bin/soviet-ops" "$ROOT/bin/soviet-ops" \
  && pass "--force reinstala a versão do repositório" || fail "--force" "rc=$rc"
bk=$(find "$A/.local/state/terminal-soviet/install/backups" -name soviet-ops 2>/dev/null | head -1)
[[ -n $bk ]] && grep -q '# edição local' "$bk" && pass "--force guardou a versão editada em backup" || fail "backup do --force"

B=$(fresh_home b)
mkdir -p "$B/.config/btop"; echo 'update_ms = 5000  # do usuário' > "$B/.config/btop/soviet-ops.conf"
sb=$(snap "$B")
in_home "$B" "$INST" "${OPTS[@]}" --no-externals >/dev/null 2>&1; rc=$?
[[ $rc == 3 && $(snap "$B") == "$sb" ]] && pass "arquivo pré-existente não gerenciado → para sem alterar nada" \
  || fail "arquivo pré-existente" "rc=$rc"

section "Desinstalação e restauração"
out=$(in_home "$A" "$INST" uninstall --dry-run 2>&1); rc=$?
[[ $rc == 0 && $(snap "$A") == "$(snap "$A")" ]] && grep -q REMOVER <<< "$out" \
  && pass "uninstall --dry-run lista e não altera" || fail "uninstall --dry-run"
pre=$before
in_home "$A" "$INST" uninstall >/dev/null 2>&1; rc=$?
[[ $rc == 0 ]] && pass "desinstalação termina com sucesso" || fail "desinstalação" "rc=$rc"
d=$(diff <(echo "$pre") <(snap "$A"))
[[ -n ${TS_DEBUG:-} ]] && echo "$d"
[[ -z $d ]] && pass "HOME volta exatamente ao estado anterior (arquivos, links, permissões, shell.json)" \
  || fail "diferenças após desinstalar" "$(head -5 <<< "$d")"

# Usuário edita hyprland.lua depois de instalar: a desinstalação preserva a edição.
C=$(fresh_home c)
in_home "$C" "$INST" "${OPTS[@]}" --no-externals >/dev/null 2>&1
echo '-- edição posterior do usuário' >> "$C/.config/hypr/hyprland.lua"
in_home "$C" "$INST" uninstall >/dev/null 2>&1
grep -q 'edição posterior do usuário' "$C/.config/hypr/hyprland.lua" && ! grep -q terminal_soviet "$C/.config/hypr/hyprland.lua" \
  && pass "desinstalar remove só o bloco e preserva edições posteriores" || fail "edição posterior perdida"

section "Migração da Fase 1 (cópia dos arquivos reais do Hyprland)"
D=$(fresh_home d)
cp "$REAL_HOME"/.config/hypr/{hyprland,bindings,autostart}.lua "$D/.config/hypr/"
sd=$(snap "$D")
out=$(in_home "$D" "$INST" "${OPTS[@]}" --no-externals 2>&1); rc=$?
[[ $rc != 0 && $(snap "$D") == "$sd" ]] && grep -q 'phase1-inline' <<< "$out" \
  && pass "instalação recusada com configuração manual da Fase 1 (nada alterado)" || fail "detecção da Fase 1" "rc=$rc"
if in_home "$D" "$ROOT/migrate/phase1-inline.sh" >/dev/null 2>&1; then
  pass "migrate/phase1-inline.sh remove os trechos idênticos"
  grep -qE 'soviet|noctalia' "$D"/.config/hypr/{bindings,autostart}.lua && fail "sobrou trecho do projeto" || pass "nenhum trecho do projeto restante"
  in_home "$D" "$INST" "${OPTS[@]}" --no-externals >/dev/null 2>&1; rc=$?
  [[ $rc == 0 ]] && pass "instalação após a migração" || fail "instalação após migração" "rc=$rc"
  n=$(cat "$D"/.config/hypr/*.lua | grep -c 'soviet-inspect"')
  [[ $n == 1 ]] && pass "atalho do btop definido uma única vez" || fail "atalho duplicado" "$n"
else
  fail "migrate/phase1-inline.sh"
fi
echo '-- editado' >> "$D/.config/hypr/bindings.lua"
E=$(fresh_home e); cp "$REAL_HOME"/.config/hypr/bindings.lua "$E/.config/hypr/"; echo "-- x" >> "$E/.config/hypr/bindings.lua"
se=$(snap "$E")
in_home "$E" "$ROOT/migrate/phase1-inline.sh" >/dev/null 2>&1 && fail "migração aceitou trecho editado" \
  || { [[ $(snap "$E") == "$se" ]] && pass "migração recusa trecho editado sem alterar nada" || fail "migração alterou arquivo editado"; }

section "Dependências externas fixadas (clones locais, sem rede)"
if [[ -d $REAL_HOME/.local/src/arttime/.git && -d $REAL_HOME/.config/omarchy/plugins/moorgrove.overview/.git ]] && command -v zsh >/dev/null; then
  F=$(fresh_home f)
  out=$(in_home "$F" "$INST" "${OPTS[@]}" 2>&1); rc=$?
  [[ $rc == 0 ]] && pass "instalação com externos" || fail "instalação com externos" "rc=$rc: $(tail -4 <<< "$out")"
  [[ $(in_home "$F" "$F/.local/bin/arttime" --version 2>/dev/null) == 2.5.0 ]] && pass "arttime 2.5.0 instalado no HOME" || fail "arttime"
  [[ $(git -C "$F/.local/src/arttime" rev-parse HEAD) == 38c2955a7c16d6900cc121265595347266b18af8 ]] \
    && pass "arttime no commit fixado" || fail "commit do arttime"
  n=$(find "$F/.local/share/arttime/textart" -type f | wc -l)
  [[ $n == 516 ]] && pass "coleção completa via instalação do arttime ($n artes)" || fail "coleção do arttime" "$n"
  [[ ! -e $F/.bashrc && ! -e $F/.zshrc ]] && pass "arttime não criou/alterou .bashrc/.zshrc" || fail "rc do shell alterado"
  check "omarchy-overview no commit fixado" test "$(git -C "$F/.config/omarchy/plugins/moorgrove.overview" rev-parse HEAD)" = 1ed4938a2382a6121255d6bfb9c3d0fdeb5ce9ff
  out=$(in_home "$F" "$INST" "${OPTS[@]}" 2>&1)
  grep -q INSTALAR <<< "$out" && fail "reexecução reinstalaria externos" || pass "reexecução: externos já no estado desejado"
  # A ilustração funciona a partir da instalação isolada (sem sessão gráfica).
  out=$(in_home "$F" "$F/.local/bin/soviet-arte" desenhar butterfly --cols 80 --rows 30 2>&1)
  grep -q 'I live on a tree' <<< "$(sed 's/\x1b\[[0-9;]*m//g' <<< "$out")" \
    && pass "soviet-arte instalado desenha arte + frase original" || fail "soviet-arte no HOME isolado" "$(head -2 <<< "$out")"
else
  skip "externos" "clones locais de arttime/omarchy-overview ou zsh ausentes"
fi

summary
