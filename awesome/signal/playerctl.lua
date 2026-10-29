-- Notification handling library
local naughty = require("naughty")

-- Playerctl
local playerctl = require("module.bling").signal.playerctl.lib()

-- Escapa caracteres especiales de Pango markup (&, <, >)
-- para que títulos/artistas con esos símbolos no rompan la notificación
local function escape_markup(s)
	if not s then return s end
	s = s:gsub("&", "&amp;")
	s = s:gsub("<", "&lt;")
	s = s:gsub(">", "&gt;")
	return s
end

playerctl:connect_signal("metadata", function(_, title, artist, album_path, album, new, player_name)
	if new == true then
		naughty.notify({
			app_name = "Music",
			title = escape_markup(title),
			text = escape_markup(artist),
			image = album_path,
		})
	end
end)
