# Arquitetura

O Terminal Soviético é uma camada sobre o Omarchy 4. Ele não substitui o
shell do Omarchy: usa só os pontos de extensão do usuário (`~/.config`,
`~/.local`) e serviços systemd do usuário.

```
                       ┌────────────────────────── sessão uwsm / Hyprland 0.56 (Lua) ──────────────────────────┐
                       │                                                                                         │
 ~/.config/hypr/       │  hyprland.lua ── require("default.hypr.omarchy")   (padrões do Omarchy)                  │
   hyprland.lua ───────┤               ── require("hypr.bindings") …        (arquivos do usuário)                 │
   terminal_soviet.lua │               ── bloco terminal-soviet → require("hypr.terminal_soviet")               │
                       │                     ├ o.exec_on_start  soviet-ops --login       (central no WS 1)         │
                       │                     ├ o.window         regras soviet-ops-*, soviet-inspect, soviet-arte   │
                       │                     └ o.bind           SUPER+M, SUPER+CTRL+M, SUPER+ALT+A, painéis        │
                       │                                                                                         │
 systemd --user        │  graphical-session.target                                                               │
   noctalia.service ───┤    ├ noctalia ─────────── barra "estacao" + control center + clima (sysmon desligado)│
   soviet-bar-sync ────┤    │    ├ plugin erllan/tarefas ── service: socat (socket2) → hyprctl│jq (sob evento)  │
                       │    │    ├ plugin erllan/audio ── service: pactl subscribe → pactl│jq (sob evento)       │
                       │    │    ├ plugin erllan/spotify-media                                                    │
                       │    │    ├ hook started → soviet-bar-sync --apply                                        │
                       │    │    └ idle (tempo da tela de descanso) → soviet-ops: volta à central                 │
                       │    └ soviet-bar-sync ── socat (socket2) → noctalia msg bar-hide|bar-show estacao        │
                       │                                                                                         │
 shell do Omarchy      │  quickshell (omarchy-launch-shell): notificações, lock, OSD, polkit, papel de parede,    │
   shell.json          │    menus. Barra = plugin nulo erllan.sem-barra (bar.id): não desenha nada.              │
                       └─────────────────────────────────────────────────────────────────────────────────────────┘
```

## Componentes

| Componente | Tipo | Vida | Papel |
|---|---|---|---|
| `noctalia` | serviço do usuário | permanente | a **única barra** (topo, 26 px), control center, launcher alternativo, clima (Open-Meteo); sysmon desligado |
| `soviet-bar-sync` | serviço do usuário (bash + socat) | permanente | oculta a barra no workspace da central (e onde houver janela de `COLLAPSE_CLASSES`), mostra nos demais. Orientado a eventos do socket2; só envia `bar-hide`/`bar-show` quando o estado desejado muda; nunca alterna às cegas |
| `erllan/tarefas` | plugin Luau do Noctalia | permanente (dentro do noctalia) | apps abertos (esq.) e fixados (dir.) fora do WS da central, com o ícone real; fixar/desafixar pelo clique direito. Um service com um `socat` no socket2 lê `hyprctl clients` só em eventos de janela/foco/workspace (1 leitura de segurança a cada 30 s) e alimenta os dois widgets |
| `erllan.sem-barra` | plugin QML do shell Omarchy | permanente (dentro do quickshell) | "barra nula" selecionada por `bar.id`: tira a barra do Omarchy e mantém o resto do shell |
| central (`soviet-ops`) | 4 janelas foot no WS 1 | da sessão | `btop` (soviet-ops-btop), `fastfetch` + **ilustração** (soviet-ops-fetch), relógio/clima (soviet-ops-clock), shell (soviet-ops-shell) |
| `soviet-inspect` | janela foot flutuante | sob demanda | btop detalhado (`SUPER+M`); abre no workspace atual, fecha com a mesma tecla |
| `soviet-arte` | CLI + janela foot flutuante | sob demanda | ilustração: seleção por sessão, desenho, modos de cores, menu e arttime interativo (`SUPER+ALT+A`) |

## Fluxo de inicialização (login)

