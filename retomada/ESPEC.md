Se você está retomando: leia `retomada/PROGRESSO.md` e continue do "próximo passo".

# Barra v2 — especificação (pedido de 2026-10-13)

Base: branch `redesenho-barra` (fases 1–7 da barra + tela de descanso → central),
ainda NÃO mesclada na `main`. Esta branch: `barra-v2`, no worktree
`~/www/customterminalerllin-barra-v2`. Revisão só deste pedido:
`git -C ~/www/customterminalerllin-barra-v2 log --oneline redesenho-barra..barra-v2`.

Regras: repositório é a fonte; `./install.sh` gera os destinos (NÃO rodar a partir
do worktree sem aprovação do usuário); preferências em `config/terminal-soviet.conf`;
tudo por eventos (sem polling novo); docs/comentários em português. A cada
modificação: atualizar `retomada/PROGRESSO.md` + commit pequeno `wip: …`.

## Pedido (texto do usuário, resumido fielmente)

0. Pasta separada (este worktree) + `retomada/ESPEC.md` e `retomada/PROGRESSO.md`
   (estado das fases anteriores, checklist, onde parei, próximo passo, como
   verificar, decisões em aberto). Commit `wip:` a cada modificação.
1. **Limites da API** contra a versão INSTALADA (Noctalia 5.0.1): `plugin_api`
   máximo; drag/drop só em painel (API 5); `panel.openContextMenu` (API 28, só
   painel, só de `ui.button.onRightClick`); tooltip por nó (API 32?);
   `barWidget.setTooltip` e `onHover(state,key)` (nível de cada um); callbacks de
   bar widget; comando exato de `noctalia msg` para IPC de plugin;
   `noctalia.getConfig("bar.<nome>.position")` (API 26). Se uma 5.x mais nova
   liberar API 32+: dizer o que destrava e o custo de subir (lib/compat.sh,
   testes). NÃO atualizar sem aprovação. Itens não permitidos → alternativa +
   registro em `docs/decisions.md`.
2. **Atalho fixar/desafixar** `KEY_PIN` (sugestão `SUPER + ALT + F`, conferir que
   está livre pelo mecanismo do install.sh). Mouse sobre ícone da barra → alterna
   aquele app; senão → app da janela em foco. Bind (o.bind) → `noctalia msg` →
   `onIpc` do plugin de tarefas; ícone sob o mouse via `onHover`. Sem polling.
   Retorno visual curto (piscar/animação, se a API permitir).
3. **Reordenar/mover ícones por arrasto**: reordenar fixados; esquerda→direita =
   fixar, direita→esquerda = desafixar; ordem persiste no arquivo dos fixados.
   Sem arrasto na barra → painel **"Editar barra"** (clique direito na lista de
   apps) com duas `dropZone` ("Abertos", "Fixados"); ícones `dragSource`,
   ordenáveis dentro de cada zona.
4. **Menu "Grupos"** no centro da barra (junto das ações): painel com clusters de
   apps instalados por propósito; clique = abre ou foca (mesma lógica das
   tarefas). Classificação inicial: `.desktop` de /usr/share/applications,
   ~/.local/share/applications, exports do Flatpak; ignorar NoDisplay/Hidden/
   OnlyShowIn incompatível; por `Categories=` + ajuste manual. Grupos: Desenvolvimento,
   Internet, Mídia, Jogos, Criação/Gráficos, Escritório e notas, Sistema,
   Utilitários. **Mostrar a tabela app → grupo ao usuário ANTES de gravar**; fácil
   de corrigir. Edição no painel: arrastar entre grupos, criar/renomear/apagar
   grupo, tirar app de grupo (menu de contexto se API 28; senão botões). App pode
   estar em mais de um grupo. Não classificados → "Sem grupo" (só aparece se não
   vazio). Estado em `~/.local/state/terminal-soviet/grupos.json` (com versão de
   esquema). Classificação automática só na 1ª vez e quando pedida; nunca desfaz
   escolha do usuário.
5. **Atalho no hover**: tooltip mostra o atalho ligado ao ícone ("Firefox — SUPER +
   SHIFT + B"). Fonte: `hyprctl binds -j`, lido ao iniciar e em `configreloaded`.
   Associar binds a apps pelo comando; widgets nativos pelo comando/ação. Nada
   fixo no código. Nativos: `tooltip` no 20-barra.toml.in por marcadores do
   install.sh a partir do conf. Plugin: tooltip por nó se API 32; senão onHover +
   `barWidget.setTooltip`. Testar se o tooltip acompanha o ícone ou fica preso ao
   widget e relatar.
6. **Arrastar a barra abre o menu de orientação** (topo/baixo/esq./dir.; aplica e
   persiste — fase 6 anterior). Verificar se algo recebe arrasto (botão + movimento,
   ponteiro do `ui.graph`, `onScroll` horizontal). Senão: clique direito na zona
   vazia abre o painel de orientação + alça visual "⠿" que também abre. Documentar.
7. **Avaliar plugins** (não instalar sem perguntar): audio-switcher (API 15),
   keybind-cheatsheet (9), media-island (24), spotify-lyrics/lyrics (3),
   special-workspaces (3), game-launcher (13), screen-toolkit (13), timer/notes
   (oficiais 20/26), pomodoro (22). Para cada: plugin_api × instalada, deps,
   coexistência com Omarchy. Tabela: usar como está / fork local / só referência /
   descartar. Escolhidos entram como cópia fixada (upstream/, REVISION, README de
   diferenças, licença); sem auto_update; fontes continuam desligadas.

Para tudo: testes (static.sh, live.sh), docs (controls, decisions, file-map,
noctalia/config/README), `noctalia config validate`, `tests/run.sh`, capturas.
No fim: resumo (funciona / alternativa e por quê) + comando de revisão do diff.

Pedido avulso (já feito fora do worktree, no arquivo pessoal do usuário):
remover o atalho do Google Maps (SUPER+SHIFT+S, padrão do Omarchy) →
`hl.unbind` no fim de `~/.config/hypr/bindings.lua` (backup em
`~/.local/state/terminal-soviet/install/backups/bindings.lua.antes-maps-*`).

## Decisões tomadas
(ver também PROGRESSO.md → "Decisões")
