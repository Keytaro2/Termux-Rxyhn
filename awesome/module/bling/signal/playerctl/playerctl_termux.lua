-- Playerctl-compatible backend for Termux: Audacious (audtool) + MPD (mpc).
--
-- Termux has no dbus/MPRIS or Playerctl library, so we query
-- the players directly:
--   * Audacious -> `audtool` (needs a dbus session: open it from inside
--     awesome, w/ rofi or a terminal, not from another Termux session).
--   * MPD       -> `mpc`.
-- Picks which one to show on its own: whichever is playing (Audacious first); if
-- neither is playing, the last one used. Buttons and shortcuts send the command
-- to the active player.
--
-- Same API as playerctl_lib/cli (signals and methods), so the dashboard,
-- mediakeys, decorations and media keys work w/o changes.
local awful = require("awful")
local gobject = require("gears.object")
local gtimer = require("gears.timer")
local capi = { awesome = awesome }

local base = tostring(...):match("^(.*)%.[^%.]+$")
local mpc = require((base and (base .. ".") or "") .. "playerctl_mpc")

-- MPD cover: MPD doesn't provide it by itself (no MPRIS on Termux), so
-- scripts/mpd-cover.sh pulls it from the file (embedded image or cover.jpg
-- from the folder) and drops it in ~/.cache/awesome-covers.
local COVER_SCRIPT = require("gears.filesystem").get_configuration_dir() .. "scripts/mpd-cover.sh"

local M = {}
local instance = nil

local MPC_FORMAT = "%title%@@%artist%@@%album%@@%file%"

-- A single shell for both players. Each section is marked w/ a
-- #AUD# / #MPD# line; if the player isn't installed or running, its
-- section just doesn't show up.
local POLL = [[
if command -v audtool >/dev/null 2>&1; then
  st=$(timeout 2 audtool playback-status 2>/dev/null)
  if [ -n "$st" ]; then
    echo "#AUD#"
    echo "$st"
    timeout 2 audtool current-song-output-length-seconds 2>/dev/null || echo 0
    timeout 2 audtool current-song-length-seconds 2>/dev/null || echo 0
    timeout 2 audtool current-song-filename 2>/dev/null || echo
  fi
fi
if command -v mpc >/dev/null 2>&1; then
  out=$(timeout 3 mpc -f "]] .. MPC_FORMAT .. [[" status 2>/dev/null)
  if [ -n "$out" ]; then
    echo "#MPD#"
    echo "$out"
  fi
fi
]]

