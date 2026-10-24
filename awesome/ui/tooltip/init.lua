-- Standard awesome library
local gears = require("gears")
local awful = require("awful")

-- Theme handling library
local beautiful = require("beautiful")

-- Widget library
local wibox = require("wibox")

-- Helpers
local helpers = require("helpers")

-- Helpers
-------------

local function create_boxed_widget(widget_to_be_boxed, width, height, inner_pad)
	local box_container = wibox.container.background()
	box_container.bg = beautiful.tooltip_widget_bg
	box_container.forced_height = height
	box_container.forced_width = width
	box_container.shape = helpers.rrect(beautiful.tooltip_box_border_radius)

	local inner = dpi(0)

	if inner_pad then
		inner = beautiful.tooltip_box_margin
	end

	local boxed_widget = wibox.widget({
		-- Add margins
		{
			-- Add background color
			{
				-- The actual widget goes here
				widget_to_be_boxed,
				margins = inner,
				widget = wibox.container.margin,
			},
			widget = box_container,
		},
		margins = beautiful.tooltip_gap / 2,
		color = "#FF000000",
		widget = wibox.container.margin,
	})

	return boxed_widget
end

-- Tooltip widgets
---------------------

awful.screen.connect_for_each_screen(function(s)
	-- Battery
	-------------
	local cute_battery_face = require("ui.widgets.cute-battery-face")

	-- Date
	----------

	local date_day = wibox.widget({
		font = beautiful.font_name .. "bold " .. beautiful.fs(10),
		format = helpers.colorize_text("%A", beautiful.xforeground),
		align = "center",
		valign = "center",
		widget = wibox.widget.textclock,
	})

	local date_month = wibox.widget({
		font = beautiful.font_name .. "bold " .. beautiful.fs(14),
		format = "%d %B %Y",
		align = "center",
		valign = "center",
		widget = wibox.widget.textclock,
	})

	local date = wibox.widget({
		date_day,
		nil,
		date_month,
		layout = wibox.layout.align.vertical,
	})

	-- Separator
	---------------

	local separator = wibox.widget({
		{
			bg = beautiful.accent,
			shape = helpers.rrect(dpi(5)),
			forced_width = dpi(3),
			widget = wibox.container.background,
		},
		right = dpi(5),
		widget = wibox.container.margin,
	})

	-- Analog clock
	------------------

	local analog_clock = require("ui.widgets.analog-clock")

	-- Wifi
	----------

	local wifi_status_icon = wibox.widget({
		markup = "󰤫",
		font = beautiful.icon_font_name .. "14",
		valign = "center",
		align = "center",
		widget = wibox.widget.textbox,
	})

	local wifi = wibox.widget({
		wifi_status_icon,
		forced_width = dpi(30),
		forced_height = dpi(30),
		bg = beautiful.tooltip_bg,
		shape = gears.shape.circle,
		widget = wibox.container.background,
	})

	local wifi_status = false

	awesome.connect_signal("signal::network", function(status, ssid)
		wifi_status = status
		awesome.emit_signal("widget::network")
	end)

	awesome.connect_signal("widget::network", function()
		local w, fill_color
		if wifi_status == true then
			w = "󰤨"
			fill_color = beautiful.xcolor2
		else
			w = "󰤭"
			fill_color = beautiful.xcolor1
		end

		wifi.shape_border_color = fill_color
		wifi_status_icon.markup = helpers.colorize_text(w, fill_color)
	end)

	-- UpTime
	------------

	local uptime_label = wibox.widget({
		font = beautiful.font_name .. "medium " .. beautiful.fs(9),
		markup = helpers.colorize_text("Uptime", beautiful.accent),
		valign = "center",
		widget = wibox.widget.textbox,
	})

	local uptime_text = wibox.widget({
		font = beautiful.font_name .. "bold " .. beautiful.fs(13),
		markup = helpers.colorize_text("-", beautiful.accent),
		valign = "center",
		widget = wibox.widget.textbox,
	})

	local function set_uptime(value)
		value = tostring(value or "")
		if value == "" then
			value = "0m"
		end
		uptime_text.markup = helpers.colorize_text(value, beautiful.xforeground or beautiful.fg_normal or "#ffffff")
	end

	awesome.connect_signal("signal::uptime", set_uptime)
	s.set_uptime_text = set_uptime

	local uptime_container = wibox.widget({
		separator,
		{
			{
				uptime_label,
				uptime_text,
				spacing = dpi(2),
				layout = wibox.layout.fixed.vertical,
			},
			valign = "center",
			widget = wibox.container.place,
		},
		{
			wifi,
			valign = "center",
			widget = wibox.container.place,
		},
		layout = wibox.layout.align.horizontal,
	})

	-- Widget
	------------

	-- free height: w/ font_scale > 1 the letters no longer fit in a fixed height of 50
	local uptime_boxed = create_boxed_widget(uptime_container, dpi(170), nil, true)
	local analog_clock_boxed = create_boxed_widget(analog_clock, dpi(110), dpi(110), true)

	-- Tooltip setup
	-------------------

	s.stats_tooltip = wibox({
		type = "dock",
		screen = s,
		height = beautiful.tooltip_height,
		width = beautiful.tooltip_width,
		bg = beautiful.transparent,
		ontop = true,
		visible = false,
	})

	local function place_tooltip()
		awful.placement.bottom_left(s.stats_tooltip, {
			margins = {
				left = beautiful.wibar_width + dpi(50),
				bottom = dpi(30),
			},
		})
	end
	place_tooltip()

	-- The window height is measured based on the content (before it was fixed, from the
	-- original theme, and w/ bigger letters it cut off the Uptime row).
	function s.fit_stats_tooltip()
		-- uptime refreshes every time the popup opens
		pcall(function()
			local up = require("signal.uptime")
			set_uptime(up.value())
			up.refresh()
		end)
		local ok, h = pcall(function()
			local w = s.stats_tooltip.widget
			local _, fh = wibox.widget.base.fit_widget(
				w,
				{ dpi = beautiful.xresources.get_dpi(s) },
				w,
				s.stats_tooltip.width,
				10000
			)
			return fh
		end)
		if ok and h and h > 0 then
			s.stats_tooltip.height = math.ceil(h)
		else
			-- if it couldn't be measured, we leave some slack so the Uptime row doesn't get cut off
			s.stats_tooltip.height = beautiful.tooltip_height + dpi(60)
			pcall(function()
				local f = io.open(os.getenv("HOME") .. "/.cache/awesome-tooltip-error.log", "a")
				if f then
					f:write(os.date("%c") .. " fit_stats_tooltip: " .. tostring(h) .. "\n")
					f:close()
				end
			end)
		end
		place_tooltip()
	end

	s.stats_tooltip:setup({
		{
			{
				{
					{
						date,
						{
							analog_clock_boxed,
							nil,
							cute_battery_face,
							expand = "none",
							layout = wibox.layout.fixed.horizontal,
						},
						layout = wibox.layout.fixed.vertical,
					},
					layout = wibox.layout.fixed.horizontal,
				},
				{
					uptime_boxed,
					layout = wibox.layout.fixed.horizontal,
				},
				layout = wibox.layout.fixed.vertical,
			},
			margins = beautiful.tooltip_gap,
			widget = wibox.container.margin,
		},
		shape = helpers.rrect(beautiful.tooltip_border_radius),
		bg = beautiful.tooltip_bg,
		widget = wibox.container.background,
	})
end)

function tooltip_toggle()
	local s = awful.screen.focused()
	if not s.stats_tooltip.visible and s.fit_stats_tooltip then
		s.fit_stats_tooltip()
	end
	s.stats_tooltip.visible = not s.stats_tooltip.visible
end
