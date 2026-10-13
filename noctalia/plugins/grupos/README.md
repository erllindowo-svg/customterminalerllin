# erllan/grupos — painel "Grupos" (Terminal Soviético)

Apps instalados agrupados por propósito, abertos pelo ícone de grupos no
centro da barra.

* **Classificação** (`bin/soviet-grupos`): lê os `.desktop` (usuário, sistema,
  Flatpak), ignora ocultos e incompatíveis com o desktop atual e propõe um grupo
  por `Categories=` com ajustes manuais (webapps sem categoria, Steam, editores).
  `soviet-grupos tabela` mostra a proposta sem gravar; `classificar` grava. Só
  apps nunca vistos são classificados: nada que você mudou é desfeito.
* **Painel**: clique abre ou foca o app; arrastar move entre grupos; clique
  direito no nome abre o menu nativo (abrir, tirar do grupo, adicionar a outro
  grupo); botões para criar, renomear e apagar grupo e para classificar os apps
  novos. Um app pode estar em vários grupos. "Sem grupo" aparece só se houver
  apps fora de todos.
* **Estado**: `~/.local/state/terminal-soviet/grupos.json` (esquema 1),
  gravado de forma atômica.

API de plugin 28 (`panel.openContextMenu`), Noctalia 5.0.1.
