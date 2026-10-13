# Terminal Soviético

Configuração pessoal de desktop para o **Omarchy 4** (Hyprland em Lua):

* uma **central de operações** no workspace 1: btop, fastfetch com uma ilustração
  do arttime, relógio e clima do Rio, e um shell, em verde fósforo sobre grafite;
* uma **barra única** (Noctalia) que some na central e aparece nos demais
  workspaces, com os apps abertos à esquerda e os fixados à direita (estilo
  Windows, ícones reais; fixar/desafixar pelo clique direito), ações rápidas
  (btop, captura, luz noturna, cafeína, perfil de energia, jogo), clima e relógio;
* um **btop flutuante sob demanda** (`SUPER+M`);
* a **ilustração** do arttime (arte + frase original, sem relógio), com menu,
  arttime interativo e dois modos de cor (`SUPER+ALT+A`).

Repositório privado, de uso pessoal, para levar essa configuração a novos
computadores. Não é uma distribuição genérica: só o Omarchy 4 é suportado.

## Instalação rápida

```bash
git clone <remoto-privado> ~/www/customterminalerllin   # qualquer diretório serve
cd ~/www/customterminalerllin
./install.sh check        # compatibilidade, dependências, atalhos e plano — não altera nada
./install.sh --dry-run    # plano de instalação
./install.sh              # instala (idempotente), baixa arttime/omarchy-overview fixados e ativa
scripts/fetch-backgrounds.sh && omarchy theme set soviet-terminal
```

Passo a passo, pré-requisitos e migração desta máquina:
[`docs/installation-omarchy.md`](docs/installation-omarchy.md).

## Uso

| Atalho | Ação |
|---|---|
| `SUPER+M` | btop flutuante no workspace atual (abre/fecha) |
| `SUPER+ALT+A` | ilustração: Cores da ilustração, sortear, arttime interativo |
| `SUPER+CTRL+M` | recompor a central do workspace 1 |
| `SUPER+SHIFT+SPACE` | mostrar/ocultar a barra manualmente |

Preferências (atalhos, clima, workspace da central, semente dos fixados,
jogo da barra) ficam em [`config/terminal-soviet.conf`](config/terminal-soviet.conf).
Depois de editar, rode `./install.sh`. Tudo sobre os controles:
[`docs/controls.md`](docs/controls.md).

## Atualizar, verificar, desfazer

```bash
git pull && ./install.sh --dry-run && ./install.sh   # atualizar
./install.sh status                                  # o que está instalado / editado
./install.sh uninstall --dry-run                     # o que seria desfeito
./install.sh uninstall                               # desfaz e restaura os originais
tests/run.sh [--live|--disruptive]                   # testes
```

Recuperação e backups das fases anteriores: [`docs/backup-restore.md`](docs/backup-restore.md).

## Estrutura

```
install.sh                 instalador: check | install | status | uninstall
config/terminal-soviet.conf  preferências pessoais (versionadas)
lib/                       funções do instalador (configuração, modelos, compatibilidade)
bin/                       scripts → ~/.local/bin (soviet-ops, soviet-arte, soviet-inspect…)
share/terminal-soviet/arte filtro de cores e shim do artprint → ~/.local/share/terminal-soviet/arte
hypr/                      módulo Hyprland (modelo) → ~/.config/hypr/terminal_soviet.lua
noctalia/config/           configuração do Noctalia (modelos .in) → ~/.config/noctalia
noctalia/plugins/          plugins Luau (tarefas, volume-slider, spotify-media) → ~/.local/share/noctalia/plugins
omarchy/plugins/           barra nula erllan.sem-barra → ~/.config/omarchy/plugins
omarchy/themes/            tema soviet-terminal (sem as fotos) → ~/.config/omarchy/themes
omarchy/workspace-layouts/ layout dwindle da central → ~/.local/state/omarchy/workspace-layouts
systemd/                   noctalia.service, soviet-bar-sync.service → ~/.config/systemd/user
btop/, fastfetch/          configurações dos painéis
migrate/                   migração da instalação manual da Fase 1
scripts/                   arttime fixado, papéis de parede, medição de desempenho
tests/                     estáticos, HOME isolado, ao vivo
docs/                      documentação (abaixo)
```

## Documentação

| Documento | Conteúdo |
|---|---|
| [`docs/architecture.md`](docs/architecture.md) | componentes, fluxo de inicialização, ilustração |
| [`docs/file-map.md`](docs/file-map.md) | cada arquivo: origem, destino, função, se é versionado |
| [`docs/stack.md`](docs/stack.md) | matriz de compatibilidade, dependências e versões |
| [`docs/controls.md`](docs/controls.md) | atalhos, barra por workspace, menu, modos de cores |
| [`docs/performance.md`](docs/performance.md) | medições antes/depois, metodologia, recomendações |
| [`docs/backup-restore.md`](docs/backup-restore.md) | manifesto, desinstalação, backups das fases |
| [`docs/installation-omarchy.md`](docs/installation-omarchy.md) | instalação nova e migração desta máquina |
| [`docs/decisions.md`](docs/decisions.md) | decisões, alternativas e limites |
| [`THIRD_PARTY.md`](THIRD_PARTY.md) | licenças, o que fica fora do repositório e por quê |

## Licenças

Código próprio para uso pessoal. Componentes de terceiros, como o fork MIT do
spotify-media, o arttime (GPL-3 + CFLA, arte para uso pessoal não comercial,
não versionado) e as fotos CC do tema (não versionadas), estão descritos em
[`THIRD_PARTY.md`](THIRD_PARTY.md).
