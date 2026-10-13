#!/bin/bash
# Terminal Soviético — instalador (Omarchy 4).
#
# Uso:
#   ./install.sh [install] [opções]   instala ou atualiza (idempotente)
#   ./install.sh check                compatibilidade, dependências e plano (não altera nada)
#   ./install.sh status               estado dos arquivos gerenciados
#   ./install.sh uninstall [opções]   remove o que foi instalado e restaura os originais
#
# Opções:
#   --dry-run          mostra o plano e para; nada é escrito
#   --force            sobrescreve arquivos modificados localmente ou não gerenciados
#                      (sempre com backup em ~/.local/state/terminal-soviet/install/backups)
#   --accept-untested  aceita versões fora da série verificada (docs/stack.md)
#   --no-activate      não recarrega Hyprland, não inicia serviços nem roda `omarchy bar`
#                      (testes isolados com HOME de teste)
#   --no-externals     não baixa arttime/omarchy-overview (dependências fixadas em commit)
#   --purge            (uninstall) apaga também o estado da ilustração
#
# Modelo: cópias gerenciadas. Cada arquivo instalado é registrado com seu
# SHA-256 em ~/.local/state/terminal-soviet/install/manifest.tsv. Antes de
# escrever, o instalador compara destino, manifesto e nova versão:
#   ausente -> cria; igual -> nada; gerenciado e intacto -> atualiza;
#   diferente e não gerenciado/editado localmente -> CONFLITO (para tudo).
# Nada em /usr/share/omarchy é tocado; não usa sudo.
#
# O repositório pode estar em qualquer diretório: a raiz é descoberta a partir
# do caminho deste script. Convenção: ~/www/customterminalerllin.

set -euo pipefail

ROOT=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
# shellcheck source=lib/ts-lib.sh
source "$ROOT/lib/ts-lib.sh"
# shellcheck source=lib/compat.sh
source "$ROOT/lib/compat.sh"

CMD=install DRY=0 FORCE=0 ACCEPT=0 NO_ACTIVATE=0 NO_EXTERNALS=0 PURGE=0
while (( $# )); do
  case $1 in
    install|check|status|uninstall) CMD=$1 ;;
    --dry-run) DRY=1 ;;
    --force) FORCE=1 ;;
    --accept-untested) ACCEPT=1 ;;
    --no-activate) NO_ACTIVATE=1 ;;
    --no-externals) NO_EXTERNALS=1 ;;
    --purge) PURGE=1 ;;
    -h|--help) sed -n '2,/^set -euo/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 0 ;;
    *) die "opção desconhecida: $1 (veja --help)" ;;
  esac
  shift
done

