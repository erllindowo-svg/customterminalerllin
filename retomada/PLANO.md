# Plano — tema de boot do Limine (AGUARDA APROVAÇÃO)

## Achados (2026-10-13)

**Sistema**
- Limine **12.8.0** (`limine --version`), `limine-mkinitcpio-hook` 1.38.0, `limine-snapper-sync` 1.31.0.
- ESP = `/dev/sda1` vfat montada em **`/boot`** (`ESP_PATH="/boot"` em `/etc/default/limine`),
  então `boot():/` = raiz da ESP = `/boot`. Montada com `fmask=0077,dmask=0077`: **sem root
  não dá nem para LER** `/boot/limine.conf`. Consequência: `--plan` e `--status` também
  precisam de sudo (só leitura: `sudo cat`/`sudo test`), não só a escrita.
- Secure Boot **desligado** (`bootctl status`). `ENABLE_ENROLL_LIMINE_CONFIG` não está ligado
  (o hash do limine.conf não é gravado no binário EFI), mas `/etc/limine-entry-tool.conf`
  tem `ENABLE_VERIFICATION=yes` (hash nas entradas). Gravamos o `b2sum` em `wallpaper` e
  `term_font` mesmo assim (custa nada, e protege se o Secure Boot for ligado depois).
- Modelo do Omarchy: `/usr/share/omarchy/default/limine/limine.conf` (cabeçalho com
  `default_entry: 2`, `interface_branding*`, `interface_help_color*`, `hash_mismatch_panic: no`,
  `term_background`, `backdrop`, `term_palette*`, `term_foreground*`, `term_background_bright`).
  `omarchy-refresh-limine` faz `mv limine.conf limine.conf.bak` + copia o modelo + `limine-update`
  + `limine-snapper-sync`. `omarchy-upgrade-to-quattro` (`normalize_limine_config`) mexe em
  `interface_branding_color` e `interface_help_color*` com `sed`, e remove configs legadas:
  `/boot/EFI/arch-limine/limine.conf`, `/boot/EFI/limine/limine.conf`, `/boot/EFI/BOOT/limine.conf`,
  `/boot/limine/limine.conf`.
- `limine-update` = `limine-install --no-efi-register` + `limine-mkinitcpio` (binários;
  regravam as entradas). Preservação do cabeçalho: verificar na VM/sandbox (risco R2).
- Ausentes: `qemu-system-x86_64`, `edk2-ovmf`, `python-pillow`, `python-numpy`, `shellcheck`
  (e `mtools`, desnecessário: a VM usa o `vvfat` do QEMU, `-drive file=fat:rw:<dir>`).
- Monitor: 1920×1080 (HDMI-A-1), escala 4/3 no Hyprland (irrelevante para o boot).

**Referências** (lidas por `gh api`, nada clonado)
- `Neptune3013/fallout-limine-theme` @ `9a777b9` (MIT, 2026). `Limine.txt` lido inteiro.
  `term_background: 9935453b` (TT=99 → ~60 % transparente; o comentário "99 %" do upstream
  está errado: no Limine TT=00 é opaco e FF transparente, CONFIG.md v12).
  `term_background_bright: ffffff` — chave que o próprio autor não sabe para que serve.
  Script CachyOS: marcadores BEGIN/END, remove chaves do tema por regex antes de inserir,
  backup ao lado do script, `b2sum` só com Secure Boot, `limine-enroll-config` se
  `ENABLE_ENROLL_LIMINE_CONFIG=yes`, verificação final por grep.
- `magicdude4eva/fallout-limine-theme` @ `693365d` (MIT): `setup.sh` — backup `.bak-<tema>`,
  `sed -i "/^$key:/d"` das chaves antes de inserir, `b2sum` no wallpaper. Cores inconsistentes
  (`term_background: ffffffff`): não copiadas.
- **Origem real da arte**: `high-res-bg/background.png` (SHA-256 `224e4ff6…3906`) é
  byte a byte o `background.png` de `shvchk/fallout-grub-theme` @ `b441e25` (repositório MIT,
  mas a arte — Vault Boy, RobCo — é da Bethesda/ZeniMax; a licença do repositório não cobre
  isso). `background.jpg` (`5f0d400f…fd2f`) é a versão comprimida, 1920×1080.
