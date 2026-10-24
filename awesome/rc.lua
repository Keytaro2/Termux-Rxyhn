-- rc.lua
-- Based on your awesome-bar-termux-16 (error handling, terminal chain,
-- wallpaper that covers the screen, Ctrl+Enter) w/ ALL the widgets, signals,
-- functions and scripts from rxyhn's vertical rice (AestheticArch).
--
-- Load order (same as rxyhn's original):
--   theme -> global variables -> configuration -> module -> signal -> ui
-- and at the end the dashboard panel (dashboard/init.lua, w/ rubato).

pcall(require, "luarocks.loader")

local gears     = require("gears")
local awful     = require("awful")
require("awful.autofocus")
local beautiful = require("beautiful")
local naughty   = require("naughty")
local gfs       = gears.filesystem

-- rxyhn's widgets use `dpi` as a global
dpi = beautiful.xresources.apply_dpi

-- {{{ Error handling
naughty.connect_signal("request::display_error", function(message, startup)
  naughty.notification {
    urgency = "critical",
    title   = "Oops, an error happened" .. (startup and " during startup!" or "!"),
    message = message,
  }
end)
-- }}}

-- {{{ Theme
themes = {
  "day",   -- [1] light
  "night", -- [2] dark (the one from the screenshots)
}
theme = themes[2]
beautiful.init(gfs.get_configuration_dir() .. "theme/" .. theme .. "/theme.lua")
-- }}}

-- {{{ Apps (Termux)
-- Terminal: the first installed one from the list (like the chain in your zip 16).
local function first_installed(list)
  for _, cmd in ipairs(list) do
    -- Lua 5.1 returns 0 on success; 5.2+ returns true
    local ok = os.execute("command -v " .. cmd .. " >/dev/null 2>&1")
    if ok == true or ok == 0 then return cmd end
  end
  return list[#list]
end

terminal     = first_installed({ "xfce4-terminal", "alacritty", "kitty", "foot", "xterm" })
-- no D-Bus server of its own: always opens a new window (like music.sh)
if terminal == "xfce4-terminal" then terminal = "xfce4-terminal --disable-server" end
editor       = terminal .. " -e " .. (os.getenv("EDITOR") or first_installed({ "nvim", "vim", "nano" }))
vscode       = "code"
browser      = first_installed({ "firefox", "chromium", "midori", "xdg-open" })
launcher     = "rofi -show drun -theme " .. gfs.get_configuration_dir() .. "theme/rofi.rasi"
file_manager = first_installed({ "thunar", "pcmanfm", "pcmanfm-qt", "xfe", "nautilus" })
music_client = os.getenv("HOME") .. "/.config/awesome/scripts/music.sh"

-- Weather: Open-Meteo (no account or API key). Location is auto-detected:
-- termux-location (Termux:API w/ location permission) or, failing that, by IP.
-- To pin a city, uncomment and put in your coordinates:
-- weather_lat = 18.81
-- weather_lon = -98.95
weather_units = "metric" -- "metric" (°C) or "imperial" (°F)

screen_width  = awful.screen.focused().geometry.width
screen_height = awful.screen.focused().geometry.height
-- }}}

-- {{{ Wallpaper
-- assets/wallpaper.png = rxyhn's montereyNight (theme/assets/montereyNight.png
-- from his dotfiles, shrunk to 2560x1440). It's scaled to COVER the whole
-- screen w/o stretching: looks good at any Termux:X11 size.
-- To use a different wallpaper, replace assets/wallpaper.png (or drop in an
-- assets/wallpaper.jpg and delete the png). If there's no image, a solid theme color is used.
local wallpaper_candidates = {
  gfs.get_configuration_dir() .. "assets/wallpaper.png",
  gfs.get_configuration_dir() .. "assets/wallpaper.jpg",
  os.getenv("HOME") .. "/.config/Wallpaper/s4vitar.png",
}
local wallpaper_focus_y = 0.5 -- 0 = align top, 0.5 = center, 1 = align bottom

local function find_wallpaper()
  for _, p in ipairs(wallpaper_candidates) do
    local f = io.open(p, "rb")
    if f then f:close() return p end
  end
end

local function set_wallpaper(s)
  local path = find_wallpaper()
  if path then
    local ok = pcall(function()
      local geo, cr = gears.wallpaper.prepare_context(s)
      local img = gears.surface.load_uncached(path)
      local iw, ih = gears.surface.get_size(img)
      local k = math.max(geo.width / iw, geo.height / ih)
      cr:translate((geo.width - iw * k) / 2, (geo.height - ih * k) * wallpaper_focus_y)
      cr:scale(k, k)
      cr:set_source_surface(img, 0, 0)
      cr:paint()
    end)
    if ok then return end
    if pcall(function() gears.wallpaper.maximized(path, s, false) end) then return end
  end
  pcall(function() gears.wallpaper.set(beautiful.darker_bg or beautiful.bg_normal) end)
end
screen.connect_signal("property::geometry", set_wallpaper)
-- }}}

-- Autostart (mpd, pulseaudio, picom, xrdb: each one only if installed)
awful.spawn.with_shell("sh " .. gfs.get_configuration_dir() .. "configuration/autostart")

-- {{{ rxyhn's configuration, modules, signals and UI
require("configuration") -- layouts, tags, shortcuts, rules, menu, extras
require("module")        -- bling, rubato, layout-machi, exit-screen, lockscreen...
require("signal")        -- battery, cpu, ram, disk, network, volume, music, weather...
require("ui")            -- bar, control center, notifications, decorations...
-- }}}

-- {{{ Dashboard (your zip's panel w/ rubato animation + rxyhn's widgets)
-- Main screen only: rxyhn's widgets are unique (they're
-- shared), same as the original.
function dashboard_toggle()
  local s = screen.primary
  if s.mydash then s.mydash.toggle() end
end

awful.screen.connect_for_each_screen(function(s)
  set_wallpaper(s)
  if s == screen.primary then
    s.mydash = require("dashboard").build(s)
  end
end)
-- }}}

-- Garbage: less memory (same as rxyhn)
collectgarbage("setpause", 110)
collectgarbage("setstepmul", 1000)
gears.timer({
  timeout = 5,
  autostart = true,
  call_now = true,
  callback = function() collectgarbage("collect") end,
})
