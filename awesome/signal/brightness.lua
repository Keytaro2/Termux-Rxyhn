-- Provides:
-- signal::brightness
--      percentage (integer)
--
-- Android doesn't expose /sys/class/backlight to Termux, so there's usually
-- nothing to read: 100 is emitted once so the sliders start full.
-- If you ever have brightnessctl + a readable backlight, it gets used.
local awful = require("awful")
local gears = require("gears")

local brightness_script = [[
sh -c '
if command -v brightnessctl >/dev/null 2>&1; then
  brightnessctl i 2>/dev/null | grep -o "([0-9]*%)" | tr -d "(%)"
fi
']]

local function emit_brightness_info()
	awful.spawn.easy_async_with_shell(brightness_script, function(stdout)
		local value = tonumber(stdout:match("%d+")) or 100
		awesome.emit_signal("signal::brightness", math.floor(value))
	end)
end

gears.timer({
	timeout = 30,
	autostart = true,
	call_now = true,
	callback = emit_brightness_info,
})
