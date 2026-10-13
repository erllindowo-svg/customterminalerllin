# Progresso — barra v2

## Onde parei
Passo 0 concluído (worktree + arquivos de retomada). Começando o item 1 (limites da API).

## Próximo passo exato
Item 1: conferir no fonte do Noctalia v5.0.1 (gh api repos/noctalia-dev/noctalia,
ref v5.0.1) e nas tags 5.1.0/5.2.x o `kCurrentPluginApiVersion` e o que as APIs
29+ adicionam (docs/plugin-api.json de cada tag). Registrar em "Achados da API".

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
- [ ] 1 limites da API (instalada × mais nova) → docs/decisions.md
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

## Achados da API (item 1)
(preencher)

## Decisões
- Base da branch: redesenho-barra (não main), porque o pedido continua aquele trabalho.
- Google Maps: removido no arquivo pessoal ~/.config/hypr/bindings.lua (não é do projeto).

## Decisões em aberto (dependem do usuário)
- (nenhuma ainda)
