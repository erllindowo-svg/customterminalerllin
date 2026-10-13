# Progresso — barra v2

## Onde parei
Item 5, parte 1: bin/soviet-atalhos pronto (avalia hyprland.lua num Lua isolado com hl falso + cruza com hyprctl binds -j + resolve comando → app pelos .desktop). Achado: hyprctl binds -j só mostra dispatcher "__lua" (sem comando) na config Lua. Parte 2: service do tarefas consome e widgets mostram no hover; tooltips dos nativos via install.sh.

## Próximo passo exato
Item 5 (atalho no hover): bin/soviet-atalhos → JSON {chave → "SUPER + SHIFT + B"}
a partir de `hyprctl binds -j` (exec/arg). Resolver: uwsm-app -- X.desktop → X;
omarchy-launch-or-focus/soviet-launch… → classe; omarchy-launch-browser → navegador
padrão (xdg-settings get default-web-browser); xdg-terminal-exec/omarchy-launch-
terminal → terminal padrão; binário simples → binário. Casar com apps por
desktop-id, classe e Exec. Service do tarefas roda no início e em
`configreloaded` → state "atalhos"; widgets: onHover → barWidget.setTooltip.
Nativos: tooltips do 20-barra.toml.in com @KEY_*@ e atalhos do Omarchy lidos
pelo install.sh (hyprctl binds na sessão).

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
- Atalhos: `hyprctl binds -j` não traz o comando (dispatcher "__lua"); a config é avaliada num Lua isolado (hl falso só registra bind/unbind; os.execute/io.popen inertes) e cruzada com o hyprctl (só binds ativos).
- KEY_PIN = SUPER + ALT + P (SUPER + ALT + F já é "Full width" do Omarchy; P livre em hyprctl binds).
- Base da branch: redesenho-barra (não main), porque o pedido continua aquele trabalho.
- Google Maps: removido no arquivo pessoal ~/.config/hypr/bindings.lua (não é do projeto).

## Decisões em aberto (dependem do usuário)
- Aprovar a tabela app → grupo (retomada/grupos-proposta.txt) antes de gravar grupos.json.
- O lançador "Google Maps" (~/.local/share/applications/Google Maps.desktop) ainda existe; só o atalho foi removido. Remover o webapp também?
