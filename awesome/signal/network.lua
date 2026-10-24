-- Provides:
-- signal::network
--      status (boolean)
--      ssid (string)
--
-- Termux: uses `termux-wifi-connectioninfo` (termux-api) for the SSID. W/o
-- termux-api there's no way to know from Android, so it's assumed
-- connected so the UI doesn't show "no network".
local awful = require("awful")

local update_interval = 15
local network_script = [[
sh -c '
if command -v termux-wifi-connectioninfo >/dev/null 2>&1; then
  timeout 6 termux-wifi-connectioninfo 2>/dev/null
else
  echo "unsupported"
fi
']]

awful.widget.watch(network_script, update_interval, function(_, stdout)
	local status, ssid = true, "Android"
	if stdout:find("unsupported", 1, true) then
		-- no termux-api: assume connected
	else
		local s = stdout:match('"ssid"%s*:%s*"([^"]*)"')
		local state = stdout:match('"supplicant_state"%s*:%s*"([^"]*)"')
		if s and s ~= "" and s ~= "<unknown ssid>" and state ~= "DISCONNECTED" then
			ssid = s
		elseif state == "DISCONNECTED" or stdout:match('"ip"%s*:%s*"0.0.0.0"') then
			status, ssid = false, ""
		end
	end
	awesome.emit_signal("signal::network", status, ssid)
end)
