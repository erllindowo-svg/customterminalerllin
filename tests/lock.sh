#!/bin/bash
# Testes do gerador do bloqueio (bin/soviet-lock-clone). Não alteram o sistema: rodam
# num HOME temporário, sem sessão (TS_LOCK_LIVE=0). Bloqueio real: tests/lock-live.sh.
set -uo pipefail
source "$(dirname "$0")/lib.sh"
cd "$ROOT"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
export TS_LOCK_LIVE=0 TS_CONF="$ROOT/config/terminal-soviet.conf"
OMARCHY_REAL=${OMARCHY_PATH:-/usr/share/omarchy}
CLONE=bin/soviet-lock-clone

section "Geração a partir do bloqueio nativo instalado"
check "o patch aplica na versão instalada do Omarchy" "$CLONE" check
"$CLONE" build "$TMP/p"; rc=$?
[[ $rc == 0 ]] && pass "gera o plugin" || fail "geração" "rc=$rc"
check "manifesto é clone oficial de omarchy.lock" jq -e '.id == "erllan.soviet-lock" and .omarchy.clonedFrom == "omarchy.lock" and (.omarchy.capabilities | index("authentication") != null)' "$TMP/p/manifest.json"
check "omarchy plugin validate aceita o clone" omarchy plugin validate "$TMP/p"
if grep -rq '@[A-Z_]*@' "$TMP/p"/*.qml; then fail "marcadores sobrando no QML"; else pass "nenhum marcador sobrando no QML"; fi
check "workspace da central vem da configuração" grep -q 'centralWorkspace: 1$' "$TMP/p/SovietScreen.qml"

section "Segurança: o patch não toca na autenticação"
ch=$(diff "$OMARCHY_REAL/shell/plugins/lock/Service.qml" "$TMP/p/Service.qml" | grep '^[<>]')
if grep -qE 'PamContext|passwordPam|fingerprintPam|respond|pendingPassword|sessionLock\.locked = true|passwordPamConfigured|WlSessionLock \{|allow_session' <<< "$ch"; then
  fail "o patch alterou linhas de autenticação" "$ch"
else pass "Service.qml: nenhuma linha de PAM ou de sessão foi alterada"; fi
n=$(grep -c '^<' <<< "$ch")
(( n == 2 )) && pass "Service.qml: só 2 linhas originais trocadas (cor da superfície e texto do erro)" || fail "linhas trocadas no Service.qml" "$n: $ch"
check "a tela fica acesa com a sessão bloqueada" awk '/function runBlank/ { getline; getline; achou = ($1 == "return") } END { exit !achou }' "$TMP/p/Service.qml"
check "PAM continua no serviço original" grep -q 'config: "omarchy-lock-password"' "$TMP/p/Service.qml"
check "outro monitor só com o wallpaper, sem perder o teclado" grep -q 'opacity: root.wallpaperOnly ? 0 : 1' "$TMP/p/LockView.qml"
check "wallpaper sem desfoque no outro monitor" grep -q 'visible: !sovietScreen.transparent && !root.wallpaperOnly' "$TMP/p/LockView.qml"
if grep -qP '[\x{0400}-\x{04FF}]' "$TMP/p/LockView.qml" "$TMP/p/Service.qml"; then fail "texto em russo no bloqueio"; else pass "textos do bloqueio em inglês"; fi
check "transparência exige central visível e sem workspace especial" grep -q 'property bool transparent: onCentral && noSpecial' "$TMP/p/SovietScreen.qml"
check "superfície fora da central segue opaca (fundo original)" grep -q 'central.transparent ? "transparent" : Commons.Color.background' "$TMP/p/Service.qml"
check "notificações cobertas enquanto transparente" grep -q 'visible: sovietScreen.transparent && root.visibleToasts > 0' "$TMP/p/LockView.qml"
check "falha ao ler as notificações cobre em vez de expor" grep -q 'root.visibleToasts = 1' "$TMP/p/LockView.qml"
check "Hyprland: xray ligado no módulo" grep -q 'session_lock_xray = true' hypr/terminal_soviet.lua.in

section "Instalação em HOME isolado"
H="$TMP/home"; mkdir -p "$H/.config/omarchy"
cp "$OMARCHY_REAL/config/omarchy/shell.json" "$H/.config/omarchy/shell.json"
orig=$(jq -S -c . "$H/.config/omarchy/shell.json")
run() { env -u HYPRLAND_INSTANCE_SIGNATURE HOME="$H" "$@"; }
run "$CLONE" apply; rc=$?
[[ $rc == 0 && -f $H/.config/omarchy/plugins/erllan.soviet-lock/Service.qml ]] && pass "apply instala o clone" || fail "apply" "rc=$rc"
check "apply liga o clone e desliga o nativo" jq -e '(.plugins | any(.[]; .id == "erllan.soviet-lock")) and (.disabledPlugins | index("omarchy.lock") != null)' "$H/.config/omarchy/shell.json"
check "uptodate confirma o estado" run "$CLONE" uptodate
sum=$(sha256sum "$H/.config/omarchy/shell.json")
run "$CLONE" apply
[[ $(sha256sum "$H/.config/omarchy/shell.json") == "$sum" ]] && pass "apply repetido não muda nada" || fail "apply não é idempotente"

section "Omarchy muda: atualiza ou volta ao nativo"
# 1) Mudança que o patch tolera: o clone é refeito com o conteúdo novo.
F="$TMP/omarchy1"; mkdir -p "$F/shell/plugins"; cp -aL "$OMARCHY_REAL/shell/plugins/lock" "$F/shell/plugins/lock"; chmod -R u+w "$F"
printf '\n// correção de segurança nova do Omarchy\n' >> "$F/shell/plugins/lock/FingerprintModel.js"
if OMARCHY_PATH="$F" run "$CLONE" uptodate; then fail "mudança no Omarchy passou despercebida"; else pass "uptodate acusa Omarchy atualizado"; fi
OMARCHY_PATH="$F" run "$CLONE" apply
grep -q 'correção de segurança nova' "$H/.config/omarchy/plugins/erllan.soviet-lock/FingerprintModel.js" \
  && pass "apply leva as mudanças do Omarchy para o clone" || fail "clone não atualizou"
# 2) Mudança incompatível com o patch: volta ao nativo, sem ficar sem bloqueio.
G="$TMP/omarchy2"; mkdir -p "$G/shell/plugins"; cp -aL "$OMARCHY_REAL/shell/plugins/lock" "$G/shell/plugins/lock"; chmod -R u+w "$G"
sed -i 's/color: Commons.Color.background/color: Commons.Color.surface/' "$G/shell/plugins/lock/Service.qml"
if OMARCHY_PATH="$G" run "$CLONE" check 2>/dev/null; then fail "patch aplicou em Omarchy incompatível"; else pass "check recusa Omarchy incompatível"; fi
OMARCHY_PATH="$G" run "$CLONE" apply 2>/dev/null; rc=$?
[[ $rc != 0 && ! -e $H/.config/omarchy/plugins/erllan.soviet-lock ]] && pass "Omarchy incompatível: clone removido" || fail "clone sobrou" "rc=$rc"
[[ $(jq -S -c . "$H/.config/omarchy/shell.json") == "$orig" ]] && pass "Omarchy incompatível: nativo de volta (shell.json original)" || fail "shell.json não voltou"

section "Remoção"
run "$CLONE" apply; run "$CLONE" remove
[[ ! -e $H/.config/omarchy/plugins/erllan.soviet-lock && $(jq -S -c . "$H/.config/omarchy/shell.json") == "$orig" ]] && pass "remove apaga o clone e restaura o shell.json" || fail "remove"
check "remove repetido não falha" run "$CLONE" remove
check "hook pós-atualização chama apply" grep -q 'soviet-lock-clone" apply' omarchy/hooks/post-update.d/terminal-soviet-lock

summary
