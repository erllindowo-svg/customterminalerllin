# Componentes de terceiros e licenças

O repositório é **privado e de uso pessoal**. Isso não dispensa as condições
das licenças de terceiros: o que não pode ser copiado livremente fica fora do
repositório e é obtido na instalação.

## Incluídos no repositório

| Componente | Onde | Origem | Licença | Observação |
|---|---|---|---|---|
| `erllan/spotify-media` (fork) | `noctalia/plugins/spotify-media/` | azokyen, [noctalia-dev/community-plugins](https://github.com/noctalia-dev/community-plugins) `spotify-media` @ `6a66f85` (originais em `upstream/`) | MIT | O upstream declara MIT no `plugin.toml`, mas não publica arquivo de licença nem ano. O texto MIT padrão, com o autor declarado, está em `LICENSE` no fork. Diferenças locais em `README.soviet.md`. |
| Ideia de composição da central | `bin/soviet-ops` (comentário) | [ivanimmanuel-dev/Hypr-Dashboard](https://github.com/ivanimmanuel-dev/Hypr-Dashboard) @ `0dddcdf` | MIT | Padrão adaptado: abrir um painel, esperar a janela e usar `preselect` do dwindle. A implantação original registrou que o projeto foi lido, não executado, e o `soviet-ops` é escrito para foot/bash com travas e idempotência próprias. Por ser MIT, a atribuição fica aqui e no cabeçalho do script. |

Todo o restante (scripts `soviet-*`, `install.sh`, `lib/`, plugins
`erllan/tarefas`, `erllan/audio` e `erllan.sem-barra`, paleta, tema
`soviet-terminal` sem as fotos, configurações) foi escrito para este projeto.

## Obtidos na instalação (não versionados)

| Componente | Como | Licença | Por que fica fora |
|---|---|---|---|
| **arttime** 2.5.0 (código + coleção de 516 artes e frases) | `scripts/install-arttime.sh`: clone de [poetaman/arttime](https://github.com/poetaman/arttime) @ `38c2955`, instalado pelo `install.sh --local` do próprio arttime | Código: GPL-3.0 + addendum **CFLA v1.0**. Arte: propriedade dos artistas, "uso pessoal não comercial" (`LICENSE_ART`); a curadoria também está sob CFLA. | A coleção não é nossa e o uso é só pessoal. O projeto **não copia nenhuma arte nem frase**: tudo é lido da instalação do arttime e desenhado pelo `artprint`. O `soviet-arte` copia `arttime.zsh` para uma árvore temporária em `$XDG_RUNTIME_DIR` (tmpfs) ao abrir o modo interativo; essa cópia não é distribuída. |
| **omarchy-overview** (`moorgrove.overview`) | `install.sh`: clone de [itsmoorgrove/omarchy-overview](https://github.com/itsmoorgrove/omarchy-overview) @ `1ed4938` | MIT | Plugin de terceiros instalável por si só; basta fixar o commit. |
| **Fotos do tema** `soviet-terminal` (5 imagens, 39 MB) + `preview.png` | `scripts/fetch-backgrounds.sh`: Wikimedia Commons com conferência de SHA-1 | CC BY-SA 3.0, CC BY-SA 3.0 DE, CC BY 2.0, CC BY-SA 4.0, CC0 (créditos em `omarchy/themes/soviet-terminal/SOURCES.md`) | Há dúvida concreta sobre direitos: as **esculturas** retratadas podem ter direitos próprios (a Rússia não tem liberdade de panorama ampla), e CC BY-SA exige atribuição e mesma licença em derivados (o `preview.png` é um deles). Por precaução, nada disso é versionado. |
| **Tela CRT do tema de boot** (`background.png`, 1920×1080) | `scripts/install-limine-theme.sh` (`LIMINE_ORIGEM=arte`): download de [shvchk/fallout-grub-theme](https://github.com/shvchk/fallout-grub-theme) @ `b441e25` com SHA-256 conferido; é o mesmo arquivo de `high-res-bg/background.png` do [Neptune3013/fallout-limine-theme](https://github.com/Neptune3013/fallout-limine-theme) @ `9a777b9` | Repositórios MIT, mas a arte (Vault Boy, "RobCo Industries") é propriedade da Bethesda/ZeniMax; a licença MIT dos repositórios não a cobre. | Arte de terceiros. O repositório guarda só o gerador `scripts/limine-wallpaper.py`, que **remove o personagem e o texto** e recolore (o título padrão em `config/terminal-soviet.conf` redesenha o texto da tela RobCo com a fonte do boot: é texto da Bethesda, citado só para uso pessoal); a imagem baixada e a gerada ficam só no cache local (`~/.cache/terminal-soviet/limine/`) e na ESP. Com `LIMINE_ORIGEM=zero` nada é baixado. |
| **Fonte PHXEGA8.F14** (opcional, `LIMINE_FONTE=phxega`) | download do [Neptune3013/fallout-limine-theme](https://github.com/Neptune3013/fallout-limine-theme) @ `9a777b9` com SHA-256 conferido | Não declarada (parece um dump da ROM EGA da Phoenix; nenhum dos repositórios diz a origem) | Licença incerta: nunca versionada, nunca padrão. |
| **Terminus** (fonte padrão do menu de boot) | pacote `terminus-font` (`ter-i14n.psf.gz`, IBM-437), convertida na instalação por `scripts/limine-font.py` | SIL OFL 1.1 | Pacote do sistema; a fonte convertida só existe na ESP. |
| Ideias e valores do tema de boot | [Neptune3013/fallout-limine-theme](https://github.com/Neptune3013/fallout-limine-theme) @ `9a777b9` (chaves e cores do `Limine.txt`, usadas na variante `fallout`; lógica do instalador CachyOS) e [magicdude4eva/fallout-limine-theme](https://github.com/magicdude4eva/fallout-limine-theme) @ `693365d` (lógica do `setup.sh`) | MIT | Lidos, não copiados; o instalador foi escrito para este projeto. Valores de cor da variante `fallout` = os do upstream, para comparação. |
| Noctalia, Omarchy, Hyprland, foot, btop, fastfetch, zsh… | pacotes do Arch/Omarchy | várias | Dependências do sistema (`docs/stack.md`). |

## Referências sem cópia

* `omarchy/themes/soviet-terminal/icons.theme` só **nomeia** o tema de ícones
  `Yaru-olive-dark`; `neovim.lua` só **nomeia** o plugin `everforest-nvim`.
* A fonte `JetBrainsMono Nerd Font` vem do Omarchy.
