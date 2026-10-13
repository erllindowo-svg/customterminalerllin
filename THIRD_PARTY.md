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
| Noctalia, Omarchy, Hyprland, foot, btop, fastfetch, zsh… | pacotes do Arch/Omarchy | várias | Dependências do sistema (`docs/stack.md`). |

## Referências sem cópia

* `omarchy/themes/soviet-terminal/icons.theme` só **nomeia** o tema de ícones
  `Yaru-olive-dark`; `neovim.lua` só **nomeia** o plugin `everforest-nvim`.
* A fonte `JetBrainsMono Nerd Font` vem do Omarchy.
