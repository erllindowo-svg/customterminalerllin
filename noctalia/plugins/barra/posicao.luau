--!nonstrict
-- Terminal Soviético — painel "posição da barra".
--
-- O Noctalia 5.0.1 não deixa arrastar a própria barra (widgets de barra não recebem
-- arrasto, e não há IPC de posição). Aqui o arrasto é numa mini-tela: a barrinha
-- (ui.dragSource) solta numa das 4 bordas (ui.dropZone) chama soviet-bar-pos, que
-- grava a escolha e recarrega a configuração (a barra é recriada na nova borda).
-- Os botões fazem o mesmo sem arrastar.

local CMD = noctalia.expandPath("~/.local/bin/soviet-bar-pos")
local STATE = "~/.local/state/terminal-soviet/barra-posicao"
local NOMES = { top = "topo", bottom = "baixo", left = "esquerda", right = "direita" }

local atual = "top"

local function lerAtual()
  local raw = noctalia.fileExists(STATE) and noctalia.readFile(STATE) or nil
  atual = raw and string.match(raw, "(%a+)") or "top"
  if not NOMES[atual] then atual = "top" end
end

local function mover(pos)
  if not NOMES[pos] then return end
  -- Conflito com a GUI (settings.toml): o próprio soviet-bar-pos notifica e não aplica.
  noctalia.runAsync({ CMD, pos }, nil, 10000)
  panel.close()   -- a barra é recriada; o painel preso a ela fecharia de qualquer jeito
end

local function zona(pos, props)
  local ativa = pos == atual
  props.key = "zona-" .. pos
  props.accepts = { "barra" }
  props.value = pos
  props.onDrop = "onSoltar"
  props.fill = ativa and "primary" or "surface"
  props.radius = 0
  props.hitSlop = 24
  return ui.dropZone(props, {})
end

local function render()
  local barrinha = ui.dragSource({
    key = "barrinha", dragType = "barra", payload = "barra",
    tooltip = "Arraste até uma borda",
  }, {
    ui.row({ gap = 4, align = "center", padding = 4, fill = "secondary", radius = 0 }, {
      ui.glyph({ name = "grip-horizontal", size = 14, color = "on_secondary" }),
      ui.label({ text = "barra (" .. NOMES[atual] .. ")", color = "on_secondary" }),
    }),
  })
  local tela = ui.column({ key = "tela", gap = 0, border = "outline", borderWidth = 1, height = 140 }, {
    zona("top", { height = 14 }),
    ui.row({ gap = 0, flexGrow = 1 }, {
      zona("left", { width = 14, direction = "column" }),
      ui.column({ flexGrow = 1, align = "center", justify = "center", fill = "surface_variant" }, { barrinha }),
      zona("right", { width = 14, direction = "column" }),
    }),
    zona("bottom", { height = 14 }),
  })
  local botoes = {}
  for _, p in ipairs({ { "top", "arrow-up" }, { "bottom", "arrow-down" }, { "left", "arrow-left" }, { "right", "arrow-right" } }) do
    local pos = p[1]
    table.insert(botoes, ui.button({
      key = "b-" .. pos, glyph = p[2], tooltip = NOMES[pos], controlSize = "sm",
      variant = (pos == atual) and "secondary" or "ghost", selected = pos == atual,
      onClick = function() mover(pos) end,
    }))
  end
  panel.render(ui.column({ gap = 8 }, {
    ui.label({ text = "Posição da barra", fontWeight = "bold", color = "primary" }),
    tela,
    ui.row({ gap = 4, justify = "center" }, botoes),
  }))
end

function onSoltar(_payload, pos)
  mover(pos)
end

function onOpen()
  lerAtual()
  render()
end

function onKey(chord, pressed)
  if pressed and string.lower(chord) == "escape" then panel.close() end
end
