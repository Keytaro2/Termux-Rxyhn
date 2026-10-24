local gears = require("gears")
local beautiful = require("beautiful")
local dpi = beautiful.xresources.apply_dpi
local wibox = require("wibox")
local helpers = require("helpers")

-- Control center sliders
-- * Volume: real slider (drag / tap). Uses volume.sh (termux-volume)
--   through the signal::volume::set signal, w/ a 0.08 s wait so we don't
--   launch a process for every pixel dragged.
-- * Brightness: visual only (doesn't change the real brightness), but moving it notifies w/
--   signal::brightness::popup so the brightness popup shows up.
----------
local bg_color = beautiful.accent

local function create_slider_widget(initial)
	return wibox.widget({
		{
			id = "slider",
			bar_shape = helpers.rrect(dpi(20)),
			bar_height = dpi(40),
			bar_color = bg_color .. "55",
			bar_active_color = bg_color,
			handle_width = 0,
			handle_color = bg_color,
			minimum = 0,
			maximum = 100,
			value = initial,
			forced_height = dpi(40),
			widget = wibox.widget.slider,
		},
		forced_width = dpi(148),
		forced_height = dpi(40),
		widget = wibox.container.background,
	})
end

local function create_icons(icon, color)
	return wibox.widget({
		{
			markup = helpers.colorize_text(icon, color),
			font = beautiful.icon_font_name .. "14",
			align = "left",
			valign = "center",
			widget = wibox.widget.textbox,
		},
		left = dpi(10),
		widget = wibox.container.margin,
	})
end

-- Widgets
local vol = create_slider_widget(0)
local brightness = create_slider_widget(60)

local vol_slider_container = wibox.widget({
	vol,
	create_icons("󰕾", beautiful.xforeground),
	layout = wibox.layout.stack,
})

local brightness_slider_container = wibox.widget({
	brightness,
	create_icons("󰖨", beautiful.xforeground),
	layout = wibox.layout.stack,
})

-- Volume: UI -> system (w/ a 0.08 s wait)
local pressed, updating = false, false
local pending = 0
local send_timer = gears.timer({
	timeout = 0.08,
	single_shot = true,
	callback = function()
		awesome.emit_signal("signal::volume::set", math.floor(pending))
	end,
})

vol.slider:connect_signal("property::value", function()
	if updating then
		return
	end
	pending = vol.slider.value
	if not send_timer.started then
		send_timer:start()
	end
end)
vol.slider:connect_signal("button::press", function()
	pressed = true
end)
vol.slider:connect_signal("button::release", function()
	pressed = false
end)

-- Brightness: moving the slider shows the brightness popup
brightness.slider:connect_signal("property::value", function()
	awesome.emit_signal("signal::brightness::popup", math.floor(brightness.slider.value))
end)

-- Volume: system -> UI (w/o firing the command again)
awesome.connect_signal("signal::volume", function(value)
	if pressed then
		return
	end
	updating = true
	vol.slider.value = value or 0
	updating = false
end)

local stats = wibox.widget({
	{
		{
			brightness_slider_container,
			vol_slider_container,
			spacing = dpi(15),
			layout = wibox.layout.fixed.horizontal,
		},
		expand = "none",
		layout = wibox.layout.fixed.vertical,
	},
	expand = "none",
	layout = wibox.layout.align.horizontal,
})

return stats
