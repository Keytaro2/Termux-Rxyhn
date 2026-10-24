local awful = require("awful")
local watch = awful.widget.watch
local wibox = require("wibox")
local beautiful = require("beautiful")
local xresources = require("beautiful.xresources")
local dpi = xresources.apply_dpi

local active_color = beautiful.accent

local temp_arc = wibox.widget({
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

local max_temp = 80

-- Android blocks almost all of /sys for Termux. Tried, in order:
--   1) /sys/class/thermal/thermal_zone*/temp  (if readable)
--   2) /sys/class/power_supply/battery/temp   (tenths of a degree)
--   3) termux-battery-status                  (needs the Termux:API app)
-- Prints whole degrees, or nothing if there's no source.
local temp_script = [[
for f in /sys/class/thermal/thermal_zone*/temp; do
  [ -r "$f" ] || continue
  v=$(cat "$f" 2>/dev/null)
  case "$v" in ''|*[!0-9]*) continue ;; esac
  [ "$v" -gt 0 ] || continue
  if [ "$v" -gt 1000 ]; then echo $((v / 1000)); else echo "$v"; fi
  exit 0
done
if [ -r /sys/class/power_supply/battery/temp ]; then
  v=$(cat /sys/class/power_supply/battery/temp 2>/dev/null)
  case "$v" in ''|*[!0-9]*) ;; *) echo $((v / 10)); exit 0 ;; esac
fi
if command -v termux-battery-status >/dev/null 2>&1; then
  termux-battery-status 2>/dev/null | sed -n 's/.*"temperature": *\([0-9]*\).*/\1/p' | head -n 1
fi
]]

watch({ "sh", "-c", temp_script }, 10, function(_, stdout)
	local temp = tonumber(stdout:match("%d+"))
	if temp then
		temp_arc:set_value(math.min(100, temp / max_temp * 100))
	else
		temp_arc:set_value(0)
	end
	collectgarbage("collect")
end)

return temp_arc
