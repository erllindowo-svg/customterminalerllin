#!/bin/bash
# Testes do bloqueio no terminal (bin/soviet-lock, prompt.py, plugin erllan.soviet-lock).
# Não alteram o sistema: PAM com serviços de teste (pam_start_confdir), e o
# supervisor roda com hyprctl/foot simulados num diretório temporário.
# O que NÃO cobrem (só ao vivo, em outra máquina): submap e stay_focused de verdade,
# posicionamento sobre o painel, e o IPC `lock` com o shell do Omarchy.
set -uo pipefail
source "$(dirname "$0")/lib.sh"
cd "$ROOT"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
export PYTHONDONTWRITEBYTECODE=1

section "Plugin e arquivos"
check "plugin erllan.soviet-lock valida (omarchy plugin validate)" omarchy plugin validate omarchy/plugins/erllan.soviet-lock
check "manifesto declara clonedFrom=omarchy.lock" bash -c "jq -e '.omarchy.clonedFrom == \"omarchy.lock\" and .id == \"erllan.soviet-lock\"' omarchy/plugins/erllan.soviet-lock/manifest.json"
check "plugin atende lock/isLocked/status (contrato do omarchy-system-sleep-lock)" \
  bash -c 'for f in lock isLocked status; do grep -q "function $f()" omarchy/plugins/erllan.soviet-lock/Service.qml || exit 1; done'
check "bin/soviet-lock é executável" test -x bin/soviet-lock

section "PAM (serviços de teste)"
mkdir -p "$TMP/ok" "$TMP/no"
printf 'auth required pam_permit.so\naccount required pam_permit.so\n' > "$TMP/ok/t"
printf 'auth required pam_deny.so\naccount required pam_permit.so\n'  > "$TMP/no/t"
cat > "$TMP/pamcheck.py" <<'PY'
import importlib.util, sys
sys.dont_write_bytecode = True
s = importlib.util.spec_from_file_location("p", sys.argv[1]); m = importlib.util.module_from_spec(s); s.loader.exec_module(m)
sys.exit(0 if m.pam_check("tester", "x", sys.argv[3], sys.argv[2]) else 1)
PY
pamcheck() { python3 -I "$TMP/pamcheck.py" share/terminal-soviet/lock/prompt.py "$1" "$2"; }
check "PAM aceita com pam_permit" pamcheck "$TMP/ok" t
if pamcheck "$TMP/no" t; then fail "PAM rejeita com pam_deny"; else pass "PAM rejeita com pam_deny"; fi
if pamcheck "$TMP/no" nao-existe; then fail "serviço PAM inexistente rejeita (não libera)"; else pass "serviço PAM inexistente rejeita (não libera)"; fi

section "Pedido de senha (pty)"
rm -f "$TMP/tok"
python3 -I tests/pty_lock.py "$TMP/tok" "$TMP/no" errada errada > "$TMP/no.out" 2>&1; rc=$?
[[ $rc == 99 && ! -e $TMP/tok ]] && pass "senha errada: segue pedindo e não cria o testemunho" || fail "senha errada" "rc=$rc"
grep -q 'Desculpe, tente novamente' "$TMP/no.out" && pass "mostra a mensagem do sudo após erro" || fail "mensagem de erro ausente"
grep -q '\[sudo\] senha de ' "$TMP/no.out" && pass "pedido no formato [sudo] senha de <usuário>:" || fail "formato do pedido"
! grep -q 'errada' "$TMP/no.out" && pass "a senha digitada não aparece na tela (sem eco)" || fail "senha ecoada na tela"
python3 -I tests/pty_lock.py "$TMP/tok" "$TMP/ok" certa > "$TMP/ok.out" 2>&1; rc=$?
[[ $rc == 0 && -e $TMP/tok ]] && pass "senha aceita: cria o testemunho (modo $(stat -c %a "$TMP/tok" 2>/dev/null)) e sai com 0" || fail "senha aceita" "rc=$rc"
[[ $(stat -c %a "$TMP/tok" 2>/dev/null) == 600 ]] && pass "testemunho com modo 600" || fail "modo do testemunho"

section "Supervisor (hyprctl e foot simulados)"
FAKE="$TMP/fake"; mkdir -p "$FAKE/bin" "$FAKE/rt"
cat > "$FAKE/bin/hyprctl" <<'STUB'
#!/bin/bash
# Simulador mínimo: registra os dispatches e responde aos JSON usados pelo soviet-lock.
F=$FAKE_DIR
case $1 in
  dispatch) printf '%s\n' "$2" >> "$F/dispatch.log" ;;
  activeworkspace) echo '{"id": 3}' ;;
  activewindow) echo '{"address": "0xprev"}' ;;
  clients)
    jq -n --argjson lock "$([[ -e $F/foot_up ]] && echo true || echo false)" '
      [{"class":"soviet-ops-shell","address":"0xshell","at":[0,590],"size":[890,220]},
       {"class":"soviet-ops-btop","address":"0xbtop","at":[0,27],"size":[890,563]},
       {"class":"outro","address":"0xprev","at":[0,0],"size":[10,10]}]
      + (if $lock then [{"class":"soviet-lock","address":"0xlock","at":[0,27],"size":[1440,783]}] else [] end)' ;;
