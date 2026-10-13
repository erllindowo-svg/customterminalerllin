#!/bin/bash
# Terminal Soviético — tema do menu de boot do Limine (opcional, à parte do install.sh).
#
# O ./install.sh não usa sudo nem toca em /boot. Este script sim, e só quando
# precisa: /boot (a ESP, vfat montada com fmask=0077) não é legível sem root,
# então até o --plan e o --status leem o limine.conf com sudo.
#
#   install-limine-theme.sh [--plan]     mostra o que mudaria (padrão; não escreve no /boot)
#   install-limine-theme.sh --install    aplica (backup datado, confere, limine-update)
#   install-limine-theme.sh --remove     volta ao backup (ou tira o bloco e devolve as chaves)
#   install-limine-theme.sh --status     aplicado? hashes batem? o Omarchy sobrescreveu?
#   --yes                                não pergunta antes de escrever
#
# O tema é um bloco no topo do /boot/limine.conf, entre
#   # >>> terminal-soviet limine >>>   …   # <<< terminal-soviet limine <<<
# substituído (nunca duplicado) a cada --install. As chaves de aparência que o
# Omarchy define no cabeçalho (interface_*, term_*, backdrop, hash_mismatch_panic,
# timeout…) saem do cabeçalho para não ficarem repetidas (chave repetida no
# Limine é ambígua); default_entry e tudo da primeira entrada ("/…") para baixo,
# gerado pelo limine-entry-tool e pelo limine-snapper-sync, ficam byte a byte.
# Fonte e papel de parede vão para /boot com o b2sum na linha (wallpaper: …#hash).
#
# Preferências: LIMINE_* em config/terminal-soviet.conf. Documentação: docs/boot-theme.md.
#
# Só para testes (sandbox, VM): TS_BOOT_DIR=<dir>, TS_SUDO="" (sem sudo) e
# TS_CONF_FILE=<conf> (outras variantes sem mexer no conf versionado). Com um
# TS_BOOT_DIR diferente do ESP_PATH do sistema, limine-update e limine-snapper-sync
# NÃO rodam (eles agem sempre na ESP real).
set -euo pipefail
ROOT=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)
# shellcheck source=lib/ts-lib.sh
source "$ROOT/lib/ts-lib.sh"
# shellcheck source=lib/compat.sh
source "$ROOT/lib/compat.sh"

BOOT_DIR=${TS_BOOT_DIR:-/boot}
CONF_TS=${TS_CONF_FILE:-$ROOT/config/terminal-soviet.conf}
SUDO=${TS_SUDO-sudo}
ESP_REAL=$(sed -n 's/^ESP_PATH="\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' /etc/default/limine 2>/dev/null | tail -1)
ESP_REAL=${ESP_REAL:-/boot}
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/terminal-soviet/limine"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/terminal-soviet/limine"
CONF="$BOOT_DIR/limine.conf"
MARK_INI="# >>> terminal-soviet limine >>>"
MARK_FIM="# <<< terminal-soviet limine <<<"
FUNDO="ts-limine-fundo.png"
FONTE="ts-limine-fonte.f14"
# Chaves de aparência retiradas do cabeçalho (o bloco do tema as redefine).
CHAVES_TEMA='^[[:space:]]*(timeout|remember_last_entry|hash_mismatch_panic|wallpaper|wallpaper_style|backdrop|term_[a-z_]+|interface_branding(_colou?r)?|interface_help_hidden|interface_help_colou?r(_bright)?)[[:space:]]*:'

ACAO=plan SIM=0
for a in "$@"; do
  case $a in
    --plan) ACAO=plan ;;
    --install) ACAO=install ;;
    --remove) ACAO=remove ;;
    --status) ACAO=status ;;
    --yes|-y) SIM=1 ;;
    -h|--help) sed -n '2,/^set -euo/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 0 ;;
    *) die "opção desconhecida: $a (use --plan, --install, --remove, --status, --yes)" ;;
  esac
done

