--!nonstrict
-- Terminal Soviético — painel "Grupos": apps instalados em grupos por propósito.
--
-- Dados: ~/.local/state/terminal-soviet/grupos.json (esquema 1), criado e
-- completado por `soviet-grupos classificar` (só apps nunca vistos; nunca desfaz
-- uma escolha feita aqui). Este painel é o único que edita grupos e apps dos grupos.
--
--   clique no app            abre (ou foca a janela mais recente, se já aberto)
--   arrastar app             move para outro grupo ("Sem grupo" = tirar do grupo)
--   clique direito no nome   menu: abrir, tirar do grupo, adicionar a outro grupo
--   + / ✎ / lixeira          criar, renomear, apagar grupo
--   ⟳                        classificar apps instalados desde a última vez
-- Um app pode estar em mais de um grupo. "Sem grupo" (instalados fora de qualquer
-- grupo) só aparece se não estiver vazio.

local ARQ = noctalia.expandPath("~/.local/state/terminal-soviet/grupos.json")
local CLASSIFICAR = noctalia.expandPath("~/.local/bin/soviet-grupos")
local SEM = "Sem grupo"
local ICONE, POR_LINHA = 32, 7

local dados = nil          -- conteúdo de grupos.json
local erro = nil
local editando = nil       -- nil | "novo" | nome do grupo sendo renomeado
local confirmarApagar = nil

local render

-- Ícones: noctalia.appIconPath custa 18–24 ms de CPU por nome com o cache frio, e
-- o 5.0.1 corta callbacks de plugin acima de 25 ms (o painel ficava vazio). O
-- render nunca procura ícone: junta os que faltam e pede todos de uma vez ao
-- ~/.local/bin/soviet-icones (mesma resolução, fora do Luau, índice em cache);
-- enquanto isso mostra o glifo genérico. O cache vale entre aberturas.
local ICONES = noctalia.expandPath("~/.local/bin/soviet-icones")
local icons, pedidos, buscando = {}, {}, false
local function buscarIcones()
  if buscando or #pedidos == 0 then return end
  buscando = true
  local args, chaves = { ICONES, tostring(ICONE) }, pedidos
  pedidos = {}
  for _, p in ipairs(chaves) do table.insert(args, p.id .. "=" .. p.nomes) end
  noctalia.runAsync(args, function(r)
    for _, p in ipairs(chaves) do icons[p.id] = false end
    for chave, caminho in string.gmatch(r.stdout or "", "([^\t\n]+)\t([^\n]+)") do icons[chave] = caminho end
    buscando = false
    if dados then render() end
    buscarIcones()
  end, 5000)
end
local function iconFor(id, app)
  local v = icons[id]
  if v == nil then
    icons[id] = false   -- pedido uma vez só
    local nomes = (app.icone and app.icone ~= "") and (app.icone .. "," .. id) or id
    table.insert(pedidos, { id = id, nomes = nomes })
  end
  return v or nil
end

local function carregar()
  erro = nil
  local raw = noctalia.fileExists(ARQ) and noctalia.readFile(ARQ) or nil
  if not raw then dados = nil; return end
  local d = noctalia.json.decode(raw)
  if type(d) ~= "table" or d.versao ~= 1 then
    dados = nil
    erro = "grupos.json com esquema desconhecido; nada foi alterado."
    return
  end
  d.grupos = d.grupos or {}
  d.apps = d.apps or {}
  d.vistos = d.vistos or {}
  dados = d
end

-- Escrita atômica: .tmp + rename (o classificador lê o mesmo arquivo).
local function salvar()
  if not dados then return end
  local tmp = ARQ .. ".tmp"
  if noctalia.writeFile(tmp, noctalia.json.encode(dados)) then noctalia.renameFile(tmp, ARQ) end
end

local function grupo(nome)
  for i, g in ipairs(dados.grupos) do
    if g.nome == nome then return g, i end
  end
  return nil
end

local function contem(g, id)
  for i, x in ipairs(g.apps) do
    if x == id then return i end
  end
  return nil
end

local function semGrupo()
  local em = {}
  for _, g in ipairs(dados.grupos) do
    for _, id in ipairs(g.apps) do em[id] = true end
  end
  local lista = {}
  for id, app in pairs(dados.apps) do
    if app.instalado and not em[id] then table.insert(lista, id) end
  end
  table.sort(lista, function(a, b) return string.lower(dados.apps[a].nome) < string.lower(dados.apps[b].nome) end)
  return lista
