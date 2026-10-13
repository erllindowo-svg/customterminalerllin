--!nonstrict
-- Terminal Soviético — painel "Editar barra" (clique direito fora de um ícone da
-- lista de apps, ou "Editar barra…" no mini-menu).
--
-- A barra do Noctalia 5.0.1 não tem arrasto (ui.dragSource/ui.dropZone só existem
-- em painéis). Aqui cada ícone é arrastável entre duas listas:
--   Abertos (esquerda da barra)  <->  Fixados (direita da barra)
-- Soltar em Fixados fixa (na posição); em Abertos desafixa. Dentro de cada lista,
-- reordena. Cada soltura vira state "pedido" { op = "mover", key, arg = "lado:pos" },
-- aplicado pelo service `fonte` (único escritor de fixados.json).

local modelo = noctalia.state.get("modelo") or {}
local ICONE = 28

local icons = {}
local function iconFor(a)
  local v = icons[a.key]
  if v == nil then
    v = noctalia.appIconPath(a.id, ICONE)
    if not v and a.class and a.class ~= a.id then v = noctalia.appIconPath(string.lower(a.class), ICONE) end
    icons[a.key] = v or false
  end
  return v or nil
end

-- Vão de inserção antes da posição `pos` (largo o bastante para mirar com folga).
local function vao(lado, pos)
  return ui.dropZone({
    key = "vao-" .. lado .. "-" .. pos,
    accepts = { "app" }, value = lado .. ":" .. pos, onDrop = "onSoltar",
    width = 6, height = ICONE + 8, hitSlop = 14,
  }, {})
end

local function lista(lado, titulo, apps)
  local filhos = {}
  for i, a in ipairs(apps) do
    table.insert(filhos, vao(lado, i))
    local path = iconFor(a)
    table.insert(filhos, ui.dragSource({
      key = "app-" .. a.key, dragType = "app", payload = a.key,
      tooltip = a.id,
    }, {
      ui.column({ gap = 2, align = "center", width = ICONE + 8, height = ICONE + 8, justify = "center",
                  opacity = (#(a.windows or {}) == 0) and 0.55 or 1.0 }, {
        path and ui.image({ path = path, width = ICONE, height = ICONE, fit = "contain" })
          or ui.glyph({ name = "app-window", size = ICONE }),
      }),
    }))
  end
  if #apps == 0 then
    table.insert(filhos, ui.label({ text = "(vazio: solte aqui)", color = "on_surface_variant" }))
  end
  return ui.column({ gap = 4 }, {
    ui.label({ text = titulo, fontWeight = "bold", color = "primary" }),
    -- A lista inteira também é zona: soltar fora de um vão manda para o fim.
    ui.dropZone({
      key = "zona-" .. lado, accepts = { "app" }, value = lado .. ":" .. (#apps + 1),
      onDrop = "onSoltar", direction = "row", minHeight = ICONE + 16,
      fill = "surface_variant", border = "outline", radius = 0, padding = 4, gap = 2,
    }, filhos),
  })
end

local function render()
  panel.render(ui.column({ gap = 10 }, {
    ui.label({ text = "Arraste para reordenar. Entre as listas: fixar ou desafixar.",
               color = "on_surface_variant", maxLines = 2 }),
    lista("abertos", "Abertos (esquerda da barra)", modelo.abertos or {}),
    lista("fixados", "Fixados (direita da barra)", modelo.fixados or {}),
  }))
end

function onSoltar(key, destino)
  noctalia.state.set("pedido", { op = "mover", key = key, arg = destino, n = noctalia.nowMs() })
end

noctalia.state.watch("modelo", function(m)
  if type(m) == "table" then modelo = m; render() end
end)

function onOpen()
  modelo = noctalia.state.get("modelo") or modelo
  render()
end

function onKey(chord, pressed)
  if pressed and string.lower(chord) == "escape" then panel.close() end
end
