# Mapa de arquivos

Legenda da coluna **V** (versionamento):
**R** = versionado no repositório · **G** = gerado na instalação a partir de um
modelo `.in` · **L** = estado/cache local, nunca versionado · **D** = obtido
como dependência (pacote ou git fixado), nunca versionado.

## Árvore do repositório

```
customterminalerllin/
├── README.md  THIRD_PARTY.md  .gitignore
├── install.sh                      instalador (check | install | status | uninstall)
├── config/terminal-soviet.conf     preferências pessoais
├── lib/
│   ├── ts-lib.sh                   configuração, marcadores, renderização, tabela de destinos
│   └── compat.sh                   matriz de versões, dependências, pontos de integração
├── bin/                            → ~/.local/bin
│   ├── soviet-ops                  compõe/restaura a central (grade dwindle, 4 painéis foot)
│   ├── soviet-ops-fetch            painel: fastfetch + área de ilustração
│   ├── soviet-ops-clock            painel: relógio grande, data, clima (cache do Noctalia)
│   ├── soviet-inspect              btop flutuante sob demanda (abre/fecha/traz)
│   ├── soviet-arte                 ilustração: seleção, desenho, cores, menu, arttime interativo
│   ├── soviet-bar-sync             visibilidade da barra por workspace (eventos)
│   └── soviet-launch-or-focus      foca a janela de classe exata ou abre (lançadores da barra)
├── share/terminal-soviet/arte/     → ~/.local/share/terminal-soviet/arte
│   ├── cores-tema.pl               "Tema do terminal": reescreve cores SGR para a rampa fósforo
│   └── artprint-shim               bin/artprint da árvore temporária do arttime interativo
├── hypr/terminal_soviet.lua.in     → ~/.config/hypr/terminal_soviet.lua (autostart, regras, atalhos)
├── noctalia/
│   ├── config/                     → ~/.config/noctalia
│   │   ├── 00-coexistencia-omarchy.toml   desliga no Noctalia o que o shell do Omarchy faz
│   │   ├── 10-tema-sovietico.toml         tema, fonte, cantos
│   │   ├── 20-barra.toml.in               barra e widgets (lançadores e GPU conforme a máquina)
│   │   ├── 30-monitoramento-clima.toml.in limiares do sysmon, endereço do clima
│   │   ├── 40-integracao-hyprland.toml    hook started → soviet-bar-sync --apply
│   │   ├── palettes/SovietTerminal.json   paleta
│   │   └── README.md
│   └── plugins/                    → ~/.local/share/noctalia/plugins
│       ├── tarefas/                favoritos + apps em execução (bar.luau.in, plugin.toml)
│       ├── volume-slider/          popup com um slider de volume
│       └── spotify-media/          fork MIT (LICENSE, upstream/, README.soviet.md)
├── omarchy/
│   ├── plugins/erllan.sem-barra/   → ~/.config/omarchy/plugins (barra nula: Bar.qml, manifest.json)
│   ├── themes/soviet-terminal/     → ~/.config/omarchy/themes (colors.toml, btop.theme, hyprland.lua,
│   │                                  icons.theme, neovim.lua, SOURCES.md; SEM backgrounds/preview)
│   └── workspace-layouts/central.lua.in → ~/.local/state/omarchy/workspace-layouts/<N>.lua
├── systemd/                        → ~/.config/systemd/user (noctalia.service, soviet-bar-sync.service)
├── btop/                           → ~/.config/btop (soviet-ops.conf, soviet-inspect.conf)
├── fastfetch/soviet-ops.jsonc      → ~/.config/fastfetch
├── migrate/phase1-inline.sh        remove os trechos manuais da Fase 1 (conferência por SHA-256)
├── scripts/
│   ├── install-arttime.sh          arttime no commit fixado (instalador oficial --local)
│   ├── fetch-backgrounds.sh        fotos do tema (Commons, SHA-1) + preview.png
│   ├── perf-sample.sh              amostragem /proc a 1 Hz
│   └── perf-run.sh                 cenários de desempenho
├── tests/
│   ├── run.sh                      orquestra e grava tests/results/ (ignorado pelo Git)
│   ├── lib.sh                      PASSOU/FALHOU/PULADO
│   ├── static.sh                   sintaxe, formatos, modelos, caminhos, segredos
│   ├── sandbox.sh                  instalador em HOMEs isolados
│   ├── live.sh                     sessão real (com e sem --disruptive)
│   └── pty_menu.py                 menu/arttime num pseudo-terminal
└── docs/
    ├── architecture.md  file-map.md  stack.md  controls.md  performance.md
    ├── backup-restore.md  installation-omarchy.md  decisions.md
    └── perf-data/2026-10-12-fase2/ dados brutos das medições (caminhos do $HOME trocados por ~)
```

