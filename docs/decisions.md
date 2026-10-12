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
central, junta favoritos e apps em execução e reage a eventos. Antes eram
consultas a cada 1 s com um aviso no log a cada render. **Reavaliar** ao
atualizar o Noctalia.

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
* Lançador osu! e sensores NVIDIA: preferências opcionais, omitidas quando
  ausentes (`BAR_LAUNCHERS`, `GPU_SENSORS=auto`).
* Teclas físicas e cliques reais não são automatizáveis aqui (o `wtype` não
  aciona atalhos globais). Os comandos que cada tecla/botão executa são testados.

## D11. Papéis de parede fora do repositório

Fotos CC BY/BY-SA de monumentos soviéticos; as esculturas podem ter direitos
próprios. `scripts/fetch-backgrounds.sh` baixa do Commons e confere o SHA-1.
Ver `THIRD_PARTY.md`.
