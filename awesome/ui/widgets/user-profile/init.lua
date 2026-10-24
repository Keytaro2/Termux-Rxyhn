local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")
local dpi = beautiful.xresources.apply_dpi

local create_profile = function()
	local profile_imagebox = wibox.widget({
		{
			id = "icon",
			image = beautiful.pfp,
			widget = wibox.widget.imagebox,
			resize = true,
			forced_height = dpi(38),
			clip_shape = gears.shape.circle,
		},
		layout = wibox.layout.align.horizontal,
	})

	local profile_name = wibox.widget({
		font = beautiful.font_name .. "Bold " .. beautiful.fs(12),
		markup = "keytaro",
		align = "left",
		valign = "center",
		widget = wibox.widget.textbox,
	})

	profile_name:set_markup("keytaro")

	local user_profile = wibox.widget({
		layout = wibox.layout.fixed.horizontal,
		spacing = dpi(10),
		{
			layout = wibox.layout.align.vertical,
			expand = "none",
			nil,
			profile_imagebox,
			nil,
		},
		profile_name,
	})

	return user_profile
end

return create_profile