end

-- Abrir ou focar: janela cuja classe bata com StartupWMClass, desktop-id ou
-- executável (sem diferenciar maiúsculas); senão abre pelo .desktop.
local function abrir(id)
  local app = dados.apps[id] or {}
  local nomes = {}
  for _, n in ipairs({ app.classe or "", id, app.exec or "" }) do
    if n ~= "" then table.insert(nomes, string.lower(n)) end
  end
  local filtro = '[.[] | select(.mapped and ((.class // "") | ascii_downcase) as $c | $ARGS.positional | index($c))]'
    .. ' | sort_by(.focusHistoryID) | .[0].address // empty'
  local args = { "sh", "-c", 'hyprctl clients -j | jq -r "$0" --args "$@"', filtro }
  for _, n in ipairs(nomes) do table.insert(args, n) end
  noctalia.runAsync(args, function(r)
    local addr = string.match(r.stdout or "", "(0x%x+)")
    if addr then
      noctalia.runAsync({ "hyprctl", "dispatch", 'hl.dsp.focus({ window = "address:' .. addr .. '" })' })
    else
      noctalia.runAsync({ "uwsm-app", "--", id .. ".desktop" })
    end
  end, 3000)
  panel.close()
end

local function mover(id, origem, destino)
  if origem == destino then return end
  local o = grupo(origem)
  if o then
    local i = contem(o, id)
    if i then table.remove(o.apps, i) end
  end
  local d = grupo(destino)
  if d and not contem(d, id) then table.insert(d.apps, id) end
  salvar()
end

local menuApp   -- definida abaixo (usada nos botões)

local function bloco(nome, ids, real)
  local linhas, linha = {}, {}
  for _, id in ipairs(ids) do
    local app = dados.apps[id]
    if app and app.instalado then
      local path = iconFor(id, app)
      table.insert(linha, ui.dragSource({
        key = "a-" .. nome .. "-" .. id, dragType = "app", payload = id .. "|" .. nome,
      }, {
        ui.column({ gap = 2, align = "center", width = 64 }, {
          ui.column({ key = "ic-" .. nome .. "-" .. id, align = "center", onClick = function() abrir(id) end }, {
            path and ui.image({ path = path, width = ICONE, height = ICONE, fit = "contain" })
              or ui.glyph({ name = "app-window", size = ICONE }),
          }),
          ui.button({
            key = "n-" .. nome .. "-" .. id, text = app.nome, variant = "ghost", fontSize = 10,
            width = 64, controlSize = "sm",
            tooltip = app.nome,
            onClick = function() abrir(id) end,
            onRightClick = function() menuApp(id, nome) end,
          }),
        }),
      }))
      if #linha == POR_LINHA then table.insert(linhas, ui.row({ gap = 4 }, linha)); linha = {} end
    end
  end
  if #linha > 0 then table.insert(linhas, ui.row({ gap = 4 }, linha)) end
  if #linhas == 0 then
    table.insert(linhas, ui.label({ text = "(vazio: arraste apps para cá)", color = "on_surface_variant" }))
  end

  local cabeca = { ui.label({ text = nome, fontWeight = "bold", color = "primary", flexGrow = 1 }) }
  if real then
    table.insert(cabeca, ui.button({ key = "ren-" .. nome, glyph = "pencil", variant = "ghost", controlSize = "sm",
      tooltip = "Renomear", onClick = function() editando = nome; render() end }))
    table.insert(cabeca, ui.button({ key = "del-" .. nome,
      glyph = "trash", text = (confirmarApagar == nome) and "Apagar?" or nil,
      variant = (confirmarApagar == nome) and "destructive" or "ghost", controlSize = "sm",
      tooltip = "Apagar o grupo (os apps continuam instalados)",
      onClick = function()
        if confirmarApagar ~= nome then confirmarApagar = nome; render(); return end
        local _, i = grupo(nome)
        if i then table.remove(dados.grupos, i) end
        confirmarApagar = nil
        salvar(); render()
      end }))
  end

  return ui.column({ key = "g-" .. nome, gap = 4 }, {
    ui.row({ gap = 4, align = "center" }, cabeca),
    ui.dropZone({
      key = "z-" .. nome, accepts = { "app" }, value = nome, onDrop = "onSoltar",
      direction = "column", gap = 4, padding = 4, minHeight = 56,
      fill = "surface_variant", border = "outline", radius = 0, hitSlop = 6,
    }, linhas),
  })
end

