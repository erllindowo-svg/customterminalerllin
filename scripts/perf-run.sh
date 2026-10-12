#!/bin/bash
# Terminal Soviético — cenários de desempenho (docs/performance.md).
#
# Uso: scripts/perf-run.sh <saída-dir> [--disruptive|--only-disruptive|--only-attribution] [--seconds N]
#
# Sem --disruptive (não abre janelas nem troca de workspace):
#   P1 repouso no workspace atual (3 repetições de N s)
#   P2 atribuição do btop da central: pausado (SIGSTOP) por N s vs. normal
#   P3 atribuição do relógio (soviet-ops-clock): pausado vs. normal
#   P4 modo interativo sem janela (arttime real num pty) por N s
#   P5 troca de modos de cores: tempo de `cores` + redesenho, e de `render`
#   P6 inicialização (journal desta sessão) e P7 estabilidade
# Com --disruptive (volta ao workspace original ao final):
#   D1 central visível (workspace da central) em repouso por N s
#   D2 painel btop: tempo até a janela aparecer (3x), consumo aberto, resíduo
#   D3 modo interativo em janela real (foot + arttime) por N s
# Processos pausados com SIGSTOP sempre recebem SIGCONT (trap), mesmo com erro.
# Cada amostra usa scripts/perf-sample.sh (/proc a 1 Hz). Caminhos do $HOME
# são trocados por "~" na saída.
set -uo pipefail
ROOT=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
OUT=${1:?diretório de saída}; shift
DISRUPT=0 SECS=60 ONLY_D=0 ONLY_ATTR=0
while (( $# )); do case $1 in --disruptive) DISRUPT=1 ;; --only-disruptive) DISRUPT=1 ONLY_D=1 ;; --only-attribution) ONLY_ATTR=1 ;; --seconds) SECS=$2; shift ;; esac; shift; done
mkdir -p "$OUT"
S="$ROOT/scripts/perf-sample.sh"
ARTE="$ROOT/bin/soviet-arte"
san() { sed "s|$HOME|~|g"; }
STOPPED=()
trap 'for p in "${STOPPED[@]}"; do kill -CONT "$p" 2>/dev/null; done' EXIT INT TERM
log() { printf '[%s] %s\n' "$(date +%T)" "$*" >&2; }

ws0=$(hyprctl activeworkspace -j | jq -r .id)
# Atenção: a linha de comando do foot CONTÉM a do programa que ele executa
# ("foot … btop --config …"). Escolher pelo nome do executável (comm), senão
# pausa-se o terminal (e o Hyprland abre "Application Not Responding").
pid_by_comm() {  # pid_by_comm <comm> <regex nos argumentos>
  local p
  for p in $(pgrep -u "$USER" -x "$1"); do
    tr '\0' ' ' < "/proc/$p/cmdline" | grep -qE -- "$2" && { echo "$p"; return; }
  done
}
btop_pid=$(pid_by_comm btop 'soviet-ops\.conf')
clock_pid=$(pgrep -u "$USER" -f '^/bin/bash .*/soviet-ops-clock$' | head -1)
for p in $btop_pid $clock_pid; do
  [[ $(cat "/proc/$p/comm") != foot ]] || { echo "PID $p é um foot; abortando" >&2; exit 1; }
done
{
  echo "# Condições"
  echo "data: $(date -Is)   uptime: $(uptime -p)   workspace ativo: $ws0"
  echo "CPU: $(lscpu | sed -n 's/^Model name: *//p') ($(nproc) threads)   RAM: $(free -m | awk '/^Mem/{print $2}') MB"
  echo "monitores: $(hyprctl monitors -j | jq -r 'map("\(.name) \(.width)x\(.height)@\(.scale)") | join(", ")')"
  echo "janelas: $(hyprctl clients -j | jq -r 'group_by(.class) | map("\(.[0].class)×\(length)") | join(" ")')"
} | san > "$OUT/00-condicoes.txt"

if (( ! ONLY_D )); then
if (( ! ONLY_ATTR )); then
log "P1 repouso (3 × ${SECS}s)"
for i in 1 2 3; do "$S" "$SECS" "P1.$i repouso, workspace $ws0" | san > "$OUT/P1-repouso-$i.txt"; done
fi

if [[ -n $btop_pid ]]; then
  log "P2 btop da central pausado ${SECS}s"
  kill -STOP "$btop_pid"; STOPPED+=("$btop_pid")
  "$S" "$SECS" "P2a btop da central PAUSADO" | san > "$OUT/P2a-btop-pausado.txt"
  kill -CONT "$btop_pid"
  "$S" "$SECS" "P2b btop da central normal (logo depois)" | san > "$OUT/P2b-btop-normal.txt"
fi
if [[ -n $clock_pid ]]; then
  log "P3 relógio pausado 30s"
  kill -STOP "$clock_pid"; STOPPED+=("$clock_pid")
  "$S" 30 "P3a soviet-ops-clock PAUSADO" | san > "$OUT/P3a-relogio-pausado.txt"
  kill -CONT "$clock_pid"
  "$S" 30 "P3b soviet-ops-clock normal" | san > "$OUT/P3b-relogio-normal.txt"
fi

(( ONLY_ATTR )) && { log "concluído (só atribuição): $OUT"; exit 0; }
log "P4 arttime interativo num pty (${SECS}s)"
python3 -I - "$ARTE" "$((SECS + 8))" <<'PY' &
import os, pty, sys, time, signal, select
exe, dur = sys.argv[1], float(sys.argv[2])
pid, fd = pty.fork()
if pid == 0:
    os.environ['TERM'] = 'xterm-256color'
    os.execv(exe, [exe, 'arttime'])
import fcntl, termios, struct
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack('HHHH', 50, 140, 0, 0)); os.kill(pid, signal.SIGWINCH)
end = time.time() + dur
while time.time() < end:
    r, _, _ = select.select([fd], [], [], 0.2)
    if r:
        try: os.read(fd, 65536)
        except OSError: break
os.write(fd, b'q'); time.sleep(0.5); os.write(fd, b'y'); time.sleep(1)
try: os.kill(pid, signal.SIGHUP)
except ProcessLookupError: pass
PY
pyp=$!
sleep 4
"$S" "$SECS" "P4 arttime interativo (pty, sem janela)" 'zsh' | san > "$OUT/P4-interativo-pty.txt"
wait "$pyp" 2>/dev/null
echo "processos arttime após sair: $(pgrep -u "$USER" -fc 'arttime.zsh')" >> "$OUT/P4-interativo-pty.txt"

log "P5 troca de cores e render"
{
  echo "### P5 troca de modos de cores"
  orig=$(sed -n 's/^CORES=//p' "${XDG_STATE_HOME:-$HOME/.local/state}/terminal-soviet/arte.conf")
  fpid=$(cat "$XDG_RUNTIME_DIR/terminal-soviet/ops-fetch.pid" 2>/dev/null)
  read -r -a st < <(sed 's/^.*) //' "/proc/$fpid/stat" 2>/dev/null); f0=$(( ${st[11]:-0} + ${st[12]:-0} ))
  t0=$(date +%s%N)
  for i in $(seq 10); do "$ARTE" cores alternar >/dev/null; sleep 0.5; done
  t1=$(date +%s%N)
  read -r -a st < <(sed 's/^.*) //' "/proc/$fpid/stat" 2>/dev/null); f1=$(( ${st[11]:-0} + ${st[12]:-0} ))
  "$ARTE" cores "$orig" >/dev/null
  echo "10 trocas (cores alternar + sinal ao painel): $(( (t1 - t0) / 1000000 - 5000 )) ms no total, excluídas as pausas de 0,5 s"
  echo "CPU do painel soviet-ops-fetch (redesenhos) nas 10 trocas: $(( (f1 - f0) * 1000 / $(getconf CLK_TCK) )) ms"
  read -r cols rows < "$XDG_RUNTIME_DIR/terminal-soviet/ops-fetch.area"
  for m in tema originais; do
    "$ARTE" cores "$m" >/dev/null
    t0=$(date +%s%N); for i in 1 2 3 4 5; do "$ARTE" render --cols "$cols" --rows "$rows" >/dev/null; done; t1=$(date +%s%N)
    echo "render ${cols}x${rows} modo $m: $(( (t1 - t0) / 5000000 )) ms por desenho (média de 5)"
  done
  "$ARTE" cores "$orig" >/dev/null
  rm -f "${XDG_CACHE_HOME:-$HOME/.cache}/terminal-soviet/arte-indice.tsv"
  t0=$(date +%s%N); "$ARTE" indice >/dev/null; t1=$(date +%s%N)
  echo "índice da coleção (516 artes) reconstruído em $(( (t1 - t0) / 1000000 )) ms (só quando a coleção muda)"
} | san > "$OUT/P5-cores.txt"

log "P6/P7 inicialização e estabilidade"
{
  echo "### P6 inicialização (journal desta sessão)"
  hs=$(ps -o lstart= -p "$(pgrep -x Hyprland | head -1)")
  echo "Hyprland iniciado: $hs"
  for u in noctalia soviet-bar-sync; do
    echo "$u: ativo desde $(systemctl --user show "$u" -p ActiveEnterTimestamp --value), reinícios: $(systemctl --user show "$u" -p NRestarts --value)"
  done
  journalctl -b -t soviet-ops --no-pager -o short-iso | head -5
  journalctl --user -b -u noctalia --no-pager -o short-iso | grep -m3 -iE 'started|ready|bar' || true
  echo; echo "### P7 estabilidade"
  echo "sessão: $(uptime -p)"
  for p in Hyprland noctalia quickshell; do
    pid=$(pgrep -x "$p" | head -1); [[ -z $pid ]] && pid=$(pgrep -f "^$p" | head -1)
    [[ -n $pid ]] && echo "$p: RSS $(awk '/^VmRSS/{printf "%.0f MB", $2/1024}' /proc/$pid/status), iniciado $(ps -o etime= -p "$pid" | tr -d ' ') atrás"
  done
  echo "avisos/erros do noctalia na última hora: $(journalctl --user -u noctalia --since '-1h' --no-pager -p warning | grep -vc '^-- ')"
  echo "linhas de log do noctalia na última hora: $(journalctl --user -u noctalia --since '-1h' --no-pager | grep -vc '^-- ')"
} | san > "$OUT/P6-P7-inicio-estabilidade.txt"
fi

if (( DISRUPT )); then
  log "D1 central visível (${SECS}s)"
  hyprctl dispatch "hl.dsp.focus({ workspace = \"${HIDDEN_WS:-1}\" })" >/dev/null; sleep 1
  "$S" "$SECS" "D1 central visível em repouso" | san > "$OUT/D1-central-visivel.txt"
  hyprctl dispatch "hl.dsp.focus({ workspace = \"$ws0\" })" >/dev/null; sleep 1

  log "D2 painel btop"
  {
    echo "### D2 painel btop sob demanda"
    for i in 1 2 3; do
      t0=$(date +%s%N); soviet-inspect
      for _ in $(seq 100); do hyprctl clients -j | jq -e 'any(.[]; .class == "soviet-inspect")' >/dev/null && break; sleep 0.05; done
      t1=$(date +%s%N); echo "abertura $i: janela mapeada em $(( (t1 - t0) / 1000000 )) ms"
      sleep 1.5; soviet-inspect; sleep 1.5
    done
  } > "$OUT/D2-btop.txt"
  soviet-inspect; sleep 2
  "$S" 20 "D2 btop sob demanda ABERTO" | san >> "$OUT/D2-btop.txt"
  soviet-inspect; sleep 2
  echo "processos após fechar: foot/btop soviet-inspect = $(ps -C foot,btop -o args= | grep -c soviet-inspect)" >> "$OUT/D2-btop.txt"

  log "D3 interativo em janela"
  "$ARTE" interativo; sleep 1.5
  if [[ $(hyprctl activewindow -j | jq -r .class) == soviet-arte ]]; then
    wtype -k Return; sleep 3
    "$S" "$SECS" "D3 arttime interativo em janela (foot)" 'zsh' | san > "$OUT/D3-interativo-janela.txt"
  else
    echo "D3 não medido: a janela da ilustração não ficou em foco (nenhuma tecla enviada)" > "$OUT/D3-interativo-janela.txt"
  fi
  "$ARTE" interativo; sleep 1.5
  echo "processos após fechar: arttime=$(pgrep -u "$USER" -fc 'arttime.zsh') menu=$(pgrep -u "$USER" -fc 'soviet-arte menu')" >> "$OUT/D3-interativo-janela.txt"
  hyprctl dispatch "hl.dsp.focus({ workspace = \"$ws0\" })" >/dev/null
fi
log "concluído: $OUT"
