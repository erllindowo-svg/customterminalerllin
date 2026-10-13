# Tema do menu de boot (Limine)

Opcional e separado do `./install.sh`. Deixa o menu do Limine com cara de tela
CRT: fundo com linhas de varredura e moldura arredondada, fonte de terminal
bitmap, o texto da tela RobCo do Fallout no topo e o verde dela. Baseado no
[fallout-limine-theme](https://github.com/Neptune3013/fallout-limine-theme)
(Limine v12), sem a arte de terceiros.

| Variante (`LIMINE_THEME`) | Texto | Destaque | Uso |
|---|---|---|---|
| `robco` (padrão) | `69D87A` | `A6F5B2` | o verde do texto da tela RobCo (medido na arte) |
| `fosforo` | `B8D58A` | `D2E8AE` | o verde do tema |
| `ambar` | `C9B26B` | `DCC88A` | clima de dosímetro |
| `fallout` | `67d97a` | `16de6d` | valores originais do upstream, para comparar |

As capturas da VM ficam em `tests/results/vm-limine/` (geradas por
`tests/vm-limine.sh`; não versionadas).

## O que o tema muda

1. **`/boot/limine.conf`**: um bloco no topo, entre
   `# >>> terminal-soviet limine >>>` e `# <<< terminal-soviet limine <<<`, com
   `timeout`, `remember_last_entry`, `wallpaper` (com `#b2sum`), `term_font`
   (com `#b2sum`), `term_font_size`, `term_font_scale`, `term_margin`,
   `term_background` (com transparência), `term_foreground*`, `term_palette*`,
   `backdrop`, `interface_branding:` vazio, `interface_help_hidden` e as cores
   `interface_*`. As chaves de aparência que o Omarchy põe no cabeçalho saem
   dele (chave repetida no Limine é ambígua). `default_entry` e todas as entradas
   (`/…`, geradas pelo `limine-entry-tool` e pelo `limine-snapper-sync`) ficam
   byte a byte.
2. **`/boot/ts-limine-fundo.png`** e **`/boot/ts-limine-fonte.f14`**.

Nada mais: nem o binário EFI, nem as entradas, nem outros arquivos.

## Instalar

```bash
scripts/install-limine-theme.sh            # = --plan: gera tudo, mostra o diff, não escreve no /boot
scripts/install-limine-theme.sh --install  # backup datado, grava, confere, limine-update + limine-snapper-sync
scripts/install-limine-theme.sh --status   # aplicado? hashes batem? o Omarchy sobrescreveu?
```

O script pede **sudo** porque a ESP (`/boot`, vfat com `fmask=0077`) só é
legível e gravável por root. Isso vale até para o `--plan` e o `--status`, que
só leem. A fonte e o papel de parede são gerados como usuário, num diretório
temporário.

Preferências em `config/terminal-soviet.conf`:

| Chave | Valores | Padrão |
|---|---|---|
| `LIMINE_THEME` | `robco`, `fosforo`, `ambar`, `fallout` | `robco` |
| `LIMINE_ORIGEM` | `arte` (tela CRT do fallout-grub-theme sem o Vault Boy e o texto), `zero` (desenhada, sem arte de terceiros) | `arte` |
| `LIMINE_FONTE` | `terminus` (Terminus IBM-437, OFL), `phxega` (PHXEGA8.F14 do upstream) | `terminus` |
| `LIMINE_RESOLUCAO` | `LxA` do monitor; define também a escala da fonte (altura ÷ 540) | `1920x1080` |
| `LIMINE_TITULO` | texto no topo do papel de parede (CP437 com acentos ou cirílico; `\|` separa linhas); vazio = sem | o texto da tela RobCo (3 linhas) |
| `LIMINE_TIMEOUT` | segundos | `15` |

Mudou algo? `--install` de novo: o bloco é substituído, nunca duplicado, e se
nada mudou o script diz que já está aplicado e não escreve.

Dependências: `python-pillow`, `python-numpy`, `terminus-font`, `b2sum`
(coreutils), `curl` (só para `LIMINE_ORIGEM=arte` e `LIMINE_FONTE=phxega`, com
SHA-256 conferido; ficam em cache em `~/.cache/terminal-soviet/limine/`).

## Remover

```bash
scripts/install-limine-theme.sh --remove
```

Se as entradas não mudaram desde a instalação, volta o backup mais recente
(`/boot/limine.conf.terminal-soviet-<data>.bak`) byte a byte. Se mudaram (kernel
novo, snapshots), tira só o bloco e devolve as chaves originais do Omarchy
(guardadas em `~/.local/state/terminal-soviet/limine/chaves-originais.conf`).
Apaga a fonte e o papel de parede; os backups ficam.

## Riscos e o que foi testado

| Situação | Efeito (observado na VM) | O que fazer |
|---|---|---|
| fonte ausente no `/boot` | o Limine usa a fonte embutida; papel de parede e cores continuam | `--install` |
| **fonte ou papel de parede alterados** (hash não confere) | **tela toda preta, sem mensagem, esperando tecla**; `Y` segue para o menu normal | apertar `Y`; depois `--status` e `--install` |
| `omarchy-refresh-limine` | troca o `limine.conf` pelo modelo (o tema some; o boot segue com a aparência do Omarchy) | `--status` mostra **SOBRESCRITO**; `--install` |
| upgrade do Omarchy (`sed` nas cores) | chaves `interface_*` reaparecem fora do bloco | `--status` avisa; `--install` |
| `limine-update` reescrever o cabeçalho | não esperado (os temas do upstream contam com isso); o `--install` confere depois e para se o bloco sumir | o backup está ao lado |
| Limine fora da v12, `limine.conf` ausente, config legada em `EFI/limine/` etc. | o script recusa antes de escrever | — |

Com Secure Boot e um hash de config registrado no binário, `hash_mismatch_panic`
vira `yes` à força: aí um hash errado trava o boot. Nesta máquina o Secure Boot
está desligado e o Omarchy não registra o hash da config.

**Texto fora do ASCII.** O Limine v12 lê o `limine.conf` em UTF-8 e desenha em
CP437. Acentos que existem no CP437 funcionam (é, ç, ü, ñ, É…, não ã/õ). Cirílico
em UTF-8 vira blocos. Com uma fonte CP866 e o texto gravado nos caracteres CP437
das mesmas posições, o cirílico aparece, mas os acentos latinos somem. Como as
entradas vêm do Omarchy, o projeto só usa isso no **título**, desenhado no papel
de parede com uma fonte CP866 própria; o menu continua em CP437.

**Resolução.** O papel de parede é gerado para `LIMINE_RESOLUCAO` e esticado
(`wallpaper_style: stretched`) para o modo de vídeo que o firmware entregar. O
projeto não força `interface_resolution`.

## Reaplicar sozinho (proposta, não instalada)

O `--status` detecta quando o Omarchy sobrescreve o tema. Para reaplicar
automaticamente, há duas opções (nenhuma é instalada pelo projeto):

* hook do pacman em `/etc/pacman.d/hooks/`, depois de transações com `limine` ou
  `omarchy`, rodando o script como o usuário com `--install --yes`;
* unit `path` do systemd vigiando `/boot/limine.conf`.

As duas rodam como root e reescrevem a ESP sem perguntar; por isso ficam a seu
critério.

## Recuperação

Se o menu ficar ilegível ou o boot não seguir:

1. **No próprio menu**: `Y` continua depois de um aviso de hash; `E` edita a
   entrada selecionada só para esse boot.
2. **No sistema**: `sudo cp /boot/limine.conf.terminal-soviet-<data>.bak /boot/limine.conf`
   (ou `scripts/install-limine-theme.sh --remove`).
3. **Live USB do Arch/Omarchy**: monte a ESP (`mount /dev/sdXN /mnt`; a ESP é a
   partição vfat) e copie o backup de volta:
   `cp /mnt/limine.conf.terminal-soviet-<data>.bak /mnt/limine.conf`. Há uma cópia
   fora da ESP em `~/.local/state/terminal-soviet/limine/backups/` (precisa do
   disco do sistema montado e, com criptografia, aberto com `cryptsetup open`).
4. Apagar o bloco entre os marcadores também basta: o Limine volta à aparência
   padrão.

## Testes

* `tests/limine.sh`: `/boot` falso (cabeçalho do Omarchy + entradas no formato do
  `limine-entry-tool`), sem sudo: planejar, instalar, reinstalar, trocar variante,
  Omarchy sobrescrevendo, chave reinserida, hash errado, fonte ausente, remover
  (com e sem entradas novas), recusas, as três variantes e o fundo a partir da arte.
* `tests/vm-limine.sh`: QEMU + OVMF com o `BOOTX64.EFI` do sistema e uma ESP
  servida pelo vvfat; capturas das variantes, do fundo do zero, da fonte do
  upstream, do hash errado, da fonte ausente e do texto acentuado e cirílico.
* `tests/static.sh`: sintaxe, shellcheck e a garantia de que toda escrita com
  privilégio do instalador vai para `$BOOT_DIR`.