esac
STUB
cat > "$FAKE/bin/foot" <<'STUB'
#!/bin/bash
# Simula o foot: abre a "janela", executa o comando do prompt e a fecha ao terminar.
F=$FAKE_DIR
n=$(( $(cat "$F/foot_runs" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$F/foot_runs"
[[ -e $F/foot_quebrado ]] && exit 1
touch "$F/foot_up"
while [[ $1 != python3 && $# -gt 0 ]]; do shift; done
"$@"; rc=$?
rm -f "$F/foot_up"; exit $rc
STUB
cat > "$FAKE/prompt" <<'STUB'
#!/usr/bin/env python3
# Falso prompt.py: na 1ª execução "morre" sem senha; na 2ª, a senha é aceita.
import os, sys, time
f = os.environ["FAKE_DIR"] + "/prompt_runs"
n = int(open(f).read()) + 1 if os.path.exists(f) else 1
open(f, "w").write(str(n))
time.sleep(0.6)
if n >= int(os.environ.get("FAKE_ACEITA_NA", "2")):
    open(os.environ["SOVIET_LOCK_TOKEN"], "w").close()
STUB
cat > "$FAKE/bin/notify-send" <<'STUB'
#!/bin/bash
echo "$*" >> "$FAKE_DIR/notify.log"
STUB
chmod +x "$FAKE"/bin/* "$FAKE/prompt"
run_lock() {  # run_lock <args...> — com o ambiente simulado
  env FAKE_DIR="$FAKE" PATH="$FAKE/bin:$PATH" XDG_RUNTIME_DIR="$FAKE/rt" HOME="$TMP/home" \
      TS_CONF=/dev/null SOVIET_LOCK_PROMPT="$FAKE/prompt" "$@"
}
mkdir -p "$TMP/home"

[[ $(run_lock bin/soviet-lock status) == '{"locked":false,"requested":false,"secure":false,"engine":"soviet-lock"}' ]] \
  && pass "status em repouso: locked=false" || fail "status em repouso"

# 1) o pedido "morre" uma vez sem senha: o supervisor reabre; na 2ª a senha é aceita.
rm -f "$FAKE"/dispatch.log "$FAKE"/foot_runs "$FAKE"/prompt_runs
run_lock bin/soviet-lock lock; rc=$?
[[ $rc == 0 ]] && pass "lock devolve 0 quando fica seguro" || fail "lock não ficou seguro" "rc=$rc"
st=$(run_lock bin/soviet-lock status)
jq -e '.locked == true and .secure == true' <<< "$st" >/dev/null && pass "status durante o bloqueio: locked e secure" || fail "status durante o bloqueio" "$st"
run_lock bin/soviet-lock lock; [[ $? == 0 && $(cat "$FAKE/prompt_runs") -le 2 ]] && pass "lock repetido é idempotente (não abre outro pedido)" || fail "lock repetido"
for i in $(seq 1 60); do [[ $(run_lock bin/soviet-lock status) == *'"locked":false'* ]] && break; sleep 0.2; done
[[ $(run_lock bin/soviet-lock status) == *'"locked":false'* ]] && pass "desbloqueia depois que o PAM aceita" || fail "não desbloqueou"
[[ $(cat "$FAKE/foot_runs") == 2 ]] && pass "o pedido que morreu sem senha foi reaberto (2 execuções)" || fail "reabertura do pedido" "execuções: $(cat "$FAKE/foot_runs")"
log="$FAKE/dispatch.log"
grep -q 'focus({ workspace = "1" })' "$log" && pass "vai para o workspace da central" || fail "não foi ao workspace da central"
grep -q 'submap("soviet_lock")' "$log" && pass "entra no submap soviet_lock (sem atalhos)" || fail "não entrou no submap"
[[ $(grep -n 'submap("soviet_lock")' "$log" | head -1 | cut -d: -f1) -gt $(grep -n 'float' "$log" | head -1 | cut -d: -f1) ]] \
  && pass "o submap só entra depois do pedido de senha estar posicionado" || fail "ordem: submap antes do pedido"
grep -q 'submap("reset")' "$log" && pass "sai do submap ao desbloquear" || fail "não saiu do submap"
grep -q 'focus({ workspace = "3" })' "$log" && pass "volta ao workspace anterior" || fail "não voltou ao workspace anterior"
grep -q 'focus({ window = "address:0xprev" })' "$log" && pass "devolve o foco à janela anterior" || fail "foco anterior não restaurado"
grep -q 'fullscreen' "$log" && pass "posicionamento que não confere cai para tela cheia" || fail "sem fallback de tela cheia"
[[ ! -e $FAKE/rt/soviet-lock/estado && ! -e $FAKE/rt/soviet-lock/liberado ]] && pass "estado e testemunho removidos" || fail "estado/testemunho sobraram"

# 2) o foot nunca abre: aborta sem prender a sessão num submap.
rm -f "$FAKE"/dispatch.log "$FAKE"/foot_runs "$FAKE"/prompt_runs "$FAKE"/notify.log; touch "$FAKE/foot_quebrado"
run_lock bin/soviet-lock lock; rc=$?
[[ $rc != 0 ]] && pass "foot quebrado: lock falha (o chamador é avisado)" || fail "lock não falhou com foot quebrado"
! grep -q 'submap("soviet_lock")' "$FAKE/dispatch.log" 2>/dev/null && pass "foot quebrado: nunca entra no submap (sem sessão presa)" || fail "entrou no submap sem terminal"
for i in $(seq 1 30); do [[ -s $FAKE/notify.log ]] && break; sleep 0.2; done
[[ -s $FAKE/notify.log ]] && pass "foot quebrado: avisa por notificação" || fail "sem notificação de falha"
rm -f "$FAKE/foot_quebrado"

summary
