# shellcheck shell=bash
# Terminal Soviético — funções comuns do instalador (carregado por install.sh).
#
# Responsável por: mensagens, leitura/validação de config/terminal-soviet.conf,
# cálculo dos marcadores @TOKEN@, renderização dos modelos *.in e a tabela de
# destinos (o que vai para onde em $HOME).

TS_RED=$'\e[31m' TS_YEL=$'\e[33m' TS_GRN=$'\e[32m' TS_DIM=$'\e[2m' TS_RST=$'\e[0m'
[[ -t 1 ]] || { TS_RED="" TS_YEL="" TS_GRN="" TS_DIM="" TS_RST=""; }

info() { printf '%s\n' "$*"; }
ok()   { printf '%s✓%s %s\n' "$TS_GRN" "$TS_RST" "$*"; }
warn() { printf '%s!%s %s\n' "$TS_YEL" "$TS_RST" "$*" >&2; }
err()  { printf '%s✗%s %s\n' "$TS_RED" "$TS_RST" "$*" >&2; }
die()  { err "$*"; exit 1; }

# ------------------------------------------------------------------ configuração
CONF_KEYS=(HIDDEN_WORKSPACE COLLAPSE_CLASSES BAR_NAME WEATHER_ADDRESS KEY_INSPECT KEY_OPS
           KEY_ARTE FAVORITES GAME_DESKTOP)

