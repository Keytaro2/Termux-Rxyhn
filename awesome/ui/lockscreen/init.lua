local awful = require("awful")
local gfs = require("gears.filesystem")

local lock_screen = {}

-- Termux has no PAM (the original .so was x86_64 and broke startup on
-- Android). The password is read from ~/.config/awesome/lockpass (first line).
-- If the file doesn't exist, the password is "awesome".
-- Change it w/:  echo 'my-password' > ~/.config/awesome/lockpass
local function read_password()
	local f = io.open(gfs.get_configuration_dir() .. "lockpass", "r")
	if f then
		local line = f:read("*l")
		f:close()
		if line and line ~= "" then
			return line
		end
	end
	return "awesome"
end

lock_screen.init = function()
	lock_screen.authenticate = function(password)
		return password == read_password()
	end
	require("ui.lockscreen.lockscreen")
end

return lock_screen
