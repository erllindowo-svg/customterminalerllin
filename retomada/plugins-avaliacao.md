# Item 7 — avaliação de plugins do Noctalia (nada instalado)

Fonte: `plugin.toml` de cada plugin, lido por `gh api` em
`noctalia-dev/community-plugins@7691612` e `noctalia-dev/official-plugins@9aec341`
(2026-10-13). Instalado: Noctalia 5.0.1, que aceita `plugin_api` 3–30, então todos
os plugins abaixo carregam. Dependências conferidas com `command -v` nesta máquina.

| Plugin | API | Licença | Dependências (faltando) | Coexistência com o Omarchy / o projeto | Proposta |
|---|---|---|---|---|---|
| blackbartblues/audio-switcher | 15 | MIT | pactl, bluetoothctl | Sobrepõe `erllan/audio` (popup, troca fone ↔ alto-falante) e `omarchy-audio-output-switch` | **Só referência** (a passagem de dispositivo Bluetooth pode inspirar o `erllan/audio`) |
| kenn/keybind-cheatsheet | 9 | MIT | hyprctl | O Omarchy já tem `SUPER + K` (`omarchy-menu-keybindings`); com a config em Lua, o `hyprctl` só dá a descrição | **Descartar** |
| notoxus/media-island | 24 | MIT | busctl | Sobrepõe o player `spotify-media` e ocupa o centro da barra, onde ficam as ações | **Só referência** |
| goatnath/spotify-lyrics | 3 | MIT | playerctl, python3, **syncedlyrics** | Busca letras em serviços externos; precisa de pacote Python fora do repositório | **Descartar** (dependência extra) |
| h465855hgg/lyrics | 3 | MIT | playerctl, python3 | Mesma função, sem `syncedlyrics`; consulta serviços externos de letras | **Candidato**: fork local, se você quiser letras no painel do player |
| jamesfeeder/special-workspaces | 3 | MIT | socat | Mostra os workspaces especiais (scratchpad do Omarchy); orientado a eventos | **Candidato**: usar como está, se você usa o scratchpad |
| alexander/game-launcher | 13 | MIT | cc, xdg-utils | Compila um auxiliar em C na máquina (`cc`); os jogos já estão no grupo "Jogos" | **Descartar** |
| alexander/screen-toolkit | 13 | MIT | 20+ (falta **wf-recorder**; niri opcional) | Sobrepõe a captura e a gravação do Omarchy (`omarchy-capture-*`, `hyprpicker`, OCR de `omarchy-capture-text`) | **Só referência** |
| thepunkoff/pomodoro | 22 | MIT | ffplay | Função coberta pelo timer oficial | **Descartar** em favor do timer |
| noctalia/timer (oficial) | 20 | MIT | — | Nada parecido no Omarchy; widget, painel e widget de área de trabalho | **Candidato**: usar como está (cópia fixada) |
| noctalia/notes (oficial) | 26 | MIT | — | O Omarchy não tem notas rápidas; painel lateral de altura inteira | **Candidato**: usar como está (cópia fixada) |

Os escolhidos entram como os outros plugins de terceiros (ver `spotify-media`): cópia
fixada em `upstream/` com `REVISION`, `README` de diferenças, licença, sem
`auto_update`, e as fontes de plugins do Noctalia continuam desligadas.

**Aguarda o usuário**: quais candidatos instalar (timer, notes, special-workspaces, lyrics).