## Destinos no sistema

| Destino | Origem | V | Observação |
|---|---|---|---|
| `~/.local/bin/soviet-*` | `bin/` | R | 0755 |
| `~/.local/share/terminal-soviet/arte/*` | `share/terminal-soviet/arte/` | R | |
| `~/.config/hypr/terminal_soviet.lua` | `hypr/terminal_soviet.lua.in` | G | atalhos e workspace de `config/` |
| `~/.config/hypr/hyprland.lua` | — | bloco | o instalador acrescenta 3 linhas marcadas (`require`) |
| `~/.config/noctalia/*.toml`, `palettes/`, `README.md` | `noctalia/config/` | R/G | `20-*` e `30-*` são gerados |
| `~/.local/share/noctalia/plugins/{tarefas,volume-slider,spotify-media}/` | `noctalia/plugins/` | R/G | `tarefas/bar.luau` é gerado |
| `~/.config/omarchy/plugins/erllan.sem-barra/` | `omarchy/plugins/` | R | |
| `~/.config/omarchy/shell.json` | — | chaves | `bar.id`, `bar.position` via `omarchy bar` |
| `~/.config/omarchy/themes/soviet-terminal/` | `omarchy/themes/` | R | `backgrounds/`, `preview.png`: **D** (`fetch-backgrounds.sh`) |
| `~/.local/state/omarchy/workspace-layouts/1.lua` | `omarchy/workspace-layouts/central.lua.in` | G | formato do toggle de layout do Omarchy |
| `~/.config/systemd/user/{noctalia,soviet-bar-sync}.service` | `systemd/` | R | |
| `~/.config/systemd/user/graphical-session.target.wants/*.service` | — | link | habilitação |
| `~/.config/btop/soviet-{ops,inspect}.conf` | `btop/` | R | `btop.conf` do usuário não é tocado |
| `~/.config/fastfetch/soviet-ops.jsonc` | `fastfetch/` | R | `/etc/fastfetch` não é tocado |
| `~/.config/terminal-soviet/terminal-soviet.conf` | `config/terminal-soviet.conf` | R | lido pelos scripts em tempo de execução |
| `~/.local/share/icons/hicolor/scalable/apps/soviet-*.svg` | — | link | → ícones do btop/foot do sistema (só se existirem) |
| `~/.local/src/arttime`, `~/.local/bin/{arttime,artprint}`, `~/.local/share/arttime/` | git fixado | D | `scripts/install-arttime.sh` |
| `~/.config/omarchy/plugins/moorgrove.overview/` | git fixado | D | omarchy-overview |
| `~/.local/state/terminal-soviet/install/` | — | L | manifesto, backups, `shelljson.prev` |
| `~/.local/state/terminal-soviet/arte.conf`, `arte-selecao` | — | L | modo de cores, política, conjunto da sessão |
| `~/.cache/terminal-soviet/arte-indice.tsv` | — | L | índice da coleção |
| `$XDG_RUNTIME_DIR/terminal-soviet/` | — | L | PID/área do painel, travas, árvore temporária do arttime, log de artes |
| `~/.local/state/noctalia/settings.toml` | — | L | ajustes feitos pela GUI do Noctalia (**vencem** os arquivos) |

## Fora do projeto (existem nesta máquina, não são versionados)

| Caminho | O que é |
|---|---|
| `~/terminal-sovietico-backups/fase1-*` | backup e linha de base da Fase 1 |
| `~/.local/share/terminal-soviet/{README.md,backups,legacy,art}` | documentação, backups e legado das fases 0–1 (o `art/globe.txt` é uma cópia de arte do arttime, por isso fica fora) |
| `~/.local/bin/soviet-monitor`, `~/.config/btop/soviet-monitor.conf` | painel legado do workspace 10, substituído pela central |
| `~/.local/share/applications/Discord.desktop` | ajuste de `StartupWMClass` de um web app (revisão 2), específico da máquina |
