#!/bin/bash
# Testes AO VIVO na sessão Hyprland atual (componentes já instalados).
#
#   tests/live.sh                 só observa e testa a ilustração em pty;
#                                 estado da ilustração é salvo e restaurado
#   tests/live.sh --disruptive    também abre/fecha janelas (btop, ilustração)
#                                 e troca de workspace por instantes, voltando
#                                 ao workspace original. Não envia teclas a
#                                 outras janelas.
#
# A ilustração é testada com o soviet-arte DO REPOSITÓRIO (roda do checkout).
set -uo pipefail
source "$(dirname "$0")/lib.sh"
DISRUPT=0; [[ ${1:-} == --disruptive ]] && DISRUPT=1
[[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && hyprctl version >/dev/null 2>&1 || { echo "sem sessão Hyprland"; exit 2; }
source "$ROOT/lib/ts-lib.sh"; load_conf "$ROOT/config/terminal-soviet.conf"
ARTE="$ROOT/bin/soviet-arte"
ST="${XDG_STATE_HOME:-$HOME/.local/state}/terminal-soviet"
SAVE=$(mktemp -d); trap 'rm -rf "$SAVE"' EXIT
cp -a "$ST/arte.conf" "$ST/arte-selecao" "$SAVE/" 2>/dev/null
restore_arte() { cp -a "$SAVE/arte.conf" "$SAVE/arte-selecao" "$ST/" 2>/dev/null; "$ARTE" cores "$(sed -n 's/^CORES=//p' "$ST/arte.conf")" >/dev/null 2>&1; }

mask_of() { local m=0 p; for p in ${1//+/ }; do case $p in SUPER) ((m|=64));; SHIFT) ((m|=1));; CTRL) ((m|=4));; ALT) ((m|=8));; esac; done; echo $m; }
key_of() { echo "${1##*+ }"; }

section "Hyprland"
[[ -z $(hyprctl configerrors | sed '/^$/d') ]] && pass "hyprctl configerrors vazio" || fail "erros de configuração do Hyprland"
for k in KEY_INSPECT KEY_OPS KEY_ARTE KEY_PIN; do
  d=$(hyprctl binds -j | jq -r --argjson m "$(mask_of "${!k}")" --arg key "$(key_of "${!k}")" \
      '[.[] | select(.modmask == $m and .key == $key)] | map(.description) | join("|")')
  [[ $d == Soviet* && $d != *"|"* ]] && pass "$k (${!k}) ligado uma vez: $d" || fail "$k (${!k})" "binds: '$d'"
done

section "Processos permanentes (sem duplicatas)"
for u in noctalia.service soviet-bar-sync.service; do
  check "$u ativo" systemctl --user is-active --quiet "$u"
done
n=$(pgrep -xc noctalia); [[ $n == 1 ]] && pass "1 processo noctalia" || fail "processos noctalia" "$n"
n=$(pgrep -u "$USER" -fc '^/bin/bash .*/soviet-bar-sync$'); [[ $n == 1 ]] && pass "1 soviet-bar-sync" || fail "soviet-bar-sync" "$n"
npid=$(pgrep -x noctalia)
n=$(pgrep -P "$npid" -x socat | wc -l); [[ $n == 1 ]] && pass "1 socat do plugin tarefas (service fonte, filho do noctalia)" || fail "socat do noctalia" "$n"
for c in btop fetch clock shell; do
  n=$(hyprctl clients -j | jq --arg c "soviet-ops-$c" --argjson ws "$HIDDEN_WORKSPACE" '[.[] | select(.class == $c and .workspace.id == $ws)] | length')
  [[ $n == 1 ]] && pass "painel soviet-ops-$c: 1 janela no WS $HIDDEN_WORKSPACE" || fail "painel soviet-ops-$c" "$n"
done
n=$(pgrep -u "$USER" -f 'arttime.zsh' | wc -l); [[ $n == 0 ]] && pass "nenhum arttime órfão" || fail "arttime órfão" "$n"

section "Barra"
bar_ok() {  # estado da barra coerente com a regra para o workspace ativo
  local st want vis
  st=$(soviet-bar-sync --status)
  want=$(sed -n 's/.*desejado=\([a-z]*\).*/\1/p' <<< "$st")
  vis=$(sed -n 's/.*"barVisible":\([a-z]*\).*/\1/p' <<< "$st")
  [[ ($want == hide && $vis == false) || ($want == show && $vis == true) ]]
}
ws0=$(hyprctl activeworkspace -j | jq -r .id)
bar_ok && pass "barra coerente com o workspace ativo ($ws0)" || fail "barra incoerente" "$(soviet-bar-sync --status)"
if (( DISRUPT )); then
  free=$(hyprctl workspaces -j | jq '[.[].id] as $u | [range(9; 1; -1)] | map(select(. as $i | $u | index($i) | not)) | .[0] // empty')
  for w in "$HIDDEN_WORKSPACE" ${free:+$free}; do
    hyprctl dispatch "hl.dsp.focus({ workspace = \"$w\" })" >/dev/null; sleep 0.8
    bar_ok && pass "barra correta no workspace $w ($(soviet-bar-sync --status | sed -n 's/.*desejado=\([a-z]*\).*/\1/p'))" || fail "barra no workspace $w"
  done
  hyprctl dispatch "hl.dsp.focus({ workspace = \"$ws0\" })" >/dev/null; sleep 0.5
  [[ $(hyprctl activeworkspace -j | jq -r .id) == "$ws0" ]] && pass "voltou ao workspace $ws0" || fail "workspace não restaurado"
else
  skip "barra em cada workspace" "requer --disruptive (troca de workspace)"
fi

section "Ilustração: modos de cores (soviet-arte do repositório)"
green_only() { grep -o $'\e\[[0-9;]*m' | perl -ne 'chomp; s/^\e\[//; s/m$//; my @p=split/;/; while(@p){my $x=shift @p; if(($x==38||$x==48)&&@p&&$p[0]==2){shift @p; my($r,$g,$b)=splice @p,0,3; $bad++ unless $g>=$r&&$g>=$b} elsif(($x==38||$x==48)&&@p&&$p[0]==5){splice @p,0,2; $bad++} elsif(($x>=30&&$x<=37)||($x>=90&&$x<=97)||($x>=40&&$x<=47)){$bad++}} END{exit($bad?1:0)}'; }
for a in butterfly butterfly2 buddha5; do
  "$ARTE" cores originais >/dev/null
  orig=$("$ARTE" desenhar "$a" --cols 200 --rows 80)
  t=$(head -n1 "$HOME/.local/share/arttime/textart/$a"); [[ $t == '"Custom message for art goes here"' ]] && t=-
  ref=$("$HOME/.local/bin/artprint" -a "$a" -t "$t" --width 200 --height 80; printf '\e[0m')
  [[ $orig == "$ref" ]] && pass "$a: Cores originais = artprint nativo (byte a byte)" || fail "$a: originais difere do artprint"
  "$ARTE" cores tema >/dev/null
  tema=$("$ARTE" desenhar "$a" --cols 200 --rows 80)
  green_only <<< "$tema" && pass "$a: Tema do terminal só com tons fósforo" || fail "$a: cor fora da paleta no tema"
  [[ $(sed 's/\x1b\[[0-9;]*m//g' <<< "$tema") == "$(sed 's/\x1b\[[0-9;]*m//g' <<< "$ref")" ]] \
    && pass "$a: tema preserva texto e alinhamento" || fail "$a: tema alterou o texto"
done
"$ARTE" cores originais >/dev/null
[[ $(env -i HOME="$HOME" PATH="$PATH" "$ARTE" atual | sed -n 's/^cores: *//p') == "Cores originais" ]] \
  && pass "modo de cores persiste para novos processos" || fail "persistência do modo de cores"
out=$(python3 -I "$ROOT/tests/pty_menu.py" "$ARTE" cores); rc=$?
grep -q '● Cores originais' <<< "$out" && [[ $(sed -n 's/^CORES=//p' "$ST/arte.conf") == tema ]] && (( rc == 0 )) \
  && pass "menu 'Cores da ilustração' alterna e grava (originais → tema)" || fail "menu de cores" "rc=$rc"
restore_arte

section "Ilustração: modo interativo (arttime original em pty)"
before=$("$ARTE" atual | sed -n 's/^arte: *\([^ ]*\).*/\1/p')
python3 -I "$ROOT/tests/pty_menu.py" "$ARTE" hup >/dev/null; rc=$?
sleep 1
after=$("$ARTE" atual | sed -n 's/^arte: *\([^ ]*\).*/\1/p')
(( rc == 0 )) && pass "menu termina ao fechar o terminal com o arttime aberto (SIGHUP)" || fail "menu não terminou"
last=$(awk 'NR == 1 || $1 - prev > 0.3 { first = $2 } { prev = $1 } END { print first }' "$XDG_RUNTIME_DIR/terminal-soviet/arttime-artes.log")
[[ -n $last && $after == "$last" ]] && pass "seleção do arttime sincronizada ($before → $after)" || fail "sincronização" "antes=$before depois=$after log=$last"
n=$(pgrep -u "$USER" -f 'arttime.zsh|soviet-arte menu' | wc -l)
[[ $n == 0 ]] && pass "sem processos órfãos após fechar" || fail "processos órfãos" "$n"
restore_arte

section "Painéis sob demanda (janelas reais)"
if (( DISRUPT )); then
  count() { hyprctl clients -j | jq --arg c "$1" '[.[] | select(.class == $c)] | length'; }
  procs() { ps -C "$1" -o args= | grep -c -- "$2"; }   # só o executável pedido (o foot repete a linha do btop)
  soviet-inspect; for _ in {1..40}; do [[ $(count soviet-inspect) == 1 ]] && break; sleep 0.1; done
  soviet-inspect & soviet-inspect & wait   # acionamentos repetidos durante a abertura
  sleep 0.5
  [[ $(count soviet-inspect) == 1 && $(procs btop 'soviet-inspect') == 1 ]] \
    && pass "btop: abre 1 janela e 1 processo (acionamentos repetidos não duplicam)" || fail "btop duplicado" "$(count soviet-inspect)"
  [[ $(hyprctl clients -j | jq '[.[] | select(.class == "soviet-inspect")][0].floating') == true ]] && pass "btop flutuante" || fail "btop não flutua"
  sleep 1; soviet-inspect; sleep 1
  [[ $(count soviet-inspect) == 0 && $(procs foot,btop 'soviet-inspect') == 0 ]] && pass "btop fecha sem processos órfãos" || fail "btop não fechou"
  ws=$(hyprctl activeworkspace -j | jq -r .id)
  "$ARTE" interativo; for _ in {1..40}; do [[ $(count soviet-arte) == 1 ]] && break; sleep 0.1; done
  [[ $(count soviet-arte) == 1 && $(hyprctl activeworkspace -j | jq -r .id) == "$ws" ]] \
    && pass "ilustração abre no workspace atual" || fail "ilustração não abriu"
  sleep 1; "$ARTE" interativo; sleep 1
  [[ $(count soviet-arte) == 0 && $(pgrep -u "$USER" -fc 'soviet-arte menu') == 0 ]] && pass "ilustração fecha sem órfãos" || fail "ilustração não fechou"
  for c in btop fetch clock shell; do [[ $(count "soviet-ops-$c") == 1 ]] || fail "central perdeu soviet-ops-$c"; done
  pass "central intacta após abrir/fechar os painéis"
else
  skip "btop e ilustração em janela" "requer --disruptive (abre janelas)"
fi

summary
