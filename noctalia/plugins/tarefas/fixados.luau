--!nonstrict
-- Terminal Soviético — tarefas: apps FIXADOS (direita da barra), na ordem em que
-- foram fixados. Atenuado = fechado; claro com traço = aberto/focado.
-- Dados: service `fonte`; render: comum.luau.
local tarefas = require("./comum.luau")
local widget = tarefas.widget("fixados", barWidget)

function update()
  widget.update()
end

function onRightClick()
  widget.menu()
end

-- noctalia msg plugin erllan/tarefas:fixados focused menu <key>  (testes)
function onIpc(event, payload)
  if event == "menu" then widget.menu(payload) end
end
