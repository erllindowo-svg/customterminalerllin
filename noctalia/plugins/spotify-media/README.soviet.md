# erllan/spotify-media — fork local de azokyen/spotify-media

Origem: `noctalia-dev/community-plugins`, diretório `spotify-media`, v0.1.1, MIT,
autor azokyen. A revisão está em `upstream/REVISION`; os arquivos originais
estão em `upstream/`. O README do upstream fica em `README.md`.

Diferenças (o diff completo sai de `diff upstream/bar.luau bar.luau.in`):

1. **A barra é o player.** Nada de ícone do Spotify. O widget mostra sempre a
   última música tocada (capa, artista – título), inclusive logo após ligar o
   PC com o Spotify fechado: título, artista, capa e `mpris:trackid` ficam em
   `pluginDataDir()/ultima.json` (+ `capa-N.jpg`) a cada troca de faixa.
2. **Play com o Spotify fechado**: `tocar.sh` abre o Spotify **sem mostrar a
   janela** (workspace especial `musica`, regra em `hypr/terminal_soviet.lua.in`
   e, para a classe definida tarde, um `window.move` silencioso) e retoma a
   última faixa (`playerctl open spotify:track:…`).
3. **Painel `player`** (clique na capa ou no título): capa grande, ⏮ ⏯ ⏭,
   progresso (lido a cada segundo só com o painel aberto), "Mostrar o app"
   (alterna `special:musica`) e um campo de busca:
   * com `~/.config/terminal-soviet/spotify.env` (permissão **600**, fora do
     repositório):
     ```
     SPOTIFY_CLIENT_ID=...
     SPOTIFY_CLIENT_SECRET=...
     ```
     a Web API (client credentials) é usada **só para buscar**; o clique num
     resultado toca pelo MPRIS local. Arquivo com outra permissão é recusado.
   * sem credenciais: Enter abre a busca no app (`spotify --uri=spotify:search:…`).
4. **Metadados por evento**: um `playerctl --follow metadata` no lugar do
   `playerctl metadata` a cada 1 s. O tick de 500 ms só existe enquanto o texto
   rola.
5. `bar.luau.in` é um modelo: o `install.sh` gera `bar.luau` com os tamanhos da
   grade única da barra (`@ITEM@` = 22, `@ICON@` = 16, em `lib/ts-lib.sh`). A
   capa fica numa caixa fixa ITEM×ITEM que não encolhe, com cantos retos.
6. Texto rolante com 11 caracteres / 92 px (upstream 16 / 136); sem a prop
   `align` dos `ui.button` (a API 5.0.1 não a aceita). Barra vertical: capa + ⏯
   empilhados.

O marquee (`utf8Chars`, `charWidth`, `scrollingText`) e `stripNewline` são do
upstream, sem mudança.

Dependências: `playerctl` (extra), `hyprctl`, `jq`, `spotify` (pacote nativo).
Rede: só a busca com credenciais (accounts.spotify.com, api.spotify.com).
