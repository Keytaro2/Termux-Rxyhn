-- Standard awesome library
local awful = require("awful")
local gears = require("gears")

-- Widget library
local wibox = require("wibox")

-- Theme handling library
local beautiful = require("beautiful")

-- Rubato
local rubato = require("module.rubato")

-- Helpers
local helpers = require("helpers")
local dpi = beautiful.xresources.apply_dpi

local notif_header = wibox.widget({
	text = "Notification Center",
	font = beautiful.font_name .. "Bold " .. beautiful.fs(10),
	align = "left",
	valign = "center",
	widget = wibox.widget.textbox,
})

local clear_all = require("ui.notifs.notif-center.clear-all")
local dnd_bell = require("ui.notifs.notif-center.dnd-bell")
local notifbox_layout = require("ui.notifs.notif-center.build-notifbox").notifbox_layout

local notifs = wibox.widget({
	expand = "none",
	layout = wibox.layout.fixed.vertical,
	spacing = dpi(10),
	{
		expand = "none",
		layout = wibox.layout.align.horizontal,
		{
			notif_header,
			strategy = "max",
			width = dpi(185),
			widget = wibox.container.constraint,
		},
		nil,
		{
			{
				layout = wibox.layout.fixed.horizontal,
				spacing = dpi(5),
				dnd_bell,
				clear_all,
			},
			strategy = "min",
			width = dpi(75),
			widget = wibox.container.constraint,
		},
	},
	notifbox_layout,
})

notif_center = wibox({
	type = "dock",
	screen = screen.primary,
	height = screen.primary.geometry.height,
	width = dpi(300),
	bg = beautiful.transparent,
	ontop = true,
	visible = false,
})

awful.placement.maximize_vertically(notif_center, { honor_workarea = true, margins = beautiful.useless_gap * 5 })

-- Rubato
local slide = rubato.timed({
	pos = dpi(-300),
	rate = 60,
	intro = 0.1,
	duration = 0.35,
	easing = rubato.quadratic,
	awestore_compat = true,
	subscribed = function(pos)
		notif_center.x = pos
	end,
})

local notif_center_status = false

-- To avoid overlapping w/ the dashboard (ui/dashboard, dashboard/init.lua):
-- we find out through the "panel::visible" signal where the dashboard panel
-- ends when it's open (shown_x + width) and we shift to the
-- right of that. If the dashboard is closed, we go right where the
-- dashboard would show up (next to the bar), same as before.
local dashboard_open = false
local dashboard_shown_x = nil
local dashboard_width = nil

local function notif_center_target_x()
	local gap = beautiful.useless_gap * 5
	if dashboard_shown_x then
		if dashboard_open and dashboard_width then
			return dashboard_shown_x + dashboard_width + gap
		end
		return dashboard_shown_x
	end
	-- We don't know where the dashboard is yet (it was never opened): the usual value
	-- as a fallback.
	return dpi(100)
end

awesome.connect_signal("panel::visible", function(name, visible, shown_x, width)
	if name ~= "dashboard" then
		return
	end
	dashboard_open = visible
	if shown_x then
		dashboard_shown_x = shown_x
	end
	if width then
		dashboard_width = width
	end
	-- If the notification center is already open, reposition it live
	-- (e.g.: you open it, then open/close the dashboard).
	if notif_center.visible and not notif_center_status then
		slide:set(notif_center_target_x())
	end
end)

local function force_redraw()
	require("gears").timer.start_new(0.05, function()
		pcall(function()
			local root = notif_center.widget
			if root then
				root:emit_signal("widget::redraw_needed")
			end
		end)
		return false
	end)
end

slide.ended:subscribe(function()
	if notif_center_status then
		notif_center.visible = false
	else
		force_redraw()
	end
end)

notif_center:connect_signal("mouse::enter", force_redraw)

-- Android keyboard / resolution change: readjust height and position
screen.primary:connect_signal("property::geometry", function()
	require("gears").timer.start_new(0.2, function()
		pcall(function()
			awful.placement.maximize_vertically(notif_center, { honor_workarea = true, margins = beautiful.useless_gap * 5 })
		end)
		return false
	end)
end)

-- Make toogle button
local notif_center_show = function()
	notif_center.visible = true
	slide:set(notif_center_target_x())
	notif_center_status = false
end

local notif_center_hide = function()
	slide:set(dpi(-300))
	notif_center_status = true
end

notif_center_toggle = function()
	if notif_center.visible then
		notif_center_hide()
	else
		notif_center_show()
	end
end

notif_center:setup({
	{
		notifs,
		margins = dpi(15),
		widget = wibox.container.margin,
	},
	bg = beautiful.xbackground,
	shape = helpers.rrect(beautiful.notif_center_radius),
	widget = wibox.container.background,
})
