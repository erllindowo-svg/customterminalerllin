import QtQuick
import Quickshell.Io
import qs.Commons

// Terminal Soviético — substitui o serviço de bloqueio do Omarchy (omarchy.lock,
// desligado em disabledPlugins pelo install.sh). Atende o mesmo alvo IPC `lock`,
// que é por onde passam TODOS os caminhos de bloqueio do Omarchy:
//   omarchy-system-lock (atalho, menu, tempo ocioso) e omarchy-system-sleep-lock
//   (antes de suspender, que espera status.secure == true).
// O trabalho é do bin/soviet-lock; este arquivo só traduz o contrato.
Item {
  id: root

  property var shell: null

  readonly property string home: Quickshell.env("HOME")
  property bool lockRunning: false
  property string lastStatus: "{\"locked\":false,\"requested\":false,\"secure\":false}"

  Process {
    id: lockProcess
    command: ["bash", "-lc", "exec \"$HOME/.local/bin/soviet-lock\" lock"]
    onRunningChanged: root.lockRunning = running
  }

  Process {
    id: statusProcess
    command: ["bash", "-lc", "exec \"$HOME/.local/bin/soviet-lock\" status"]
    stdout: StdioCollector {
      onStreamFinished: { if (text.trim().length > 0) root.lastStatus = text.trim() }
    }
  }

  function parsed() {
    try { return JSON.parse(root.lastStatus) } catch (e) { return ({}) }
  }

  // O estado verdadeiro é o do bin/soviet-lock; aqui fica o último conhecido,
  // renovado a cada segundo enquanto há bloqueio em andamento ou ativo (sem custo
  // em repouso) e uma vez na inicialização (o shell pode reiniciar bloqueado).
  Timer {
    interval: 1000
    repeat: true
    running: root.lockRunning || root.parsed().locked === true
    onTriggered: statusProcess.running = true
  }

  Component.onCompleted: statusProcess.running = true

  ShellIpc {
    target: "lock"

    // Pedido de bloqueio (idempotente). O soviet-lock sai quando está seguro; a
    // resposta "ok" é imediata e quem precisa da garantia consulta `status`.
    function lock(): string {
      if (!lockProcess.running) lockProcess.running = true
      return "ok"
    }

    function isLocked(): string {
      statusProcess.running = true
      return (root.lockRunning || root.parsed().locked === true) ? "true" : "false"
    }

    function status(): string {
      statusProcess.running = true
      var s = root.parsed()
      s.requested = s.requested === true || root.lockRunning
      return JSON.stringify(s)
    }

    // Sem pré-visualização no bloqueio em terminal.
    function preview(): string { return "ok" }
    function hidePreview(): string { return "ok" }
  }
}
