#!/bin/bash
# Tema de boot numa VM: QEMU + OVMF (UEFI) com o Limine do sistema, sem tocar no
# /boot real e sem root.
#
# A ESP da VM é um diretório servido como disco FAT pelo próprio QEMU (vvfat:
# -drive file=fat:rw:<dir>): EFI/BOOT/BOOTX64.EFI = /usr/share/limine/BOOTX64.EFI
# (o mesmo binário da máquina) + tests/fixtures/limine.conf. O tema é aplicado
# pelo install-limine-theme.sh com TS_BOOT_DIR=<esp> (limine-update não roda: não
# é a ESP do sistema). Só na VM, interface_resolution fixa a resolução do monitor
# (o OVMF começa em 1280×800). A tela é capturada pelo monitor do QEMU (screendump).
#
# Uso: tests/vm-limine.sh [saída]   (padrão: tests/results/vm-limine/)
# Cenários: fosforo, ambar, fallout (arte), fosforo do zero, fonte phxega,
# hash errado, fonte ausente, cirílico CP866. Requer qemu-system-x86_64,
# edk2-ovmf (/usr/share/edk2/x64), socat, Pillow; KVM se houver.
set -uo pipefail
source "$(dirname "$0")/lib.sh"
OUT=${1:-$ROOT/tests/results/vm-limine}
OVMF=/usr/share/edk2/x64
W=$(mktemp -d "${TMPDIR:-/tmp}/ts-vm.XXXXXX")     # caminho curto: socket Unix ≤ 108 bytes
trap 'pkill -f "ts-vm-limine-$$" 2>/dev/null; rm -rf "$W"' EXIT
mkdir -p "$OUT"
RES=1920x1080

for c in qemu-system-x86_64 socat; do command -v $c >/dev/null || { skip "VM" "$c ausente"; summary; exit 0; }; done
[[ -f $OVMF/OVMF_CODE.4m.fd ]] || { skip "VM" "edk2-ovmf ausente"; summary; exit 0; }
KVM=(); [[ -w /dev/kvm ]] && KVM=(-enable-kvm)

conf() {  # conf chave=valor…: o conf versionado com LIMINE_* trocados
  local f="$W/conf.$RANDOM" kv
  cp "$ROOT/config/terminal-soviet.conf" "$f"
  for kv in "$@"; do sed -i "s|^${kv%%=*}=.*|${kv%%=*}=\"${kv#*=}\"|" "$f"; done
  printf '%s\n' "$f"
}

# esp <nome> <conf>: ESP nova com o tema aplicado pelo instalador.
esp() {
  local e="$W/$1/esp"
  mkdir -p "$e/EFI/BOOT" "$W/$1/home/.cache/terminal-soviet/limine"
  cp /usr/share/limine/BOOTX64.EFI "$e/EFI/BOOT/"
  cp "$ROOT/tests/fixtures/limine.conf" "$e/limine.conf"
  [[ -d $HOME/.cache/terminal-soviet/limine/upstream ]] \
    && cp -r "$HOME/.cache/terminal-soviet/limine/upstream" "$W/$1/home/.cache/terminal-soviet/limine/"
  env -u XDG_CACHE_HOME -u XDG_STATE_HOME HOME="$W/$1/home" TS_BOOT_DIR="$e" TS_SUDO= TS_CONF_FILE="$2" \
    "$ROOT/scripts/install-limine-theme.sh" --install --yes > "$W/$1/instalar.log" 2>&1 \
    || { cat "$W/$1/instalar.log" >&2; return 1; }
  sed -i "1i interface_resolution: $RES" "$e/limine.conf"
  printf '%s\n' "$e"
}

# capturar <nome> <esp> [espera]: liga a VM, espera o menu e salva <saída>/<nome>.png.
capturar() {
  local nome=$1 e=$2 espera=${3:-7}
  cp "$OVMF/OVMF_VARS.4m.fd" "$W/vars-$nome.fd"
  timeout 40 qemu-system-x86_64 "${KVM[@]}" -name "ts-vm-limine-$$" -machine q35 -m 512 \
    -display none -monitor "unix:$W/mon-$nome,server,nowait" -net none \
    -drive if=pflash,format=raw,readonly=on,file="$OVMF/OVMF_CODE.4m.fd" \
    -drive if=pflash,format=raw,file="$W/vars-$nome.fd" \
    -drive file=fat:rw:"$e",format=raw,if=virtio > "$W/qemu-$nome.log" 2>&1 &
  local pid=$!
  sleep "$espera"
  echo "screendump $W/$nome.ppm" | socat - "UNIX-CONNECT:$W/mon-$nome" >/dev/null 2>&1
  sleep 0.5
  echo quit | socat - "UNIX-CONNECT:$W/mon-$nome" >/dev/null 2>&1
  wait "$pid" 2>/dev/null
  [[ -s $W/$nome.ppm ]] && python3 -I -c 'import sys; from PIL import Image; Image.open(sys.argv[1]).save(sys.argv[2])' \
    "$W/$nome.ppm" "$OUT/$nome.png"
}

