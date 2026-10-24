-- Provides:
-- signal::ram
--      used (integer - mega bytes)
--      total (integer - mega bytes)
--
-- Reads /proc/meminfo directly (works on Android/Termux and doesn't depend
-- on the language like `free` does).
local awful = require("awful")

local update_interval = 20
local ram_script = [[
sh -c "awk '/^MemTotal:/{t=\$2} /^MemAvailable:/{a=\$2} END{printf \"%d@@%d@\", a/1024, t/1024}' /proc/meminfo 2>/dev/null"
]]

awful.widget.watch(ram_script, update_interval, function(_, stdout)
	local available = tonumber(stdout:match("(%d+)@@"))
	local total = tonumber(stdout:match("@@(%d+)@"))
	if not available or not total or total == 0 then
		return
	end
	awesome.emit_signal("signal::ram", total - available, total)
end)
