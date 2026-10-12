# erllan/spotify-media — fork local de azokyen/spotify-media

Origem: `noctalia-dev/community-plugins`, diretório `spotify-media`, v0.1.1, MIT,
autor azokyen. A revisão está em `upstream/REVISION`; os arquivos originais
estão em `upstream/`. O README do upstream fica em `README.md`.

Diferenças (o diff completo sai de `diff upstream/bar.luau bar.luau`):
1. Abre o Spotify **nativo** (`uwsm-app -- spotify`) quando não há janela, em
   vez do `spotify-launcher`, outro cliente que não está nem será instalado.
2. Capa com cantos retos (radius 0).
3. Texto rolante com 11 caracteres / 92 px (upstream 16 / 136) para caber na barra.
4. Removida a prop `align` dos `ui.button`. A API 5.0.1 não a aceita e gerava
   cerca de 25 avisos por segundo no journal.

Dependências: `playerctl` (extra), `hyprctl`, `spotify` (pacote nativo).
Sem API Web e sem credenciais: só MPRIS local (player `spotify`).