# Lê VAR="valor" sem executar o arquivo (só chaves conhecidas).
load_conf() {
  local file=$1 line k v
  [[ -r $file ]] || die "configuração não encontrada: $file"
  while IFS= read -r line || [[ -n $line ]]; do
    [[ $line =~ ^[[:space:]]*(#|$) ]] && continue
    [[ $line =~ ^([A-Z_]+)=\"([^\"]*)\"[[:space:]]*(#.*)?$ ]] \
      || die "linha inválida em $file: $line  (use VAR=\"valor\")"
    k=${BASH_REMATCH[1]} v=${BASH_REMATCH[2]}
    [[ " ${CONF_KEYS[*]} " == *" $k "* ]] || die "chave desconhecida em $file: $k"
    printf -v "$k" '%s' "$v"
  done < "$file"
  local missing=()
  for k in "${CONF_KEYS[@]}"; do [[ -v $k ]] || missing+=("$k"); done
  (( ${#missing[@]} == 0 )) || die "faltam chaves em $file: ${missing[*]}"
  validate_conf
}

validate_conf() {
  [[ $HIDDEN_WORKSPACE =~ ^[1-9][0-9]?$ ]] || die "HIDDEN_WORKSPACE deve ser um número (1-99)"
  [[ $BAR_NAME =~ ^[a-z][a-z0-9_-]*$ ]] || die "BAR_NAME inválido: $BAR_NAME"
  [[ $WEATHER_ADDRESS != *\\* ]] || die "WEATHER_ADDRESS não pode conter \\"
  [[ $GAME_DESKTOP =~ ^[A-Za-z0-9._-]*$ ]] || die "GAME_DESKTOP inválido: $GAME_DESKTOP (desktop-id sem .desktop)"
  local k
  for k in KEY_INSPECT KEY_OPS KEY_ARTE; do
    [[ ${!k} =~ ^(SUPER|SHIFT|CTRL|ALT)( \+ (SUPER|SHIFT|CTRL|ALT))*( \+ [A-Z0-9]+)$ ]] \
      || die "$k inválido: '${!k}' (ex.: \"SUPER + ALT + A\")"
  done
  local f
  for f in $FAVORITES; do
    [[ $f =~ ^[A-Za-z0-9._-]+:[a-z0-9._,!-]+$ ]] || die "FAVORITES: item inválido '$f' (desktop-id:classe1,classe2)"
  done
}

# ------------------------------------------------------------------ marcadores
# Valores derivados que dependem da máquina (jogo instalado) e a grade da barra.
compute_tokens() {
  T_HOME=$HOME
  T_BIN="$HOME/.local/bin"

  # Grade da barra: uma só régua para widgets nativos e plugins (px lógicos).
  #   BAR_THICKNESS  espessura da barra (borda de 1 px incluída: sobra 24 por dentro)
  #   ITEM           altura de todo item: botões, capa, coluna ícone+traço, cápsulas
  #   ICON           ícones de app e glifos (= Style::baseGlyphSize dos nativos)
  #   GAP            espaço entre widgets e entre itens dentro de um plugin
  # Não são preferências: mudar um valor exige conferir a barra com capturas.
  T_BAR_THICKNESS=26 T_ITEM=22 T_ICON=16 T_GAP=6
  T_CAPSULE_THICKNESS=$(awk -v i="$T_ITEM" -v b="$T_BAR_THICKNESS" 'BEGIN { printf "%.3f", i / b }')

  # Seção da direita: player, fixados (erllan/tarefas:fixados) e utilidades.
  T_BAR_END='["spotify", "fixados", "tray", "notificacoes", "volume", "weather", "clock", "control-center"]'

  # Centro: ações (grupo "acoes"); o botão do jogo só entra se o .desktop existir.
  T_ACOES_MEMBERS='["inspecao", "captura", "luz_noturna", "cafeina", "energia"'
  T_GAME_NAME="" T_GAME_ICON=""
  local desk
  desk=$(desktop_file "$GAME_DESKTOP")
  if [[ -n $desk ]]; then
    T_GAME_NAME=$(sed -n 's/^Name=//p' "$desk" | head -1)
    T_GAME_ICON=$(icon_path "$(sed -n 's/^Icon=//p' "$desk" | head -1)")
    T_ACOES_MEMBERS+=', "jogo"'
  fi
  T_ACOES_MEMBERS+="]"
  T_GAME_NAME=${T_GAME_NAME:-$GAME_DESKTOP} T_GAME_NAME=${T_GAME_NAME//\"/}

  local pins="" f id classes c list l
  for f in $FAVORITES; do
    id=${f%%:*} classes=${f#*:} list=""
    IFS=, read -r -a c <<< "$classes"
    for l in "${c[@]}"; do list+="\"$l\", "; done
    pins+="  { id = \"$id\", classes = { ${list%, } } },"$'\n'
  done
  T_PINNED_LUA=${pins%$'\n'}
}

# Caminho do <id>.desktop nos diretórios XDG de aplicativos (usuário primeiro), ou nada.
desktop_file() {
  [[ -n $1 ]] || return 0
  local d
  for d in "${XDG_DATA_HOME:-$HOME/.local/share}" ${XDG_DATA_DIRS//:/ } /usr/local/share /usr/share; do
    [[ -f $d/applications/$1.desktop ]] && { echo "$d/applications/$1.desktop"; return; }
  done
}

# Arquivo de ícone para um Icon= de .desktop (caminho absoluto ou nome no tema
# hicolor/pixmaps); vazio se não achar (a barra usa o glifo).
icon_path() {
  local icon=$1 base s f
  [[ -z $icon ]] && return 0
  [[ $icon == /* ]] && { [[ -f $icon ]] && echo "$icon"; return 0; }
  for base in "${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor" /usr/share/icons/hicolor; do
    for s in scalable 48x48 64x64 32x32 128x128 256x256; do
      for f in "$base/$s/apps/$icon.svg" "$base/$s/apps/$icon.png"; do
        [[ -f $f ]] && { echo "$f"; return 0; }
      done
    done
  done
  for f in /usr/share/pixmaps/"$icon".{svg,png}; do [[ -f $f ]] && { echo "$f"; return 0; }; done
}

# render <origem> <destino>: *.in -> troca @TOKEN@; outros -> cópia exata.
render() {
  local src=$1 dst=$2
  mkdir -p "$(dirname "$dst")"
  if [[ $src == *.in ]]; then
    TS_HOME="$T_HOME" TS_BIN="$T_BIN" TS_BAR_NAME="$BAR_NAME" TS_BAR_END="$T_BAR_END" \
    TS_ACOES_MEMBERS="$T_ACOES_MEMBERS" TS_WEATHER_ADDRESS="$WEATHER_ADDRESS" \
    TS_GAME_DESKTOP="$GAME_DESKTOP" TS_GAME_NAME="$T_GAME_NAME" TS_GAME_ICON="$T_GAME_ICON" \
    TS_KEY_INSPECT="$KEY_INSPECT" TS_KEY_OPS="$KEY_OPS" TS_KEY_ARTE="$KEY_ARTE" \
    TS_HIDDEN_WORKSPACE="$HIDDEN_WORKSPACE" TS_PINNED_LUA="$T_PINNED_LUA" \
    TS_BAR_THICKNESS="$T_BAR_THICKNESS" TS_ITEM="$T_ITEM" TS_ICON="$T_ICON" TS_GAP="$T_GAP" \
    TS_CAPSULE_THICKNESS="$T_CAPSULE_THICKNESS" \
    perl -pe 's/@([A-Z_]+)@/exists $ENV{"TS_$1"} ? $ENV{"TS_$1"} : "\@$1\@"/ge' "$src" > "$dst"
    if grep -qE '@[A-Z][A-Z_]+@' "$dst"; then
      die "marcador sem valor em $src: $(grep -oE '@[A-Z][A-Z_]+@' "$dst" | sort -u | tr '\n' ' ')"
    fi
    chmod --reference="$src" "$dst"
  else
    cp -p "$src" "$dst"
  fi
}

# ------------------------------------------------------------------ destinos
# Imprime "<origem relativa ao repo>\t<destino relativo a $HOME>" para cada
# arquivo gerenciado. Modelos perdem o sufixo .in no destino.
payload_map() {
  local r=$1 f rel
  emit() { printf '%s\t%s\n' "$1" "${2%.in}"; }
  for f in "$r"/bin/soviet-*; do emit "bin/${f##*/}" ".local/bin/${f##*/}"; done
  for f in "$r"/share/terminal-soviet/arte/*; do emit "${f#"$r"/}" ".local/${f#"$r"/}"; done
  emit hypr/terminal_soviet.lua.in .config/hypr/terminal_soviet.lua
  while IFS= read -r rel; do emit "noctalia/config/$rel" ".config/noctalia/$rel"; done \
    < <(cd "$r/noctalia/config" && find . -type f | sed 's|^\./||' | sort)
  while IFS= read -r rel; do emit "noctalia/plugins/$rel" ".local/share/noctalia/plugins/$rel"; done \
    < <(cd "$r/noctalia/plugins" && find . -type f | sed 's|^\./||' | sort)
  while IFS= read -r rel; do emit "omarchy/plugins/$rel" ".config/omarchy/plugins/$rel"; done \
    < <(cd "$r/omarchy/plugins" && find . -type f | sed 's|^\./||' | sort)
  while IFS= read -r rel; do emit "omarchy/themes/$rel" ".config/omarchy/themes/$rel"; done \
    < <(cd "$r/omarchy/themes" && find . -type f | sed 's|^\./||' | sort)
  emit omarchy/workspace-layouts/central.lua.in ".local/state/omarchy/workspace-layouts/$HIDDEN_WORKSPACE.lua"
  for f in "$r"/systemd/*.service; do emit "systemd/${f##*/}" ".config/systemd/user/${f##*/}"; done
  for f in "$r"/btop/*.conf; do emit "btop/${f##*/}" ".config/btop/${f##*/}"; done
  for f in "$r"/fastfetch/*; do emit "fastfetch/${f##*/}" ".config/fastfetch/${f##*/}"; done
  emit config/terminal-soviet.conf .config/terminal-soviet/terminal-soviet.conf
}

# Links simbólicos gerenciados: "<destino relativo a $HOME>\t<alvo absoluto>".
# Ícones para as classes soviet-* (a barra procura o ícone pela classe).
# Só são criados se o ícone do sistema existir.
link_map() {
  local icons="$HOME/.local/share/icons/hicolor/scalable/apps" sys=/usr/share/icons/hicolor/scalable/apps
  local c t
  for c in soviet-ops-btop:btop soviet-inspect:btop soviet-ops-fetch:foot soviet-ops-clock:foot \
           soviet-ops-shell:foot soviet-arte:foot; do
    t="$sys/${c#*:}.svg"
    [[ -e $t ]] && printf '%s\t%s\n' "${icons#"$HOME"/}/${c%%:*}.svg" "$t"
  done
  # Equivalente a `systemctl --user enable` (WantedBy=graphical-session.target),
  # feito como link para funcionar também sem o gerenciador (testes isolados).
  for c in noctalia.service soviet-bar-sync.service; do
    printf '%s\t%s\n' ".config/systemd/user/graphical-session.target.wants/$c" "$HOME/.config/systemd/user/$c"
  done
}

sha() { sha256sum "$1" 2>/dev/null | cut -d' ' -f1; }
