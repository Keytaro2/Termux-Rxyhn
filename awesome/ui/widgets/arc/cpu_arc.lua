local wibox = require("wibox")
local beautiful = require("beautiful")
local xresources = require("beautiful.xresources")
local dpi = xresources.apply_dpi

local active_color = beautiful.accent

local cpu_arc = wibox.widget({
	max_value = 100,
	value = 0,
	thickness = dpi(8),
	start_angle = 4.3,
	rounded_edge = true,
	bg = active_color .. "44",
	paddings = dpi(10),
	colors = { active_color },
	widget = wibox.container.arcchart,
})

-- Android 8+ blocks /proc/stat for Termux, so the data isn't read here:
-- it comes from signal/cpu.lua, which uses /proc/stat if possible or the
-- load average (/proc/loadavg) if not.
awesome.connect_signal("signal::cpu", function(used)
	cpu_arc:set_value(tonumber(used) or 0)
end)

return cpu_arc
