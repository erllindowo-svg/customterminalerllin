# Progresso — barra v2

## Onde parei
Item 5 COMPLETO: soviet-atalhos ganhou "linhas" (comando completo → teclas) e
troca comma/period/slash por , . /; lib/ts-lib.sh compute_tokens gera T_AT_* via
atalho_de (linhas exatas, senão cmds pelo executável); 20-barra.toml.in usa
@AT_MENU@ @AT_CAPTURA@ @AT_GRAVAR@ @AT_NOTURNA@ @AT_CAFEINA@ @AT_NOTIF@ @AT_SILENCIO@
e @KEY_INSPECT@. static 57/0, sandbox 41/0.

## Próximo passo exato
1. Item 6 (alça "⠿" na barra: widget erllan/barra:alca → panel-toggle erllan/barra:posicao;
   dead_zone right já abre o painel de orientação desde a fase 6 anterior).
2. Item 7 (tabela de plugins: gh api nos catálogos community-plugins/official-plugins,
   plugin.toml de cada um: plugin_api, dependencies; nada instalado).
3. DOCS PENDENTES: docs/decisions.md (achados da API, KEY_PIN, Editar barra, Grupos sem
   webapps, atalhos via Lua isolado, tooltip preso ao widget, nativos só mudam com
   ./install.sh, sem arrasto na barra), docs/controls.md (KEY_PIN, clique direito fora de
   ícone = Editar barra, Grupos, tooltips), docs/file-map.md (soviet-grupos,
   soviet-atalhos, plugins grupos, editar.luau, grupos.json, fixados.json v2),
   noctalia/config/README.md, README.md (tabela de atalhos).
4. Resumo final ao usuário + `git log --oneline redesenho-barra..barra-v2`.

## Estado do pedido anterior (fases 1–7, branch redesenho-barra)
| Fase | Estado | Commit |
|---|---|---|
| 1 grade + capa quadrada | feito | 0d76578 |
| 2 abertos/fixados + mini-menu | feito | f86f06c |
| 3 áudio (erllan/audio) | feito (troca de saída não testada ao vivo) | eb712c4 |
| 4 player (spotify-media) | feito (busca Web API e play com Spotify fechado não testados) | e27185b |
| 5 Firefox com barra + animação | feito (speed 1.0) | 67c6707 |
| 6 posição da barra (painel com arrasto) | feito | 21ce686 |
| 7 ações no centro | feito | 6335ee4 |
| extra: idle → central | feito (gatilho de 150 s não observado) | e91db04 |
Instalado no sistema: tudo acima (a partir do checkout principal, branch redesenho-barra).

## Checklist deste pedido
- [x] 0 worktree + retomada/
- [x] 1 limites da API (achados abaixo; falta registrar em docs/decisions.md junto dos itens)
- [x] 2 KEY_PIN = SUPER+ALT+P + onIpc alternar-fixado + hover + piscar (doc pendente)
- [x] 3 painel "Editar barra" (abertos/fixados, ordenar, mover) + ordem persistida (não testado ao vivo: exige install)
- [x] 4 Grupos: classificador + tabela (aguarda aprovação) + painel + edição (grupos.json só após aprovação)
- [x] 5 atalhos no hover: soviet-atalhos + plugin + nativos (marcadores AT_*)
- [ ] 6 arrasto da barra → orientação (verificar; alça ⠿)
- [ ] 7 avaliação de plugins (tabela)
- [ ] testes, docs, validate, capturas, resumo final

## Como verificar o que já foi feito
- `git -C ~/www/customterminalerllin-barra-v2 log --oneline redesenho-barra..barra-v2`
- No worktree: `tests/static.sh` e `tests/sandbox.sh` (não tocam no sistema).
- NÃO rodar `./install.sh` do worktree sem aprovação.

## Achados da API (item 1) — fonte: gh api noctalia-dev/noctalia, tags v5.0.1/v5.1.0/v5.2.x
- Instalada: noctalia 5.0.1 (extra tem só 5.0.1). `plugin_api` aceito: 3–30
  (`kCurrentPluginApiVersion = kPanelLayerPluginApiVersion` = 30).
- 5.1.0: também 30. 5.2.0/5.2.1: 32 → 31 `noctalia.getColor(role)`, 32 `tooltip`
  em ui.box/row/column/image (tooltip POR ÍCONE). Não está no `extra` do Arch.
- drag/drop: `ui.dragSource/dropZone` só em painéis (reconciler rejeita fora:
  "only supported in plugin panels"). Barra: sem arrasto.
- `panel.openContextMenu`: API 28 (temos), só painel, só de `ui.button.onRightClick`.
- `onHover(state, key)` por nó (row/column/box/image/button): API base.
- `barWidget.setTooltip(text)`: API base; vale para a área do widget INTEIRO
  (PluginWidget::luaSetTooltip → m_area). Trocar o texto no onHover funciona, mas o
  balão fica ancorado ao widget, não ao ícone.
- Callbacks de widget: onClick/onRightClick/onMiddleClick (botões não capturados
  pelos nós; nós clicáveis só aceitam BTN_LEFT), onHover (widget), onScroll
  (axis vertical|horizontal), onIpc(event, payload), update(), onExit.
- IPC: `noctalia msg plugin <autor/plugin:entrada> <alvo> <evento> [payload]`;
  alvo `all` obrigatório para [[service]]/[[panel]]; `focused` para widget.
- Posição da barra: é `noctalia.getSetting("bar.<nome>.position")` (API 26), não
  getConfig (getConfig lê só as settings declaradas do próprio plugin).
- Arrasto: `ui.graph.onPointerMove` (API 29) dá só posição (sem botão);
  `onScroll` horizontal existe (touchpad), mas não é arrasto. Nada detecta
  "pressionar + mover" na barra.

## Decisões
- Grupos: webapps (Exec com omarchy-launch-webapp / firefox --new-window http / firefox-webapp) são ignorados pelo soviet-grupos; tabela caiu de 66 para 54 apps. Pendente: aprovação da tabela.
- Atalhos: `hyprctl binds -j` não traz o comando (dispatcher "__lua"); a config é avaliada num Lua isolado (hl falso só registra bind/unbind; os.execute/io.popen inertes) e cruzada com o hyprctl (só binds ativos).
- KEY_PIN = SUPER + ALT + P (SUPER + ALT + F já é "Full width" do Omarchy; P livre em hyprctl binds).
- Base da branch: redesenho-barra (não main), porque o pedido continua aquele trabalho.
- Google Maps: removido no arquivo pessoal ~/.config/hypr/bindings.lua (não é do projeto).

## Decisões em aberto (dependem do usuário)
- Aprovar a tabela app → grupo (retomada/grupos-proposta.txt) antes de gravar grupos.json.
- (RESOLVIDO: Google Maps fica como está, só sem o atalho; webapps/sites não entram nos Grupos.)
- [obsoleto] O lançador "Google Maps" (~/.local/share/applications/Google Maps.desktop) ainda existe; só o atalho foi removido. Remover o webapp também?
