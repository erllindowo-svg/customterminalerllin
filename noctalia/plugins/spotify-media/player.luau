--!nonstrict
-- Terminal Soviético — painel do player (clique na capa/título da barra).
-- Capa grande, artista – título, ⏮ ⏯ ⏭, progresso (lido a cada segundo só com o
-- painel aberto), botão para mostrar o app e um campo de busca:
--   * com ~/.config/terminal-soviet/spotify.env (SPOTIFY_CLIENT_ID e
--     SPOTIFY_CLIENT_SECRET, permissão 600): Web API do Spotify só para BUSCAR
--     (client credentials); tocar continua local, pelo MPRIS (tocar.sh →
--     playerctl open spotify:track:ID). Arquivo com outra permissão é recusado.
--   * sem credenciais: Enter abre a busca no próprio app (spotify:search:…).
-- Estado da música: noctalia.state "musica" (publicado pelo widget da barra).

local ENV_FILE = "~/.config/terminal-soviet/spotify.env"
local TOCAR = (noctalia.pluginDir() or ".") .. "/tocar.sh"

local musica = noctalia.state.get("musica") or {}
local posicao, duracao = 0, 0
local lendo = false
local resultados = {}
local aviso = nil
local credenciais = nil       -- { id, secret } | false (ausentes/inválidas) | nil (não lidas)
local token, tokenExpira = nil, 0
local buscaRev = 0

local function pedir(op, uri)
  noctalia.state.set("musica-pedido", { op = op, uri = uri, n = noctalia.nowMs() })
end

local function tempo(us)
  local s = math.floor((tonumber(us) or 0) / 1000000)
  return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

local function render()
  local playing = musica.status == "Playing"
  local capa = (musica.artPath and musica.artPath ~= "")
    and ui.image({ key = "capa", path = musica.artPath, width = 160, height = 160, radius = 0, fit = "cover" })
    or ui.box({ key = "capa-vazia", width = 160, height = 160, fill = "surface_variant" })

  local linhas = {}
  for _, r in ipairs(resultados) do
    local uri = r.uri
    table.insert(linhas, ui.button({
      key = "r-" .. uri,
      text = r.artista .. " – " .. r.titulo,
      glyph = "music", variant = "ghost", contentAlign = "start", controlSize = "sm",
      tooltip = r.album,
      onClick = function()
        noctalia.runAsync({ "bash", TOCAR, uri }, nil, 45000)
      end,
    }))
  end

  panel.render(ui.column({ gap = 10 }, {
    ui.row({ gap = 12, align = "center" }, {
      capa,
      ui.column({ gap = 6, flexGrow = 1 }, {
        ui.label({ text = (musica.title ~= "" and musica.title) or "Nada tocando", fontWeight = "bold",
                   color = "primary", maxLines = 2 }),
        ui.label({ text = musica.artist or "", color = "on_surface_variant", maxLines = 2 }),
        ui.row({ gap = 4, align = "center" }, {
          ui.button({ key = "ant", glyph = "player-skip-back-filled", variant = "ghost", controlSize = "sm",
                      onClick = function() noctalia.runAsync({ "playerctl", "-p", "spotify", "previous" }) end }),
          ui.button({ key = "play", glyph = playing and "player-pause-filled" or "player-play-filled",
                      variant = "primary", controlSize = "sm", onClick = function() pedir("tocar") end }),
          ui.button({ key = "prox", glyph = "player-skip-forward-filled", variant = "ghost", controlSize = "sm",
                      onClick = function() noctalia.runAsync({ "playerctl", "-p", "spotify", "next" }) end }),
        }),
        ui.button({ key = "app", text = "Mostrar o app", glyph = "app-window", variant = "ghost",
                    controlSize = "sm", contentAlign = "start",
                    onClick = function()
                      noctalia.runAsync({ "hyprctl", "dispatch", 'hl.dsp.workspace.toggle_special("musica")' })
                      panel.close()
                    end }),
      }),
    }),
    ui.column({ gap = 2 }, {
      ui.progress({ progress = (duracao > 0) and math.min(1, posicao / duracao) or 0, height = 4 }),
      ui.row({ justify = "space_between" }, {
        ui.label({ text = tempo(posicao), color = "on_surface_variant" }),
        ui.label({ text = tempo(duracao), color = "on_surface_variant" }),
      }),
    }),
    ui.separator({}),
    ui.input({ key = "busca", placeholder = "Buscar música…", controlSize = "sm", focus = true,
               onSubmit = "onBuscar" }),
    aviso and ui.label({ text = aviso, color = "on_surface_variant", maxLines = 2 }) or ui.spacer({ height = 0 }),
    ui.scroll({ gap = 2, flexGrow = 1 }, linhas),
  }))
