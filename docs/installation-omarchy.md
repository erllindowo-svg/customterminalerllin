# Instalação numa máquina Omarchy nova

> **Status de validação.** Validado só no computador onde o projeto foi
> criado: Omarchy **4.0.4-1**, Hyprland 0.56.2, Noctalia 5.0.1. O instalador
> foi testado em diretórios HOME isolados com os arquivos padrão do Omarchy
> 4.0.4 (simulação, instalação, reexecução, conflitos, desinstalação exata,
> migração). **Este procedimento ainda não foi executado de ponta a ponta numa
> instalação limpa real nem numa VM.** Trate-o como preparado, porém não
> validado integralmente.

Compatibilidade conhecida (`docs/stack.md`): Omarchy 4.0.4 verificado; 4.x
aceito com aviso; outras séries fazem o instalador parar antes de alterar
qualquer arquivo (a menos que se use `--accept-untested`).

## 1. Verificar o Omarchy e os pré-requisitos

Faça pelo menos um login gráfico depois de instalar o Omarchy (isso cria
`~/.config/omarchy/shell.json`). No terminal da sessão:

```bash
omarchy version                  # esperado: 4.x (validado: 4.0.4)
hyprctl version | head -1        # validado: 0.56.2
ls ~/.config/hypr/hyprland.lua ~/.config/omarchy/shell.json
```

Instale os pacotes que o projeto usa (o instalador não instala pacotes; só
aponta os que faltam):

```bash
omarchy pkg add noctalia zsh socat jq fastfetch playerctl fzf git
# opcionais: firefox e osu-lazer (fixados na barra por padrão)
# opcional, AUR: omarchy pkg aur add osu-lazer-bin
```

## 2. Acesso ao repositório privado

Use **um** dos métodos. Nenhum deles grava token no projeto.

```bash
# A) GitHub CLI (HTTPS, login pelo navegador)
gh auth login                    # GitHub.com → HTTPS → "Login with a web browser"
gh auth setup-git

# B) SSH
ssh-keygen -t ed25519 -C "$(hostname)"
gh ssh-key add ~/.ssh/id_ed25519.pub   # ou cole a chave em GitHub → Settings → SSH keys
ssh -T git@github.com
```

## 3. Clonar

Convenção: `~/www/customterminalerllin`. Qualquer outro diretório funciona,
porque o instalador descobre a raiz pelo próprio caminho.

```bash
mkdir -p ~/www
gh repo clone <usuario>/customterminalerllin ~/www/customterminalerllin
# ou: git clone git@github.com:<usuario>/customterminalerllin.git ~/www/customterminalerllin
cd ~/www/customterminalerllin
```

Ajuste as preferências antes de instalar, se quiser:
`config/terminal-soviet.conf` (workspace da central, clima, atalhos,
favoritos, lançadores, sensores de GPU).

## 4. Dependências externas nas versões esperadas

O `install.sh` baixa as duas dependências de git **fixadas em commit**
(passo 8). Para fazer isso antes, separadamente:

```bash
scripts/install-arttime.sh       # arttime 2.5.0 @ 38c2955 → ~/.local (instalador oficial --local)
~/.local/bin/arttime --version   # 2.5.0
```

O omarchy-overview (`1ed4938`) é clonado pelo próprio `install.sh`.

## 5. Simulação

```bash
./install.sh check       # integração com o Omarchy, versões, dependências, atalhos livres, plano
./install.sh --dry-run   # o mesmo plano de instalação; nada é escrito
```

`check` para com explicação se faltar um ponto de integração, uma versão
estiver fora da série verificada, faltar pacote ou um atalho de
`config/terminal-soviet.conf` já estiver em uso por outro recurso.

## 6. Examinar as alterações

No plano, cada linha é uma ação:

