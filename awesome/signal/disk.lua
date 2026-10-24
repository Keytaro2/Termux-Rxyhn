-- Provides:
-- signal::disk
--      used (integer - giga bytes)
--      total (integer - giga bytes)
--
-- Measures the storage where your Termux $HOME lives.
local awful = require("awful")

local update_interval = 180 -- every 3 minutes

local disk_script = [[
sh -c "df -B1M \"$HOME\" 2>/dev/null | tail -1 | awk '{printf \"%d@%d\", \$4, \$3}'"
]]

awful.widget.watch(disk_script, update_interval, function(_, stdout)
	local available = tonumber(stdout:match("^(%d+)@"))
	local used = tonumber(stdout:match("@(%d+)$"))
	if not available or not used then
		return
	end
	available, used = available / 1000, used / 1000
	awesome.emit_signal("signal::disk", used, used + available)
end)
