-- Playerctl-compatible backend for MPD (Termux).
--
-- Termux no tiene dbus/MPRIS ni la libreria Playerctl de GObject, asi que
-- bling no puede hablar con ningun reproductor. Este backend expone LA MISMA
-- API que playerctl_lib/playerctl_cli (mismas senales y metodos) pero lee el
-- estado desde `mpc` (cliente de MPD). Sirve tal cual para el dashboard,
-- mediakeys, decoraciones de musica y los atajos de teclado.
--
-- Senales: metadata, position, playback_status, loop_status, shuffle,
--          volume, no_players
local awful = require("awful")
local gobject = require("gears.object")
local gtimer = require("gears.timer")
local capi = { awesome = awesome }

local PLAYER = "mpd"
local FORMAT = "%title%@@%artist%@@%album%@@%file%"

local M = {}
local instance = nil

-- "1:23" | "01:02:03" -> segundos
local function to_seconds(s)
    if not s then return 0 end
    local total, mult = 0, 1
    local parts = {}
    for p in tostring(s):gmatch("%d+") do parts[#parts + 1] = tonumber(p) end
    for i = #parts, 1, -1 do
        total = total + parts[i] * mult
        mult = mult * 60
    end
    return total
end

-- Parsea la salida de: mpc -f FORMAT status
-- Devuelve nil si MPD no responde, o una tabla de estado.
function M.parse(out)
    if not out or out:match("^%s*$") then return nil end
    local lines = {}
    for l in out:gmatch("[^\r\n]+") do lines[#lines + 1] = l end
    local st = {
        state = "stopped", title = "", artist = "", album = "", file = "",
        position = 0, length = 0, volume = nil, repeat_on = false, random_on = false,
    }
    for _, l in ipairs(lines) do
        local state, t = l:match("^%[(%a+)%]%s+#%d+/%d+%s+([%d:]+/[%d:]+)")
        if state then
            st.state = state
            local p, len = t:match("([%d:]+)/([%d:]+)")
            st.position, st.length = to_seconds(p), to_seconds(len)
        elseif l:match("^volume:") then
            st.volume = tonumber(l:match("volume:%s*(%d+)"))
            st.repeat_on = l:match("repeat:%s*(%a+)") == "on"
            st.random_on = l:match("random:%s*(%a+)") == "on"
        elseif l:find("@@", 1, true) then
            local title, artist, album, file = l:match("^(.-)@@(.-)@@(.-)@@(.*)$")
            st.title, st.artist, st.album, st.file = title or "", artist or "", album or "", file or ""
        end
    end
    if st.title == "" and st.file ~= "" then
        st.title = st.file:match("([^/]+)$") or st.file
        st.title = st.title:gsub("%.%w+$", "")
    end
    return st
end

local function sh(cmd) awful.spawn.with_shell(cmd) end

function M:pause() sh("mpc -q pause") end
function M:play() sh("mpc -q play") end
function M:stop() sh("mpc -q stop") end
function M:play_pause() sh("mpc -q toggle") end
function M:previous() sh("mpc -q prev") end
function M:next() sh("mpc -q next") end
function M:set_position(position)
    position = math.max(0, math.floor(tonumber(position) or 0))
    sh(string.format("mpc -q seek %d:%02d:%02d", position // 3600, (position % 3600) // 60, position % 60))
end
function M:cycle_loop_status() sh("mpc -q repeat") end
function M:set_loop_status() sh("mpc -q repeat") end
function M:cycle_shuffle() sh("mpc -q random") end
function M:set_shuffle() sh("mpc -q random") end
function M:set_volume(volume)
    volume = math.floor(math.max(0, math.min(1, tonumber(volume) or 0)) * 100)
    sh("mpc -q volume " .. volume)
end
function M:disable()
    if self._private.timer then self._private.timer:stop() end
end
function M:get_active_player() return nil end
function M:get_manager() return nil end
function M:get_player_of_name() return nil end

local function poll(self)
    local p = self._private
    awful.spawn.easy_async_with_shell(
        "command -v mpc >/dev/null 2>&1 && timeout 3 mpc -f '" .. FORMAT .. "' status 2>/dev/null",
        function(out)
            p.tick = p.tick + 1
            local st = M.parse(out)

            -- MPD apagado / mpc no instalado: avisar una vez y bajar la frecuencia
            if not st or (st.file == "" and st.title == "") then
                if st then
                    -- MPD responde pero esta detenido y sin cancion
                    if p.last_playing ~= false then
                        p.last_playing = false
                        self:emit_signal("playback_status", false, PLAYER)
                        capi.awesome.emit_signal("bling::playerctl::status", false, PLAYER)
                    end
                end
                if p.last_key ~= "none" then
                    p.last_key = "none"
                    self:emit_signal("no_players")
                    capi.awesome.emit_signal("bling::playerctl::no_players")
                end
                p.timer.timeout = st and 2 or 6
                p.timer:again()
                return
            end

            p.timer.timeout = 1
            local key = st.title .. "\0" .. st.artist .. "\0" .. st.album .. "\0" .. st.file
            local new = key ~= p.last_key
            if new or p.tick % 10 == 0 then
                p.last_key = key
                self:emit_signal("metadata", st.title, st.artist, "", st.album, new, PLAYER)
                capi.awesome.emit_signal("bling::playerctl::title_artist_album", st.title, st.artist, "", PLAYER)
            end

            local playing = st.state == "playing"
            if playing ~= p.last_playing or p.tick % 5 == 0 then
                p.last_playing = playing
                self:emit_signal("playback_status", playing, PLAYER)
                capi.awesome.emit_signal("bling::playerctl::status", playing, PLAYER)
            end

            self:emit_signal("position", st.position, st.length, PLAYER)
            capi.awesome.emit_signal("bling::playerctl::position", st.position, st.length, PLAYER)

            if st.volume then self:emit_signal("volume", st.volume / 100, PLAYER) end
            local loop = st.repeat_on and "playlist" or "none"
            if loop ~= p.last_loop then
                p.last_loop = loop
                self:emit_signal("loop_status", loop, PLAYER)
            end
            if st.random_on ~= p.last_shuffle then
                p.last_shuffle = st.random_on
                self:emit_signal("shuffle", st.random_on, PLAYER)
            end
            p.timer:again()
        end
    )
end

local function new()
    -- singleton: un solo poller aunque 5 widgets pidan el objeto
    if instance then return instance end
    local ret = gobject({})
    for k, v in pairs(M) do
        if type(v) == "function" and k ~= "parse" then ret[k] = v end
    end
    ret._private = { tick = 0 }
    ret._private.timer = gtimer({
        timeout = 1,
        autostart = false,
        single_shot = true,
        callback = function() poll(ret) end,
    })
    gtimer.delayed_call(function() poll(ret) end)
    instance = ret
    return ret
end

return setmetatable(M, { __call = function(_, ...) return new(...) end })