# Média de cor de uma região (para conferir que o fundo aparece por trás do texto).
regiao() { python3 -I -c '
import sys; from PIL import Image; import numpy as np
a = np.asarray(Image.open(sys.argv[1]).convert("RGB")).astype(float)
x0, y0, x1, y1 = map(int, sys.argv[2:6]); r = a[y0:y1, x0:x1].reshape(-1, 3)
print(" ".join(f"{v:.0f}" for v in r.mean(axis=0)), f"{r.std(axis=0).mean():.1f}")' "$@"; }

section "Variantes (capturas em ${OUT#"$ROOT"/})"
for v in fosforo ambar fallout; do
  e=$(esp "$v" "$(conf LIMINE_THEME=$v LIMINE_ORIGEM=arte)") || { fail "variante $v (instalar)"; continue; }
  capturar "$v" "$e"
  if [[ -s $OUT/$v.png ]]; then
    read -r w h < <(python3 -I -c 'import sys; from PIL import Image; print(*Image.open(sys.argv[1]).size)' "$OUT/$v.png")
    check "variante $v: menu capturado em $RES" test "${w}x$h" = "$RES"
    # Faixa sem texto à direita do menu: varredura visível = desvio entre linhas > 0.
    read -r _ _ _ desvio < <(regiao "$OUT/$v.png" 1500 400 1800 700)
    check "variante $v: papel de parede aparece (varredura visível atrás do terminal)" \
      awk -v d="$desvio" 'BEGIN { exit !(d > 2) }'
  else
    fail "variante $v: sem captura" "$(tail -3 "$W/qemu-$v.log")"
  fi
done

section "Fundo do zero e fonte do upstream"
e=$(esp zero "$(conf LIMINE_ORIGEM=zero)") && capturar zero "$e" && check "fundo do zero: capturado" test -s "$OUT/zero.png"
e=$(esp phxega "$(conf LIMINE_ORIGEM=arte LIMINE_FONTE=phxega)") && capturar phxega "$e" && check "fonte phxega: capturado" test -s "$OUT/phxega.png"

section "Falhas: hash errado e fonte ausente"
e=$(esp hash "$(conf LIMINE_ORIGEM=arte)") && printf 'x' >> "$e/ts-limine-fonte.f14" && capturar hash-errado "$e" \
  && check "hash errado: capturado (ver a tela)" test -s "$OUT/hash-errado.png"
e=$(esp ausente "$(conf LIMINE_ORIGEM=arte)") && rm "$e/ts-limine-fonte.f14" && capturar fonte-ausente "$e" \
  && check "fonte ausente: capturado (ver a tela)" test -s "$OUT/fonte-ausente.png"

section "Cirílico (CP866)"
# Fonte CP866 (ter-k14n + ter-i14n) e o nome da entrada gravado em CP866.
e=$(esp cirilico "$(conf LIMINE_ORIGEM=arte LIMINE_TITULO=)") && {
  K=/usr/share/kbd/consolefonts
  python3 -I "$ROOT/scripts/limine-font.py" "$e/ts-limine-fonte.f14" "$K/ter-k14n.psf.gz" "$K/ter-i14n.psf.gz" --pagina cp866 >/dev/null
  h=$(b2sum "$e/ts-limine-fonte.f14" | cut -d' ' -f1)
  sed -i "s|^term_font: boot():/ts-limine-fonte.f14#.*|term_font: boot():/ts-limine-fonte.f14#$h|" "$e/limine.conf"
  python3 -I - "$e/limine.conf" <<'PY'
import sys
p = sys.argv[1]
d = open(p, "rb").read()
d = d.replace(b"/+Omarchy", "/+ТЕРМИНАЛ СОВЕТСКИЙ".encode("cp866"), 1)
d = d.replace(b"//linux-omarchy\n", "//Ядро linux-omarchy\n".encode("cp866"), 1)
open(p, "wb").write(d)
PY
  capturar cirilico "$e"
  check "cirílico CP866: capturado (ver a tela)" test -s "$OUT/cirilico.png"
}

summary