1. O uwsm inicia o Hyprland. O `hyprland.lua` carrega os padrões do Omarchy,
   os arquivos do usuário e, por fim, o módulo `terminal_soviet.lua`, que
   registra regras, atalhos e `exec_on_start`.
2. O `graphical-session.target` sobe `noctalia.service` e
   `soviet-bar-sync.service` (habilitados por links em
   `~/.config/systemd/user/graphical-session.target.wants/`).
3. O hook `started` do Noctalia roda `soviet-bar-sync --apply`, que aplica o
   estado da barra para o workspace ativo. O Noctalia sempre inicia com a
   barra visível.
4. O `exec_on_start` roda `soviet-ops --login`, que vai ao WS 1 e compõe a
   grade (layout dwindle, garantido por
   `~/.local/state/omarchy/workspace-layouts/1.lua`):
   btop → preselect r → fetch → preselect d no btop → shell → preselect d no
   fetch → relógio. Depois ajusta as proporções (62 %/38 %, 72 % de altura).
   Uma trava (`flock`) impede composições simultâneas, e só os painéis que
   faltam são abertos.
5. O painel `soviet-ops-fetch` grava seu PID e a área disponível em
   `$XDG_RUNTIME_DIR/terminal-soviet/`, roda o fastfetch e pede ao
   `soviet-arte render` a ilustração da sessão. A arte é sorteada nesse momento
   (1ª vez na sessão), entre as que cabem na área, e fica estável até o fim da
   sessão.

## Ilustração (arttime)

```
 soviet-ops-fetch ──render──▶ soviet-arte ──▶ artprint (instalação do arttime) ──▶ [cores-tema.pl] ──▶ tela
        ▲                        │  seleção: ~/.local/state/terminal-soviet/arte-selecao (SESSAO, DATA, NOME)
        │ SIGUSR1                │  cores:   ~/.local/state/terminal-soviet/arte.conf    (CORES, POLITICA)
        └────────────────────────┤  índice:  ~/.cache/terminal-soviet/arte-indice.tsv
                                 │
 SUPER+ALT+A ──▶ soviet-arte interativo ──▶ foot (soviet-arte) ──▶ menu ──Enter──▶ arttime original
                                                                              │ (árvore em $XDG_RUNTIME_DIR:
                                                                              │  arttime.zsh copiado sem mudança,
                                                                              │  textart/keypoems por link,
                                                                              │  bin/artprint = artprint-shim)
                                         ao sair (q) ou fechar (SIGHUP) ◀─────┘ shim registra cada arte desenhada
                                         → soviet-arte definir <última arte "a"> → SIGUSR1 ao painel
```

* **Conjunto arte+frase**: a frase é a 1ª linha do arquivo da arte. 509 das
  516 artes trazem só o texto-modelo `"Custom message for art goes here"`, e
  essas são exibidas **sem frase**. Nada é inventado.
* **Sem polling**: o painel só redesenha em SIGWINCH (tamanho) e SIGUSR1
  (conjunto ou cores mudaram). O fastfetch é relido a cada 30 min, e a arte
  em cache só é reimpressa.
* **Cores**: `Tema do terminal` passa a saída do `artprint` por
  `cores-tema.pl`, que reescreve só os parâmetros de cor SGR para a rampa
  fósforo do tema ativo, pela luminância. `Cores originais` é a saída do
  `artprint` sem alteração. O modo vale para o painel e para o arttime
  interativo (o shim lê `arte.conf` a cada desenho) e não toca na paleta do
  desktop.

## Instalação (modelo)

`install.sh` usa **cópias gerenciadas**: renderiza os modelos `*.in` com
`config/terminal-soviet.conf`, compara cada destino com o manifesto
(`~/.local/state/terminal-soviet/install/manifest.tsv`, SHA-256) e só então
escreve. As integrações com arquivos do usuário são mínimas e reversíveis:

* `~/.config/hypr/hyprland.lua`: um bloco marcado com uma linha `require`;
* `~/.config/omarchy/shell.json`: `bar.id` e `bar.position`, via
  `omarchy bar use/position` (valores anteriores guardados);
* `graphical-session.target.wants/`: dois links (equivalente a `systemctl --user enable`).

Detalhes e motivos: `docs/decisions.md`. Arquivo por arquivo: `docs/file-map.md`.