| Ação | Significado |
|---|---|
| `CRIAR` | arquivo novo do projeto |
| `ATUALIZAR` | arquivo do projeto, intacto, com versão nova |
| `ADOTAR` | o arquivo já existe idêntico ao do projeto: só passa a ser gerenciado |
| `ADICIONAR block` | 3 linhas marcadas no fim de `~/.config/hypr/hyprland.lua` (`require("hypr.terminal_soviet")`) |
| `ALTERAR shelljson` | `bar.id` → `erllan.sem-barra`, `bar.position` → `top` |
| `INSTALAR external` | arttime / omarchy-overview no commit fixado |
| `CONFLITO` | existe um arquivo diferente no destino. **Nada é aplicado**; compare com `diff ~/<destino> <arquivo do repositório>` |

Lista completa de destinos: `docs/file-map.md`.

## 7. Backup da configuração recém-instalada

O instalador guarda sozinho cada arquivo que sobrescreve ou altera (em
`~/.local/state/terminal-soviet/install/backups/`). Para ter também uma cópia
completa do Omarchy "de fábrica" antes de aplicar:

```bash
mkdir -p ~/terminal-sovietico-backups
tar -C ~ -czf ~/terminal-sovietico-backups/omarchy-original-$(date +%Y%m%d-%H%M%S).tar.gz \
    .config/hypr .config/omarchy/shell.json .config/systemd/user .config/noctalia \
    .config/btop .config/fastfetch 2>/dev/null
```

(`tar` reclama de caminhos inexistentes, como `.config/noctalia` numa máquina
nova; isso é esperado.)

## 8. Aplicar

```bash
./install.sh
```

O instalador:
1. escreve os arquivos e registra o manifesto (`~/.local/state/terminal-soviet/install/manifest.tsv`);
2. clona e instala o arttime e o omarchy-overview fixados;
3. ativa: `systemctl --user daemon-reload`, inicia `noctalia` e
   `soviet-bar-sync`, roda `hyprctl reload` e exige `hyprctl configerrors`
   vazio.

Tema e papéis de parede (as fotos não ficam no repositório):

```bash
scripts/fetch-backgrounds.sh      # Wikimedia Commons, confere SHA-1, gera preview.png
omarchy theme set soviet-terminal
```

## 9. Reiniciar só o necessário

Nada do Omarchy precisa ser reiniciado. O shell do Omarchy recarrega o
`shell.json` sozinho, e o Noctalia recarrega configuração e plugins sozinho.

* **Central do workspace 1**: é composta no login. Para compor já, sem
  relogar, use `SUPER+CTRL+M`.
* Se a barra do Omarchy continuar visível: `omarchy restart shell`.
* Se a barra do Noctalia não reagir: `systemctl --user restart noctalia soviet-bar-sync`.

## 10. Verificar

```bash
./install.sh status                         # todos os itens conferem
systemctl --user is-active noctalia soviet-bar-sync
soviet-bar-sync --status                    # workspace, estado desejado, estado da barra
hyprctl configerrors                        # vazio
soviet-arte atual                           # arte da sessão, frase, modo de cores
```

Visual e controles (detalhes em `docs/controls.md`):

| O quê | Esperado |
|---|---|
| Workspace 1 | 4 painéis (btop, sistema + ilustração, relógio/clima, shell); **sem barra** |
| Workspace 2 | barra no topo: favoritos com ícones reais, CPU/RAM/(GPU)/NET, clima, relógio |
| Workspace com Firefox | barra visível (só oculta se a classe estiver em `COLLAPSE_CLASSES`) |
| `SUPER+M` | btop flutuante no workspace atual; de novo, fecha |
| `SUPER+ALT+A` | menu da ilustração; `Enter` abre o arttime; `c` → Cores da ilustração |
| `SUPER+CTRL+M` | recompõe a central |
| Cores | `c` → `2` deixa a arte com as cores originais, `c` → `1` volta ao tema; vale também no painel |

Testes do repositório: `tests/run.sh` (estáticos + HOME isolado) e
`tests/live.sh` (sessão real; `--disruptive` abre janelas).

