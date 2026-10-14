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

Transição: o Noctalia 5.0.1 já anima o `bar-hide/bar-show` (slide de
`Style::animNormal` = 200 ms × `shell.animation.speed`, `EaseInQuad` ao
ocultar, `EaseOutCubic` ao mostrar; `src/shell/bar/bar.cpp`). Não há duração
nem curva por barra, só a velocidade global. Ela era 1.6 (125 ms) e passou a
1.0. O espaço reservado é liberado no início do hide, e o Hyprland anima o
reajuste das janelas. O Firefox mostra a barra (`COLLAPSE_CLASSES` vazio).
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

## D13. Posição da barra: painel com arrasto + config-reload

* **Contexto**: o pedido era arrastar a barra até uma borda, como no Windows.
  No Noctalia 5.0.1 (API de plugins 3–30), widgets de barra não recebem arrasto
  nem movimento do ponteiro, `ui.dragSource`/`ui.dropZone` só existem dentro de
  painéis, e não há IPC para mudar `position`. Um `config-reload` com outro
  `position` recria a superfície da barra na nova borda
  (`barConfigSurfaceFieldsEqual` compara `position`, em `src/shell/bar/bar.cpp`).
* **Escolha**: clique direito na zona vazia → painel `erllan/barra:posicao` com
  uma mini-tela em que a barrinha é arrastada até a borda (arrasto real, dentro
  do painel) ou escolhida por botões. `soviet-bar-pos` grava a escolha, gera
  `~/.config/noctalia/90-posicao-barra.toml` (estado local, fora do manifesto,
  removido no uninstall), recarrega e reaplica o `soviet-bar-sync`.
* **settings.toml da GUI**: vence os arquivos. O `soviet-bar-pos` detecta
  `position` em `[bar.<BAR_NAME>]` e, em vez de falhar calado, avisa e não
  aplica; o `install.sh check` avisa também.
* **Vertical**: `barWidget.isVertical()` do 5.0.1 compara altura × largura do
  *conteúdo* do widget (`PluginWidget::doLayout`). Um item de 22 px numa barra
  de 26 conta como horizontal, e uma linha larga se perpetua. Os plugins leem a
  posição efetiva com `noctalia.getSetting("bar.<BAR_NAME>.position")` (API 26).
  Na horizontal, sem ícones de apps e sem player: a música é só um símbolo no
  fim da cápsula das ações, que abre o painel do player. Na vertical (810 px
  lógicos de altura), o `soviet-bar-pos` refaz as seções: ações no centro exato,
  abertos em cima e fixados embaixo e, para a seção de baixo caber nos ~315 px
  que sobram, sem clima (fica no control center) e espaço de 4 entre widgets.
* **Fora**: arrastar a própria barra; posição diferente por monitor.

## D15. Central no lugar da tela de descanso do Omarchy

* **Contexto**: no Omarchy 4, o idle é um serviço do shell (`plugins/services/idle`)
  que, no tempo de `idle.screensaver`, roda `bash -lc 'omarchy-launch-screensaver'`.
  Não há hook para isso, e o `PATH` do shell começa por `/usr/share/omarchy/bin`,
  então um `omarchy-launch-screensaver` em `~/.local/bin` nunca seria chamado
  (e sobrepor comandos do Omarchy seria frágil). Não há `hypridle` nem `swayidle`.
* **Escolha**: desligar a tela de descanso pelo flag suportado do Omarchy
  (`toggles/screensaver-off`) e usar o idle do próprio Noctalia
  (`[idle.behavior.central]`, `ext_idle_notifier_v1`, respeita inibidores) para
  rodar `soviet-ops` no mesmo tempo, sem esmaecer antes. O bloqueio segue com o
  Omarchy. O instalador só religa a tela de descanso no uninstall se foi ele
  que a desligou (`install/screensaver-off.nosso`).
* **Limite**: o tempo é lido do `shell.json` na instalação; mudou lá, rode
  `./install.sh` de novo.

## D16. Barra v2: o que a API do Noctalia 5.0.1 permite e as alternativas

* **Fonte**: código do `noctalia-dev/noctalia` nas tags v5.0.1, v5.1.0 e v5.2.x
  (`gh api`). Instalado: 5.0.1, o único no repositório `extra` do Arch, com
  `plugin_api` 3–30. A 5.1.0 também é 30; a 5.2.x sobe para 32
  (`noctalia.getColor` na 31, `tooltip` por nó em `ui.box/row/column/image` na 32).
  Não atualizamos: exigiria pacote fora do `extra`, nova linha em `lib/compat.sh` e
  a revisão dos testes.
* **Arrasto**: `ui.dragSource`/`ui.dropZone` só existem em painéis (o reconciler
  recusa fora deles: "only supported in plugin panels"). Na barra, nada detecta
  "pressionar e mover": `ui.graph.onPointerMove` (API 29) não diz o botão, e
  `onScroll` horizontal é rolagem. Por isso:
  * **reordenar/mover ícones** → painel **"Editar barra"** (`erllan/tarefas:editar`),
    aberto pelo clique direito fora de um ícone da lista de apps ou por "Editar
    barra…" no mini-menu. Duas zonas (Abertos, Fixados): soltar em Fixados fixa
    na posição, em Abertos desafixa; dentro de cada zona, reordena. A ordem vai
    para `fixados.json` (esquema 2: `fixados` + `ordemAbertos`; o esquema 1 é lido e
    regravado como 2). O service `fonte` continua o único escritor.
  * **arrastar a barra** → alça `grip-vertical` no início da barra (e o clique
    direito na zona vazia, como antes): ambos abrem o painel de posição (D13).
