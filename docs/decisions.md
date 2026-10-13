# Decisões

Cada item traz o contexto, a escolha, as alternativas descartadas e o limite conhecido.

## D1. Raiz do repositório = `~/www/customterminalerllin`

* **Contexto**: a pasta existia vazia; nenhum Git nela nem nos pais. O
  vizinho `~/www/hyprland-guide` é outro projeto Git (só cita o tema).
* **Escolha**: a própria pasta é a raiz do repositório. Os arquivos ativos
  continuam em `~/.config` e `~/.local`, onde o Omarchy/Hyprland/Noctalia os
  leem; o repositório é a fonte, e o `install.sh` gera os destinos.
* **Descartado**: mover os arquivos ativos para dentro do repositório (quebraria
  a sessão atual); repositório aninhado em `www/`.

## D2. Modelo de instalação: cópias gerenciadas + manifesto

* **Escolha**: `install.sh` renderiza/copia arquivos e registra o SHA-256 de
  cada um. Ele compara destino × manifesto × versão nova antes de escrever e
  **para inteiro** se houver conflito, sem aplicar mudanças parciais.
* **Por quê**: funciona com qualquer diretório de checkout e com o
  repositório movido ou apagado depois; detecta edições locais; permite
  desinstalar só o que foi instalado; a reexecução é verificável (testes de
  idempotência).
* **Descartado**:
  * **links simbólicos** para o repositório: editar o checkout muda a sessão
    viva sem revisão, mover o repositório quebra o desktop, e o Noctalia
    precisa dos caminhos absolutos do `$HOME` renderizados;
  * **GNU Stow / chezmoi / yadm**: o projeto tem ~60 arquivos, modelos com 10
    marcadores e três integrações pontuais (bloco Lua, `shell.json`, links do
    systemd). Um framework traria dependência e convenções sem resolver essas
    integrações, que exigiriam scripts de qualquer forma.
* **Limite**: depois de editar o repositório, é preciso rodar `./install.sh`.

## D3. Integração mínima com arquivos do usuário

* `hyprland.lua`: **um** bloco marcado com `require("hypr.terminal_soviet")`.
  Todo o resto fica no módulo próprio. A desinstalação remove só o bloco e
  preserva edições posteriores do usuário (testado).
* `shell.json`: só `bar.id` e `bar.position`, pelo comando suportado
  `omarchy bar use/position`. Fora de sessão (testes), as mesmas duas chaves
  são editadas com `jq`, sem IPC. Os valores anteriores ficam em
  `shelljson.prev`.
* Nada em `/usr/share/omarchy` é alterado. Não usa sudo.

## D4. Barra: Noctalia como única barra, shell do Omarchy preservado

* **Contexto**: barra, notificações, lock, OSD, polkit, papel de parede e
  menus do Omarchy rodam no mesmo processo (quickshell). Ferramentas do Omarchy
  dependem desses serviços.
* **Escolha**: manter o shell e trocar só a barra, pelo mecanismo suportado
  `bar.id` (plugin `kind: "bar"` nulo). O Noctalia faz só a barra e os painéis
  que ela abre; `00-coexistencia-omarchy.toml` desliga nele tudo o que o
  Omarchy já faz.
* **Descartado**: barra do Omarchy customizada (sem sysmon/clima/IPC
  `bar-hide` equivalentes); substituir o shell inteiro; duas barras.
* **Limite**: dois processos de shell (Noctalia ~210 MB RSS e quickshell
  ~400–500 MB RSS). Ver `docs/performance.md`.

## D5. Visibilidade da barra por eventos, nunca por toggle

`soviet-bar-sync` lê o socket2 do Hyprland e envia `bar-hide`/`bar-show`
explícitos só quando o estado desejado muda. O hook `started` reaplica o
estado se o Noctalia reiniciar. Sem polling; não há como dessincronizar.
**Limite**: com vários monitores, a barra segue o monitor focado (D10).

## D6. Plugin próprio de tarefas em vez do taskbar nativo

O taskbar do Noctalia 5.0.1 não exclui um workspace (`hidden_workspaces` só
existe em versões posteriores). O `erllan/tarefas` exclui o workspace da
central e reage a eventos. Antes eram consultas a cada 1 s com um aviso no log
a cada render. **Reavaliar** ao atualizar o Noctalia.

Desde a versão 2.0 ele imita a barra do Windows: dois widgets do mesmo plugin
(`abertos` à esquerda, `fixados` à direita) e um `[[service]]` (`fonte`), que é
o **único** `socat` e o único escritor de `fixados.json`. Os widgets recebem o
modelo por `noctalia.state` (VMs isoladas não compartilham memória). O
`hyprctl clients -j` passa pelo `jq` antes do Luau, porque decodificar o JSON
inteiro estourava o orçamento de CPU do callback.

