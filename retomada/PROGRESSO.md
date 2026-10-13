# Progresso — tema de boot do Limine

## Onde parei
Pesquisa feita e plano escrito em `retomada/PLANO.md`. **Aguardando aprovação do
usuário** (e respostas Q1–Q5 do plano). Nada implementado; nada tocado em /boot.
Também na branch: cherry-pick do fix da espessura da barra (`102f272` da redesenho-barra).

## Próximo passo exato
1. Se aprovado: instalar dependências de teste (Q1) — o usuário roda o `sudo pacman`.
2. `scripts/limine-font.py` (PSF+Unicode → raw CP437/CP866) + teste.
3. `scripts/limine-wallpaper.py` (remoção do Vault Boy/texto, recolor, `--gerar-do-zero`).
4. `scripts/install-limine-theme.sh` + `tests/fixtures/limine.conf` + `tests/limine.sh`.
5. `tests/vm-limine.sh` (QEMU/OVMF/vvfat) → capturas das 3 variantes → mostrar.
6. Docs (boot-theme.md, decisions D19, file-map, stack, THIRD_PARTY, README) e static.sh.

## Checklist
- [x] worktree `../customterminalerllin-limine` (branch `limine`, base redesenho-barra) + ESPEC
- [x] leitura das referências e do sistema (achados em PLANO.md)
- [ ] aprovação do plano
- [ ] fonte · papel de parede · instalador · testes sandbox · VM e capturas · docs
- [ ] (nunca) --install no /boot real sem aprovação das capturas

## Como verificar
`git -C ~/www/customterminalerllin-limine log --oneline redesenho-barra..limine`

## Ativos upstream (SHA-256 conferidos em 2026-10-13, baixados só no scratchpad)
- shvchk/fallout-grub-theme@b441e25a6d115614dc00ee6d11355d019a4969bf background.png
  224e4ff6ae09c54cda9b8519494eb5d2e87526761da6310444d5c4397ccb3906
- Neptune3013/fallout-limine-theme@9a777b932de07dce60e58b2a1162b7d41ecfd2e9
  Fallout_limine/PHXEGA8.F14 4811ac4edd9c2d5996131ec416b1c50ce8f94cbafea82b70069eedea91622537
  Fallout_limine/background.jpg 5f0d400f0dc6419fbde91c6cd2a82837f6cb3aa05acbd8be6ae603848146fd2f

## Decisões
(propostas em PLANO.md; registrar aqui as aprovadas)

## Decisões em aberto (dependem do usuário)
Q1–Q5 em PLANO.md.
