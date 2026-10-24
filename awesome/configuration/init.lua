-- Standard awesome library
local awful = require("awful")
local gears = require("gears")
local gfs = gears.filesystem
local wibox = require("wibox")

-- Theme handling library
local beautiful = require("beautiful")

-- Helpers
local helpers = require("helpers")

-- Bling Module
local bling = require("module.bling")

-- Layout Machi
local machi = require("module.layout-machi")
beautiful.layout_machi = machi.get_icon()

-- This is to slave windows' positions in floating layout
require("module.savefloats")

-- Better mouse resizing on tiled
require("module.better-resize")

-- Desktop
-------------

-- Custom Layouts
local mstab = bling.layout.mstab
local centered = bling.layout.centered
local horizontal = bling.layout.horizontal
local equal = bling.layout.equalarea
local deck = bling.layout.deck

machi.editor.nested_layouts = {
	["0"] = deck,
	["1"] = awful.layout.suit.spiral,
	["2"] = awful.layout.suit.fair,
	["3"] = awful.layout.suit.fair.horizontal,
}

-- Set the layouts
tag.connect_signal("request::default_layouts", function()
	awful.layout.append_default_layouts({
		awful.layout.suit.tile,
		awful.layout.suit.floating,
		centered,
		mstab,
		horizontal,
		machi.default_layout,
		equal,
		deck,
	})
end)

-- Screen Padding and Tags
screen.connect_signal("request::desktop_decoration", function(s)
	-- Screen padding
	screen[s].padding = { left = dpi(40), right = dpi(15), top = dpi(15), bottom = dpi(15) }
	-- Each screen has its own tag table.
	awful.tag({ "1", "2", "3", "4", "5" }, s, awful.layout.layouts[1])
end)

-- Wallpaper: handled by rc.lua (assets/wallpaper.png, scaled to cover)

-- Stuff
-----------

require("configuration.keys")
require("configuration.ruled")
require("configuration.extras")
require("configuration.menu")
