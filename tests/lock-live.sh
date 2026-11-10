#!/bin/bash
# Testes AO VIVO do bloqueio da central: bloqueia e desbloqueia a sessão de verdade.
# Só rode numa sessão que possa ser bloqueada: digita no teclado virtual (wtype).
#
#   SOVIET_TEST_PASSWORD='...' tests/lock-live.sh     [SOVIET_TEST_CRASH=1 inclui o teste de queda do shell]
#
# A senha vem só do ambiente: nunca a escreva neste arquivo nem em commits.
set -uo pipefail
source "$(dirname "$0")/lib.sh"
cd "$ROOT"
PW=${SOVIET_TEST_PASSWORD:-}
[[ -n $PW ]] || { skip "bloqueio ao vivo" "defina SOVIET_TEST_PASSWORD"; summary; exit 0; }
[[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] || { skip "bloqueio ao vivo" "sem sessão Hyprland"; summary; exit 0; }
for dep in wtype grim magick jq; do command -v "$dep" >/dev/null || { skip "bloqueio ao vivo" "falta $dep"; summary; exit 0; }; done
TMP=$(mktemp -d)
WS_CENTRAL=$(. config/terminal-soviet.conf; echo "${HIDDEN_WORKSPACE:-1}")
WS_OUTRO=2
WS_INICIAL=$(hyprctl activeworkspace -j | jq .id)
ESTAVA_ACORDADO=$([[ -f $HOME/.local/state/omarchy/indicators/stay-awake ]] && echo 1 || echo 0)
omarchy toggle idle stay-awake >/dev/null 2>&1   # o ocioso não atropela os testes

st() { omarchy-shell lock status 2>/dev/null; }
is() { jq -e "$1" <<< "$(st)" >/dev/null 2>&1; }
ws() { hyprctl activeworkspace -j | jq .id; }
ir() { hyprctl dispatch "hl.dsp.focus({ workspace = \"$1\" })" >/dev/null; sleep 0.5; }
esperar() { local i; for (( i = 0; i < 100; i++ )); do is "$1" && return 0; sleep 0.1; done; return 1; }
travar() { omarchy-shell lock lock >/dev/null; esperar '.secure == true'; sleep 0.7; }
digitar() { wtype -- "$1"; sleep 0.15; wtype -k Return; }
soltar() { digitar "$PW"; esperar '.locked == false'; sleep 0.8; }
# Sai de qualquer estado de bloqueio, mesmo depois de uma falha no meio de um teste.
trap 'is ".locked == true" && soltar; ir "$WS_INICIAL"; (( ESTAVA_ACORDADO )) || omarchy toggle idle allow-idle >/dev/null 2>&1; rm -rf "$TMP"' EXIT
tela() { grim "$TMP/$1.png"; }
# Média e desvio padrão de um recorte em pixels físicos: "média desvio" (0 a 1).
stat() { magick "$TMP/$1.png" -crop "$2" +repage -format '%[fx:mean] %[fx:standard_deviation]' info:; }
maior() { awk -v a="$1" -v b="$2" 'BEGIN { exit !(a > b) }'; }
# Garante a tela acesa antes de capturar (o bloqueio não a apaga, mas o DPMS manual pode).
acordar() {
  local i
  wtype -k Shift_L
  for (( i = 0; i < 40; i++ )); do [[ $(hyprctl monitors -j | jq '.[0].dpmsStatus') == true ]] && break; sleep 0.1; done
  sleep 0.8
}
rmse() { magick compare -metric RMSE "$TMP/$1.png" "$TMP/$2.png" null: 2>&1 | sed 's/.*(\(.*\)).*/\1/'; }

section "Pré-condições"
check "clone responde ao alvo lock" is '.engine == "soviet-clone" and .passwordPam == true'
hyprctl getoption misc:session_lock_xray -j | jq -e '.bool == true or .int == 1' >/dev/null && pass "xray ligado no Hyprland" || fail "xray desligado"
is '.locked == false' && pass "sessão começa desbloqueada" || { fail "sessão já bloqueada"; summary; exit 1; }

section "Fluxo principal: bloqueia na central e volta"
ir "$WS_OUTRO"; tela outro
travar; rc=$?
[[ $rc == 0 ]] && pass "bloqueia (ext-session-lock seguro)" || fail "não ficou seguro" "$(st)"
omarchy-hyprland-session-locked; [[ $? == 0 ]] && pass "o compositor confirma a sessão travada" || fail "compositor não travou"
[[ $(ws) == "$WS_CENTRAL" ]] && pass "levou ao workspace da central" || fail "workspace errado" "$(ws)"
tela central
read -r _ dev <<< "$(stat central 1100x700+20+20)"
maior "$dev" 0.03 && pass "central visível através do bloqueio (texto nítido, desvio $dev)" || fail "central não visível" "desvio $dev"

section "Atalhos e senha"
wtype -M logo -k 3 -m logo; sleep 0.5
[[ $(ws) == "$WS_CENTRAL" ]] && pass "SUPER+3 não troca de workspace com a sessão travada" || fail "atalho vazou" "$(ws)"
wtype -M ctrl -k u -m ctrl
digitar "senha-errada-do-teste"; sleep 3.2
is '.locked == true and .authenticating == false' && pass "senha errada não desbloqueia" || fail "senha errada" "$(st)"
soltar; rc=$?
[[ $rc == 0 ]] && pass "senha certa desbloqueia" || fail "senha certa não desbloqueou" "$(st)"
omarchy-hyprland-session-locked; [[ $? == 1 ]] && pass "o compositor confirma a sessão livre" || fail "compositor segue travado"
[[ $(ws) == "$WS_OUTRO" ]] && pass "volta ao workspace de antes" || fail "não voltou" "$(ws)"

section "Privacidade: transparente só na central"
ir "$WS_OUTRO"; travar; tela central2
hyprctl dispatch "hl.dsp.focus({ workspace = \"$WS_OUTRO\" })" >/dev/null; sleep 1
[[ $(ws) == "$WS_OUTRO" ]] && pass "(teste) outro workspace ativo com a sessão travada" || fail "(teste) não trocou"
tela vazou
d1=$(rmse vazou outro); d2=$(rmse vazou central2)
maior "$d1" 0.05 && pass "fundo opaco: o workspace privado não aparece (RMSE $d1)" || fail "workspace privado vazou" "RMSE $d1"
maior "$d2" 0.05 && pass "fundo opaco: deixou de mostrar a central (RMSE $d2)" || fail "fundo não mudou" "RMSE $d2"
ir "$WS_CENTRAL"; sleep 0.5; tela volta
d3=$(rmse volta central2)
maior 0.08 "$d3" && pass "ao voltar à central, a transparência retorna (RMSE $d3)" || fail "transparência não voltou" "RMSE $d3"

section "Notificações não aparecem através do bloqueio"
acordar; tela antestoast
read -r _ dev <<< "$(stat antestoast 540x220+1380+20)"
maior "$dev" 0.02 && pass "(teste) antes do toast a coluna mostra a central (desvio $dev)" || fail "(teste) coluna sem conteúdo" "desvio $dev"
notify-send -t 2500 -a soviet-teste "Código de verificação" "SEGREDO 123456"; sleep 0.7; tela toast
read -r _ dev <<< "$(stat toast 540x220+1380+20)"
maior 0.02 "$dev" && pass "toast coberto (coluna uniforme, desvio $dev)" || fail "toast visível" "desvio $dev"
for (( i = 0; i < 80; i++ )); do [[ $(omarchy-shell notifications count) == 0 ]] && break; sleep 0.25; done
[[ $(omarchy-shell notifications count) == 0 ]] && pass "(teste) o toast expirou" || skip "toast" "continua aberto"
acordar; sleep 0.3; tela semtoast
read -r _ dev <<< "$(stat semtoast 540x220+1380+20)"
maior "$dev" 0.02 && pass "sem toast, a cobertura some (desvio $dev)" || fail "cobertura presa" "desvio $dev"
soltar || fail "desbloqueio após notificações"

section "Workspace especial"
hyprctl dispatch 'hl.dsp.workspace.toggle_special("scratchpad")' >/dev/null; sleep 0.5
[[ $(hyprctl monitors -j | jq -r '.[0].specialWorkspace.name') == special:scratchpad ]] && pass "(teste) scratchpad aberto" || skip "scratchpad" "não abriu"
travar
[[ -z $(hyprctl monitors -j | jq -r '.[0].specialWorkspace.name') ]] && pass "bloqueio fecha o workspace especial" || fail "especial segue aberto"
soltar || fail "desbloqueio após especial"

section "Caminhos do Omarchy"
omarchy-system-lock; esperar '.secure == true'; rc=$?
[[ $rc == 0 ]] && pass "omarchy-system-lock (atalho, menu e ocioso) bloqueia" || fail "omarchy-system-lock" "$(st)"
soltar || fail "desbloqueio após system-lock"
omarchy-system-sleep-lock 6000; rc=$?
[[ $rc == 0 ]] && is '.secure == true' && pass "omarchy-system-sleep-lock confirma seguro antes de suspender" || fail "sleep-lock" "rc=$rc $(st)"
sleep 6.5
[[ $(hyprctl monitors -j | jq '.[0].dpmsStatus') == true ]] && pass "a tela segue acesa no pedido de senha" || fail "tela apagou"
soltar; rc=$?
[[ $rc == 0 && $(hyprctl monitors -j | jq '.[0].dpmsStatus') == true ]] && pass "digitar a senha desbloqueia com a tela acesa" || fail "desbloquear" "rc=$rc"

section "Painel de terminal ausente: retângulo centralizado, sem mexer em janelas"
P=$(hyprctl clients -j | jq -r '[.[] | select(.class == "soviet-ops-shell")][0].pid')
A=$(hyprctl clients -j | jq -r '[.[] | select(.class == "soviet-ops-shell")][0].address')
SHPID=$(pgrep -P "$P" | head -1)
if [[ -n $(pgrep -P "${SHPID:-0}") ]]; then
  skip "painel ausente" "o terminal da central está em uso"
else
  hyprctl dispatch "hl.dsp.window.close({ window = \"address:$A\" })" >/dev/null; sleep 1
  travar; tela sempainel
  [[ -z $(hyprctl clients -j | jq -r '.[] | select(.class == "soviet-ops-shell") | .address') ]] \
    && pass "bloqueio não recompõe janelas com a sessão travada" || fail "abriu janela durante o bloqueio"
  soltar || fail "desbloqueio após painel"
  "$HOME/.local/bin/soviet-ops" >/dev/null 2>&1; sleep 1
  [[ -n $(hyprctl clients -j | jq -r '.[] | select(.class == "soviet-ops-shell") | .address') ]] \
    && pass "depois de desbloquear, a central repõe o painel" || fail "painel não voltou"
fi

if [[ ${SOVIET_TEST_CRASH:-} == 1 ]]; then
  section "Queda do shell com a sessão travada"
  travar
  pkill -9 -x quickshell; sleep 1.5
  omarchy-hyprland-session-locked; [[ $? == 0 ]] && pass "shell caiu: a sessão SEGUE travada" || fail "shell caiu e a sessão soltou"
  tela queda
  timeout 30 omarchy restart shell >/dev/null 2>&1
  esperar '.secure == true'; rc=$?
  [[ $rc == 0 ]] && is '.engine == "soviet-clone"' && pass "shell reiniciado retoma o bloqueio (clone)" || fail "não retomou" "$(st)"
  sleep 1; soltar; rc=$?
  [[ $rc == 0 ]] && pass "desbloqueia depois da retomada" || fail "não desbloqueou após a queda" "$(st)"
fi

summary