## 11. Logs e problemas comuns

```bash
journalctl --user -u noctalia -f           # barra
journalctl --user -u soviet-bar-sync -f    # "workspace N -> barra hide|show"
journalctl -t soviet-ops -t soviet-arte    # central e ilustração
noctalia config validate                   # configuração do Noctalia
```

| Sintoma | Causa provável | Solução |
|---|---|---|
| Duas barras | `omarchy refresh shell`, `omarchy bar defaults` ou o menu Style reescreveram o `shell.json` | `omarchy bar use erllan.sem-barra && omarchy bar position top`, ou `./install.sh` |
| Barra não some no workspace 1 | serviço parado | `systemctl --user restart soviet-bar-sync` |
| Grade da central desalinhada | workspace 1 fora do layout dwindle | conferir `~/.local/state/omarchy/workspace-layouts/1.lua` (`./install.sh status`); fechar os painéis e usar `SUPER+CTRL+M` |
| Ajuste da barra feito na GUI do Noctalia "não sai" | `~/.local/state/noctalia/settings.toml` vence os arquivos | apagar esse arquivo |
| Ilustração vazia / "arttime não encontrado" | arttime não instalado | `scripts/install-arttime.sh` |
| "«arte» não cabe nesta área" | arte maior que o painel, escolhida no modo interativo | `SUPER+ALT+A` → `s` (sorteia uma que cabe) |
| `install.sh` para com CONFLITO | arquivo existente diferente | revisar o `diff`; levar a mudança para o repositório ou usar `--force` (guarda backup) |
| `install.sh` para por versão | Omarchy/Noctalia fora da série verificada | ler `docs/stack.md`; `--accept-untested` só depois de revisar |

## 12. Atualizar

```bash
cd ~/www/customterminalerllin
git pull
./install.sh --dry-run && ./install.sh
```

Arquivos editados à mão no sistema aparecem como CONFLITO, e nada é aplicado.
Painéis já abertos da central usam a versão antiga até serem reabertos
(`SUPER+CTRL+M`). Para trocar o commit do arttime/omarchy-overview, edite
`ARTTIME_COMMIT`/`OVERVIEW_COMMIT` em `install.sh` depois de revisar o
upstream.

## 13. Reverter e restaurar

```bash
./install.sh uninstall --dry-run   # o que seria removido/restaurado
./install.sh uninstall             # desfaz tudo o que o instalador fez
```

Remove os arquivos instalados intactos, restaura os que existiam antes,
devolve `bar.id`/`bar.position` aos valores anteriores (a barra do Omarchy
volta), tira o bloco do `hyprland.lua` sem mexer no resto do arquivo, para
os serviços e recarrega o Hyprland. O arttime e o omarchy-overview ficam;
removê-los está em `docs/backup-restore.md`. Para voltar ao Omarchy "de
fábrica" a partir do backup do passo 7:

```bash
tar -C ~ -xzf ~/terminal-sovietico-backups/omarchy-original-<data>.tar.gz
hyprctl reload && omarchy restart shell
```

## Componentes nativos do Omarchy: o que muda e o que fica

O shell do Omarchy (`omarchy-shell`, um processo quickshell) faz várias coisas
ao mesmo tempo. **Ele não é desinstalado nem encerrado**: só a barra é
trocada, pelo mecanismo suportado `bar.id` (plugin de barra, descrito em
`$OMARCHY_PATH/shell/README.md`). Nada em `/usr/share/omarchy` é alterado.

### Substituído ou desativado

