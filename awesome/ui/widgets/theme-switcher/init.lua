local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local naughty = require("naughty")
local beautiful = require("beautiful")
local dpi = beautiful.xresources.apply_dpi
local clickable_container = require("ui.widgets.clickable-container")
local helpers = require("helpers")
local day_night = {}

-- "AestheticArch / rxyhn" notification after switching themes.
-- Set it to true/false depending on which theme you want it on.
local NOTIFY_THEMES = { day = true, night = true }
local flag_path = (os.getenv("HOME") or "") .. "/.cache/awesome-theme-switched"

local function mark_switch(name)
	pcall(function()
		gears.filesystem.make_directories((os.getenv("HOME") or "") .. "/.cache")
		local f = io.open(flag_path, "w")
		if f then
			f:write(name)
			f:close()
		end
	end)
end

-- on startup (after the theme-switch restart) show the notification
pcall(function()
	local f = io.open(flag_path, "r")
	if not f then
		return
	end
	local name = (f:read("*l") or ""):gsub("%s+", "")
	f:close()
	os.remove(flag_path)
	if NOTIFY_THEMES[name] then
		gears.timer.start_new(1.5, function()
			naughty.notification({
				app_name = "AestheticArch",
				title = "rxyhn",
				message = "~ AestheticArch ~",
				-- Same ghost as the dashboard's (beautiful.pfp), not the loose
				-- assets/ghost.png: that one came out bigger and w/o the
				-- gray background because it's a small, transparent image.
				icon = beautiful.pfp,
				timeout = 5,
			})
			return false
		end)
	end
end)

local function theme_container(widget)
	local container = wibox.widget({
		{
			{
				widget,
				margins = dpi(15),
				forced_height = dpi(30),
				forced_width = dpi(30),
				widget = wibox.container.margin,
			},
			widget = clickable_container,
		},
		shape = helpers.rrect(beautiful.control_center_widget_radius),
		bg = beautiful.lighter_bg,
		widget = wibox.container.background,
	})

	return container
end

local night = wibox.widget({
	{
		id = "icon",
		image = gears.color.recolor_image(beautiful.night, beautiful.xforeground),
		widget = wibox.widget.imagebox,
		resize = true,
	},
	layout = wibox.layout.align.horizontal,
})

night:connect_signal("button::press", function()
	mark_switch("night")
	awful.spawn.easy_async_with_shell("sh " .. gears.filesystem.get_configuration_dir() .. "theme/themes night", function()
		awesome.restart()
	end)
end)

local day = wibox.widget({
	{
		id = "icon",
		image = gears.color.recolor_image(beautiful.day, beautiful.xforeground),
		widget = wibox.widget.imagebox,
		resize = true,
	},
	layout = wibox.layout.align.horizontal,
})

day:connect_signal("button::press", function()
	mark_switch("day")
	awful.spawn.easy_async_with_shell("sh " .. gears.filesystem.get_configuration_dir() .. "theme/themes day", function()
		awesome.restart()
	end)
end)

day_night.night = theme_container(night)
day_night.day = theme_container(day)

local update_themes = function()
	if theme == themes[2] then
		day_night.night.bg = beautiful.accent
	else
		day_night.day.bg = beautiful.accent
	end
end

update_themes()

return day_night
