#!/bin/bash
# Testes estáticos: não alteram nada fora de um diretório temporário.
#   sintaxe (bash, perl, Lua, Luau*), JSON, TOML (noctalia config validate),
#   manifest do plugin Omarchy, modelos sem marcador sobrando, caminhos e segredos.
# * Luau: não há compilador Luau no sistema; os plugins são carregados de fato
#   só no teste ao vivo (Noctalia em execução).
set -uo pipefail
source "$(dirname "$0")/lib.sh"
cd "$ROOT"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

section "Sintaxe dos scripts"
for f in install.sh lib/*.sh bin/soviet-* scripts/*.sh migrate/*.sh tests/*.sh \
         noctalia/plugins/*/*.sh share/terminal-soviet/arte/artprint-shim; do
  check "bash -n $f" bash -n "$f"
done
check "perl -c cores-tema.pl" perl -c share/terminal-soviet/arte/cores-tema.pl
if command -v shellcheck >/dev/null; then
  check "shellcheck (erros)" shellcheck -S error install.sh lib/*.sh bin/soviet-* scripts/*.sh migrate/*.sh
else
  skip "shellcheck" "não instalado (pacote shellcheck)"
fi

section "Formatos de dados"
for f in noctalia/config/palettes/*.json omarchy/plugins/*/manifest.json noctalia/plugins/*/translations/*.json; do
  check "JSON válido: $f" jq -e . "$f"
done
check "plugin de barra Omarchy (omarchy plugin validate)" omarchy plugin validate omarchy/plugins/erllan.sem-barra

section "Modelos renderizados (configuração versionada)"
(
  source lib/ts-lib.sh
  load_conf config/terminal-soviet.conf >/dev/null && compute_tokens
  HOME=$TMP/home
  while IFS=$'\t' read -r src rel; do render "$ROOT/$src" "$TMP/out/$rel"; done < <(payload_map "$ROOT")
) && pass "todos os modelos renderizam sem marcador sobrando" || fail "renderização dos modelos"
check "noctalia config validate (configuração gerada)" noctalia config validate "$TMP/out/.config/noctalia"
check "luac -p terminal_soviet.lua (sintaxe Lua)" luac -p "$TMP/out/.config/hypr/terminal_soviet.lua"
check "luac -p workspace layout" luac -p "$TMP/out/.local/state/omarchy/workspace-layouts/1.lua"
check "luac -p tema soviet-terminal/hyprland.lua" luac -p omarchy/themes/soviet-terminal/hyprland.lua
# O Luau aceita a sintaxe do Lua 5.1 + anotações; os plugins não usam anotações.
for f in "$TMP"/out/.local/share/noctalia/plugins/*/*.luau; do
  check "luajit -bl (sintaxe Lua 5.1) ${f#"$TMP"/out/}" bash -c "sed 's/^--!nonstrict//' '$f' | luajit -bl - >/dev/null"
done
check "atalhos do módulo vêm da configuração" grep -q 'o.bind("SUPER + ALT + A"' "$TMP/out/.config/hypr/terminal_soviet.lua"

section "Caminhos e conteúdo sensível"
hits=$(grep -rIl --exclude-dir=.git --exclude=.git --exclude-dir=docs --exclude-dir=tests --exclude-dir=retomada -e "/home/$USER" -e "/home/erll" . 2>/dev/null || true)
[[ -z $hits ]] && pass "nenhum caminho absoluto de usuário no código/configuração" || fail "caminhos de usuário" "$hits"
hits=$(grep -rIlE --exclude-dir=.git --exclude=.git -e '(api[_-]?key|secret|token|passw(or)?d)[[:space:]]*[=:][[:space:]]*["'"'"']?[A-Za-z0-9/+_-]{12,}|BEGIN [A-Z ]*PRIVATE KEY|ghp_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9]{20,}' \
      . 2>/dev/null || true)
[[ -z $hits ]] && pass "nenhum padrão de segredo (chaves, tokens, senhas)" || fail "possível segredo" "$hits"
big=$(find . -path ./.git -prune -o -type f -size +500k -print)
[[ -z $big ]] && pass "nenhum arquivo > 500 KB (mídia de terceiros fica fora)" || fail "arquivos grandes" "$big"
[[ -z $(find . -path ./.git -prune -o -type l -print) ]] && pass "nenhum link simbólico versionado" || fail "links simbólicos no repositório"
[[ ! -e omarchy/themes/soviet-terminal/backgrounds && ! -e omarchy/themes/soviet-terminal/preview.png ]] \
  && pass "papéis de parede/preview fora do repositório" || fail "papéis de parede presentes no repositório"

summary
