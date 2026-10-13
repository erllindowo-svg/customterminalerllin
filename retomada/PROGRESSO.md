# Progresso — tema de boot do Limine

## Onde parei
Implementação COMPLETA no worktree; nada tocado no /boot real.
- scripts/limine-font.py, scripts/limine-wallpaper.py, scripts/install-limine-theme.sh
- tests/limine.sh (50/0, /boot falso), tests/vm-limine.sh (14/0, capturas em
  tests/results/vm-limine/), tests/static.sh (60/0)
- docs: boot-theme.md, decisions D19, stack, file-map, THIRD_PARTY, README.
Achados da VM: hash errado = tela PRETA esperando tecla (Y segue); fonte ausente =
fonte embutida; Limine v12 converte UTF-8→CP437 (acentos ok, cirílico só com
fonte CP866 + texto nas posições CP437) → título em cirílico via fonte CP866 própria.

## Próximo passo exato
1. Mostrar as capturas ao usuário e pedir aprovação para o --install no /boot real.
2. Se aprovado: `scripts/install-limine-theme.sh` (plano, com sudo), depois
   `--install`, `--status`; o usuário reinicia para ver.
3. Mesclar limine → redesenho-barra (sem retomada/) quando aprovado.

## Checklist
- [x] worktree `../customterminalerllin-limine` (branch `limine`, base redesenho-barra) + ESPEC
- [x] leitura das referências e do sistema (achados em PLANO.md)
- [x] aprovação do plano
- [x] fonte · papel de parede · instalador · testes sandbox · VM e capturas · docs
- [ ] (nunca) --install no /boot real sem aprovação das capturas

## Como verificar
`git -C ~/www/customterminalerllin-limine log --oneline redesenho-barra..limine`

## Ativos upstream (SHA-256 conferidos em 2026-10-13, baixados só no scratchpad)
- shvchk/fallout-grub-theme@b441e25a6d115614dc00ee6d11355d019a4969bf background.png
  224e4ff6ae09c54cda9b8519494eb5d2e87526761da6310444d5c4397ccb3906
- Neptune3013/fallout-limine-theme@9a777b932de07dce60e58b2a1162b7d41ecfd2e9
  Fallout_limine/PHXEGA8.F14 4811ac4edd9c2d5996131ec416b1c50ce8f94cbafea82b70069eedea91622537
  Fallout_limine/background.jpg 5f0d400f0dc6419fbde91c6cd2a82837f6cb3aa05acbd8be6ae603848146fd2f

## Decisões (aprovadas pelo usuário em 2026-10-13)
- Plano aprovado. Q1: dependências de teste instaladas (qemu-base, edk2-ovmf, pillow,
  numpy, terminus-font, shellcheck). Q2: fonte padrão Terminus, `phxega` opcional.
  Q3: sudo também para LER /boot no --plan/--status. Q4: NÃO forçar
  interface_resolution. Q5: timeout 15 s.
- O --install no /boot REAL continua dependendo de o usuário ver as capturas da VM.

## Decisões em aberto (dependem do usuário)
- Aprovar as capturas da VM antes do --install real.