[[ $EUID -ne 0 ]] || die "não rode como root: tudo é instalado no \$HOME do usuário"
# Destinos são sempre relativos a $HOME; XDG_* apontando para fora dele (por
# exemplo, HOME de teste herdando a sessão) misturaria duas instalações.
for v in XDG_CONFIG_HOME XDG_STATE_HOME XDG_CACHE_HOME XDG_DATA_HOME; do
  [[ -z ${!v:-} || ${!v} == "$HOME"/* ]] || die "$v=${!v} está fora de \$HOME=$HOME (remova com: env -u $v ...)"
done

STATE="${XDG_STATE_HOME:-$HOME/.local/state}/terminal-soviet/install"
MANIFEST="$STATE/manifest.tsv"
SHELLJSON_PREV="$STATE/shelljson.prev"
HYPR_MAIN="$HOME/.config/hypr/hyprland.lua"
BLOCK_BEGIN='-- >>> terminal-soviet (gerenciado por install.sh; não editar) >>>'
BLOCK_END='-- <<< terminal-soviet <<<'
BLOCK_BODY='require("hypr.terminal_soviet")'
BAR_ID="erllan.sem-barra"
TS=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="$STATE/backups/$TS"
STAGE=$(mktemp -d "${TMPDIR:-/tmp}/terminal-soviet-stage.XXXXXX")
trap 'rm -rf "$STAGE"' EXIT

# Dependências externas fixadas (docs/stack.md).
ARTTIME_URL="${TS_ARTTIME_URL:-https://github.com/poetaman/arttime.git}"   # TS_*: só para testes offline
ARTTIME_COMMIT="38c2955a7c16d6900cc121265595347266b18af8"
OVERVIEW_URL="${TS_OVERVIEW_URL:-https://github.com/itsmoorgrove/omarchy-overview.git}"
OVERVIEW_COMMIT="1ed4938a2382a6121255d6bfb9c3d0fdeb5ce9ff"
OVERVIEW_DIR="$HOME/.config/omarchy/plugins/moorgrove.overview"

live_session() { (( ! NO_ACTIVATE )) && [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && hyprctl version >/dev/null 2>&1; }

# ------------------------------------------------------------------ manifesto
# kind \t destino(relativo a $HOME) \t sha256 \t backup(relativo a $STATE ou -)
declare -A M_SHA=() M_BAK=() M_KIND=()   # =(): sob set -u, vazio ≠ não definido
read_manifest() {
  [[ -r $MANIFEST ]] || return 0
  local kind rel s b
  while IFS=$'\t' read -r kind rel s b; do
    [[ -z $kind || $kind == \#* ]] && continue
    M_KIND[$rel]=$kind M_SHA[$rel]=$s M_BAK[$rel]=$b
  done < "$MANIFEST"
}
write_manifest() {  # só regrava se o conteúdo mudou (reexecução não altera nada)
  mkdir -p "$STATE"
  local body rel
  body=$(for rel in "${!M_KIND[@]}"; do
           printf '%s\t%s\t%s\t%s\n' "${M_KIND[$rel]}" "$rel" "${M_SHA[$rel]}" "${M_BAK[$rel]:--}"
         done | sort -t$'\t' -k2,2)
  [[ -f $MANIFEST && $(grep -v '^#' "$MANIFEST") == "$body" ]] && return 0
  { printf '# Terminal Soviético — arquivos instalados (%s, %s)\n' "$(date -Is)" "$ROOT"
    printf '%s\n' "$body"; } > "$MANIFEST.tmp" && mv -f "$MANIFEST.tmp" "$MANIFEST"
}

save_copy() {  # save_copy <rel>: cópia de segurança que NÃO é restaurada ao desinstalar
  mkdir -p "$BACKUP_DIR/$(dirname "$1")"
  cp -a "$HOME/$1" "$BACKUP_DIR/$1"
  warn "~/$1 tinha edições locais; cópia em $BACKUP_DIR/$1"
}
backup() {  # backup <rel>: guarda o original uma única vez (o mais antigo vence)
  local rel=$1
  [[ -n ${M_BAK[$rel]:-} && ${M_BAK[$rel]} != - ]] && return 0
  mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
  cp -a "$HOME/$rel" "$BACKUP_DIR/$rel"
  M_BAK[$rel]="backups/$TS/$rel"
}

# ------------------------------------------------------------------ verificações
preflight() {
  info "== Compatibilidade (pontos de integração)"
  check_integration || die "ponto de integração ausente: nada foi alterado (veja docs/installation-omarchy.md)"
  info "== Versões"
  check_versions "$ACCEPT" || die "versão não verificada: nada foi alterado"
  info "== Dependências"
  check_deps || die "dependência obrigatória ausente: nada foi alterado"
  info "== Configuração"
  load_conf "$ROOT/config/terminal-soviet.conf"; compute_tokens
  ok "config/terminal-soviet.conf válido (workspace da central: $HIDDEN_WORKSPACE, clima: $WEATHER_ADDRESS)"
  check_legacy
  check_keys
}

# Instalação da Fase 1 com blocos do projeto escritos à mão nos arquivos do
# usuário: instalar por cima duplicaria atalhos e regras.
check_legacy() {
  local f hits=""
  for f in hyprland.lua bindings.lua autostart.lua; do
    [[ -f $HOME/.config/hypr/$f ]] || continue
    if sed "\|^$BLOCK_BEGIN\$|,\|^$BLOCK_END\$|d" "$HOME/.config/hypr/$f" \
        | grep -v '^[[:space:]]*--' | grep -qE 'soviet-(ops|inspect|arte)|soviet_bin|noctalia msg'; then
      hits+=" $f"
    fi
  done
  if [[ -n $hits ]]; then
    err "configuração do projeto escrita à mão em ~/.config/hypr/:$hits"
    info "  Isso duplicaria atalhos e regras. Migre primeiro (com backup e conferência exata):"
    info "    $ROOT/migrate/phase1-inline.sh --dry-run"
    die "nada foi alterado"
  fi
  ok "nenhuma configuração do projeto fora do módulo gerenciado"
  # Posição da barra fixada pela GUI do Noctalia (vence soviet-bar-pos).
  local conflito
  conflito=$(BAR_NAME=$BAR_NAME "$ROOT/bin/soviet-bar-pos" --status 2>/dev/null | sed -n 's/^CONFLITO: //p')
  [[ -n $conflito ]] && warn "posição da barra: $conflito — o painel de posição não terá efeito até remover essa linha"
  return 0
}

# Atalhos novos não podem tomar teclas de outros recursos.
check_keys() {
  live_session || { warn "sem sessão Hyprland ativa: conflito de atalhos não verificado"; return 0; }
  local binds k keys mask key m part desc bad=0
  binds=$(hyprctl binds -j)
  for k in KEY_INSPECT KEY_OPS KEY_ARTE; do
    keys=${!k} mask=0 key=""
    IFS='+' read -r -a parts <<< "${keys// /}"
    for part in "${parts[@]}"; do
      case $part in SUPER) m=64 ;; SHIFT) m=1 ;; CTRL) m=4 ;; ALT) m=8 ;; *) m=0; key=$part ;; esac
      (( mask |= m ))
    done
    desc=$(jq -r --argjson m "$mask" --arg k "$key" \
      '[.[] | select(.modmask == $m and (.key | ascii_upcase) == $k)][0].description // empty' <<< "$binds")
    if [[ -n $desc && $desc != Soviet* ]]; then
      err "$k ($keys) já está em uso: \"$desc\". Troque em config/terminal-soviet.conf"; bad=1
    fi
  done
  (( bad )) && die "conflito de atalhos: nada foi alterado"
  ok "atalhos livres ou já do projeto: $KEY_INSPECT · $KEY_OPS · $KEY_ARTE"
}

# ------------------------------------------------------------------ plano
PLAN=()      # "ação\tkind\tdestino\torigem"
CONFLICTS=0
plan_files() {
  local src rel stage new cur act
  declare -gA WANT=()
  while IFS=$'\t' read -r src rel; do
    stage="$STAGE/$rel"
    render "$ROOT/$src" "$stage"
    WANT[$rel]=1
    new=$(sha "$stage")
    if [[ -L $HOME/$rel ]]; then act=CONFLITO
    elif [[ ! -e $HOME/$rel ]]; then act=CRIAR
    else
      cur=$(sha "$HOME/$rel")
      if [[ $cur == "$new" ]]; then [[ -n ${M_SHA[$rel]:-} ]] && act=OK || act=ADOTAR
      elif [[ -n ${M_SHA[$rel]:-} && $cur == "${M_SHA[$rel]}" ]]; then act=ATUALIZAR
      else act=CONFLITO
      fi
    fi
    PLAN+=("$act"$'\t'file$'\t'"$rel"$'\t'"$stage")
  done < <(payload_map "$ROOT")
  # Arquivos que saíram do projeto: remove se intactos.
  for rel in "${!M_KIND[@]}"; do
    [[ ${M_KIND[$rel]} == file && -z ${WANT[$rel]:-} ]] || continue
    if [[ ! -e $HOME/$rel ]]; then PLAN+=("ESQUECER"$'\t'file$'\t'"$rel"$'\t'-)
    elif [[ $(sha "$HOME/$rel") == "${M_SHA[$rel]}" ]]; then PLAN+=("REMOVER"$'\t'file$'\t'"$rel"$'\t'-)
    else PLAN+=("MANTER"$'\t'file$'\t'"$rel"$'\t'-)
    fi
  done
}

plan_links() {
  local rel tgt act
  while IFS=$'\t' read -r rel tgt; do
    if [[ -L $HOME/$rel && $(readlink "$HOME/$rel") == "$tgt" ]]; then act=OK
    elif [[ ! -e $HOME/$rel && ! -L $HOME/$rel ]]; then act=CRIAR
    elif [[ ${M_KIND[$rel]:-} == link ]]; then act=ATUALIZAR
    else act=CONFLITO
    fi
    PLAN+=("$act"$'\t'link$'\t'"$rel"$'\t'"$tgt")
  done < <(link_map)
}

block_text() { printf '%s\n%s\n%s\n' "$BLOCK_BEGIN" "$BLOCK_BODY" "$BLOCK_END"; }
plan_block() {
  local act
  if grep -qxF -e "$BLOCK_BEGIN" "$HYPR_MAIN"; then
    if [[ $(sed -n "\|^$BLOCK_BEGIN\$|,\|^$BLOCK_END\$|p" "$HYPR_MAIN") == "$(block_text)" ]]; then act=OK; else act=ATUALIZAR; fi
  else act=ADICIONAR
  fi
  PLAN+=("$act"$'\t'block$'\t'".config/hypr/hyprland.lua"$'\t'"require(\"hypr.terminal_soviet\")")
}

plan_shelljson() {
  local id pos
  id=$(jq -r '.bar.id // "omarchy.bar"' "$HOME/.config/omarchy/shell.json")
  pos=$(jq -r '.bar.position // "top"' "$HOME/.config/omarchy/shell.json")
  if [[ $id == "$BAR_ID" && $pos == top ]]; then
    PLAN+=("OK"$'\t'shelljson$'\t'".config/omarchy/shell.json"$'\t'"bar.id=$BAR_ID, bar.position=top")
  else
    PLAN+=("ALTERAR"$'\t'shelljson$'\t'".config/omarchy/shell.json"$'\t'"bar.id $id→$BAR_ID, bar.position $pos→top (omarchy bar use/position)")
  fi
}

plan_externals() {
  (( NO_EXTERNALS )) && return 0
  if [[ -x $HOME/.local/bin/arttime && $(git -C "$HOME/.local/src/arttime" rev-parse HEAD 2>/dev/null) == "$ARTTIME_COMMIT" ]]; then
    PLAN+=("OK"$'\t'external$'\t'"arttime"$'\t'"${ARTTIME_COMMIT:0:7}")
  else
    PLAN+=("INSTALAR"$'\t'external$'\t'"arttime"$'\t'"$ARTTIME_URL @ ${ARTTIME_COMMIT:0:7} → ~/.local (install.sh --local)")
  fi
  if [[ -d $OVERVIEW_DIR ]]; then
    PLAN+=("OK"$'\t'external$'\t'"omarchy-overview"$'\t'"$(git -C "$OVERVIEW_DIR" rev-parse --short HEAD 2>/dev/null || echo 'sem git')")
  else
    PLAN+=("INSTALAR"$'\t'external$'\t'"omarchy-overview"$'\t'"$OVERVIEW_URL @ ${OVERVIEW_COMMIT:0:7}")
  fi
}

print_plan() {
  local line act kind rel extra n_ok=0
  for line in "${PLAN[@]}"; do
    IFS=$'\t' read -r act kind rel extra <<< "$line"
    case $act in
      OK) (( ++n_ok )); continue ;;
      CONFLITO) (( ++CONFLICTS )); printf '  %s%-9s%s %-9s ~/%s\n' "$TS_RED" "$act" "$TS_RST" "$kind" "$rel" ;;
      *) printf '  %-9s %-9s ~/%s%s\n' "$act" "$kind" "$rel" "$( [[ $kind =~ ^(block|shelljson|external|link)$ ]] && printf '  %s(%s)%s' "$TS_DIM" "$extra" "$TS_RST")" ;;
    esac
  done
  info "  ($n_ok itens já no estado desejado)"
}

# ------------------------------------------------------------------ aplicação
apply_plan() {
  local line act kind rel extra
  for line in "${PLAN[@]}"; do
    IFS=$'\t' read -r act kind rel extra <<< "$line"
    case "$kind:$act" in
      file:OK) ;;
      file:ADOTAR) M_KIND[$rel]=file M_SHA[$rel]=$(sha "$HOME/$rel") ;;
      file:CRIAR|file:ATUALIZAR|file:CONFLITO)
        if [[ $act == CONFLITO ]]; then
          if [[ -n ${M_SHA[$rel]:-} ]]; then save_copy "$rel"   # arquivo do projeto editado: cópia só para consulta
          else backup "$rel"; fi                                  # original do usuário: restaurado ao desinstalar
        fi
        mkdir -p "$(dirname "$HOME/$rel")"
        [[ -L $HOME/$rel ]] && rm -f "$HOME/$rel"
        install -m "$(stat -c %a "$extra")" "$extra" "$HOME/$rel"
        M_KIND[$rel]=file M_SHA[$rel]=$(sha "$HOME/$rel")
        [[ -n ${M_BAK[$rel]:-} ]] || M_BAK[$rel]=- ;;
      file:REMOVER) rm -f "$HOME/$rel"; unset "M_KIND[$rel]" "M_SHA[$rel]" "M_BAK[$rel]" ;;
      file:ESQUECER) unset "M_KIND[$rel]" "M_SHA[$rel]" "M_BAK[$rel]" ;;
      file:MANTER) warn "~/$rel saiu do projeto mas foi editado: mantido e esquecido"; unset "M_KIND[$rel]" "M_SHA[$rel]" "M_BAK[$rel]" ;;
      link:OK) M_KIND[$rel]=link M_SHA[$rel]=$extra; [[ -n ${M_BAK[$rel]:-} ]] || M_BAK[$rel]=- ;;
      link:*)
        [[ $act == CONFLITO ]] && backup "$rel"
        mkdir -p "$(dirname "$HOME/$rel")"
        ln -sfn "$extra" "$HOME/$rel"
        M_KIND[$rel]=link M_SHA[$rel]=$extra; [[ -n ${M_BAK[$rel]:-} ]] || M_BAK[$rel]=- ;;
      block:OK) M_KIND[$rel]=block; [[ -n ${M_SHA[$rel]:-} ]] || M_SHA[$rel]=nosep; [[ -n ${M_BAK[$rel]:-} ]] || M_BAK[$rel]=- ;;
      block:*)
        backup "$rel"
        if [[ $act == ATUALIZAR ]]; then
          # Troca só o miolo entre os marcadores; o resto do arquivo fica intacto.
          local tmp; tmp=$(mktemp)
          awk -v b="$BLOCK_BEGIN" -v e="$BLOCK_END" -v body="$BLOCK_BODY" '
            $0 == b { print; print body; skip = 1; next }
            $0 == e { skip = 0 } !skip' "$HYPR_MAIN" > "$tmp" && cat "$tmp" > "$HYPR_MAIN"
          rm -f "$tmp"
        else
          # Acrescenta no fim. "sep" = foi preciso inserir uma linha em branco
          # antes do bloco (desfeita na desinstalação).
          local sep=nosep
          [[ -n $(tail -c1 "$HYPR_MAIN") ]] && printf '\n' >> "$HYPR_MAIN"
          [[ -n $(tail -n1 "$HYPR_MAIN") ]] && { printf '\n' >> "$HYPR_MAIN"; sep=sep; }
          block_text >> "$HYPR_MAIN"
          M_SHA[$rel]=$sep
        fi
        M_KIND[$rel]=block; [[ -n ${M_SHA[$rel]:-} ]] || M_SHA[$rel]=nosep ;;
      shelljson:OK) M_KIND[$rel]=shelljson M_SHA[$rel]=-; [[ -n ${M_BAK[$rel]:-} ]] || M_BAK[$rel]=- ;;
      shelljson:ALTERAR) apply_shelljson; M_KIND[$rel]=shelljson M_SHA[$rel]=- ;;
      external:*) ;;   # depois do manifesto
    esac
  done
}

apply_shelljson() {
  local f="$HOME/.config/omarchy/shell.json"
  backup .config/omarchy/shell.json
  [[ -f $SHELLJSON_PREV ]] || jq -c '{id: (.bar.id // null), position: (.bar.position // null)}' "$f" > "$SHELLJSON_PREV"
  if live_session; then
    # Mecanismo suportado: omarchy-bar valida que o plugin de barra existe e
    # pede ao shell em execução para recarregar (IPC).
    if ! omarchy bar use "$BAR_ID" >/dev/null || ! omarchy bar position top >/dev/null; then
      die "omarchy bar use/position falhou; shell.json original em $STATE/${M_BAK[.config/omarchy/shell.json]}"
    fi
  else
    # Sem sessão (--no-activate, HOME de teste): mesmas duas chaves via jq e
    # nenhum IPC, para não tocar no shell de outra sessão.
    [[ -f $HOME/.config/omarchy/plugins/$BAR_ID/manifest.json ]] || die "plugin de barra $BAR_ID não instalado"
    set_shelljson "$BAR_ID" top
  fi
}

set_shelljson() {  # set_shelljson <id|""> <posição|"">
  local f="$HOME/.config/omarchy/shell.json" tmp
  tmp=$(mktemp)
  jq --arg id "$1" --arg pos "$2" '
    (if $id == "" or $id == "omarchy.bar" then del(.bar.id) else .bar.id = $id end)
    | (if $pos == "" then . else .bar.position = $pos end)' "$f" > "$tmp" && mv "$tmp" "$f"
}

install_externals() {
  (( NO_EXTERNALS )) && return 0
  local line act kind rel extra
  for line in "${PLAN[@]}"; do
    IFS=$'\t' read -r act kind rel extra <<< "$line"
    [[ $kind == external && $act == INSTALAR ]] || continue
    case $rel in
      arttime) "$ROOT/scripts/install-arttime.sh" "$ARTTIME_URL" "$ARTTIME_COMMIT" ;;
      omarchy-overview)
        git clone -q "$OVERVIEW_URL" "$OVERVIEW_DIR"
        git -C "$OVERVIEW_DIR" checkout -q "$OVERVIEW_COMMIT"
        omarchy plugin validate "$OVERVIEW_DIR" >/dev/null && ok "omarchy-overview @ ${OVERVIEW_COMMIT:0:7}" ;;
    esac
  done
}

activate() {
  if ! live_session; then
    warn "ativação pulada (sem sessão Hyprland ou --no-activate): faça logout/login ou rode ./install.sh de dentro da sessão"
    return 0
  fi
  systemctl --user daemon-reload
  systemctl --user start noctalia.service soviet-bar-sync.service
  local line act kind rel extra restart_sync=0 restart_noctalia=0
  for line in "${PLAN[@]}"; do
    IFS=$'\t' read -r act kind rel extra <<< "$line"
    [[ $act != OK && $rel == .local/bin/soviet-bar-sync ]] && restart_sync=1
    # Plugin novo, removido ou com entradas mudadas: a recarga a quente do Noctalia
    # pode ler a barra antes do plugin.toml novo ("unrecognized widget type").
    [[ $act != OK && $rel == .local/share/noctalia/plugins/*/plugin.toml ]] && restart_noctalia=1
  done
  (( restart_sync )) && systemctl --user restart soviet-bar-sync.service
  (( restart_noctalia )) && systemctl --user restart noctalia.service
  hyprctl reload >/dev/null
  local errs; errs=$(hyprctl configerrors 2>&1 | sed '/^$/d')
  if [[ -n $errs ]]; then
    err "hyprctl configerrors:"; printf '%s\n' "$errs" >&2
    die "Hyprland reportou erros (reverter: ./install.sh uninstall)"
  fi
  ok "Hyprland recarregado sem erros; Noctalia e soviet-bar-sync ativos"
  info "  Painéis já abertos da central usam a versão anterior até serem reabertos ($KEY_OPS)."
}

