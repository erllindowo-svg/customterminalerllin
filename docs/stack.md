# Stack, dependências e compatibilidade

Verificado em **2026-10-12** numa única máquina: Omarchy sobre Arch Linux,
Ryzen 5 1600, GTX 1660 SUPER (driver NVIDIA 610.57), monitor único HDMI-A-1
1920×1080 com escala 1,333.

## Matriz de compatibilidade

O `install.sh` aplica esta matriz (`lib/compat.sh`, variável `VERIFIED`):

| Componente | Verificado | Aceito com aviso | Fora disso |
|---|---|---|---|
| Omarchy (pacote `omarchy`) | **4.0.4-1** | 4.x | para (ou `--accept-untested`) |
| Hyprland | **0.56.2** | 0.56.x | para |
| Noctalia | **5.0.1** | 5.x | para |
| Quickshell (shell do Omarchy) | **0.3.1** | 0.3.x | para |
| foot | **1.28.0** | 1.x | para |
| btop | **1.4.7** | 1.x | para |
| arttime | **2.5.0** (commit `38c2955`) | 2.5.x | para |

Além das versões, o instalador confere **pontos de integração** (detecção de
recurso). Se algum faltar, ele para antes de alterar qualquer arquivo:

| Ponto de integração | Onde o projeto depende dele | Como é verificado |
|---|---|---|
| Hyprland configurado em Lua pelo Omarchy | módulo `~/.config/hypr/terminal_soviet.lua` | `$OMARCHY_PATH/default/hypr/bootstrap.lua` existe |
| `hyprland.lua` do usuário carrega os padrões | bloco `require("hypr.terminal_soviet")` | `require("default.hypr.omarchy")` no arquivo |
| Helpers `o.bind`, `o.window`, `o.exec_on_start` | atalhos, regras, autostart | definições em `$OMARCHY_PATH/default/hypr/helpers.lua` |
| Layouts por workspace | dwindle no workspace da central | `default/hypr/workspace-layouts.lua` lê `~/.local/state/omarchy/workspace-layouts` |
| Barra selecionável do shell (`bar.id`, plugin `kind: "bar"`) | barra nula `erllan.sem-barra` | `bar.id` em `$OMARCHY_PATH/shell/README.md` e `cmd_use` em `omarchy-bar` |
| `~/.config/omarchy/shell.json` versão 1 | `bar.id`/`bar.position` | `jq .version` |
| Noctalia com IPC | `noctalia msg bar-hide/bar-show`, painéis | `noctalia --help` lista `msg` |

### Diferenças conhecidas entre versões

* **Instalações do Omarchy configuradas por `hyprland.conf` (hyprlang)**, e
  não por Lua, não são suportadas. Não verifiquei em que versão a troca
  aconteceu; só a 4.0.4 foi testada. Os scripts usam a sintaxe de dispatch Lua
  (`hyprctl dispatch 'hl.dsp.focus({...})'`) e não funcionam lá. Não há
  adaptador: o instalador para no primeiro ponto de integração.
* **Noctalia 5.0.1**: `tooltip` em `ui.column` exige `plugin_api` 32 (não
  suportado aqui); `bar-hide <barra> <monitor>` responde "ok" mas não oculta
  (por isso a barra segue o monitor focado); `hidden_workspaces` do taskbar
  ainda não existe (por isso o plugin `erllan/tarefas`). Versões novas do
  Noctalia podem tornar o plugin desnecessário: reavalie antes de aceitar a 6.x.
* **Shell do Omarchy**: se a interface de plugins `bar` mudar e a barra nula
  falhar, o shell volta sozinho para `omarchy.bar` (comportamento documentado),
  e passam a existir duas barras. É visível e não quebra a sessão.

## Dependências

Todas são pacotes oficiais do Arch/Omarchy, exceto as marcadas como "git
fixado". O instalador **não instala pacotes** (não usa sudo). Ele lista os que
faltam com o comando `omarchy pkg add …`.

