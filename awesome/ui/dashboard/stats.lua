-- Standard awesome library
local gears = require("gears")
local awful = require("awful")

-- Theme handling library
local beautiful = require("beautiful")

-- Notification library
local naughty = require("naughty")

-- Widget library
local wibox = require("wibox")

-- rubato
local rubato = require("module.rubato")

-- Helpers
local helpers = require("helpers")

-- Stats
----------

local stats_text = wibox.widget({
	font = beautiful.font_name .. "bold " .. beautiful.fs(10),
	markup = helpers.colorize_text("Stats", beautiful.dashboard_box_fg),
	valign = "center",
	widget = wibox.widget.textbox,
})

-- Vars
local vol_color = beautiful.xcolor4
local disk_color = beautiful.xcolor5 -- purple: storage
local battery_color = beautiful.xcolor6 -- teal: battery
local ram_color = beautiful.xcolor2
local vol_now = 0

-- Helpers
local function create_slider_widget(slider_color)
	local slider_widget = wibox.widget({
		{
			id = "slider",
			max_value = 100,
			value = 20,
			background_color = slider_color .. "44",
			color = slider_color,
			shape = gears.shape.rounded_rect,
			bar_shape = gears.shape.rounded_rect,
			widget = wibox.widget.progressbar,
		},
		forced_width = dpi(4),
		forced_height = dpi(145),
		direction = "east",
		widget = wibox.container.rotate,
	})

	return slider_widget
end

local stats_tooltip = wibox.widget({
	visible = false,
	top_only = true,
	layout = wibox.layout.stack,
})

local tooltip_counter = 0
local function create_tooltip(w)
	local tooltip = wibox.widget({
		font = beautiful.font_name .. "bold " .. beautiful.fs(10),
		align = "right",
		valign = "center",
		widget = wibox.widget.textbox,
	})

	tooltip_counter = tooltip_counter + 1
	local index = tooltip_counter

	stats_tooltip:insert(index, tooltip)

	w:connect_signal("mouse::enter", function()
		-- Raise tooltip to the top of the stack
		stats_tooltip:set(1, tooltip)
		stats_tooltip.visible = true
	end)
	w:connect_signal("mouse::leave", function()
		stats_tooltip.visible = false
	end)

	return tooltip
end

-- Widget
local vol = create_slider_widget(vol_color)
local disk = create_slider_widget(disk_color)
local battery = create_slider_widget(battery_color)
local ram = create_slider_widget(ram_color)

local vol_tooltip = create_tooltip(vol)
local disk_tooltip = create_tooltip(disk)
local battery_tooltip = create_tooltip(battery)
local ram_tooltip = create_tooltip(ram)

awesome.connect_signal("signal::volume", function(value, muted)
	local fill_color
	local vol_value = value or 0

	if muted then
		fill_color = beautiful.xcolor8
	else
		fill_color = vol_color
	end

	vol_now = vol_value
	vol.slider.value = vol_value
	vol.slider.color = fill_color
	vol_tooltip.markup = helpers.colorize_text(vol_value .. "%", vol_color)
end)

awesome.connect_signal("signal::disk", function(used, total)
	local pct = (total and total > 0) and (used / total) * 100 or 0
	disk.slider.value = pct
	disk_tooltip.markup = helpers.colorize_text(string.format("%.0f/%.0fG", used, total), disk_color)
end)

awesome.connect_signal("signal::battery", function(value)
	battery.slider.value = value
	battery_tooltip.markup = helpers.colorize_text(value .. "%", battery_color)
end)

awesome.connect_signal("signal::ram", function(used, total)
	local r_average = (used / total) * 100
	local r_used = string.format("%.1f", used / 1000) .. "G"

	ram.slider.value = r_average
	ram_tooltip.markup = helpers.colorize_text(r_used, ram_color)
end)

-- Volume: click on the bar = sets that level; wheel = +-5
local function set_volume(v)
	awesome.emit_signal("signal::volume::set", math.max(0, math.min(100, v)))
end

vol:connect_signal("button::press", function(_, _, ly, button, _, geo)
	if button == 1 then
		-- 'geo' is the table w/ the widget's geometry (x, y, width, height)
		local h = (type(geo) == "table" and geo.height) or dpi(145)
		set_volume(math.floor((1 - ly / h) * 100 + 0.5))
	elseif button == 4 then
		set_volume(vol_now + 5)
	elseif button == 5 then
		set_volume(vol_now - 5)
	end
end)

local stats = wibox.widget({
	{
		stats_text,
		nil,
		stats_tooltip,
		expand = "none",
		layout = wibox.layout.align.horizontal,
	},
	{
		nil,
		{
			nil,
			{
				vol,
				disk,
				battery,
				ram,
				spacing = dpi(24),
				layout = wibox.layout.fixed.horizontal,
			},
			expand = "none",
			layout = wibox.layout.fixed.vertical,
		},
		expand = "none",
		layout = wibox.layout.align.horizontal,
	},
	spacing = dpi(10),
	layout = wibox.layout.fixed.vertical,
})

return stats