- **Fonte `PHXEGA8.F14`** (`4811ac4e…2537`, 3584 B = 256 × 14): aparenta ser dump da ROM EGA
  da Phoenix; nenhum dos repositórios declara origem nem licença. → **não entra no repositório.**
- Coordenadas do pedido conferidas na imagem: Vault Boy ≈ x 1400–1870, y 540–1030; texto
  RobCo ≈ y 40–135, x 580–1290.

## Decisões propostas

1. **Fonte padrão livre, gerada na instalação**: `scripts/limine-font.py` (Python puro, sem
   dependências) converte uma fonte PSF com tabela Unicode em fonte crua de 256 glifos
   **na ordem CP437** (ou CP866, para o teste de cirílico), consultando o Unicode de cada
   posição da página de código. Fonte de origem: **Terminus 8×14** (`ter-114n.psf.gz`, pacote
   `terminus-font`, SIL OFL 1.1). Nada de fonte binária no repositório.
   Opção `LIMINE_FONTE="phxega"`: baixa o `PHXEGA8.F14` do upstream por commit fixo + SHA-256
   (licença incerta, escolha consciente do usuário, nunca versionado).
2. **Papel de parede**: `scripts/limine-wallpaper.py` (Pillow + numpy). Modo padrão parte do
   PNG de `shvchk/fallout-grub-theme@b441e25` (SHA-256 conferido), remove Vault Boy e texto
   pela mediana de linha (faixa limpa x 300–1100), máscara dilatada 4 px, moldura preservada,
   `--titulo` opcional (desenhado com a própria fonte do boot, ASCII), recolore para a variante
   (fósforo/âmbar/original) e redimensiona para `LIMINE_RESOLUCAO`. `--gerar-do-zero` desenha
   varredura + vinheta + moldura arredondada sem a arte. Imagem só em `/boot` e num cache
   local (`~/.cache/terminal-soviet/limine/`), nunca no repositório.
3. **Paleta** `LIMINE_THEME="fosforo|ambar|fallout"` em `config/terminal-soviet.conf`
   (+ `LIMINE_RESOLUCAO="1920x1080"`, `LIMINE_FONTE="terminus|phxega"`,
   `LIMINE_TITULO=""`, `LIMINE_TIMEOUT="5"`, `LIMINE_ORIGEM="arte|zero"`):
   - fosforo: `term_foreground B8D58A`, `term_foreground_bright D2E8AE`,
     `interface_help_color 718D58`, `interface_help_color_bright D2E8AE`,
     `interface_branding_color B8D58A`, `backdrop 101210`, `term_background 99101210`
     (transparência validada na VM), `term_palette` = 101210;BD4A42;B8D58A;C9B26B;7F9A88;A27B76;8FB09A;C8CBBF,
     `term_palette_bright` = 444B42;D2625A;D2E8AE;DCC88A;9FB8A6;BE9A94;AECBB8;E2E5D8;
   - ambar: texto C9B26B, destaque DCC88A, ajuda 8A7A48, fundo 101210, paleta com os
     amarelos/laranjas do tema;
   - fallout: valores do `Limine.txt` do Neptune (comparação), papel de parede sem recolorir.
   - `term_font_scale` calculado: `max(1, altura // 540)` → 2×2 em 1080p, 1×1 em 768p,
     4×4 em 2160p. `term_margin: 0`, `interface_branding:` vazio, `interface_help_hidden: yes`,
     `remember_last_entry: yes`.
