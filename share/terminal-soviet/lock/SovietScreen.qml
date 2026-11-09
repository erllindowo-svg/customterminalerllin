import QtQuick
import Quickshell
import Quickshell.Hyprland

// Terminal Soviético — decide, por tela, se o bloqueio nativo pode ficar transparente.
//
// A transparência só liga quando esta tela está comprovadamente mostrando a central
// (workspace da central ativo e nenhum workspace especial aberto por cima). Em
// qualquer dúvida (estado ainda desconhecido, outro workspace), vale o fundo borrado
// original do Omarchy: errar aqui só muda a aparência. Se a central está em outro
// monitor, esta tela mostra só o wallpaper, sem desfoque e sem o pedido de senha.
QtObject {
  id: central

  property var screen: null

  readonly property int centralWorkspace: @HIDDEN_WORKSPACE@
  readonly property string userName: Quickshell.env("USER") || ""
  readonly property string lockedAt: Qt.formatTime(new Date(), "HH:mm")

  readonly property var monitor: screen ? Hyprland.monitorFor(screen) : Hyprland.focusedMonitor
  readonly property var monitorInfo: monitor ? monitor.lastIpcObject : null
  readonly property bool onCentral: !!monitor && !!monitor.activeWorkspace
    && monitor.activeWorkspace.id === centralWorkspace
  readonly property bool noSpecial: !!monitorInfo && !!monitorInfo.specialWorkspace
    && monitorInfo.specialWorkspace.name === ""
  readonly property bool transparent: onCentral && noSpecial

  // Só vale quando outro monitor comprovadamente tem a central: é lá que a senha
  // aparece. Sem isso, esta tela mantém o campo, para nunca faltar onde digitar.
  readonly property bool wallpaperOnly: {
    if (!monitor || onCentral) return false
    var monitors = Hyprland.monitors.values
    for (var i = 0; i < monitors.length; i++) {
      var other = monitors[i]
      if (other !== monitor && other.activeWorkspace && other.activeWorkspace.id === centralWorkspace)
        return true
    }
    return false
  }

  // O painel de terminal da central: o pedido de senha é desenhado por cima dele
  // (e, sendo opaco, esconde o que estiver no terminal).
  readonly property var panel: {
    var windows = Hyprland.toplevels.values
    for (var i = 0; i < windows.length; i++) {
      var info = windows[i].lastIpcObject
      if (info && info.class === "soviet-ops-shell" && info.at && info.size
          && info.workspace && info.workspace.id === centralWorkspace)
        return info
    }
    return null
  }
  // Painel pequeno demais não comporta o pedido: fica o retângulo centralizado.
  readonly property bool terminalMode: transparent && !!panel && panel.size[0] >= 320 && panel.size[1] >= 96
  readonly property real panelX: terminalMode ? panel.at[0] - monitor.x : 0
  readonly property real panelY: terminalMode ? panel.at[1] - monitor.y : 0
  readonly property real panelWidth: terminalMode ? panel.size[0] : 0
  readonly property real panelHeight: terminalMode ? panel.size[1] : 0
}
