Se você está retomando: leia `retomada/PROGRESSO.md` e continue do "próximo passo".

# Tema de boot do Limine — especificação (pedido de 2026-10-13)

Base: branch `redesenho-barra` (ainda não mesclada na `main`). Esta branch: `limine`,
no worktree `~/www/customterminalerllin-limine`. Revisão só deste pedido:
`git -C ~/www/customterminalerllin-limine log --oneline redesenho-barra..limine`.

Regras: MODO DE PLANO primeiro (arquivos, riscos, dúvidas) e esperar aprovação do
usuário. Commits pequenos `wip: …` + `retomada/PROGRESSO.md` atualizado a cada passo.
NUNCA rodar `--install` no /boot real sem aprovação do plano E das capturas da VM.
O `install.sh` principal não usa sudo nem toca /boot: não alterá-lo para isso.

## Pedido (texto do usuário, completo)

1. **Referência** (ler o código, não só o README; sem clonar histórico nem copiar
   para o repositório):
   - `Neptune3013/fallout-limine-theme` (MIT, Limine v12.3) — BASE: `Fallout_limine/Limine.txt`
     (bloco de configuração), `background.jpg`/`high-res-bg/background.png`, fonte
     `PHXEGA8.F14`, `install-fallout-limine-cachyos.sh` (menu, backup, restauração,
     hashes de Secure Boot).
   - `magicdude4eva/fallout-limine-theme` (MIT) — só a lógica do `setup.sh` (backup em
     `/boot/limine.conf.bak-*`, `b2sum`, remover entradas antigas antes de inserir).
     Cores dele inconsistentes (`term_background: ffffffff`): não copiar.
   - O tema é um conjunto de chaves do `limine.conf`: `wallpaper`, `term_font`
     (+ `term_font_size: 8x14`, `term_font_scale: 2x2`), `term_background` (TTRRGGBB,
     transparência para o papel de parede aparecer), `term_margin: 0`, `term_foreground`,
     `term_palette`, `term_palette_bright`, `interface_branding:` vazio,
     `interface_help_hidden`, `timeout`, `remember_last_entry`. Reproduzir TODAS, com as
     dependências (fonte combinando com `term_font_size`).
2. **Direitos**:
   - Arte (Vault Boy, "RobCo Industries") é de terceiros: NÃO commitar `background.*`
     nem versão editada. Verificar licença da `PHXEGA8.F14`; se não clara, não copiar:
     baixar do upstream na instalação ou usar fonte CP437 livre (Terminus/`kbd`).
   - Baixar ativos do upstream por commit fixo + SHA-256 (padrão do `install-arttime.sh`).
     Registrar repo, commit, licença e observação de direitos em `THIRD_PARTY.md`.
   - Repositório guarda só o gerador `scripts/limine-wallpaper.py` (Pillow + numpy):
     parte da imagem baixada e REMOVE o Vault Boy. Linhas de varredura periódicas iguais
     em todas as colunas; personagem ≈ x 1380–1875, y 520–1040 em 1920×1080. Substituir
     pixels que diferem da mediana da linha (faixa limpa, ex. x 300–1100) pela mediana,
     dilatar máscara ~4 px, preservar a moldura arredondada. Remover o texto
     "ROBCO INDUSTRIES…" do topo; opção `--titulo "TERMINAL SOVIETICO"`. Tela fica só com
     fundo CRT e menu. Opção `--gerar-do-zero` (varredura, vinheta, moldura sem a arte).
   - Resolução do monitor (hoje 1920×1080), configurável.
3. **Instalador separado** `scripts/install-limine-theme.sh`:
   - `--plan` (padrão, não escreve), `--install`, `--remove` (volta ao backup),
     `--status` (aplicado? hash bate? Omarchy sobrescreveu?);
   - sudo só na hora de escrever em /boot, dizendo por quê;
   - backup datado de `/boot/limine.conf` antes de mudar; conferir depois (arquivo
     válido, entradas intactas);
   - idempotente: bloco entre `# >>> terminal-soviet limine >>>` … `# <<<`, substituído,
     nunca duplicado;
   - SUBSTITUI (não duplica) chaves do topo do Omarchy (`interface_branding`,
     `interface_branding_color`, `interface_help_color`, `interface_help_color_bright`,
     `term_*`, `backdrop`, `hash_mismatch_panic`). Manter `default_entry`,
     `hash_mismatch_panic: no` e tudo abaixo do cabeçalho (entradas do
     `limine-entry-tool` e `limine-snapper-sync`);
   - copia fonte e papel de parede para /boot (conferir ESP real e `boot():`), grava
     `b2sum` após `#` nas linhas `wallpaper` e `term_font`;
   - roda `limine-update` e `limine-snapper-sync` no fim (como `omarchy-refresh-limine`);
   - recusa se `limine --version` ≠ v12.x (matriz em `lib/compat.sh`), se faltar
     `/boot/limine.conf`, ou se houver configs legadas lidas antes
     (`/boot/EFI/limine/limine.conf` etc., ver `omarchy-upgrade-to-quattro`).
4. **Paleta** `LIMINE_THEME="fosforo|ambar|fallout"` em `config/terminal-soviet.conf`,
   valores de `omarchy/themes/soviet-terminal/colors.toml`:
   - fosforo (padrão): texto B8D58A, destaque D2E8AE, ajuda 718D58, fundo 101210,
     palette/bright a partir do tema;
   - ambar: texto C9B26B, destaque DCC88A, fundo 101210;
   - fallout: valores originais do upstream (comparação).
   Papel de parede acompanha a variante (verde ou âmbar).
5. **Pontos que podem quebrar**:
   - Omarchy sobrescreve `limine.conf` (`omarchy-refresh-limine` troca pelo modelo e
     guarda .bak; upgrade mexe nas cores com sed): `--status` detecta e propõe
     reaplicar; se aprovado, oferecer hook do pacman ou unit path do systemd. NÃO
     instalar sem perguntar.
   - Cirílico: fonte CP437 → título e entradas em ASCII. Testar (só VM) fonte CP866
     (`kbd`) com texto em CP866; se não funcionar, documentar.
   - `term_background` com transparência: validar em VM (papel aparece, texto legível).
   - Escala 2×2 em 1920×1080 e outras: calcular `term_font_scale` pela resolução.
6. **Verificação**: VM QEMU + OVMF com ESP e Limine v12; aplicar o tema; capturas
   (`screendump`) das três variantes e mostrar ao usuário. Testar na VM: instalar,
   reinstalar, remover, Omarchy sobrescrevendo, hash errado, fonte ausente.
7. **Docs e testes**: `docs/boot-theme.md` (o que é, instalação, remoção, variantes,
   riscos, recuperação pelo shell do Limine ou live USB); atualizar `README.md`,
   `docs/decisions.md`, `docs/file-map.md`, `docs/stack.md` (b2sum, Pillow, numpy,
   qemu/ovmf só para testes), `THIRD_PARTY.md`. `tests/static.sh`: bash -n, shellcheck,
   script nunca escreve fora de /boot e do backup. `tests/sandbox.sh` com limine.conf
   falso, sem sudo.
8. **Entregar**: resumo do plano, lista de arquivos novos, capturas da VM, comando exato
   para revisar e instalar; o que ficou de fora e por quê.

## Decisões tomadas
(ver PROGRESSO.md → "Decisões")
