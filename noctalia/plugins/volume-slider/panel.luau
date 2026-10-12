--!nonstrict
-- Terminal Soviético — popup de volume: um slider horizontal e nada mais.
--
-- Fonte da verdade: o sink padrão do PipeWire, via `wpctl` (WirePlumber).
--   * arrastar -> wpctl set-volume @DEFAULT_AUDIO_SINK@ N% (limite 100 %, como o Noctalia)
--   * enquanto aberto, espera eventos do PipeWire (watch-sink.sh: `pactl subscribe`
--     até a primeira mudança de sink) e relê o volume, refletindo atalhos de teclado,
--     o scroll do widget e outros controles. Fechado, nada roda.
-- Mudo: o slider fica atenuado (não há outros elementos).

local volume = 0
local muted = false
local dragging = false
local reading = false
local isOpen = false
local watching = false
local WATCHER = (noctalia.pluginDir() or ".") .. "/watch-sink.sh"

local function render()
  panel.render(ui.row({ flexGrow = 1, align = "center" }, {
    ui.slider({
      key = "volume",
      min = 0,
      max = 100,
      step = 1,
      value = volume,
      flexGrow = 1,
      controlSize = "sm",
      opacity = muted and 0.45 or 1,
      onChange = "onVolumeChange",
      onDragEnd = "onVolumeDragEnd",
    }),
  }))
end

local function readVolume()
  if reading then return end
  reading = true
  noctalia.runAsync({ "wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@" }, function(result)
    reading = false
    if result.exitCode ~= 0 then return end
    local out = result.stdout or ""
    local v = tonumber(string.match(out, "Volume:%s*([%d%.]+)") or "")
    if v == nil then return end
    local pct = math.floor(v * 100 + 0.5)
    local isMuted = string.find(out, "MUTED", 1, true) ~= nil
    if not dragging and (pct ~= volume or isMuted ~= muted) then
      volume = pct
      muted = isMuted
      render()
    end
  end, 1000)
end

function onVolumeChange(value)
  -- O slider também reporta o valor quando ele muda por render() (volume vindo de
  -- fora); igual ao atual = não é interação do usuário, ignora.
  local pct = math.floor((tonumber(value) or volume) + 0.5)
  if pct == volume then return end
  dragging = true
  volume = pct
  noctalia.runAsync({ "wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", tostring(pct) .. "%" })
end

function onVolumeDragEnd()
  dragging = false
  readVolume()
end

-- Uma espera por vez; rearmada após cada evento enquanto o popup estiver aberto.
local function watchSink()
  if watching or not isOpen then return end
  watching = true
  noctalia.runAsync({ "bash", WATCHER }, function(result)
    watching = false
    if not isOpen then return end
    if result.exitCode == 0 then readVolume() end
    watchSink()
  end, 60000)
end

function onOpen(context)
  isOpen = true
  render()
  readVolume()
  watchSink()
end

function onClose()
  isOpen = false
  dragging = false
end

function onKey(chord, pressed)
  if pressed and string.lower(chord) == "escape" then panel.close() end
end