end

local function lerPosicao()
  if lendo or not musica.disponivel then return end
  lendo = true
  noctalia.runAsync({ "playerctl", "-p", "spotify", "metadata", "--format", "{{position}} {{mpris:length}}" },
    function(r)
      lendo = false
      local p, d = string.match(r.stdout or "", "^(%d+)%s+(%d+)")
      posicao, duracao = tonumber(p) or 0, tonumber(d) or 0
      render()
    end, 2000)
end

-- Credenciais: só aceitas com permissão 600/400 (dono lê, mais ninguém).
local function comCredenciais(fn)
  if credenciais ~= nil then fn(credenciais); return end
  noctalia.runAsync({ "sh", "-c", 'f="$HOME/.config/terminal-soviet/spotify.env"; [ -f "$f" ] && stat -c %a "$f"' },
    function(r)
      local modo = string.match(r.stdout or "", "^(%d+)")
      if not modo then
        credenciais = false
      elseif modo ~= "600" and modo ~= "400" then
        credenciais = false
        aviso = "spotify.env com permissão " .. modo .. ": use chmod 600. Buscando no app."
      else
        local raw = noctalia.readFile(ENV_FILE) or ""
        local id = string.match(raw, "SPOTIFY_CLIENT_ID=[\"']?([%w]+)")
        local secret = string.match(raw, "SPOTIFY_CLIENT_SECRET=[\"']?([%w]+)")
        credenciais = (id and secret) and { id = id, secret = secret } or false
      end
      fn(credenciais)
    end, 2000)
end

local function comToken(cred, fn)
  if token and noctalia.nowMs() < tokenExpira then fn(token); return end
  noctalia.http({
    url = "https://accounts.spotify.com/api/token",
    method = "POST",
    body = "grant_type=client_credentials",
    headers = { "Content-Type: application/x-www-form-urlencoded" },
    basic_username = cred.id,
    basic_password = cred.secret,
  }, function(res)
    local data = res.ok and noctalia.json.decode(res.body or "") or nil
    if type(data) == "table" and data.access_token then
      token = data.access_token
      tokenExpira = noctalia.nowMs() + ((tonumber(data.expires_in) or 3600) - 60) * 1000
      fn(token)
    else
      fn(nil)
    end
  end)
end

local function buscarNoApp(q)
  noctalia.runAsync({ "setsid", "-f", "spotify", "--uri=spotify:search:" .. q })
  noctalia.runAsync({ "hyprctl", "dispatch", 'hl.dsp.workspace.toggle_special("musica")' })
  panel.close()
end

function onBuscar(texto)
  local q = string.gsub(texto or "", "^%s*(.-)%s*$", "%1")
  if q == "" then return end
  buscaRev = buscaRev + 1
  local rev = buscaRev
  comCredenciais(function(cred)
    if not cred then buscarNoApp(q); return end
    aviso = "Buscando…"; render()
    comToken(cred, function(tk)
      if not tk then aviso = "Falha ao autenticar na Web API; buscando no app."; buscarNoApp(q); return end
      noctalia.http({
        url = "https://api.spotify.com/v1/search?type=track&limit=8&q=" .. noctalia.string.urlEncode(q),
        headers = { "Authorization: Bearer " .. tk },
      }, function(res)
        if rev ~= buscaRev then return end
        local data = res.ok and noctalia.json.decode(res.body or "") or nil
        resultados = {}
        local itens = type(data) == "table" and data.tracks and data.tracks.items or {}
        for _, t in ipairs(itens) do
          local nomes = {}
          for _, a in ipairs(t.artists or {}) do table.insert(nomes, a.name) end
          table.insert(resultados, {
            uri = t.uri or ("spotify:track:" .. tostring(t.id)),
            titulo = t.name or "?", artista = table.concat(nomes, ", "),
            album = t.album and t.album.name or "",
          })
        end
        aviso = (#resultados == 0) and "Nada encontrado." or nil
        render()
      end)
    end)
  end)
end

noctalia.state.watch("musica", function(v)
  if type(v) == "table" then musica = v; render() end
end)

function update()
  lerPosicao()
end

function onOpen()
  musica = noctalia.state.get("musica") or musica
  panel.setWantsSecondTicks(true)
  render()
  lerPosicao()
end

function onClose()
  panel.setWantsSecondTicks(false)
end

function onKey(chord, pressed)
  if pressed and string.lower(chord) == "escape" then panel.close() end
end