| Componente nativo | Mudança | Onde | Motivo |
|---|---|---|---|
| Barra do Omarchy (`omarchy.bar`) | trocada pela barra nula `erllan.sem-barra` (não cria janela nem reserva espaço) | `~/.config/omarchy/shell.json`: `bar.id`, `bar.position`; plugin em `~/.config/omarchy/plugins/erllan.sem-barra/` | a barra visível é a do Noctalia; evita duas barras |
| Painéis ancorados na barra (`SUPER+CTRL+A/B/W/D/P`, `SUPER+CTRL+ALT+D`) | passam a abrir o control center do Noctalia (áudio, Bluetooth, rede, monitor, energia, calendário) | `~/.config/hypr/terminal_soviet.lua` (`hl.unbind` + `o.bind`) | os painéis da barra antiga não existem sem ela |
| "Bar panel 1–9" (`SUPER+CTRL+1…9`) | desligados | idem | sem equivalente posicional no Noctalia |
| "Toggle top bar" (`SUPER+SHIFT+SPACE`) | alterna a barra do Noctalia | idem | mesmo papel, outra barra |

### Continuam ativos (shell do Omarchy)

Notificações (popups, histórico, não perturbe), OSD de volume/brilho, bloqueio
de tela, idle/suspensão, protetor de tela, agente polkit, papel de parede por
tema, histórico da área de transferência e os menus (`SUPER+SPACE` menu do
Omarchy, `SUPER+ALT+SPACE` apps). O overview (`moorgrove.overview`) é um plugin
de terceiros instalado pelo projeto, não um componente nativo. A barra do Noctalia **usa** esses serviços: o
sino abre o histórico do Omarchy, e a estrela, o menu do Omarchy.

Para não haver dois donos do mesmo recurso, o
`~/.config/noctalia/00-coexistencia-omarchy.toml` **desliga no Noctalia**:
daemon de notificações, OSD, papel de parede, bloqueio de tela, clipboard,
polkit, luz noturna, widgets de desktop, templates de tema (que reescreveriam
foot/btop/GTK) e o download automático de plugins.

### Voltar à configuração padrão

* Completo: `./install.sh uninstall` (passo 13).
* Só a barra, sem desinstalar: `omarchy bar reset && omarchy bar position <anterior>`
  e `systemctl --user disable --now noctalia soviet-bar-sync`. A posição
  anterior está em `~/.local/state/terminal-soviet/install/shelljson.prev`.
* Atenção: `omarchy refresh shell` e `omarchy bar defaults` também devolvem a
  barra do Omarchy, mas com o Noctalia ainda rodando ficam **duas barras**.

### Diferenças entre a instalação testada e outras versões

* Só o **Omarchy 4.0.4** foi testado. O projeto depende da configuração do
  Hyprland em Lua, dos helpers `o.bind`/`o.window`/`o.exec_on_start`, dos
  layouts por workspace em `~/.local/state/omarchy/workspace-layouts` e do
  `bar.id` do shell. O `install.sh check` confere cada um e para se faltar
  algum. Não há adaptador para versões configuradas por `hyprland.conf`.
* Se uma versão futura mudar a interface de plugins `bar`, o shell volta sozinho
  para a barra nativa e aparecem duas barras. É visível e não quebra a sessão:
  rode `./install.sh uninstall` ou atualize o plugin `erllan.sem-barra`.
* Noctalia 6.x pode tornar o plugin `erllan/tarefas` desnecessário
  (`hidden_workspaces`) e mudar a API de plugins; o instalador para fora da série 5.x.

## Migrar a máquina original (instalação manual das fases 0–1)

Só vale para o computador onde o projeto nasceu, porque a Fase 1 escreveu
atalhos e regras à mão no fim de `~/.config/hypr/{hyprland,bindings,autostart}.lua`.
O `install.sh` detecta isso e se recusa a instalar, para não duplicar atalhos.
**Ainda não executado nessa máquina** (testado só numa cópia isolada):

```bash
migrate/phase1-inline.sh --dry-run   # confere byte a byte os trechos da Fase 1
migrate/phase1-inline.sh             # remove só esses trechos (com backup)
./install.sh --dry-run               # o restante aparece como ATUALIZAR/CONFLITO/ADOTAR
./install.sh --force                 # substitui pelas versões do repositório (com backup)
```
