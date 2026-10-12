// Terminal Soviético — barra nula para o shell Omarchy.
//
// Selecionada por `bar.id = "erllan.sem-barra"` em ~/.config/omarchy/shell.json.
// Não cria nenhuma janela nem zona exclusiva: a barra real é a do Noctalia
// (~/.config/noctalia/20-barra.toml). O resto do shell Omarchy continua ativo.
//
// As propriedades abaixo existem porque o shell e os popups (notificações,
// teclado) leem posição/tamanho da barra ativa para se posicionar: informamos
// a geometria da barra do Noctalia (topo, 26 px) para os popups não a cobrirem.
// As funções de painel retornam false: os painéis da barra antiga foram
// substituídos pelo control center do Noctalia (ver ~/.config/hypr/bindings.lua).
import QtQuick

Item {
  id: root
  visible: false

  property string omarchyPath: ""
  property var shell: null
  property var manifest: null
  property var barWidgetRegistry: null
  property var pluginRegistry: null
  property var barConfig: ({})

  property string position: "top"
  property int barSize: 26
  property bool barHidden: false
  property string fontFamily: "JetBrainsMono Nerd Font"

  function summonBarWidget(id) { return false }
  function hideBarWidget(id) { return false }
  function isBarWidgetOpen(id) { return false }
  function panelWidgetIdAt(section, index) { return "" }
  function toggleTransparency() { }
  function debugBarGeometry() { return "erllan.sem-barra: sem geometria (barra do Noctalia)" }
}
