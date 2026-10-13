# Controles

Os atalhos do projeto vêm de `config/terminal-soviet.conf` (`KEY_*`). Antes de
instalar, o `install.sh` confere que essas teclas estão livres, ou já
pertencem ao projeto, na sessão atual.

## Atalhos globais

| Atalho (padrão) | Ação | Comportamento |
|---|---|---|
| `SUPER+M` (`KEY_INSPECT`) | painel btop sob demanda | Abre flutuante, centralizado, no **workspace atual**. Se já estiver aberto aqui, fecha; se estiver em outro workspace, traz para cá. Acionamentos repetidos durante a abertura são ignorados (trava). Fechar encerra o btop (sem órfãos). |
| `SUPER+ALT+A` (`KEY_ARTE`) | ilustração: menu + arttime | Abre a janela flutuante `soviet-arte` no workspace atual; a mesma tecla fecha. Não troca de workspace nem toca na central. |
| `SUPER+CTRL+M` (`KEY_OPS`) | recompor a central | Vai ao workspace da central e reabre **só** os painéis que faltam. |
| `SUPER+SHIFT+SPACE` | barra: alternar manualmente | Oculta/mostra a barra do Noctalia; a próxima troca de workspace volta à regra automática. |
| `SUPER+CTRL+A / B / W / D / P` | control center do Noctalia | Áudio, Bluetooth, rede, monitor, energia (antes: painéis da barra do Omarchy). |
| `SUPER+CTRL+ALT+D` | calendário | Control center → calendário. |
| `SUPER+CTRL+1…9` | — | Desligados ("Bar panel N" da barra antiga, sem equivalente). |

## Ocioso: central no lugar da tela de descanso

A tela de descanso do Omarchy fica desligada (flag
`~/.local/state/omarchy/toggles/screensaver-off`, o mesmo do
`omarchy-toggle-screensaver`). No tempo dela (`idle.screensaver` em
`~/.config/omarchy/shell.json`, 150 s por padrão, lido na instalação), o idle do
Noctalia roda `soviet-ops`: vai ao workspace da central e reabre os painéis que
faltarem. O bloqueio (`idle.lock`) continua com o Omarchy. A cafeína da barra e
vídeos em tela cheia (inibidores de idle) impedem a troca. Mudou o tempo no
`shell.json`? Rode `./install.sh`.

## Barra por workspace

| Situação | Barra |
|---|---|
| Workspace da central (`HIDDEN_WORKSPACE`, padrão 1) | **oculta** |
| Workspace com janela de classe em `COLLAPSE_CLASSES` (padrão: vazio, nenhuma; ex.: `^firefox$`) | **oculta** |
| Qualquer outro | **visível**: menu, workspaces, overview, apps abertos · ações · Spotify, apps fixados, bandeja, notificações, volume, clima, relógio, control center |
| Troca de foco no mesmo workspace | nada muda |

### Posição da barra

**Clique direito numa área vazia da barra** → painel com uma mini-tela: arraste
a barrinha até uma das 4 bordas (ou use os botões ←↑→↓). A barra é recriada na
borda escolhida, e a escolha persiste (`~/.local/state/terminal-soviet/barra-posicao`
→ `~/.config/noctalia/90-posicao-barra.toml`). Linha de comando:
`soviet-bar-pos top|bottom|left|right|--status`.

Se a GUI do Noctalia tiver gravado `position` em
`~/.local/state/noctalia/settings.toml`, ela vence: o `soviet-bar-pos` avisa
qual linha remover e não aplica. O `./install.sh check` também avisa.

Na vertical, os plugins viram coluna: apps empilhados, o player só com capa e
⏯ (o título vai para o tooltip), o áudio só com o glifo.

### Música (a barra é o player)

* Mostra sempre a última música (capa, artista – título), mesmo com o Spotify
  fechado. ⏮ ⏯ ⏭ controlam o Spotify; **play com ele fechado** abre o app
  escondido (workspace especial `musica`) e retoma a última faixa.
* **Clique na capa ou no título**: painel com capa grande, controles,
  progresso, **Mostrar o app** e **busca** (Enter). Com
  `~/.config/terminal-soviet/spotify.env` (chmod 600), os resultados aparecem no
  painel; sem ele, a busca abre no app.

### Áudio

O ícone mostra a saída ativa: **fone** ou **alto-falante** (riscado e vermelho no mudo).

| Gesto | Ação |
|---|---|
| clique | popup: mudo, volume e lista de saídas (clicar numa saída a torna padrão e move o que está tocando) |
| **clique direito** | **alterna fone ↔ alto-falante** |
| clique do meio | mudo |
| rolagem | volume ±5 % |

