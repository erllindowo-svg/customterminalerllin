--!nonstrict
-- Terminal Soviético — áudio: fonte única de dados (service, sem UI).
--
-- Um único `pactl subscribe` (filho do Noctalia, como o socat das tarefas): cada
-- evento de sink, card (fone plugado) ou servidor (saída padrão trocada) agenda
-- uma leitura coalescida de `pactl -f json list sinks`, reduzida pelo jq. O
-- resultado vai para o widget e o popup por noctalia.state:
--   "audio" = { padrao, vol, mudo, tipo, saidas = { { id, nome, titulo, tipo } } }
-- tipo = "fone" (porta Headphones/Headset, form factor headphone/headset ou
-- Bluetooth) ou "alto" (HDMI, linha, alto-falante).
--
-- Pedidos (state "pedido" = { op, arg, n }, ou IPC):
--   alternar         fone <-> alto-falante (a outra saída disponível do outro tipo)
--   saida <nome>     torna <nome> a saída padrão e move os fluxos tocando para ela
--   mudo             alterna o mudo da saída padrão
--   volume <0-100>   volume da saída padrão (limite 100 %, como o Noctalia)
--   mais / menos     ±5 %

local TROCAR = (noctalia.pluginDir() or ".") .. "/trocar-saida.sh"

local JQ = [[{padrao: $d, saidas: [.[] | {
  nome: .name, id: (.properties["object.id"] // ""), desc: (.description // .name),
  porta: (.active_port as $p | ([.ports[]? | select(.name == $p)][0] // {})),
  ff: (.properties["device.form_factor"] // ""), bus: (.properties["device.bus"] // ""),
  mudo: .mute,
  vol: ([.volume[]?.value_percent | rtrimstr("%") | tonumber] | if length > 0 then add / length else 0 end)
}]}]]

local busy, pending, streaming = false, false, false
local saidas = {}
local lastPedido = nil

local FONE_FF = { headphone = true, headset = true, handsfree = true, earbuds = true }

local function tipoDe(s)
  local t = s.porta and s.porta.type or ""
  if t == "Headphones" or t == "Headset" or FONE_FF[s.ff] or s.bus == "bluetooth" then return "fone" end
  return "alto"
end

local PORTAS = {
  Headphones = "Fone de ouvido", Headset = "Headset", HDMI = "HDMI",
  Line = "Saída de linha", Speaker = "Alto-falante", SPDIF = "S/PDIF",
}

-- Nome legível: o que está entre colchetes (nome do monitor/TV na HDMI), senão o
-- tipo da porta ativa, senão a descrição sem o sufixo técnico.
local function nomeDe(s)
  local entre = string.match(s.desc, "%[([^%]]+)%]%s*$")
  if entre then return entre end
  local t = s.porta and s.porta.type
  if t and PORTAS[t] then return PORTAS[t] end
  local curta = string.gsub(s.desc, "%s*Analog Stereo$", "")
  curta = string.gsub(curta, "%s*Digital Stereo.*$", "")
  return curta
end

-- Título (linha secundária): a placa, sem "High Definition Audio Controller" etc.
local function tituloDe(s)
  local t = string.gsub(s.desc, "%s*%[.-%]%s*$", "")
  t = string.gsub(t, " High Definition Audio Controller", "")
  t = string.gsub(t, " HD Audio Controller", "")
  return t
end

local function refresh()
  if busy then pending = true; return end
  busy = true
  noctalia.runAsync({ "sh", "-c",
    "d=$(pactl get-default-sink) && pactl -f json list sinks | jq -c --arg d \"$d\" '" .. JQ .. "'" },
    function(r)
      busy = false
      local data = noctalia.json.decode(r.stdout or "")
      if type(data) == "table" and type(data.saidas) == "table" then
        local estado = { padrao = data.padrao, vol = 0, mudo = false, tipo = "alto", saidas = {} }
        saidas = {}
        for _, s in ipairs(data.saidas) do
          local item = { id = s.id, nome = s.nome, rotulo = nomeDe(s), titulo = tituloDe(s), tipo = tipoDe(s) }
          table.insert(saidas, item)
          table.insert(estado.saidas, item)
          if s.nome == data.padrao then
            estado.vol = math.floor((tonumber(s.vol) or 0) + 0.5)
            estado.mudo = s.mudo == true
            estado.tipo = item.tipo
          end
        end
        noctalia.state.set("audio", estado)
      end
      if pending then pending = false; refresh() end
    end, 3000)
end

local function trocar(nome)
  for _, s in ipairs(saidas) do
    if s.nome == nome then
      noctalia.runAsync({ "bash", TROCAR, s.id, s.nome }, function() refresh() end, 5000)
      return
    end
  end
end

local function alternar()
  local atual = noctalia.state.get("audio") or {}
  local outro = (atual.tipo == "fone") and "alto" or "fone"
  for _, s in ipairs(saidas) do
    if s.tipo == outro and s.nome ~= atual.padrao then trocar(s.nome); return end
  end
  -- Sem saída do outro tipo: passa para a próxima da lista.
  for i, s in ipairs(saidas) do
    if s.nome == atual.padrao and #saidas > 1 then trocar(saidas[(i % #saidas) + 1].nome); return end
  end
end

local function wpctl(args)
  local cmd = { "wpctl" }
  for _, a in ipairs(args) do table.insert(cmd, a) end
  noctalia.runAsync(cmd)
end

local OPS = {
  alternar = function() alternar() end,
  saida = function(arg) trocar(arg) end,
  mudo = function() wpctl({ "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle" }) end,
  mais = function() wpctl({ "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", "5%+" }) end,
  menos = function() wpctl({ "set-volume", "@DEFAULT_AUDIO_SINK@", "5%-" }) end,
  volume = function(arg)
    local v = math.max(0, math.min(100, math.floor(tonumber(arg) or 0)))
    wpctl({ "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", tostring(v) .. "%" })
  end,
}

noctalia.state.watch("pedido", function(p)
  if type(p) ~= "table" or p.n == lastPedido then return end
  lastPedido = p.n
  local op = OPS[p.op]
  if op then op(p.arg) end
end)

-- noctalia msg plugin erllan/audio:fonte all <alternar|mudo|mais|menos|saida <nome>|volume <n>>
function onIpc(event, payload)
  local op = OPS[event]
  if op then op(payload) end
end

local function startStream()
  if streaming or not noctalia.commandExists("pactl") then return end
  streaming = true
  noctalia.runStream("exec pactl subscribe", function(line)
    line = line or ""
    if string.find(line, "on sink #", 1, true) or string.find(line, "on server", 1, true)
      or string.find(line, "on card #", 1, true) then
      refresh()
    end
  end)
end

-- Rede de segurança: uma leitura por minuto, mesmo sem eventos.
function update()
  noctalia.setUpdateInterval(60000)
  startStream()
  refresh()
end

startStream()
refresh()