-- Audacious metadata (only when the song changes) + cover art if there's a
-- cover/folder/front/album .jpg/.png next to the file.
local AUD_META = [[
t=$(timeout 2 audtool current-song-tuple-data title 2>/dev/null)
a=$(timeout 2 audtool current-song-tuple-data artist 2>/dev/null)
b=$(timeout 2 audtool current-song-tuple-data album 2>/dev/null)
c=$(timeout 2 audtool current-song 2>/dev/null)
f=$(timeout 2 audtool current-song-filename 2>/dev/null)
f=${f#file://}
d=$(dirname "$f" 2>/dev/null)
art=""
case "$f" in
  /*) for n in cover folder front album Cover Folder Front; do
        for e in jpg png jpeg; do
          if [ -f "$d/$n.$e" ]; then art="$d/$n.$e"; break 2; fi
        done
      done ;;
esac
printf "%s\n%s\n%s\n%s\n%s\n" "$t" "$a" "$b" "$c" "$art"
]]

local function trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

-- quotes a string so it can be passed as a shell argument
local function shq(s) return "'" .. (tostring(s):gsub("'", "'\\''")) .. "'" end

-- Splits the POLL output into {aud = {lines}, mpd = "text"}
function M.split(out)
    local res, cur = { aud = nil, mpd = nil }, nil
    for line in (out or ""):gmatch("([^\r\n]*)\r?\n?") do
        if line == "#AUD#" then
            res.aud, cur = {}, "aud"
        elseif line == "#MPD#" then
            res.mpd, cur = {}, "mpd"
        elseif cur then
            table.insert(res[cur], line)
        end
    end
    if res.mpd then res.mpd = table.concat(res.mpd, "\n") end
    return res
end

-- Audacious lines -> normalized state (nil if there's no data)
function M.parse_aud(lines)
    if not lines or not lines[1] then return nil end
    local status = trim(lines[1]):lower()
    local st = {
        state = (status == "playing" or status == "paused") and status or "stopped",
        position = tonumber(lines[2] and lines[2]:match("%d+")) or 0,
        length = tonumber(lines[3] and lines[3]:match("%d+")) or 0,
        file = trim(lines[4]),
    }
    st.has_song = st.file ~= "" and st.state ~= "stopped"
    return st
end

-- Audacious metadata (5 lines of AUD_META) -> title, artist, album, art
function M.parse_aud_meta(out, file)
    local l = {}
    for line in (out or ""):gmatch("([^\n]*)\n?") do l[#l + 1] = line end
    local title, artist, album, cur, art = trim(l[1]), trim(l[2]), trim(l[3]), trim(l[4]), trim(l[5])
    if title == "" and cur ~= "" then
        local a, t = cur:match("^(.-)%s+%-%s+(.+)$")
        if a and artist == "" then artist = a end
        title = t or cur
    end
    if title == "" and file and file ~= "" then
        title = (file:match("([^/]+)$") or file):gsub("%.%w+$", "")
    end
    return title, artist, album, art
end

local function sh(cmd) awful.spawn.with_shell(cmd) end

-- Command to the active player. If we don't know which one it is yet: Audacious if
-- it's installed, otherwise MPD.
local function control(self, aud_cmd, mpd_cmd)
    local who = self._private.active
    if who == "audacious" then
        sh(aud_cmd)
    elseif who == "mpd" then
        sh(mpd_cmd)
    else
        sh("if command -v audtool >/dev/null 2>&1 && audtool playback-status >/dev/null 2>&1; then " ..
            aud_cmd .. "; else " .. mpd_cmd .. "; fi")
    end
end

function M:pause() control(self, "audtool playback-pause", "mpc -q pause") end
function M:play() control(self, "audtool playback-play", "mpc -q play") end
function M:stop() control(self, "audtool playback-stop", "mpc -q stop") end
function M:play_pause() control(self, "audtool playback-playpause", "mpc -q toggle") end
function M:previous() control(self, "audtool playlist-reverse", "mpc -q prev") end
function M:next() control(self, "audtool playlist-advance", "mpc -q next") end
function M:set_position(position)
    position = math.max(0, math.floor(tonumber(position) or 0))
    control(self, "audtool playback-seek " .. position,
        string.format("mpc -q seek %d:%02d:%02d", position // 3600, (position % 3600) // 60, position % 60))
end
function M:cycle_loop_status() control(self, "audtool playlist-repeat-toggle", "mpc -q repeat") end
function M:set_loop_status() control(self, "audtool playlist-repeat-toggle", "mpc -q repeat") end
function M:cycle_shuffle() control(self, "audtool playlist-shuffle-toggle", "mpc -q random") end
function M:set_shuffle() control(self, "audtool playlist-shuffle-toggle", "mpc -q random") end
function M:set_volume(volume)
    volume = math.floor(math.max(0, math.min(1, tonumber(volume) or 0)) * 100)
    control(self, "audtool set-volume " .. volume, "mpc -q volume " .. volume)
end
function M:disable() if self._private.timer then self._private.timer:stop() end end
function M:get_active_player() return nil end
function M:get_manager() return nil end
function M:get_player_of_name() return nil end

-- Picks which player to show. Returns name, normalized state.
function M.pick(aud, mpd, last)
    if aud and aud.state == "playing" then return "audacious", aud end
    if mpd and mpd.state == "playing" then return "mpd", mpd end
    local mpd_has = mpd and (mpd.file ~= "" or mpd.title ~= "")
    if last == "audacious" and aud and aud.has_song then return "audacious", aud end
    if last == "mpd" and mpd_has then return "mpd", mpd end
    if aud and aud.has_song then return "audacious", aud end
    if mpd_has then return "mpd", mpd end
    return nil
end

local function emit_none(self)
    local p = self._private
    if p.last_key ~= "none" then
        p.last_key, p.active = "none", nil
        if p.last_playing ~= false then
            p.last_playing = false
            self:emit_signal("playback_status", false, "none")
            capi.awesome.emit_signal("bling::playerctl::status", false, "none")
        end
        -- Announce "nothing playing" (empty title/artist) so the widgets
        -- (dashboard Music card, window decoration) show
        -- "Nothing Playing" instead of staying blank. new=false so
        -- signal/playerctl.lua does NOT fire an empty notification.
        self:emit_signal("metadata", "", "", "", "", false, "none")
        capi.awesome.emit_signal("bling::playerctl::title_artist_album", "", "", "", "none")
        self:emit_signal("position", 0, 0, "none")
        self:emit_signal("no_players")
        capi.awesome.emit_signal("bling::playerctl::no_players")
    end
end

-- Custom covers: any image in ~/.config/awesome/assets/covers/ whose
-- name (w/o extension) shows up in the song's title or file name
-- replaces the normal cover. E.g.: "turan slowed.jpg" for "Turan slowed".
local COVERS_DIR = require("gears.filesystem").get_configuration_dir() .. "assets/covers/"

local function norm(s)
    s = tostring(s or ""):lower():gsub("[_%.%-%(%)%[%]]", " "):gsub("%s+", " ")
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function cover_override(title, file)
    local ok, found = pcall(function()
        local Gio = require("lgi").Gio
        local dir = Gio.File.new_for_path(COVERS_DIR)
        local en = dir:enumerate_children("standard::name", Gio.FileQueryInfoFlags.NONE)
        if not en then return nil end
        local haystack = norm(title) .. " | " .. norm(file)
        for info in function() return en:next_file() end do
            local fname = info:get_name()
            local base = norm(fname:gsub("%.%w+$", ""))
            if fname:match("%.[JjPpWw][PpNnEe][GgBbEe]?[Gg]?$") and base ~= "" and haystack:find(base, 1, true) then
                return COVERS_DIR .. fname
            end
        end
        return nil
    end)
    if ok then return found end
    return nil
end

-- Emits the chosen player's signals. n = normalized state:
-- title, artist, album, art, position, length, playing, [volume, loop, shuffle]
local function emit_state(self, name, n)
    local p = self._private
    p.active = name
    local custom = cover_override(n.title, n.file)
    if custom then n.art = custom end
    local key = name .. "\0" .. n.title .. "\0" .. n.artist .. "\0" .. n.album .. "\0" .. n.file
    local new = key ~= p.last_key
    if new or p.tick % 10 == 0 then
        p.last_key = key
        self:emit_signal("metadata", n.title, n.artist, n.art or "", n.album, new, name)
        capi.awesome.emit_signal("bling::playerctl::title_artist_album", n.title, n.artist, n.art or "", name)
    end
    if n.playing ~= p.last_playing or p.tick % 5 == 0 then
        p.last_playing = n.playing
        self:emit_signal("playback_status", n.playing, name)
        capi.awesome.emit_signal("bling::playerctl::status", n.playing, name)
    end
    self:emit_signal("position", n.position, n.length, name)
    capi.awesome.emit_signal("bling::playerctl::position", n.position, n.length, name)
    if n.volume then self:emit_signal("volume", n.volume, name) end
    if n.loop and n.loop ~= p.last_loop then
        p.last_loop = n.loop
        self:emit_signal("loop_status", n.loop, name)
    end
    if n.shuffle ~= nil and n.shuffle ~= p.last_shuffle then
        p.last_shuffle = n.shuffle
        self:emit_signal("shuffle", n.shuffle, name)
    end
end

local function finish(self, aud, mpd_st)
    local p = self._private
    local name, st = M.pick(aud, mpd_st, p.active)
    if not name then
        emit_none(self)
        p.timer.timeout = 3
        p.timer:again()
        return
    end
    p.timer.timeout = 1
    if name == "audacious" then
        local m = p.aud_meta
        emit_state(self, name, {
            title = m.title, artist = m.artist, album = m.album, art = m.art, file = aud.file,
            position = aud.position, length = aud.length, playing = aud.state == "playing",
        })
    else
        emit_state(self, name, {
            title = mpd_st.title, artist = mpd_st.artist, album = mpd_st.album, art = p.mpd_art or "", file = mpd_st.file,
            position = mpd_st.position, length = mpd_st.length, playing = mpd_st.state == "playing",
            volume = mpd_st.volume and mpd_st.volume / 100 or nil,
            loop = mpd_st.repeat_on and "playlist" or "none", shuffle = mpd_st.random_on,
        })
    end
    p.timer:again()
end

local function poll(self)
    local p = self._private
    awful.spawn.easy_async_with_shell(POLL, function(out)
        p.tick = p.tick + 1
        local sec = M.split(out)
        local aud = M.parse_aud(sec.aud)
        local mpd_st = mpc.parse(sec.mpd)

        -- MPD cover: only when the song changes (the script uses a cache).
        -- Through a shell so the callback always runs, even if the script is missing.
        local function with_mpd_art()
            if mpd_st and mpd_st.file ~= "" and p.mpd_file ~= mpd_st.file then
                local file = mpd_st.file
                awful.spawn.easy_async_with_shell(
                    "timeout 15 sh " .. shq(COVER_SCRIPT) .. " " .. shq(file) .. " 2>/dev/null",
                    function(art_out)
                        p.mpd_file = file
                        p.mpd_art = trim(art_out)
                        finish(self, aud, mpd_st)
                    end
                )
            else
                finish(self, aud, mpd_st)
            end
        end

        -- Audacious metadata only if the song changed
        if aud and aud.has_song and (p.aud_file ~= aud.file or not p.aud_meta) then
            awful.spawn.easy_async_with_shell(AUD_META, function(meta_out)
                local title, artist, album, art = M.parse_aud_meta(meta_out, aud.file)
                p.aud_file = aud.file
                p.aud_meta = { title = title, artist = artist, album = album, art = art }
                with_mpd_art()
            end)
        else
            if not p.aud_meta then p.aud_meta = { title = "", artist = "", album = "", art = "" } end
            with_mpd_art()
        end
    end)
end

local function new()
    -- singleton: a single poller even if 5 widgets ask for the object
    if instance then return instance end
    local ret = gobject({})
    for k, v in pairs(M) do
        if type(v) == "function" and (k == "pause" or k == "play" or k == "stop" or k == "play_pause" or
            k == "previous" or k == "next" or k == "set_position" or k == "cycle_loop_status" or
            k == "set_loop_status" or k == "cycle_shuffle" or k == "set_shuffle" or k == "set_volume" or
            k == "disable" or k == "get_active_player" or k == "get_manager" or k == "get_player_of_name") then
            ret[k] = v
        end
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

M._POLL, M._AUD_META = POLL, AUD_META
return setmetatable(M, { __call = function(_, ...) return new(...) end })
