--!nonstrict
-- Terminal Soviético — popup de áudio: volume, mudo e lista de saídas.
-- Clicar numa saída a torna padrão (wpctl set-default) e move os fluxos que estão
-- tocando para ela (service `fonte`, trocar-saida.sh). Dados: state "audio".

local estado = noctalia.state.get("audio") or {}
local arrastando = false
local volume = estado.vol or 0

local function pedir(op, arg)
  noctalia.state.set("pedido", { op = op, arg = arg, n = noctalia.nowMs() })
end

local function render()
  local fone = estado.tipo == "fone"
  local lista = {}
  for _, s in ipairs(estado.saidas or {}) do
    local nome = s.nome
    table.insert(lista, ui.button({
      key = "saida-" .. nome,
      text = s.rotulo .. "  ·  " .. s.titulo,
      glyph = s.tipo == "fone" and "headphones" or "device-speaker",
      variant = (nome == estado.padrao) and "secondary" or "ghost",
      selected = nome == estado.padrao,
      contentAlign = "start", controlSize = "sm",
      onClick = function() pedir("saida", nome) end,
    }))
  end
  panel.render(ui.column({ gap = 8 }, {
    ui.row({ gap = 8, align = "center" }, {
      ui.button({
        key = "mudo",
        glyph = estado.mudo and ((fone and "headphones" or "device-speaker") .. "-off")
          or (fone and "headphones" or "device-speaker"),
        variant = estado.mudo and "destructive" or "ghost",
        controlSize = "sm",
        tooltip = estado.mudo and "Tirar do mudo" or "Mudo",
        onClick = function() pedir("mudo") end,
      }),
      ui.slider({
        key = "volume",
        min = 0, max = 100, step = 1, value = volume,
        flexGrow = 1, controlSize = "sm",
        opacity = estado.mudo and 0.45 or 1,
        onChange = "onVolumeChange",
        onDragEnd = "onVolumeDragEnd",
      }),
      ui.label({ text = tostring(volume) .. "%", color = "on_surface_variant" }),
    }),
    ui.separator({}),
    ui.label({ text = "Saída", fontWeight = "bold", color = "primary" }),
    ui.column({ gap = 2 }, lista),
  }))
end

noctalia.state.watch("audio", function(v)
  if type(v) ~= "table" then return end
  estado = v
  if not arrastando then volume = v.vol or volume end
  render()
end)

function onVolumeChange(value)
  -- O slider também reporta o valor quando ele muda por render() (volume vindo de
  -- fora); igual ao atual = não é interação do usuário, ignora.
  local pct = math.floor((tonumber(value) or volume) + 0.5)
  if pct == volume then return end
  arrastando = true
  volume = pct
  pedir("volume", pct)
end

function onVolumeDragEnd()
  arrastando = false
end

function onOpen()
  estado = noctalia.state.get("audio") or estado
  volume = estado.vol or volume
  render()
end

function onClose()
  arrastando = false
end

function onKey(chord, pressed)
  if pressed and string.lower(chord) == "escape" then panel.close() end
end
