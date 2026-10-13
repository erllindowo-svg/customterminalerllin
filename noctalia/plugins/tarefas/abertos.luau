--!nonstrict
-- Terminal Soviético — tarefas: apps ABERTOS e não fixados (esquerda da barra),
-- fora do workspace da central. Dados: service `fonte`; render: comum.luau.
local tarefas = require("./comum.luau")
local widget = tarefas.widget("abertos", barWidget)

function onRightClick()
  widget.menu()
end

-- noctalia msg plugin erllan/tarefas:abertos focused menu <key>  (testes)
function onIpc(event, payload)
  if event == "menu" then widget.menu(payload) end
end