# Tela de descanso do Omarchy: desligada pelo flag do próprio Omarchy (o mesmo do
# omarchy-toggle-screensaver); o idle do Noctalia leva à central no lugar dela
# (40-integracao-hyprland.toml). Só desfazemos no uninstall se fomos nós que ligamos.
SCREENSAVER_FLAG="$HOME/.local/state/omarchy/toggles/screensaver-off"
SCREENSAVER_OURS="$STATE/screensaver-off.nosso"
plan_screensaver() {
  [[ -f $SCREENSAVER_FLAG ]] || info "  DESLIGAR  toggle    tela de descanso do Omarchy  (~/${SCREENSAVER_FLAG#"$HOME"/})"
}
apply_screensaver() {
  [[ -f $SCREENSAVER_FLAG ]] && return 0
  mkdir -p "${SCREENSAVER_FLAG%/*}" "$STATE" && touch "$SCREENSAVER_FLAG" "$SCREENSAVER_OURS"
  ok "tela de descanso do Omarchy desligada: ocioso leva à central de operações"
}

cmd_install() {
  preflight
  read_manifest
  info "== Plano"
  plan_files; plan_links; plan_block; plan_shelljson; plan_externals
  print_plan
  plan_screensaver
  if (( CONFLICTS && ! FORCE )); then
    err "$CONFLICTS conflito(s): arquivo existente diferente e não instalado por este projeto (ou editado depois)."
    info "  Compare com 'diff ~/<arquivo> <repo>/...'; para sobrescrever COM backup: --force"
    exit 3
  fi
  (( DRY )) && { info "(--dry-run: nada foi alterado)"; return 0; }
  info "== Aplicando"
  apply_plan
  write_manifest
  apply_screensaver
  [[ -d $BACKUP_DIR ]] && ok "originais guardados em $BACKUP_DIR"
  install_externals
  activate
  ok "instalação concluída ($(grep -vc '^#' "$MANIFEST") itens no manifesto)"
}

