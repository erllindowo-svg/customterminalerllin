# Progresso — barra v2

## Onde parei
Item 2: KEY_PIN feito no conf/ts-lib/install.sh/hypr/testes. Falta o lado do plugin (onIpc alternar-fixado, hover publicado, piscar).

## Próximo passo exato
Item 2, plugin: em noctalia/plugins/tarefas/comum.luau.in publicar
state "hover-<grupo>" (key ou "") no onHover; em fonte.luau.in, onIpc
"alternar-fixado": key = hover-abertos/hover-fixados ou app da janela focada
(clients com h == 0); fixar/desafixar; state "piscar" {key, n}; widgets
realçam o item ~0,7 s (runAsync sleep como timer).

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
- [ ] 2 KEY_PIN (conferir livre) + onIpc + hover + piscar
- [ ] 3 painel "Editar barra" (abertos/fixados, ordenar, mover) + ordem persistida
- [ ] 4 Grupos: classificador + tabela p/ aprovação + painel + edição + grupos.json
- [ ] 5 atalhos no hover (hyprctl binds → apps; nativos por marcadores)
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
- KEY_PIN = SUPER + ALT + P (SUPER + ALT + F já é "Full width" do Omarchy; P livre em hyprctl binds).
- Base da branch: redesenho-barra (não main), porque o pedido continua aquele trabalho.
- Google Maps: removido no arquivo pessoal ~/.config/hypr/bindings.lua (não é do projeto).

## Decisões em aberto (dependem do usuário)
- (nenhuma ainda)