TMP=$(mktemp -d "${TMPDIR:-/tmp}/ts-limine.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

# ------------------------------------------------------------------ privilégio
SUDO_OK=0
root() {
  if [[ -z $SUDO ]]; then "$@"; return; fi
  if (( ! SUDO_OK )); then
    if ! $SUDO -n true 2>/dev/null; then
      info "sudo: $BOOT_DIR é a partição EFI (vfat, só root lê e escreve). O sudo é usado"
      info "      só para ler o limine.conf, copiar fonte e papel de parede, gravar o limine.conf,"
      info "      fazer o backup ao lado dele e rodar limine-update/limine-snapper-sync."
      $SUDO -v || die "sem sudo, nada foi feito"
    fi
    SUDO_OK=1
  fi
  $SUDO "$@"
}

# ------------------------------------------------------------------ verificações
verificar() {
  command -v limine >/dev/null || die "limine não encontrado"
  local v
  v=$(limine --version 2>/dev/null | sed -n '1s/^Limine \([0-9.]*\).*/\1/p')
  [[ -n $v ]] || die "não consegui ler 'limine --version'"
  if [[ $v == "$LIMINE_VERIFIED" ]]; then ok "Limine $v (verificado)"
  elif [[ $v == "$LIMINE_SERIES"* ]]; then warn "Limine $v: mesma série de $LIMINE_VERIFIED, não verificado"
  else die "Limine $v: fora da série $LIMINE_SERIES*; as chaves do tema foram conferidas só na v12"
  fi
  root test -f "$CONF" || die "$CONF não existe: o tema só se aplica a um Limine configurado"
  local l achadas=()
  for l in "${LIMINE_LEGADAS[@]}"; do root test -f "$BOOT_DIR/$l" && achadas+=("$BOOT_DIR/$l"); done
  (( ${#achadas[@]} == 0 )) || die "configs legadas que o Limine lê antes de $CONF: ${achadas[*]} (o omarchy-upgrade-to-quattro as remove); nada foi feito"
  ok "$CONF presente; nenhuma config legada"
}

# entradas <arquivo>: da primeira entrada ("/…") até o fim — o que nunca mudamos.
entradas() { awk 'f || /^[[:space:]]*\//{ f = 1; print }' "$1"; }

ler_conf() { root cat "$CONF" > "$1"; }

# ------------------------------------------------------------------ ativos
baixar() {  # baixar <url> <sha256> <destino>
  local url=$1 sha=$2 dst=$3
  if [[ -f $dst ]] && [[ $(sha256sum "$dst" | cut -d' ' -f1) == "$sha" ]]; then return 0; fi
  mkdir -p "$(dirname "$dst")"
  info "  baixando $url"
  curl -fsSL --proto '=https' --tlsv1.2 -o "$dst.tmp" "$url" || { rm -f "$dst.tmp"; die "download falhou: $url"; }
  if [[ $(sha256sum "$dst.tmp" | cut -d' ' -f1) != "$sha" ]]; then
    rm -f "$dst.tmp"; die "SHA-256 diferente do fixado para $url: o upstream mudou? nada foi usado"
  fi
  mv "$dst.tmp" "$dst"
}

ALTURA=14
gerar_ativos() {
  python3 -c 'import PIL, numpy' 2>/dev/null || die "faltam Pillow e numpy: omarchy pkg add python-pillow python-numpy"
  case $LIMINE_FONTE in
    terminus)
      [[ -r $LIMINE_TERMINUS_PSF ]] || die "$LIMINE_TERMINUS_PSF ausente: omarchy pkg add terminus-font"
      read -r ALTURA _ < <(python3 -I "$ROOT/scripts/limine-font.py" "$TMP/$FONTE" "$LIMINE_TERMINUS_PSF") ;;
    phxega)
      baixar "$LIMINE_PHXEGA_URL" "$LIMINE_PHXEGA_SHA256" "$CACHE/upstream/PHXEGA8.F14"
      cp "$CACHE/upstream/PHXEGA8.F14" "$TMP/$FONTE"
      ALTURA=$(( $(stat -c %s "$TMP/$FONTE") / 256 )) ;;
  esac
  local args=("$TMP/$FUNDO" --variante "$LIMINE_THEME" --resolucao "$LIMINE_RESOLUCAO")
  if [[ $LIMINE_ORIGEM == arte ]]; then
    baixar "$LIMINE_ARTE_URL" "$LIMINE_ARTE_SHA256" "$CACHE/upstream/fallout-grub-background.png"
    args+=(--origem "$CACHE/upstream/fallout-grub-background.png")
  else
    args+=(--gerar-do-zero)
  fi
  # O título é desenhado no papel de parede, não pelo Limine: se não couber no
  # CP437 (cirílico), usa uma fonte CP866 só para ele; o menu continua em CP437.
  if [[ -n $LIMINE_TITULO ]]; then
    if printf '%s' "$LIMINE_TITULO" | iconv -f UTF-8 -t CP437 >/dev/null 2>&1; then
      args+=(--titulo "$LIMINE_TITULO" --fonte "$TMP/$FONTE")
    else
      local k=${LIMINE_TERMINUS_PSF%/*}
      python3 -I "$ROOT/scripts/limine-font.py" "$TMP/titulo-866.f14" "$k/ter-k14n.psf.gz" "$LIMINE_TERMINUS_PSF" --pagina cp866 >/dev/null
      args+=(--titulo "$LIMINE_TITULO" --fonte "$TMP/titulo-866.f14" --pagina cp866)
    fi
  fi
  python3 -I "$ROOT/scripts/limine-wallpaper.py" "${args[@]}" >/dev/null
}

# ------------------------------------------------------------------ bloco do tema
# Cores por variante. fosforo/ambar: omarchy/themes/soviet-terminal/colors.toml.
# fallout: Fallout_limine/Limine.txt do Neptune3013 (@9a777b9), sem interface_*.
cores() {
  case $LIMINE_THEME in
    fosforo) cat <<'EOF'
backdrop: 080908
term_background: 99101210
term_foreground: B8D58A
term_background_bright: 191C19
term_foreground_bright: D2E8AE
term_palette: 101210;BD4A42;B8D58A;C9B26B;7F9A88;A27B76;8FB09A;C8CBBF
term_palette_bright: 444B42;D2625A;D2E8AE;DCC88A;9FB8A6;BE9A94;AECBB8;E2E5D8
interface_branding_color: B8D58A
interface_help_color: 718D58
interface_help_color_bright: D2E8AE
EOF
    ;;
    ambar) cat <<'EOF'
backdrop: 080908
term_background: 99101210
term_foreground: C9B26B
term_background_bright: 191C19
term_foreground_bright: DCC88A
term_palette: 101210;BD4A42;C9B26B;B9824A;8A7A48;A27B76;B9A46A;C9B26B
term_palette_bright: 4A4436;D2625A;DCC88A;D9A066;A8956A;BE9A94;D3BC80;E8DDB5
interface_branding_color: C9B26B
interface_help_color: 8A7A48
interface_help_color_bright: DCC88A
EOF
    ;;
    fallout) cat <<'EOF'
term_background: 9935453b
term_background_bright: ffffff
term_foreground: 67d97a
term_palette: 000000;5c110c;074224;4d1c0d;00594d;f5c2e7;16de6d;989e9b
term_palette_bright: 2f3030;ff0000;16de6d;f7cd34;0ddeaa;f5c2e7;16de6d;ffffff
EOF
    ;;
  esac
}

bloco() {  # bloco <hash do fundo> <hash da fonte>
  local esc h=${LIMINE_RESOLUCAO#*x}
  esc=$(( h / 540 )); (( esc >= 1 )) || esc=1
  printf '%s\n' "$MARK_INI"
  printf '# Gerado por scripts/install-limine-theme.sh (Terminal Soviético): não edite aqui,\n'
  printf '# mude LIMINE_* em config/terminal-soviet.conf e rode --install; desfazer: --remove.\n'
  printf '# variante: %s · fundo: %s · fonte: %s · %s\n' "$LIMINE_THEME" "$LIMINE_ORIGEM" "$LIMINE_FONTE" "$LIMINE_RESOLUCAO"
  printf 'timeout: %s\n' "$LIMINE_TIMEOUT"
  printf 'remember_last_entry: yes\n'
  printf 'hash_mismatch_panic: no\n'
  printf 'wallpaper: boot():/%s#%s\n' "$FUNDO" "$1"
  printf 'wallpaper_style: stretched\n'
  printf 'term_font: boot():/%s#%s\n' "$FONTE" "$2"
  printf 'term_font_size: 8x%s\n' "$ALTURA"
  printf 'term_font_scale: %sx%s\n' "$esc" "$esc"
  printf 'term_margin: 0\n'
  cores
  printf 'interface_branding:\n'
  printf 'interface_help_hidden: yes\n'
  printf '%s\n' "$MARK_FIM"
}

# novo_conf <atual> <bloco> <saída> <removidas>: tira o bloco antigo e as chaves do
# tema do cabeçalho (guardadas em <removidas>), põe o bloco depois dos comentários
# iniciais e mantém o resto, entradas intactas.
novo_conf() {
  MARK_INI=$MARK_INI MARK_FIM=$MARK_FIM CHAVES=$CHAVES_TEMA BLOCO=$2 REMOVIDAS=$4 perl -e '
    use strict; use warnings;
    my ($ini, $fim, $re) = @ENV{qw(MARK_INI MARK_FIM CHAVES)};
    open(my $in, "<", $ARGV[0]) or die; my @l = <$in>; close $in;
    open(my $b, "<", $ENV{BLOCO}) or die; my $bloco = do { local $/; <$b> }; close $b;
    my (@cab, @ent, @rem, $dentro, $entrou);
    for (@l) {
      if (!$entrou && /^\s*\//) { $entrou = 1 }
      if ($entrou) { push @ent, $_; next }
      if ($_ eq "$ini\n") { $dentro = 1; next }
      if ($dentro) { $dentro = 0 if $_ eq "$fim\n"; next }
      if (/$re/i) { push @rem, $_; next }
      push @cab, $_;
    }
    my $i = 0;
    $i++ while $i < @cab && $cab[$i] =~ /^\s*(#.*)?$/ && $cab[$i] !~ /^\s*$/;
    open(my $out, ">", $ARGV[1]) or die;
    print $out @cab[0 .. $i - 1], $bloco, @cab[$i .. $#cab], @ent;
    close $out;
    open(my $r, ">", $ENV{REMOVIDAS}) or die; print $r @rem; close $r;
  ' "$1" "$3"
}

# validar <conf> <entradas de referência>: marcadores únicos, cabeçalho sem chave
# repetida e só com "chave: valor"/comentários, entradas idênticas.
validar() {
  local c=$1 ref=$2 n
  n=$(grep -cxF "$MARK_INI" "$c" || true)
  [[ $n == 1 && $(grep -cxF "$MARK_FIM" "$c" || true) == 1 ]] || { err "marcadores do tema: $n (esperado 1)"; return 1; }
  local cab
  cab=$(awk '/^[[:space:]]*\//{ exit } { print }' "$c")
  local ruins
  ruins=$(grep -vE '^[[:space:]]*(#.*)?$|^[A-Za-z_]+:' <<< "$cab" || true)
  [[ -z $ruins ]] || { err "linhas inválidas no cabeçalho: $ruins"; return 1; }
  local dup
  dup=$(grep -oE '^[A-Za-z_]+:' <<< "$cab" | tr '[:upper:]' '[:lower:]' | sed 's/colour/color/' | sort | uniq -d)
  [[ -z $dup ]] || { err "chaves repetidas no cabeçalho: $(tr '\n' ' ' <<< "$dup")"; return 1; }
  cmp -s <(entradas "$c") "$ref" || { err "as entradas de boot mudariam"; return 1; }
}

hash_de() { b2sum "$1" | cut -d' ' -f1; }

atualizar_limine() {
  if [[ $BOOT_DIR != "$ESP_REAL" ]]; then
    info "  (teste: $BOOT_DIR não é a ESP do sistema, $ESP_REAL — limine-update/limine-snapper-sync não rodam)"
    return 0
  fi
  if command -v limine-update >/dev/null; then info "  limine-update"; root limine-update >/dev/null; fi
  if command -v limine-snapper-sync >/dev/null; then info "  limine-snapper-sync"; root limine-snapper-sync >/dev/null || warn "limine-snapper-sync falhou (snapshots não atualizados)"; fi
}

confirmar() {
  (( SIM )) && return 0
  [[ -t 0 ]] || die "sem terminal para confirmar: use --yes"
  local r; read -r -p "Prosseguir? [s/N] " r
  [[ $r =~ ^[sS]$ ]] || die "cancelado; nada foi alterado"
}

preparar() {  # gera ativos, monta o novo conf em $TMP/novo.conf e valida
  load_conf "$CONF_TS"
  verificar
  ler_conf "$TMP/atual.conf"
  entradas "$TMP/atual.conf" > "$TMP/entradas.ref"
  [[ -s $TMP/entradas.ref ]] || warn "$CONF não tem nenhuma entrada de boot ('/…')"
  info "== Gerando fonte e papel de parede (como usuário, em $TMP)"
  gerar_ativos
  bloco "$(hash_de "$TMP/$FUNDO")" "$(hash_de "$TMP/$FONTE")" > "$TMP/bloco"
  novo_conf "$TMP/atual.conf" "$TMP/bloco" "$TMP/novo.conf" "$TMP/removidas"
  validar "$TMP/novo.conf" "$TMP/entradas.ref" || die "o limine.conf gerado não passou na conferência; nada foi alterado"
}

mostrar_plano() {
  info "== Plano (${CONF})"
  if cmp -s "$TMP/atual.conf" "$TMP/novo.conf"; then
    info "  limine.conf: já no estado desejado"
  else
    diff -u --label "$CONF (atual)" --label "$CONF (novo)" "$TMP/atual.conf" "$TMP/novo.conf" || true
  fi
  local f
  for f in "$FUNDO" "$FONTE"; do
    if root test -f "$BOOT_DIR/$f" && [[ $(root b2sum "$BOOT_DIR/$f" | cut -d' ' -f1) == "$(hash_de "$TMP/$f")" ]]; then
      info "  $BOOT_DIR/$f: já igual"
    else
      info "  copiar $f → $BOOT_DIR/$f ($(stat -c %s "$TMP/$f") bytes, b2sum $(hash_de "$TMP/$f" | cut -c1-16)…)"
    fi
  done
  info "  backup: $CONF.terminal-soviet-<data>.bak e $STATE/backups/"
  if [[ $BOOT_DIR == "$ESP_REAL" ]]; then info "  depois: limine-update e limine-snapper-sync"; fi
}

# ------------------------------------------------------------------ ações
cmd_plan() {
  preparar
  mostrar_plano
  info "(--plan: nada foi escrito em $BOOT_DIR)"
}

cmd_install() {
  preparar
  mostrar_plano
  local igual=0
  cmp -s "$TMP/atual.conf" "$TMP/novo.conf" && igual=1
  if (( igual )) && root cmp -s "$TMP/$FUNDO" "$BOOT_DIR/$FUNDO" && root cmp -s "$TMP/$FONTE" "$BOOT_DIR/$FONTE"; then
    ok "tema já aplicado e idêntico; nada a fazer"; return 0
  fi
  confirmar
  local ts; ts=$(date +%Y%m%d-%H%M%S)
  info "== Aplicando"
  mkdir -p "$STATE/backups"
  cp "$TMP/atual.conf" "$STATE/backups/limine.conf.$ts"
  # Chaves originais do cabeçalho (as do Omarchy): só a primeira instalação as vê.
  [[ -s $TMP/removidas ]] && cp "$TMP/removidas" "$STATE/chaves-originais.conf"
  root cp "$CONF" "$CONF.terminal-soviet-$ts.bak"
  ok "backup: $CONF.terminal-soviet-$ts.bak (cópia fora da ESP: $STATE/backups/limine.conf.$ts)"
  root cp "$TMP/$FUNDO" "$BOOT_DIR/$FUNDO"
  root cp "$TMP/$FONTE" "$BOOT_DIR/$FONTE"
  root cp "$TMP/novo.conf" "$CONF.ts-novo"
  root mv "$CONF.ts-novo" "$CONF"
  ler_conf "$TMP/gravado.conf"
  cmp -s "$TMP/gravado.conf" "$TMP/novo.conf" || die "o limine.conf gravado difere do gerado (backup: $CONF.terminal-soviet-$ts.bak)"
  conferir_hashes "$TMP/gravado.conf" || die "hash de fonte/papel de parede não confere (backup: $CONF.terminal-soviet-$ts.bak)"
  ok "limine.conf gravado e conferido (entradas intactas, hashes batem)"
  atualizar_limine
  ler_conf "$TMP/depois.conf"
  if ! validar "$TMP/depois.conf" "$(entradas_tmp "$TMP/depois.conf")"; then
    die "o bloco do tema não sobreviveu ao limine-update (backup: $CONF.terminal-soviet-$ts.bak)"
  fi
  printf 'instalado=%s\nvariante=%s\nfundo=%s\nfonte=%s\n' "$ts" "$LIMINE_THEME" "$LIMINE_ORIGEM" "$LIMINE_FONTE" > "$STATE/instalado"
  ok "tema '$LIMINE_THEME' aplicado. Reinicie para ver; desfazer: $0 --remove"
}

# entradas_tmp <conf>: grava as entradas atuais num arquivo e imprime o caminho
# (depois do limine-update as entradas podem ter mudado legitimamente).
entradas_tmp() { entradas "$1" > "$TMP/entradas.depois"; printf '%s\n' "$TMP/entradas.depois"; }

# conferir_hashes <conf>: o b2sum das linhas wallpaper/term_font bate com os arquivos?
conferir_hashes() {
  local c=$1 chave arq hash ok_=0
  for chave in wallpaper term_font; do
    read -r arq hash < <(sed -n "s|^$chave: boot():/\([^#]*\)#\([0-9a-f]*\)\$|\1 \2|p" "$c" | head -1)
    [[ -n ${arq:-} ]] || { err "$chave sem caminho/hash no bloco"; ok_=1; continue; }
    root test -f "$BOOT_DIR/$arq" || { err "$BOOT_DIR/$arq ausente"; ok_=1; continue; }
    [[ $(root b2sum "$BOOT_DIR/$arq" | cut -d' ' -f1) == "$hash" ]] || { err "$arq: hash não confere"; ok_=1; }
  done
  return $ok_
}

cmd_remove() {
  load_conf "$CONF_TS"
  root test -f "$CONF" || die "$CONF não existe"
  ler_conf "$TMP/atual.conf"
  local tem_bloco=0 tem_ativos=0
  grep -qxF "$MARK_INI" "$TMP/atual.conf" && tem_bloco=1
  { root test -f "$BOOT_DIR/$FUNDO" || root test -f "$BOOT_DIR/$FONTE"; } && tem_ativos=1
  if (( ! tem_bloco && ! tem_ativos )); then ok "tema não aplicado; nada a remover"; rm -f "$STATE/instalado"; return 0; fi
  local bak
  # shellcheck disable=SC2016  # $1 expande no sh de dentro (como root)
  bak=$(root sh -c 'ls -1 "$1"/limine.conf.terminal-soviet-*.bak 2>/dev/null' _ "$BOOT_DIR" | sort | tail -1)
  if [[ -n $bak ]]; then root cat "$bak" > "$TMP/bak.conf"; fi
  if [[ -n $bak ]] && ! grep -qxF "$MARK_INI" "$TMP/bak.conf" \
     && cmp -s <(entradas "$TMP/bak.conf") <(entradas "$TMP/atual.conf"); then
    info "== Remover: volta ao backup $bak (entradas iguais às atuais)"
    cp "$TMP/bak.conf" "$TMP/volta.conf"
  else
    info "== Remover: as entradas mudaram desde o backup (ou não há backup) — tira o bloco"
    info "   e devolve as chaves originais do cabeçalho ($STATE/chaves-originais.conf)"
    : > "$TMP/vazio"
    [[ -s $STATE/chaves-originais.conf ]] && cp "$STATE/chaves-originais.conf" "$TMP/vazio"
    novo_conf "$TMP/atual.conf" "$TMP/vazio" "$TMP/volta.conf" "$TMP/removidas"
  fi
  diff -u --label "$CONF (atual)" --label "$CONF (depois)" "$TMP/atual.conf" "$TMP/volta.conf" || true
  info "  apagar $BOOT_DIR/$FUNDO e $BOOT_DIR/$FONTE (os backups ficam)"
  confirmar
  root cp "$TMP/volta.conf" "$CONF.ts-novo"
  root mv "$CONF.ts-novo" "$CONF"
  root rm -f "$BOOT_DIR/$FUNDO" "$BOOT_DIR/$FONTE"
  ler_conf "$TMP/gravado.conf"
  cmp -s "$TMP/gravado.conf" "$TMP/volta.conf" || die "o limine.conf gravado difere do esperado"
  grep -qxF "$MARK_INI" "$TMP/gravado.conf" && die "o bloco do tema continua no limine.conf"
  atualizar_limine
  rm -f "$STATE/instalado"
  ok "tema removido"
}

cmd_status() {
  load_conf "$CONF_TS"
  verificar || true
  ler_conf "$TMP/atual.conf"
  local n st=0
  n=$(grep -cxF "$MARK_INI" "$TMP/atual.conf" || true)
  if [[ $n == 0 ]]; then
    if [[ -f $STATE/instalado ]]; then
      warn "SOBRESCRITO: o tema foi aplicado ($(sed -n 's/^instalado=//p' "$STATE/instalado")), mas o $CONF atual não tem o bloco"
      warn "  (omarchy-refresh-limine troca o arquivo pelo modelo e guarda $CONF.bak)."
      info "  Reaplicar: $0 --install"
      info "  Para reaplicar sozinho depois de atualizações, dá para instalar um hook do pacman"
      info "  ou uma unit path do systemd (docs/boot-theme.md); nada disso é instalado sem você pedir."
      st=3
    else
      info "tema não aplicado ($CONF sem o bloco)"
    fi
  elif [[ $n == 1 ]]; then
    ok "tema aplicado: $(sed -n 's/^# variante: //p' "$TMP/atual.conf" | head -1)"
    conferir_hashes "$TMP/atual.conf" && ok "fonte e papel de parede presentes; hashes batem" || st=2
    local fora
    fora=$(awk -v ini="$MARK_INI" -v fim="$MARK_FIM" '/^[[:space:]]*\//{ exit } $0 == ini { d = 1; next } $0 == fim { d = 0; next } !d' "$TMP/atual.conf" \
           | grep -iE "$CHAVES_TEMA" || true)
    if [[ -n $fora ]]; then
      warn "chaves de aparência fora do bloco (o upgrade do Omarchy as reinsere com sed?):"
      printf '    %s\n' "$fora"; info "  Reaplicar: $0 --install"; st=3
    fi
    grep -qF "variante: $LIMINE_THEME · fundo: $LIMINE_ORIGEM · fonte: $LIMINE_FONTE · $LIMINE_RESOLUCAO" "$TMP/atual.conf" \
      || { warn "config/terminal-soviet.conf mudou desde a aplicação: rode --install"; st=3; }
  else
    err "$n blocos do tema no $CONF (esperado 1): rode --install para corrigir"; st=2
  fi
  return $st
}

case $ACAO in
  plan) cmd_plan ;;
  install) cmd_install ;;
  remove) cmd_remove ;;
  status) cmd_status ;;
esac