cmd_check() {
  local saved=$DRY; DRY=1
  preflight
  read_manifest
  info "== Plano (simulação)"
  plan_files; plan_links; plan_block; plan_shelljson; plan_externals
  print_plan
  DRY=$saved
  (( CONFLICTS )) && { warn "$CONFLICTS conflito(s): ./install.sh pararia (ou use --force, com backup)"; return 3; }
  return 0
}

cmd_status() {
  read_manifest
  (( ${#M_KIND[@]} )) || { info "não instalado (sem $MANIFEST)"; return 1; }
  local rel st n=0 bad=0
  for rel in $(printf '%s\n' "${!M_KIND[@]}" | sort); do
    case ${M_KIND[$rel]} in
      file) if [[ ! -e $HOME/$rel ]]; then st=AUSENTE; elif [[ $(sha "$HOME/$rel") == "${M_SHA[$rel]}" ]]; then st=ok; else st=EDITADO; fi ;;
      link) [[ $(readlink "$HOME/$rel" 2>/dev/null) == "${M_SHA[$rel]}" ]] && st=ok || st=ALTERADO ;;
      block) grep -qxF -e "$BLOCK_BEGIN" "$HYPR_MAIN" && st=ok || st=AUSENTE ;;
      shelljson) [[ $(jq -r '.bar.id // empty' "$HOME/.config/omarchy/shell.json") == "$BAR_ID" ]] && st=ok || st=ALTERADO ;;
    esac
    (( ++n )); [[ $st == ok ]] || { (( ++bad )); printf '  %-9s %s\n' "$st" "~/$rel"; }
  done
  info "$n itens gerenciados, $bad com divergência"
  (( bad == 0 ))
}