menuApp = function(id, nome)
  local itens = {
    { kind = "header", label = dados.apps[id].nome },
    { id = "abrir", label = "Abrir" },
  }
  if nome ~= SEM then table.insert(itens, { id = "tirar", label = "Tirar de " .. nome }) end
  local outros = {}
  for _, g in ipairs(dados.grupos) do
    if g.nome ~= nome then
      table.insert(outros, { id = "add:" .. g.nome, label = g.nome, enabled = not contem(g, id) })
    end
  end
  if #outros > 0 then
    table.insert(itens, { kind = "separator" })
    table.insert(itens, { kind = "header", label = "Adicionar a…" })
    for _, it in ipairs(outros) do table.insert(itens, it) end
  end
  panel.openContextMenu({ items = itens, onActivate = "onMenu", context = id .. "|" .. nome, maxVisible = 14 })
end

function onMenu(acao, contexto)
  local id, nome = string.match(contexto or "", "^(.-)|(.*)$")
  if not id then return end
  if acao == "abrir" then
    abrir(id)
  elseif acao == "tirar" then
    mover(id, nome, SEM); render()
  elseif string.sub(acao, 1, 4) == "add:" then
    local g = grupo(string.sub(acao, 5))
    if g and not contem(g, id) then table.insert(g.apps, id); salvar(); render() end
  end
end

function onSoltar(payload, destino)
  local id, origem = string.match(payload or "", "^(.-)|(.*)$")
  if not id then return end
  mover(id, origem, destino)
  render()
end

function onNome(texto)
  local nome = string.gsub(texto or "", "^%s*(.-)%s*$", "%1")
  if nome == "" or nome == SEM or (grupo(nome) and nome ~= editando) then editando = nil; render(); return end
  if editando == "novo" then
    table.insert(dados.grupos, { nome = nome, apps = {} })
  else
    local g = grupo(editando)
    if g then g.nome = nome end
  end
  editando = nil
  salvar(); render()
end

local function classificar()
  noctalia.runAsync({ CLASSIFICAR, "classificar" }, function(r)
    if r.exitCode ~= 0 then erro = "soviet-grupos classificar falhou: " .. (r.stderr or "") end
    icons = {}
    carregar(); render()
  end, 20000)
end

render = function()
  if not dados then
    panel.render(ui.column({ gap = 10 }, {
      ui.label({ text = "Grupos", fontWeight = "bold", color = "primary" }),
      ui.label({ text = erro or "Ainda não há grupos. A classificação lê os apps instalados e os distribui por propósito; depois você ajusta aqui.",
                 color = "on_surface_variant", maxLines = 4 }),
      ui.button({ key = "classificar", text = "Classificar apps", glyph = "refresh", variant = "primary",
                  controlSize = "sm", enabled = erro == nil, onClick = classificar }),
    }))
    return
  end
  local blocos = {}
  for _, g in ipairs(dados.grupos) do table.insert(blocos, bloco(g.nome, g.apps, true)) end
  local sem = semGrupo()
  if #sem > 0 then table.insert(blocos, bloco(SEM, sem, false)) end

  local topo = {
    ui.label({ text = "Grupos", fontWeight = "bold", color = "primary", flexGrow = 1 }),
    ui.button({ key = "novo", glyph = "plus", text = "Grupo", variant = "ghost", controlSize = "sm",
                onClick = function() editando = "novo"; render() end }),
    ui.button({ key = "reclass", glyph = "refresh", variant = "ghost", controlSize = "sm",
                tooltip = "Classificar apps instalados desde a última vez", onClick = classificar }),
  }
  local corpo = { ui.row({ gap = 4, align = "center" }, topo) }
  if editando then
    table.insert(corpo, ui.input({
      key = "nome-" .. editando, value = (editando ~= "novo") and editando or "",
      placeholder = (editando == "novo") and "Nome do grupo novo (Enter)" or "Novo nome (Enter)",
      controlSize = "sm", focus = true, onSubmit = "onNome",
    }))
  end
  if erro then table.insert(corpo, ui.label({ text = erro, color = "error", maxLines = 3 })) end
  table.insert(corpo, ui.scroll({ gap = 10, flexGrow = 1 }, blocos))
  panel.render(ui.column({ gap = 8 }, corpo))
  buscarIcones()
end

function onOpen()
  editando, confirmarApagar = nil, nil
  carregar()
  render()
end

function onKey(chord, pressed)
  if pressed and string.lower(chord) == "escape" then panel.close() end
end
