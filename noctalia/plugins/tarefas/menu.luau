--!nonstrict
-- Terminal Soviético — tarefas: mini-menu do clique direito num ícone da barra.
-- O widget grava state "menu" = { key, nome, fixado, janelas, n } e abre este
-- painel. Cada ação vira state "pedido" = { op, key, n }, aplicado pelo service
-- `fonte` (único escritor de fixados.json).

local alvo = nil

local function pedir(op)
  if alvo then
    noctalia.state.set("pedido", { op = op, key = alvo.key, n = noctalia.nowMs() })
  end
  panel.close()
end

local function render()
  if not alvo then
    panel.render(ui.column({}, {}))
    return
  end
  local fechar = alvo.janelas > 1 and ("Fechar " .. alvo.janelas .. " janelas") or "Fechar janela"
  panel.render(ui.column({ gap = 4 }, {
    ui.label({ text = alvo.nome, fontWeight = "bold", color = "primary", maxLines = 1 }),
    ui.separator({}),
    ui.button({
      key = "fixar",
      text = alvo.fixado and "Desafixar" or "Fixar na barra",
      glyph = alvo.fixado and "pinned-off" or "pin",
      variant = "ghost", contentAlign = "start", controlSize = "sm",
      onClick = function() pedir(alvo.fixado and "desafixar" or "fixar") end,
    }),
    ui.button({
      key = "novo",
      text = "Nova janela", glyph = "plus",
      variant = "ghost", contentAlign = "start", controlSize = "sm",
      onClick = function() pedir("novo") end,
    }),
    ui.button({
      key = "fechar",
      text = fechar, glyph = "x",
      variant = "ghost", contentAlign = "start", controlSize = "sm",
      enabled = alvo.janelas > 0,
      onClick = function() pedir("fechar") end,
    }),
    ui.button({
      key = "editar",
      text = "Editar barra…", glyph = "arrows-move",
      variant = "ghost", contentAlign = "start", controlSize = "sm",
      onClick = function() noctalia.togglePanel("erllan/tarefas:editar") end,
    }),
  }))
end

noctalia.state.watch("menu", function(m)
  alvo = type(m) == "table" and m or nil
  render()
end)

function onOpen()
  local m = noctalia.state.get("menu")
  alvo = type(m) == "table" and m or nil
  render()
end

function onKey(chord, pressed)
  if pressed and string.lower(chord) == "escape" then panel.close() end
end
