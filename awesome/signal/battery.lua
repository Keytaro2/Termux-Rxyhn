-- Provides:
-- signal::battery
--      percentage (integer)
-- signal::charger
--      plugged (boolean)
--
-- Termux: Android doesn't let you read /sys/class/power_supply, so we use
-- `termux-battery-status` (termux-api package + Termux:API app). If it's not
-- installed, /sys is tried and, if that fails too, nothing is emitted (the
-- battery widgets stay in their initial state).
local awful = require("awful")

local update_interval = 60

local battery_script = [[
sh -c '
if command -v termux-battery-status >/dev/null 2>&1; then
  timeout 6 termux-battery-status 2>/dev/null
elif [ -r /sys/class/power_supply/battery/capacity ]; then
  echo "\"percentage\": $(cat /sys/class/power_supply/battery/capacity)"
  echo "\"status\": \"$(cat /sys/class/power_supply/battery/status)\""
fi
']]

awful.widget.watch(battery_script, update_interval, function(_, stdout)
	local pct = tonumber(stdout:match('"percentage"%s*:%s*(%d+)'))
	if not pct then
		return
	end
	local status = (stdout:match('"status"%s*:%s*"([%w_ ]+)"') or ""):upper()
	awesome.emit_signal("signal::battery", pct)
	awesome.emit_signal("signal::charger", status == "CHARGING" or status == "FULL")
end)