* **Menu de contexto**: `panel.openContextMenu` (API 28) só existe em painel e só
  a partir de `ui.button.onRightClick`. Usado no painel Grupos; na barra fica o
  mini-menu próprio (D6).
* **Tooltip**: `barWidget.setTooltip` vale para a área do widget inteiro
  (`PluginWidget::luaSetTooltip` → `m_area`). Trocar o texto no `onHover` de cada
  ícone funciona, mas o balão fica ancorado ao widget, não ao ícone. O tooltip por
  ícone só chega com a API 32.
* **Orçamento de CPU**: cada callback de plugin tem 25 ms de CPU (`kCallBudget`
  em `src/scripting/script_runtime.cpp`); acima disso o 5.0.1 corta o callback.
  `noctalia.appIconPath` custa 18–24 ms por nome com o cache frio, então os
  painéis com muitos ícones (Grupos, Editar barra) abriam vazios. A busca foi para
  `bin/soviet-icones` (mesma ordem do resolvedor: `.desktop` → tema do GTK e
  `Inherits` → hicolor → pixmaps; índice em `~/.cache/terminal-soviet/`): um
  processo por abertura, e o callback só lê os caminhos. Os widgets da barra
  continuam no `appIconPath` (poucos ícones por vez, em cache).
* **IPC de plugin**: `noctalia msg plugin <autor/plugin:entrada> <alvo> <evento>
  [payload]`; `all` é obrigatório para `[[service]]` e `[[panel]]`.
* **Posição efetiva da barra**: `noctalia.getSetting("bar.<nome>.position")`
  (API 26). `getConfig` só lê as settings declaradas do próprio plugin.

## D17. Fixar por atalho e atalhos nos tooltips

* **`KEY_PIN`** (`SUPER + ALT + P`; o `SUPER + ALT + F` sugerido é "Full width" do
  Omarchy) → `noctalia msg plugin erllan/tarefas:fonte all alternar-fixado`.
  O service alterna o ícone sob o mouse (estado `hover-abertos`/`hover-fixados`,
  gravado pelo `onHover` dos widgets) ou, sem ícone sob o mouse, o app da janela
  em foco. O ícone pisca para confirmar. Nada de polling.
* **De onde vêm os atalhos**: com a configuração do Hyprland em Lua, `hyprctl
  binds -j` só traz tecla e descrição (dispatcher `__lua`), não o comando.
  `bin/soviet-atalhos` avalia a própria configuração num Lua isolado (o `hl` falso
  só registra `bind`/`unbind`; `os.execute`/`io.popen` não fazem nada), cruza com
  o `hyprctl` (só binds ativos) e liga comando → app pelos `.desktop` instalados.
  Nenhuma tabela fixa de apps no código.
* **Ícones de apps** (plugin de tarefas): o service roda o `soviet-atalhos` ao
  iniciar e a cada `configreloaded`; o tooltip mostra "Nome — TECLAS".
* **Widgets nativos** (menu, inspeção, captura, luz noturna, cafeína,
  notificações): o `tooltip` do TOML recebe os marcadores `@AT_*@`, calculados
  pelo instalador (`atalho_de` em `lib/ts-lib.sh`, primeiro pela linha de
  comando exata, depois pelo executável). Ficam fixos no arquivo: mudou um
  atalho, rode `./install.sh`.

## D18. Grupos de apps

* **Classificação** (`bin/soviet-grupos`): `.desktop` do usuário, do sistema e
  do Flatpak; ignora ocultos, `OnlyShowIn`/`NotShowIn` incompatíveis e
  **webapps** (`omarchy-launch-webapp`, `firefox --new-window http…`,
  `firefox-webapp-*`): o pedido é só por programas instalados. Grupo por
  `Categories=`, com ajustes manuais onde a categoria falha (Steam, editores,
  Docker, Cursor). `tabela` mostra sem gravar.
* **Nunca desfaz escolha do usuário**: só apps nunca vistos (`vistos` no
  `grupos.json`, esquema 1) são classificados. Ordem, nomes e remoções feitas
  no painel ficam.
* **Painel** `erllan/grupos:painel`, aberto pelo ícone no centro da barra: clique
  abre ou foca; arrastar entre grupos; menu de contexto (API 28); criar,
  renomear e apagar grupo; um app pode estar em vários grupos.
* **Plugins de terceiros avaliados** (item 7 do pedido), sem instalar nada:
  `retomada/plugins-avaliacao.md`. Candidatos: `noctalia/timer`, `noctalia/notes`,
  `special-workspaces`, `lyrics`. Os outros sobrepõem o que o Omarchy ou o projeto
  já fazem, ou pedem dependências extras.
