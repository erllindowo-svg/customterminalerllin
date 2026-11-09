import QtQuick
import Quickshell
import Quickshell.Hyprland

// Terminal Soviético — leva a sessão à central antes do bloqueio e a devolve depois.
// Só troca de workspace: autenticação, PAM e sessão seguem no Service.qml do Omarchy.
// Não recompõe painéis: com a sessão travada o foco por comando não vale, e o
// soviet-ops colocaria as janelas no lugar errado. Sem o painel de terminal, o pedido
// fica no retângulo centralizado.
Item {
  id: workflow

  readonly property int centralWorkspace: @HIDDEN_WORKSPACE@
  property bool active: false
  property int previousWorkspace: 0

  function refresh() {
    Hyprland.refreshMonitors()
    Hyprland.refreshToplevels()
  }

  // Chamado antes do bloqueio subir (o Service.qml espera 500 ms para pedir a sessão).
  function prepare() {
    var monitor = Hyprland.focusedMonitor
    var current = monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : 0
    previousWorkspace = current > 0 && current !== centralWorkspace ? current : 0
    active = true
    Hyprland.dispatch('hl.dsp.focus({ workspace = "' + centralWorkspace + '" })')
    refresh()
    settle.restart()
  }

  function restore() {
    active = false
    if (previousWorkspace > 0)
      Hyprland.dispatch('hl.dsp.focus({ workspace = "' + previousWorkspace + '" })')
    previousWorkspace = 0
  }

  // Um workspace especial aberto ficaria visível através do bloqueio: fecha.
  function closeSpecial() {
    var monitor = Hyprland.focusedMonitor
    var info = monitor ? monitor.lastIpcObject : null
    var name = info && info.specialWorkspace ? String(info.specialWorkspace.name || "") : ""
    var match = /^special:([A-Za-z0-9_-]+)$/.exec(name)
    if (match) Hyprland.dispatch('hl.dsp.workspace.toggle_special("' + match[1] + '")')
  }

  Timer {
    id: settle
    interval: 120
    repeat: false
    onTriggered: {
      workflow.closeSpecial()
      workflow.refresh()
    }
  }

  Connections {
    target: workflow.active ? Hyprland : null
    function onRawEvent(event) {
      if (event.name.indexOf("activespecial") === 0 || event.name === "openwindow"
          || event.name === "closewindow" || event.name === "movewindow")
        settle.restart()
    }
  }
}