* **Fixar/desafixar**: na API 5.0.1 (níveis 3–30), o menu de contexto nativo
  (`panel.openContextMenu`) só existe dentro de painéis. Na barra, ícones
  clicáveis capturam só o botão esquerdo; o direito chega ao `onRightClick()`
  do widget, e o `onHover` de cada ícone diz qual estava sob o ponteiro. O
  clique direito abre então um mini-menu (painel `erllan/tarefas:menu`).
* **Descartado**: `custom_button` por lançador (Firefox, osu) e separadores; a
  seção `end` da barra corta à esquerda o que não cabe.

## D7. arttime: instalação externa fixada, sem copiar a coleção

* **Escolha**: clonar o arttime num commit fixo e usar o instalador dele
  (`--local`). O projeto lê arte e frase da instalação.
* **Por quê**: a arte é "uso pessoal não comercial" e pertence aos artistas
  (`LICENSE_ART` + CFLA); o código é GPL-3.
* **Descartado**: copiar artes para o repositório (o "globe.txt" da Fase 0
  ficou fora); AUR `arttime-git` (não fixado, exige root); `curl | sh` do
  instalador online.

## D8. Integração com o arttime interativo por uma árvore temporária + shim

O arttime chama `"$bindir/artprint"`, com `bindir` derivado do caminho **real**
do `arttime.zsh` (`${0:A}`). Para aplicar as cores e saber a arte escolhida
sem alterar o arttime, o `soviet-arte` monta em `$XDG_RUNTIME_DIR` uma árvore
com o `arttime.zsh` original copiado, a coleção por link e `bin/artprint`
substituído por um shim que registra a arte e repassa ao `artprint`
verdadeiro.
* **Descartado**: modificar o arttime (perde-se a atualização limpa);
  interceptar o terminal com um proxy de pty (complexo, frágil); ler o
  histórico `aart.hist` (não registra o sorteio `j`).
* **Limite**: fechar a janela no meio de um sorteio adota a arte em exibição.

## D9. Frases ausentes

509 das 516 artes só têm o texto-modelo como "frase". Elas aparecem sem frase,
e o menu diz "(sem frase no acervo original)". Não se combinam artes e frases
de fontes diferentes nem se escrevem frases novas.

## D10. Limites aceitos nesta versão

* Vários monitores: barra única que segue o monitor focado. Não testado com
  hardware real.
* Sem sensores na barra: o centro tem ações (D14). Firefox e osu! são fixados
  comuns (sem lançador próprio). O jogo da barra (`GAME_DESKTOP`) é omitido
  quando o `.desktop` não existe.
* Teclas físicas e cliques reais não são automatizáveis aqui (o `wtype` não
  aciona atalhos globais). Os comandos que cada tecla/botão executa são testados.

## D11. Papéis de parede fora do repositório

Fotos CC BY/BY-SA de monumentos soviéticos; as esculturas podem ter direitos
próprios. `scripts/fetch-backgrounds.sh` baixa do Commons e confere o SHA-1.
Ver `THIRD_PARTY.md`.

## D14. Centro da barra: ações no lugar dos sensores

* **Contexto**: o grupo CPU/RAM/GPU/NET ocupava ~520 px no centro. A seção da
  direita do Noctalia só recebe o espaço entre o fim do centro e a borda e corta
  à esquerda o que não cabe; com os fixados à direita, o player sumia.
* **Escolha**: só o ícone de inspeção (btop) fica, mais ações tiradas do que
  ficava escondido no control center: captura, luz noturna, cafeína, perfil de
  energia e um jogo. O que é do Omarchy chama o Omarchy (captura, hyprsunset,
  idle do shell); o perfil de energia é o widget nativo (power-profiles-daemon
  via D-Bus, que não é serviço do shell Omarchy). Wi-Fi e Bluetooth ficaram de
  fora: esta máquina não tem nenhum dos dois.
* `[system.monitor]` desligado: nada na barra usa o sysmon. Só a aba "System"
  do control center depende dele.
* **Limite**: luz noturna e cafeína são `custom_button`, sem estado visível.

## D12. Música: a barra é o player; Web API do Spotify opcional, só para busca

* **Contexto**: o fork `spotify-media` não usava a Web API, só o MPRIS local. A
  barra agora finge ser o próprio player: sem ícone do Spotify, última faixa
  sempre visível, Spotify aberto oculto (`special:musica`), painel com busca.
* **Escolha**: o MPRIS só lista o que está tocando; para listar resultados de
  busca no painel é preciso a Web API. Ela é usada **só para buscar**, com
  client credentials (sem login de usuário), e tocar continua local
  (`playerctl open spotify:track:ID`). As credenciais ficam fora do repositório,
  em `~/.config/terminal-soviet/spotify.env` com permissão 600. Sem elas, a
  busca abre no próprio app (`spotify:search:…`).
* **Descartado**: OAuth de usuário (refresh token guardado, escopos amplos para
  só buscar); controlar a reprodução pela Web API (exige Premium e rede para algo
  que o MPRIS faz localmente).
* **Limite**: a busca depende da política de apps de desenvolvedor do Spotify.
  O Spotify define a classe da janela tarde, e por isso o `tocar.sh` também move
  a janela.
