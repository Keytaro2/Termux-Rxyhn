-- Standard awesome library
local gears = require("gears")
local awful = require("awful")

-- Theme handling library
local beautiful = require("beautiful")

-- Widget library
local wibox = require("wibox")

-- Rubato
local rubato = require("module.rubato")

-- Helpers
local helpers = require("helpers")

-- Helpers
-------------

local format_item = function(widget)
	return wibox.widget({
		{
			{
				layout = wibox.layout.align.vertical,
				expand = "none",
				nil,
				widget,
				nil,
			},
			margins = dpi(10),
			widget = wibox.container.margin,
		},
		forced_height = dpi(58),
		bg = beautiful.control_center_widget_bg,
		shape = helpers.rrect(beautiful.control_center_widget_radius),
		widget = wibox.container.background,
	})
end

local format_item_no_fix_height = function(widget)
	return wibox.widget({
		{
			{
				layout = wibox.layout.align.vertical,
				expand = "none",
				nil,
				widget,
				nil,
			},
			margins = dpi(10),
			widget = wibox.container.margin,
		},
		bg = beautiful.control_center_widget_bg,
		shape = helpers.rrect(beautiful.control_center_widget_radius),
		widget = wibox.container.background,
	})
end

local function format_progress_bar(bar, image)
	local image = wibox.widget({
		image = image,
		widget = wibox.widget.imagebox,
		resize = true,
	})
	image.forced_height = dpi(8)
	image.forced_width = dpi(8)

	local w = wibox.widget({
		{
			image,
			margins = dpi(30),
			widget = wibox.container.margin,
		},
		bar,
		layout = wibox.layout.stack,
	})

	return w
end

local function create_boxed_widget(widget_to_be_boxed, width, height, radius, bg_color)
	local box_container = wibox.container.background()
	box_container.bg = bg_color
	box_container.forced_height = height
	box_container.forced_width = width
	box_container.shape = helpers.rrect(radius)

	local boxed_widget = wibox.widget({
		{
			nil,
			{
				widget_to_be_boxed,
				layout = wibox.layout.align.vertical,
				expand = "none",
			},
			layout = wibox.layout.align.horizontal,
		},
		widget = box_container,
	})
	return boxed_widget
end

local function create_arc_container(markup, widget)
	local text = wibox.widget({
		font = beautiful.font_name .. "Bold " .. beautiful.fs(10),
		markup = helpers.colorize_text(markup, beautiful.dashboard_box_fg),
		valign = "center",
		widget = wibox.widget.textbox,
	})

	local arc_container = wibox.widget({
		{
			{
				text,
				expand = "none",
				layout = wibox.layout.align.horizontal,
			},
			top = dpi(10),
			left = dpi(10),
			widget = wibox.container.margin,
		},
		{
			widget,
			left = dpi(15),
			right = dpi(15),
			top = dpi(10),
			widget = wibox.container.margin,
		},
		layout = wibox.layout.fixed.vertical,
	})

	return arc_container
end

local function create_buttons(icon, color)
	local button = wibox.widget({
		id = "icon",
		markup = helpers.colorize_text(icon, color),
		font = beautiful.icon_font_name .. "13",
		align = "center",
		valign = "center",
		ellipsize = "none",
		widget = wibox.widget.textbox,
	})

	local button_container = wibox.widget({
		{
			{
				button,
				margins = dpi(9),
				forced_height = dpi(40),
				forced_width = dpi(40),
				widget = wibox.container.margin,
			},
			widget = require("ui.widgets.clickable-container"),
		},
		bg = beautiful.control_center_button_bg,
		shape = gears.shape.circle,
		widget = wibox.container.background,
	})

	return button_container
end

-- Control Center
--------------------

-- widgets
-------------

-- color indicator
local off = beautiful.control_center_button_bg
local on = beautiful.accent

-- wifi button
local wifi = create_buttons("󰤨", beautiful.xforeground)
local wifi_status = false -- off

awesome.connect_signal("signal::network", function(status, ssid)
	wifi_status = status
	awesome.emit_signal("widget::network")
end)

