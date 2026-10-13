# shellcheck shell=bash
# Terminal Soviético — verificações de compatibilidade (Omarchy) e dependências.
#
# Duas camadas:
#   1. pontos de integração (detecção de recurso): se faltar algum, o instalador
#      PARA antes de modificar qualquer arquivo;
#   2. versões: comparadas à matriz verificada (docs/stack.md). Versão exata
#      verificada = ok; mesma série = aviso; série diferente = PARA, a não ser
#      com --accept-untested.

OMARCHY_PATH=${OMARCHY_PATH:-/usr/share/omarchy}

# Matriz verificada (2026-10-12). "série" = prefixo que ainda é aceito com aviso.
#            componente   versão verificada   série aceita
VERIFIED=(   "omarchy     4.0.4-1             4."
             "hyprland    0.56.2              0.56."
             "noctalia    5.0.1               5."
             "quickshell  0.3.1               0.3."
             "foot        1.28.0              1."
             "btop        1.4.7               1."
             "arttime     2.5.0               2.5." )

# Dependências: comando  pacote  obrigatória(1)/opcional(0)  função
DEPS=( "hyprctl    hyprland    1  compositor e IPC"
       "omarchy    omarchy     1  plataforma, comandos omarchy bar/plugin"
       "noctalia   noctalia    1  barra (extra/noctalia)"
       "foot       foot        1  terminal dos painéis"
       "btop       btop        1  monitoramento"
       "fastfetch  fastfetch   1  painel de sistema"
       "jq         jq          1  JSON do hyprctl"
       "socat      socat       1  eventos do socket2 do Hyprland"
       "uwsm-app   uwsm        1  lançar apps na sessão uwsm"
       "flock      util-linux  1  travas contra instâncias duplicadas"
       "setsid     util-linux  1  desacoplar janelas"
       "perl       perl        1  índice e cores da ilustração"
       "zsh        zsh         1  exigido pelo arttime"
       "git        git         1  baixar arttime fixado em commit"
       "systemctl  systemd     1  serviços do usuário"
       "pactl      libpulse    1  áudio da barra (eventos e lista de saídas)"
       "wpctl      wireplumber 1  áudio da barra (saída padrão, volume)"
       "playerctl  playerctl   0  widget do Spotify"
       "fzf        fzf         0  tecla x do arttime (escolher com fzf)"
       "logger     util-linux  0  registro no journal" )

component_version() {
  case $1 in
    omarchy)    pacman -Q omarchy 2>/dev/null | awk '{print $2}' ;;
    hyprland)   hyprland_version ;;
    noctalia)   noctalia --version 2>/dev/null | sed -n 's/^noctalia v//p' ;;
    quickshell) pacman -Q quickshell 2>/dev/null | awk '{print $2}' | sed 's/-[0-9]*$//' ;;
    foot)       pacman -Q foot 2>/dev/null | awk '{print $2}' | sed 's/-[0-9]*$//' ;;
    btop)       pacman -Q btop 2>/dev/null | awk '{print $2}' | sed 's/-[0-9]*$//' ;;
    arttime)    "$HOME/.local/bin/arttime" --version 2>/dev/null ;;
  esac
}

# Hyprland sem sessão ativa (teste isolado, TTY): usa o pacote.
hyprland_version() {
  local v
  v=$(hyprctl version -j 2>/dev/null | jq -r '.tag // empty' 2>/dev/null | sed 's/^v//')
  [[ -n $v ]] || v=$(pacman -Q hyprland 2>/dev/null | awk '{print $2}' | sed 's/-[0-9]*$//')
  printf '%s\n' "$v"
}

# check_versions <aceitar_nao_testadas:0|1> [incluir_arttime:0|1]
check_versions() {
  local accept=$1 with_art=${2:-1} line comp ver series cur bad=0
  for line in "${VERIFIED[@]}"; do
    read -r comp ver series <<< "$line"
    [[ $comp == arttime && $with_art == 0 ]] && continue
    cur=$(component_version "$comp")
    if [[ -z $cur ]]; then
      [[ $comp == arttime ]] && { warn "arttime: não instalado (o instalador baixa a versão fixada)"; continue; }
      err "$comp: não encontrado"; bad=1; continue
    fi
    if [[ $cur == "$ver" ]]; then ok "$comp $cur (verificado)"
    elif [[ $cur == "$series"* ]]; then warn "$comp $cur: mesma série de $ver, mas não verificado"
    elif (( accept )); then warn "$comp $cur: FORA da série verificada ($ver); seguindo por --accept-untested"
    else err "$comp $cur: fora da série verificada ($ver). Revise docs/stack.md ou use --accept-untested"; bad=1
    fi
  done
  return $bad
}

check_deps() {
  local line cmd pkg req what bad=0 missing=()
  for line in "${DEPS[@]}"; do
    read -r cmd pkg req what <<< "$line"
    if command -v "$cmd" >/dev/null; then
      ok "$cmd ($pkg) — $what"
    elif (( req )); then
      err "$cmd ausente — instale o pacote '$pkg' ($what)"; missing+=("$pkg"); bad=1
    else
      warn "$cmd ausente (opcional, pacote '$pkg') — $what"
    fi
  done
  (( bad )) && info "  Para instalar (como usuário, o Omarchy pede a senha): omarchy pkg add ${missing[*]}"
  return $bad
}

# Pontos de integração do Omarchy/Hyprland/Noctalia usados pelo projeto.
check_integration() {
  local bad=0 hl="$HOME/.config/hypr/hyprland.lua"
  _need() { if eval "$2"; then ok "$1"; else err "$1 — AUSENTE${3:+ ($3)}"; bad=1; fi; }
  _need "configuração Lua do Hyprland do Omarchy ($OMARCHY_PATH/default/hypr/bootstrap.lua)" \
        "[[ -f '$OMARCHY_PATH/default/hypr/bootstrap.lua' ]]"
  _need "~/.config/hypr/hyprland.lua carrega os padrões do Omarchy (require(\"default.hypr.omarchy\"))" \
        "grep -q 'require(\"default.hypr.omarchy\")' '$hl' 2>/dev/null" "módulo do projeto entra neste arquivo"
  _need "helpers o.bind / o.window / o.exec_on_start" \
        "grep -q '^function o.bind(' '$OMARCHY_PATH/default/hypr/helpers.lua' && grep -q '^function o.window(' '$OMARCHY_PATH/default/hypr/helpers.lua' && grep -q '^function o.exec_on_start(' '$OMARCHY_PATH/default/hypr/helpers.lua'"
  _need "layouts por workspace (~/.local/state/omarchy/workspace-layouts)" \
        "grep -q 'workspace-layouts' '$OMARCHY_PATH/default/hypr/workspace-layouts.lua' 2>/dev/null"
  _need "shell Omarchy com barra selecionável (bar.id + plugin kind \"bar\")" \
        "grep -q 'bar.id' '$OMARCHY_PATH/shell/README.md' 2>/dev/null && grep -q 'cmd_use()' '$OMARCHY_PATH/bin/omarchy-bar' 2>/dev/null"
  _need "~/.config/omarchy/shell.json existe (versão 1)" \
        "[[ \$(jq -r '.version // empty' '$HOME/.config/omarchy/shell.json' 2>/dev/null) == 1 ]]" \
        "rode o Omarchy uma vez para criá-lo"
  _need "Noctalia com IPC (noctalia msg) e plugins Luau" \
        "noctalia --help 2>&1 | grep -q 'msg'"
  return $bad
}