### Ações (centro)

| Ícone | Clique | Clique direito |
|---|---|---|
| batimento | btop flutuante (= `SUPER+M`) | — |
| captura | `omarchy-capture-screenshot` | gravar/parar (`omarchy-capture-screenrecording`) |
| lua | luz noturna (`omarchy-toggle-nightlight`, hyprsunset) | — |
| café | cafeína: manter acordado (`omarchy-toggle-idle`) | — |
| perfil de energia | próximo perfil (power-profiles-daemon) | perfil anterior |
| jogo (`GAME_DESKTOP`) | abre o jogo pelo `.desktop` | — |

Luz noturna e cafeína são botões sem estado: o ícone não mostra se estão ligadas.

### Aplicativos (estilo Windows)

* **Esquerda**: apps **abertos** que não estão fixados (fora do workspace da
  central). **Direita**: apps **fixados**, na ordem em que foram fixados; um
  fixado aberto fica só à direita.
* Traço **fósforo** = app focado; **oliva** = em execução (traço largo = 2+
  janelas); ícone atenuado sem traço = fixado e fechado.
* **Clique**: foca a janela mais recente, o que leva ao workspace dela; cliques
  seguidos alternam entre as janelas do app. Fixado fechado: abre o app.
* **Clique direito**: mini-menu com **Fixar na barra** (à esquerda) ou
  **Desafixar** (à direita), **Nova janela** e **Fechar janela(s)**.
* Os fixados ficam em `~/.local/state/noctalia/plugins/data/erllan/tarefas/fixados.json`.
  `FAVORITES` (`config/terminal-soviet.conf`) é só a semente da primeira
  execução; apague o arquivo para voltar a ela.
* Linha de comando: `noctalia msg plugin erllan/tarefas:fonte all <fixar|desafixar|novo|fechar> <app:classe|pin:id>`.

**Vários monitores**: a regra vale para o workspace do **monitor focado**, em
todas as barras. No Noctalia 5.0.1, ocultar a barra por monitor não funciona.
Testado só com um monitor.

## Ilustração (`SUPER+ALT+A`)

Menu da janela:

```
[Enter]  abrir o arttime (controles nativos)
[c]      Cores da ilustração  →  [1] Tema do terminal   [2] Cores originais   [Esc] voltar
[s]      sortear outro conjunto para o painel (entre os que cabem na área)
[p]      política: por login (padrão) / diária
[q]/Esc  fechar
```

No arttime (controles do próprio arttime 2.5.0; `h` mostra todos):

| Tecla | Ação |
|---|---|
| `h` | ajuda / volta à arte |
| `a` | escolher arte pelo nome (com completação) |
| `x` | escolher com fzf (prévia já nas cores do modo atual) |
| `j` | sorteio: `j` próxima, `y` escolhe, `c` cancela |
| `c` / `t` | cor da arte (0–15) / tema claro-escuro do arttime |
| `m` | mensagem livre (não vai para o painel) |
| `g`, `p`, `r`, `i`, `z` | timers, pausa, reset, lista, fuso (recursos nativos) |
| `q` → `y` | sair; volta ao menu |

**Ao sair**, a última arte escolhida vira o conjunto da sessão, e o painel da
central é redesenhado. Fechar a janela com o arttime aberto também sincroniza.
Fechar **no meio** de um sorteio `j`, antes de `y`/`c`, adota a arte que estava
na tela. A mensagem `m` e os timers não vão para o painel.

## Modos de cores ("Cores da ilustração")

Persistente em `~/.local/state/terminal-soviet/arte.conf`. Vale para o
painel da central e para o arttime interativo. Não altera a paleta do desktop
nem de outros programas.

| Modo | Arte monocromática | Arte colorida (ANSI 16/256/truecolor) |
|---|---|---|
| **Tema do terminal** (padrão) | fósforo `#B8D58A` (o acento do tema) | cada cor de frente/fundo vira um tom da rampa fundo → fósforo → verde claro, pela luminância (curva 0,65). Texto, alinhamento, negrito etc. intactos; nenhum código ANSI removido |
| **Cores originais** | cores padrão do arttime (arte = cor 1, frase = cor 2 da paleta do terminal) | exatamente a saída do `artprint` (idêntica byte a byte, verificado nos testes) |

Linha de comando: `soviet-arte cores tema|originais|alternar`,
`soviet-arte atual`, `soviet-arte sortear`, `soviet-arte politica sessao|diaria`,
`soviet-arte desenhar <arte> --cols C --rows R` (prévia sem mudar a sessão).