awesome.connect_signal("widget::network", function()
	local w, fill_color
	if wifi_status == true then
		fill_color = on
		wifi:buttons({
			awful.button({}, 1, function()
				awful.spawn("nmcli radio wifi off")
			end),
		})
	else
		fill_color = off
		wifi:buttons({
			awful.button({}, 1, function()
				awful.spawn("nmcli radio wifi on")
			end),
		})
	end
	wifi.bg = fill_color
end)

-- bluetooth button
local bluetooth = create_buttons("󰂯", beautiful.xforeground)
local bluetooth_status = true

bluetooth:buttons({
	awful.button({}, 1, function()
		bluetooth_status = not bluetooth_status
		if bluetooth_status then
			bluetooth.bg = off
			awful.spawn("bluetoothctl power off")
		else
			bluetooth.bg = on
			awful.spawn("bluetoothctl power on")
		end
	end),
})

-- screenrec button
local screenrec = require("ui.widgets.screenrec")()

-- screenshot button
local screenshot = create_buttons("󰆞", beautiful.xforeground)
screenshot:buttons({
	awful.button({}, 1, function()
		control_center_toggle()
		-- wait for the panel to finish hiding so it doesn't show up in the screenshot
		gears.timer.start_new(0.9, function()
			screenshot_take()
			return false
		end)
	end),
})

-- user profile
local user_profile = wibox.widget({
	layout = wibox.layout.align.horizontal,
	forced_height = dpi(58),
	nil,
	format_item(require("ui.widgets.user-profile")()),
	{
		format_item({
			layout = wibox.layout.fixed.horizontal,
			require("ui.widgets.end-session")(),
		}),
		left = dpi(10),
		widget = wibox.container.margin,
	},
})

-- brightness & Volume stats
local control_center_row_two = require("ui.widgets.vol-bri-slider")

-- dnd, blue-light, airplane-mode, & theme switcher
local control_center_row_three = wibox.widget({
	layout = wibox.layout.flex.horizontal,
	spacing = dpi(12),
	format_item_no_fix_height({
		layout = wibox.layout.fixed.vertical,
		spacing = dpi(5),
		nil,
		require("ui.widgets.dont-disturb"),
		require("ui.widgets.blue-light"),
		require("ui.widgets.airplane-mode"),
		nil,
	}),
	{
		layout = wibox.layout.flex.vertical,
		spacing = dpi(12),
		format_item_no_fix_height({
			layout = wibox.layout.align.vertical,
			expand = "none",
			nil,
			require("ui.widgets.floating-mode"),
			nil,
		}),
		{
			layout = wibox.layout.flex.horizontal,
			spacing = dpi(15),
			require("ui.widgets.theme-switcher").day,
			nil,
			require("ui.widgets.theme-switcher").night,
		},
	},
})

-- wifi, bluetooth, screenrec, screenshot
local control_center_row_four = wibox.widget({
	{
		{
			wifi,
			bluetooth,
			screenrec,
			screenshot,
			spacing = dpi(6),
			layout = wibox.layout.flex.horizontal,
		},
		margins = dpi(10),
		widget = wibox.container.margin,
	},
	shape = helpers.rrect(beautiful.control_center_widget_radius),
	bg = beautiful.control_center_widget_bg,
	widget = wibox.container.background,
})

-- cpu arc
local cpu_bar = require("ui.widgets.arc.cpu_arc")
local cpu = format_progress_bar(cpu_bar, gears.color.recolor_image(beautiful.cpu, beautiful.xforeground))
local cpu_details = create_arc_container("Cpu", cpu)
local cpu_box = create_boxed_widget(
	cpu_details,
	dpi(50),
	dpi(108),
	beautiful.control_center_widget_radius,
	beautiful.control_center_widget_bg
)

-- ram arc
local ram_bar = require("ui.widgets.arc.ram_arc")
local ram = format_progress_bar(ram_bar, gears.color.recolor_image(beautiful.ram, beautiful.xforeground))
local ram_details = create_arc_container("Ram", ram)
local ram_box = create_boxed_widget(
	ram_details,
	dpi(50),
	dpi(108),
	beautiful.control_center_widget_radius,
	beautiful.control_center_widget_bg
)

-- temp arc
local temp_bar = require("ui.widgets.arc.temp_arc")
local temp = format_progress_bar(temp_bar, gears.color.recolor_image(beautiful.temp, beautiful.xforeground))
local temp_details = create_arc_container("Temp", temp)
local temp_box = create_boxed_widget(
	temp_details,
	dpi(50),
	dpi(108),
	beautiful.control_center_widget_radius,
	beautiful.control_center_widget_bg
)

