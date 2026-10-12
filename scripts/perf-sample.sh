#!/bin/bash
# Terminal Soviético — amostragem de CPU e memória dos processos do desktop.
#
# Uso: scripts/perf-sample.sh <segundos> [rótulo] [regex extra]
#
# Lê /proc a cada 1 s (utime+stime de /proc/<pid>/stat e VmRSS de
# /proc/<pid>/status). Para cada processo relevante imprime:
#   CPU% média, CPU% pico (pior intervalo de 1 s), RSS médio e máximo (MB).
# CPU% é relativo a UM núcleo (100 % = um núcleo inteiro), como no top.
# Também: CPU total do sistema (todos os núcleos, /proc/stat), processos
# criados por segundo (contador "processes" de /proc/stat) e memória usada.
# Processos que nascem durante a janela entram a partir do 1º segundo visto.
# O próprio amostrador cria ~2 processos/s (pgrep e sleep) e é excluído da lista.
set -uo pipefail
DUR=${1:?segundos}; LABEL=${2:-amostra}; EXTRA=${3:-}
PAT='Hyprland|quickshell|noctalia|soviet-|btop|foot|socat|arttime|zsh .*arttime'
[[ -n $EXTRA ]] && PAT="$PAT|$EXTRA"
HZ=$(getconf CLK_TCK)
declare -A prev name sum peak rss_sum rss_max n

cpu_now() { local a; read -r -a a < /proc/stat; echo $(( a[1]+a[2]+a[3]+a[4]+a[5]+a[6]+a[7]+a[8] )) $(( a[4]+a[5] )); }
forks_now() { awk '/^processes/ {print $2}' /proc/stat; }

sample() {
  local p s t r
  for p in $(pgrep -u "$USER" -f -- "$PAT"); do
    [[ $p == "$$" ]] && continue
    [[ -r /proc/$p/stat ]] || continue
    local line; line=$(< "/proc/$p/stat") 2>/dev/null || continue
    read -r -a s <<< "${line##*) }"          # campos após o nome (que pode ter espaços)
    t=$(( s[11] + s[12] ))                   # utime + stime
    r=""
    while read -r k v _; do [[ $k == VmRSS: ]] && { r=$v; break; }; done < "/proc/$p/status" 2>/dev/null
    [[ -n $r ]] || continue
    if [[ -n ${prev[$p]:-} ]]; then
      local d=$(( t - prev[$p] ))
      sum[$p]=$(( ${sum[$p]:-0} + d )); (( d > ${peak[$p]:-0} )) && peak[$p]=$d
      rss_sum[$p]=$(( ${rss_sum[$p]:-0} + r )); (( r > ${rss_max[$p]:-0} )) && rss_max[$p]=$r
      n[$p]=$(( ${n[$p]:-0} + 1 ))
    else
      peak[$p]=0 sum[$p]=0 rss_sum[$p]=0 rss_max[$p]=0 n[$p]=0
      name[$p]=$(tr '\0' ' ' < "/proc/$p/cmdline" | cut -c1-70 | sed 's/ *$//')
    fi
    prev[$p]=$t
  done
}

read -r tot0 idle0 < <(cpu_now); f0=$(forks_now)
sample
for (( i = 0; i < DUR; i++ )); do sleep 1; sample; done
read -r tot1 idle1 < <(cpu_now); f1=$(forks_now)

printf '### %s — %s s — %s\n' "$LABEL" "$DUR" "$(date -Is)"
printf '%-8s %8s %8s %9s %9s  %s\n' PID 'CPU%med' 'CPU%pico' 'RSSmed' 'RSSmax' COMANDO
for p in "${!n[@]}"; do
  (( n[$p] > 0 )) || continue
  awk -v s="${sum[$p]}" -v pk="${peak[$p]}" -v k="${n[$p]}" -v hz="$HZ" -v rs="${rss_sum[$p]}" -v rm="${rss_max[$p]}" \
      -v pid="$p" -v nm="${name[$p]}" \
      'BEGIN { printf "%-8s %8.2f %8.1f %9.1f %9.1f  %s\n", pid, 100*s/hz/k, 100*pk/hz, rs/k/1024, rm/1024, nm }'
done | sort -k2 -nr
awk -v t=$(( tot1 - tot0 )) -v i=$(( idle1 - idle0 )) -v f=$(( f1 - f0 )) -v d="$DUR" \
  'BEGIN { printf "CPU total do sistema (todos os núcleos): %.2f%%   processos criados: %.1f/s\n", 100*(t-i)/t, f/d }'
free -m | awk '/^Mem/ { printf "Memória: usada %d MB, disponível %d MB (total %d MB)\n", $3, $7, $2 }'