cmd_uninstall() {
  read_manifest
  (( ${#M_KIND[@]} )) || die "nada a desinstalar (sem $MANIFEST)"
  info "== Plano de remoção"
  local rel kind cur actions=() n_keep=0
  for rel in $(printf '%s\n' "${!M_KIND[@]}" | sort); do
    kind=${M_KIND[$rel]}
    case $kind in
      file)
        if [[ ! -e $HOME/$rel ]]; then continue
        elif [[ $(sha "$HOME/$rel") != "${M_SHA[$rel]}" && $FORCE == 0 ]]; then
          warn "~/$rel foi editado depois da instalação: mantido (use --force para remover/restaurar)"; (( ++n_keep )); continue
        fi ;;
      link) [[ -L $HOME/$rel ]] || continue ;;
    esac
    # Bloco e shell.json: desfaz só o que o projeto mudou (edições posteriores
    # do usuário nesses arquivos são preservadas; o backup completo fica em $STATE).
    if [[ $kind == block ]]; then actions+=("REMOVER"$'\t'"$kind"$'\t'"$rel")
    elif [[ $kind == shelljson ]]; then actions+=("REVERTER"$'\t'"$kind"$'\t'"$rel")
    elif [[ ${M_BAK[$rel]:-} != - && -n ${M_BAK[$rel]:-} ]]; then actions+=("RESTAURAR"$'\t'"$kind"$'\t'"$rel")
    else actions+=("REMOVER"$'\t'"$kind"$'\t'"$rel")
    fi
  done
  local a k r
  for a in "${actions[@]}"; do IFS=$'\t' read -r k kind r <<< "$a"; printf '  %-9s %-9s ~/%s\n' "$k" "$kind" "$r"; done
  (( DRY )) && { info "(--dry-run: nada foi alterado)"; return 0; }

  if live_session; then
    systemctl --user stop soviet-bar-sync.service noctalia.service 2>/dev/null || true
    pkill -u "$USER" -f -- 'foot .*--app-id=soviet-(arte|inspect)( |$)' 2>/dev/null || true
  fi
  for a in "${actions[@]}"; do
    IFS=$'\t' read -r k kind r <<< "$a"
    case "$kind:$k" in
      block:REMOVER)
        # Remove o bloco e, se a instalação inseriu, a linha em branco anterior.
        local tmp; tmp=$(mktemp)
        awk -v b="$BLOCK_BEGIN" -v e="$BLOCK_END" -v sep="${M_SHA[$r]}" '
          { line[NR] = $0 }
          END {
            for (i = 1; i <= NR; i++) if (line[i] == b) { s = i; break }
            for (i = s; i <= NR; i++) if (line[i] == e) { t = i; break }
            if (!s || !t) { for (i = 1; i <= NR; i++) print line[i]; exit }
            if (sep == "sep" && s > 1 && line[s-1] == "") s--
            for (i = 1; i <= NR; i++) if (i < s || i > t) print line[i]
          }' "$HYPR_MAIN" > "$tmp" && cat "$tmp" > "$HYPR_MAIN"
        rm -f "$tmp" ;;
      shelljson:*)
        local prev_id prev_pos
        prev_id=$(jq -r '.id // empty' "$SHELLJSON_PREV" 2>/dev/null || true)
        prev_pos=$(jq -r '.position // empty' "$SHELLJSON_PREV" 2>/dev/null || true)
        if live_session; then
          if [[ -z $prev_id || $prev_id == omarchy.bar ]]; then omarchy bar reset >/dev/null || true
          else omarchy bar use "$prev_id" >/dev/null || true; fi
          [[ -n $prev_pos ]] && { omarchy bar position "$prev_pos" >/dev/null || true; }
        else
          set_shelljson "$prev_id" "$prev_pos"
        fi ;;
      *:RESTAURAR)
        rm -f "$HOME/$r"; cp -a "$STATE/${M_BAK[$r]}" "$HOME/$r" ;;
      *:REMOVER) rm -f "$HOME/$r" ;;
    esac
  done
  # Tela de descanso do Omarchy: religada só se fomos nós que a desligamos.
  if [[ -f $SCREENSAVER_OURS ]]; then rm -f "$SCREENSAVER_FLAG" "$SCREENSAVER_OURS"; fi
  # Estado gerado em tempo de execução por soviet-bar-pos (fora do manifesto).
  rm -f "$HOME/.config/noctalia/90-posicao-barra.toml"
  # Diretórios do projeto que ficaram vazios.
  local d
  for d in .local/share/terminal-soviet/arte .local/share/terminal-soviet .config/terminal-soviet \
           .local/share/noctalia/plugins/tarefas .local/share/noctalia/plugins/audio .local/share/noctalia/plugins/barra \
           .local/share/noctalia/plugins/spotify-media .config/omarchy/plugins/erllan.sem-barra \
           .config/noctalia/palettes .config/noctalia; do
    [[ -d $HOME/$d ]] && find "$HOME/$d" -depth -type d -empty -delete 2>/dev/null || true
  done
  mv -f "$MANIFEST" "$MANIFEST.removido-$TS"
  rm -f "$SHELLJSON_PREV"
  (( PURGE )) && rm -rf "${XDG_STATE_HOME:-$HOME/.local/state}/terminal-soviet/arte.conf" \
                        "${XDG_STATE_HOME:-$HOME/.local/state}/terminal-soviet/arte-selecao" \
                        "${XDG_CACHE_HOME:-$HOME/.cache}/terminal-soviet"
  if live_session; then
    systemctl --user daemon-reload
    hyprctl reload >/dev/null
  fi
  ok "desinstalado ($n_keep arquivo(s) editado(s) mantidos). arttime e omarchy-overview ficam (veja docs/backup-restore.md)."
}

case $CMD in
  install) cmd_install ;;
  check) cmd_check ;;
  status) cmd_status ;;
  uninstall) cmd_uninstall ;;
esac