-- arc container
local arc_container = wibox.widget({
	layout = wibox.layout.flex.horizontal,
	spacing = dpi(15),
	ram_box,
	cpu_box,
	temp_box,
})

-- Control Center
--------------------

control_center = wibox({
	type = "dock",
	screen = screen.primary,
	bg = beautiful.transparent,
	height = beautiful.control_center_height,
	width = beautiful.control_center_width,
	ontop = true,
	visible = false,
})

awful.placement.bottom_right(control_center, { honor_workarea = true, margins = beautiful.useless_gap * 5 })

-- rubato
local slide = rubato.timed({
	pos = screen.primary.geometry.width,
	rate = 60,
	intro = 0.1,
	duration = 0.35,
	easing = rubato.quadratic,
	awestore_compat = true,
	subscribed = function(pos)
		-- integer x and no repeats: fewer requests to X per frame
		local x = math.floor(pos + 0.5)
		if x ~= control_center.x then
			control_center.x = x
		end
	end,
})

local control_center_status = false

-- Clipping: on Termux:X11 the panel sometimes ends up half-painted after
-- sliding (goes away when you move the mouse). We force a full repaint
-- when it finishes opening and every time the pointer enters.
local function force_redraw()
	gears.timer.start_new(0.05, function()
		pcall(function()
			local root = control_center.widget
			if root then
				root:emit_signal("widget::redraw_needed")
			end
		end)
		return false
	end)
end

-- While sliding, the panel ignores the pointer: widgets passing under
-- the finger/mouse fired hover on every frame and made the animation lag.
local function cc_release_input()
	pcall(function()
		control_center.input_passthrough = false
	end)
end

local function cc_hold_input()
	pcall(function()
		control_center.input_passthrough = true
	end)
	-- failsafe in case "ended" never arrives (same duration as the slide + margin)
	gears.timer.start_new(0.35 + 0.3, function()
		cc_release_input()
		return false
	end)
end

slide.ended:subscribe(function()
	cc_release_input()
	if control_center_status then
		control_center.visible = false
	else
		force_redraw()
	end
end)

control_center:connect_signal("mouse::enter", force_redraw)

-- Android keyboard / resolution change: reposition the panel
screen.primary:connect_signal("property::geometry", function()
	gears.timer.start_new(0.2, function()
		pcall(function()
			local g = screen.primary.geometry
			control_center.y = g.y + g.height - control_center.height - beautiful.useless_gap * 5
			if control_center.visible then
				control_center.x = g.x + g.width - (beautiful.control_center_width + dpi(25))
			end
		end)
		return false
	end)
end)

control_center_show = function()
	local target = screen.primary.geometry.width - (beautiful.control_center_width + dpi(25))
	control_center_status = false
	cc_hold_input()
	awesome.emit_signal("panel::visible", "control-center", true)
	if control_center.visible then
		slide:set(target)
	else
		-- first it gets mapped off-screen (all the widgets are drawn) and
		-- only then does it slide: the stutter doesn't land on the first frames
		control_center.x = screen.primary.geometry.width
		control_center.visible = true
		gears.timer.start_new(0.08, function()
			if not control_center_status then
				slide:set(target)
			end
			return false
		end)
	end
end

control_center_hide = function()
	cc_hold_input()
	slide:set(screen.primary.geometry.width)
	control_center_status = true
	awesome.emit_signal("panel::visible", "control-center", false)
end

control_center_toggle = function()
	if control_center.visible then
		control_center_hide()
	else
		control_center_show()
	end
end

control_center:setup({
	{
		{
			layout = wibox.layout.align.vertical,
			expand = "none",
			{
				user_profile,
				control_center_row_two,
				control_center_row_three,
				control_center_row_four,
				arc_container,
				spacing = dpi(12),
				layout = wibox.layout.fixed.vertical,
			},
		},
		margins = dpi(16),
		widget = wibox.container.margin,
	},
	bg = beautiful.control_center_bg,
	shape = helpers.rrect(beautiful.control_center_radius),
	widget = wibox.container.background,
})
