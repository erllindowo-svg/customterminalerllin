--!nonstrict
-- Terminal Soviético — tarefas: FERRAMENTAS DE TRABALHO, os fixados listados em
-- WORK_APPS. Atenuado = fechado; claro com traço = aberto/focado.
-- Dados: service `fonte`; render: comum.luau.
local tarefas = require("./comum.luau")
local widget = tarefas.widget("trabalho", barWidget)

function update()
  widget.update()
end

function onRightClick()
  widget.menu()
end

-- noctalia msg plugin erllan/tarefas:trabalho focused menu <key>  (testes)
function onIpc(event, payload)
  if event == "menu" then widget.menu(payload) end
end