| Comando | Pacote (versão verificada) | Origem | Obrigatória | Função | Verificar |
|---|---|---|---|---|---|
| `hyprctl` | hyprland 0.56.2-2 | extra | sim | compositor, IPC, eventos | `hyprctl version` |
| `omarchy` | omarchy 4.0.4-1 | extra (Omarchy) | sim | `omarchy bar`, `omarchy plugin` | `omarchy version` |
| `noctalia` | noctalia 5.0.1-1 | extra | sim | barra, control center, clima, sysmon | `noctalia --version` |
| `quickshell` | quickshell 0.3.1-1 | extra | sim (do Omarchy) | notificações, lock, OSD, menus | `pacman -Q quickshell` |
| `foot` | foot 1.28.0-1 | extra | sim | terminal dos painéis | `foot --version` |
| `btop` | btop 1.4.7-1 | extra | sim | monitoramento | `btop --version` |
| `fastfetch` | fastfetch 2.68.1-1 | extra | sim | painel de sistema | `fastfetch --version` |
| `jq` | jq 1.8.2-1 | extra | sim | JSON do `hyprctl` | `jq --version` |
| `socat` | socat 1.8.1.3-1 | extra | sim | eventos do socket2 | `socat -V` |
| `uwsm-app` | uwsm 0.26.7-1 | extra | sim | lançar apps na sessão | `uwsm --version` |
| `flock`, `setsid`, `logger` | util-linux 2.42.3-1 | core | sim | travas, desacoplar janelas, journal | — |
| `perl` | perl 5.42.2-2 | core | sim | índice e filtro de cores | `perl -v` |
| `zsh` | **zsh 5.9.2-1** | extra | sim | o arttime exige zsh ≥ 5.7 (instalado na Fase 1; **não** é o shell de login) | `zsh --version` |
| `git` | git 2.55.0-1 | extra | sim | arttime e omarchy-overview fixados em commit | — |
| `systemctl` | systemd | core | sim | serviços do usuário | — |
| `playerctl` | playerctl 2.4.1-5 | extra | não | widget do Spotify | `playerctl -l` |
| `fzf` | fzf 0.74.3-1 | extra | não | tecla `x` do arttime | — |
| `nvidia-smi` | nvidia-utils | extra | não | sensores de GPU na barra (`GPU_SENSORS=auto`) | — |
| `luac`, `luajit`, `python3`, `wtype`, `grim` | lua, luajit, python, wtype, grim | extra | só testes | sintaxe, pty, teclas, capturas | — |
| `shellcheck` | shellcheck | extra | só testes (opcional) | análise dos scripts; **não instalado** hoje | — |

Fonte: `JetBrainsMono Nerd Font` (vem com o Omarchy). Ícones: `btop.svg` e
`foot.svg` em `/usr/share/icons/hicolor/scalable/apps` (dos pacotes btop e
foot). Os links `soviet-*.svg` só são criados se eles existirem.

### Dependências externas fixadas em commit

| Projeto | Commit | Instalado por | Destino | Conferência |
|---|---|---|---|---|
| [poetaman/arttime](https://github.com/poetaman/arttime) 2.5.0 | `38c2955a7c16d6900cc121265595347266b18af8` (2026-08-18) | `scripts/install-arttime.sh` → `./install.sh --local --noupdaterc --zcompdir -` do próprio arttime | código em `~/.local/src/arttime`; `~/.local/bin/{arttime,artprint}`; `~/.local/share/arttime/{src,textart,keypoems,doc}`; `~/.local/share/man/man1` | `git rev-parse HEAD` igual ao fixado; `arttime --version` = 2.5.0; 516 arquivos em `textart/` |
| [itsmoorgrove/omarchy-overview](https://github.com/itsmoorgrove/omarchy-overview) | `1ed4938a2382a6121255d6bfb9c3d0fdeb5ce9ff` | `install.sh` (git clone + checkout) | `~/.config/omarchy/plugins/moorgrove.overview` | `omarchy plugin validate` |

Atualizar uma delas = trocar o commit em `install.sh` (`ARTTIME_COMMIT`,
`OVERVIEW_COMMIT`) depois de revisar o diff do upstream e rodar os testes.

### Como o projeto encontra a coleção do arttime

`soviet-arte` usa `ARTTIME_SHARE=~/.local/share/arttime` (padrão do
`install.sh --local`) e `ARTPRINT=~/.local/bin/artprint`; os dois podem ser
trocados por variável de ambiente. A frase de cada arte é a **1ª linha do
arquivo** em `textart/`, a mesma associação que o `artprint` e o `arttime`
usam. O índice (`~/.cache/terminal-soviet/arte-indice.tsv`) é refeito quando
o diretório da coleção muda.
