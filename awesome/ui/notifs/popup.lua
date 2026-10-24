-- Standard awesome library
local gears = require("gears")
local awful = require("awful")

-- Theme handling library
local beautiful = require("beautiful")

-- Widget library
local wibox = require("wibox")

-- Helpers
local helpers = require("helpers")

-- Rubato
local rubato = require("module.rubato")

-- Pop Up Notification
------------

local pop_icon = wibox.widget({
	forced_height = dpi(130),
	forced_width = dpi(130),
	font = beautiful.icon_font_name .. "96",
	align = "center",
	valign = "center",
	widget = wibox.widget.textbox(),
})

local pop_bar = wibox.widget({
	max_value = 100,
	value = 0,
	background_color = beautiful.pop_bar_bg,
	color = beautiful.bg_accent,
	shape = gears.shape.rounded_bar,
	bar_shape = gears.shape.rounded_bar,
	forced_height = dpi(30),
	widget = wibox.widget.progressbar,
})

local pop = wibox({
	type = "dock",
	screen = screen.primary,
	height = beautiful.pop_size,
	width = beautiful.pop_size,
	shape = helpers.rrect(beautiful.pop_border_radius),
	bg = beautiful.transparent,
	ontop = true,
	visible = false,
})

pop:setup({
	{
		{
			{
				pop_icon,
				layout = wibox.layout.fixed.vertical,
			},
			nil,
			pop_bar,
			layout = wibox.layout.align.vertical,
		},
		top = dpi(15),
		bottom = dpi(30),
		left = dpi(30),
		right = dpi(30),
		widget = wibox.container.margin,
	},
	bg = beautiful.xbackground,
	shape = helpers.rrect(beautiful.pop_border_radius),
	widget = wibox.container.background,
})
awful.placement.bottom(pop, { margins = { bottom = dpi(100) } })

-- Animation: slides up from the bottom (same rubato params as the notification
-- center) and goes back down when the time is up.
local function pop_target_y()
	local g = screen.primary.geometry
	return g.y + g.height - pop.height - dpi(100)
end

local function pop_hidden_y()
	local g = screen.primary.geometry
	return g.y + g.height
end

pop.y = pop_hidden_y()
local pop_open = false

local pop_slide = rubato.timed({
	pos = pop_hidden_y(),
	rate = 60,
	intro = 0.1,
	duration = 0.3,
	easing = rubato.quadratic,
	awestore_compat = true,
	subscribed = function(pos)
		pop.y = math.floor(pos + 0.5)
	end,
})

pop_slide.ended:subscribe(function()
	if not pop_open then
		pop.visible = false
	end
end)

local pop_timeout = gears.timer({
	timeout = 1.4,
	single_shot = true,
	callback = function()
		if pop_open then
			pop_open = false
			pop_slide:set(pop_hidden_y())
		end
	end,
})

local function toggle_pop()
	if not pop_open then
		pop_open = true
		pop.y = pop_hidden_y()
		pop.visible = true
		pop_slide:set(pop_target_y())
	end
	pop_timeout:again()
end

-- Volume: the popup shows every time the volume changes, no matter where it comes from:
--   * the phone's volume buttons (signal/volume.lua polls it w/
--     termux-volume every ~1.5 s)
--   * the slider / volume bars in the control center and dashboard
-- (only the first reading at startup and the rounding of the command
-- you just sent are ignored: `silent`)
local vol_first_time = true
awesome.connect_signal("signal::volume", function(value, muted, silent)
	if vol_first_time then
		vol_first_time = false
	elseif not silent then
		value = value or 0
		pop_bar.value = value

		if muted or value == 0 then
			pop_icon.markup = helpers.colorize_text("󰖁", beautiful.xcolor8)
			pop_bar.color = beautiful.xcolor8
		else
			pop_icon.markup = helpers.colorize_text("󰕾", beautiful.accent)
			pop_bar.color = beautiful.accent
		end

		toggle_pop()
	end
end)

-- Brightness: the popup shows ONLY when you move the brightness slider in the control
-- center (ui/widgets/vol-bri-slider emits signal::brightness::popup).
-- The automatic reading of signal::brightness (every 30 s) no longer shows it.
awesome.connect_signal("signal::brightness::popup", function(value)
	pop_icon.markup = helpers.colorize_text("󰖨", beautiful.accent)
	pop_bar.value = value or 0
	pop_bar.color = beautiful.accent

	toggle_pop()
end)

-- Layout list
-----------------

local layout_list = awful.widget.layoutlist({
	source = awful.widget.layoutlist.source.default_layouts, -- DOC_HIDE
	spacing = dpi(24),
	base_layout = wibox.widget({
		spacing = dpi(24),
		forced_num_cols = 4,
		layout = wibox.layout.grid.vertical,
	}),
	widget_template = {
		{
			{
				id = "icon_role",
				forced_height = dpi(68),
				forced_width = dpi(68),
				widget = wibox.widget.imagebox,
			},
			margins = dpi(24),
			widget = wibox.container.margin,
		},
		id = "background_role",
		forced_width = dpi(68),
		forced_height = dpi(68),
		widget = wibox.container.background,
	},
})

local layout_popup = awful.popup({
	widget = wibox.widget({
		{ layout_list, margins = dpi(24), widget = wibox.container.margin },
		bg = beautiful.xbackground,
		shape = helpers.rrect(beautiful.border_radius),
		border_color = beautiful.widget_border_color,
		border_width = beautiful.widget_border_width,
		widget = wibox.container.background,
	}),
	placement = awful.placement.centered,
	ontop = true,
	visible = false,
	bg = beautiful.xbackground .. "00",
})

function gears.table.iterate_value(t, value, step_size, filter, start_at)
	local k = gears.table.hasitem(t, value, true, start_at)
	if not k then
		return
	end

	step_size = step_size or 1
	local new_key = gears.math.cycle(#t, k + step_size)

	if filter and not filter(t[new_key]) then
		for i = 1, #t do
			local k2 = gears.math.cycle(#t, new_key + i)
			if filter(t[k2]) then
				return t[k2], k2
			end
		end
		return
	end

	return t[new_key], new_key
end

awful.keygrabber({
	start_callback = function()
		layout_popup.visible = true
	end,
	stop_callback = function()
		layout_popup.visible = false
	end,
	export_keybindings = true,
	stop_event = "release",
	stop_key = { "Escape", "Super_L", "Super_R", "Mod4" },
	keybindings = {
		{
			{ modkey, "Shift" },
			" ",
			function()
				awful.layout.set(gears.table.iterate_value(layout_list.layouts, layout_list.current_layout, -1), nil)
			end,
		},
		{
			{ modkey },
			" ",
			function()
				awful.layout.set(gears.table.iterate_value(layout_list.layouts, layout_list.current_layout, 1), nil)
			end,
		},
	},
})