4. **Instalador separado** `scripts/install-limine-theme.sh` (não toca no `install.sh`):
   `--plan` (padrão) · `--install` · `--remove` · `--status`; `BOOT_DIR` sobrescrevível
   (só para testes/VM). Fluxo do `--install`:
   1. recusa se `limine --version` ∉ 12.x (matriz em `lib/compat.sh`), se faltar
      `$BOOT_DIR/limine.conf` ou se existir qualquer config legada da lista acima;
   2. gera fonte + papel de parede como usuário comum, em diretório temporário;
   3. monta o novo `limine.conf` em `/tmp`: tira do cabeçalho (antes da 1ª linha `/`) as
      chaves do tema e as do Omarchy listadas no pedido (`interface_branding*`,
      `interface_help_*`, `term_*`, `backdrop`, `hash_mismatch_panic`, `timeout`,
      `remember_last_entry`, `wallpaper*`), remove bloco antigo entre marcadores, e insere
      `# >>> terminal-soviet limine >>>` … `# <<< terminal-soviet limine <<<` no topo
      (mantém `default_entry`; reescreve `hash_mismatch_panic: no` dentro do bloco);
      tudo da 1ª entrada `/` para baixo fica **byte a byte igual** (conferido por `cmp`);
   4. mostra o diff e pede sudo (`sudo -v`, com a explicação);
   5. backup datado `/boot/limine.conf.terminal-soviet-<AAAAMMDD-HHMMSS>.bak` + cópia
      fora da ESP em `~/.local/state/terminal-soviet/limine/` (para restaurar por live USB);
   6. copia `ts-boot.png` e `ts-font.f14` para `/boot`, grava `#<b2sum>` nas duas linhas;
   7. grava o novo `limine.conf` (cópia atômica), confere: arquivo parseável (chaves
      conhecidas, marcadores únicos, nenhuma chave duplicada no cabeçalho), entradas
      idênticas às de antes, hashes batem;
   8. `limine-update` e `limine-snapper-sync`, e confere de novo que o bloco sobreviveu.
   `--remove`: restaura o backup mais recente **só se** as entradas forem iguais às atuais;
   senão tira o bloco e devolve as chaves originais do Omarchy (guardadas no backup).
   `--status`: aplicado? hashes batem? marcadores presentes? Omarchy sobrescreveu (sem
   marcadores + `limine.conf.bak` mais novo, ou cores do Omarchy de volta)? → propõe reaplicar.
5. **Reaplicação automática**: só proposta (hook do pacman em `limine`/`omarchy` ou
   `systemd` path unit em `/boot/limine.conf`). Nada instalado sem você pedir.

## Arquivos

Novos: `scripts/install-limine-theme.sh`, `scripts/limine-wallpaper.py`,
`scripts/limine-font.py`, `docs/boot-theme.md`, `tests/limine.sh` (sandbox com
`limine.conf` falso: instalar, reinstalar, remover, Omarchy sobrescrevendo, hash errado,
fonte ausente, config legada, versão errada), `tests/vm-limine.sh` (QEMU + OVMF + vvfat,
`screendump` das variantes), `tests/fixtures/limine.conf` (cabeçalho do Omarchy + entradas
falsas no formato do `limine-entry-tool`).
Alterados: `config/terminal-soviet.conf` (chaves `LIMINE_*`), `lib/ts-lib.sh` (validação),
`lib/compat.sh` (matriz Limine 12.x, pins dos ativos), `tests/static.sh` (bash -n,
shellcheck se houver, `py_compile`, e grep que garante que o instalador só escreve em
`$BOOT_DIR`, no backup e em `/tmp`), `README.md`, `docs/decisions.md` (D19),
`docs/file-map.md`, `docs/stack.md`, `THIRD_PARTY.md`.

## Riscos

- R1 boot feio/ilegível → backup + recuperação documentada (editor do Limine `E`, shell
  do UEFI, live USB montando a ESP).
- R2 `limine-update`/`limine-snapper-sync` reescrevem o cabeçalho → testado na VM/sandbox;
  se reescreverem, a reaplicação vira obrigatória e documentada.
- R3 resolução do GOP ≠ 1920×1080 → `wallpaper_style: stretched` (padrão); escala da fonte
  calculada para a resolução configurada; opção `interface_resolution` (pergunta Q4).
- R4 cirílico: CP437 não tem cirílico; o teste CP866 é só na VM e só de exibição (o Limine
  não converte UTF-8, então o texto teria de estar gravado em CP866 no limine.conf).

## Perguntas (Q)

- Q1 Posso instalar as dependências de teste? `sudo pacman -S qemu-base edk2-ovmf
  python-pillow python-numpy terminus-font shellcheck` (sem elas não há VM, capturas nem
  gerador). Alternativa para Pillow/numpy: venv em `~/.cache`.
- Q2 Fonte padrão Terminus (livre) e `phxega` só como opção — ok?
- Q3 `--plan`/`--status` precisam de sudo só para LER o `/boot` (vfat 0077) — ok?
- Q4 Forçar `interface_resolution: 1920x1080` no boot real (fica nítido, mas se o firmware
  não tiver o modo o Limine cai no padrão)?
- Q5 `timeout`: o Omarchy usa o padrão do Limine (5 s, `#timeout: 3` comentado); o Fallout usa 15.
  Proposta: 5.
