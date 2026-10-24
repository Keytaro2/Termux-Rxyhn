-- Provides:
-- signal::uptime
--      up (string)   e.g. "3h 14m"
--
-- Source order:
--   1) /proc/uptime (if Android lets it be read)
--   2) `uptime -p` (procps package on Termux; on Termux /proc/uptime often
--      gives "Permission denied" but uptime -p works)
--   3) time since awesome started
-- The command is launched w/o a shell (awful.spawn.easy_async), so it doesn't depend on
-- /bin/sh or awk.
local gears = require("gears")
local awful = require("awful")

local M = {}
local started = os.time()
local cached_secs = nil -- last value read from `uptime -p`
local cached_at = nil

local function read_proc_uptime()
	local f = io.open("/proc/uptime", "r")
	if not f then
		return nil
	end
	local line = f:read("*l")
	f:close()
	return line and tonumber(line:match("^(%d+)"))
end

-- "up 6 days, 10 hours, 29 minutes" -> segundos
local function parse_uptime_p(out)
	if not out or out == "" then
		return nil
	end
	local secs, found = 0, false
	local units = {
		{ "year", 31536000 },
		{ "week", 604800 },
		{ "day", 86400 },
		{ "hour", 3600 },
		{ "minute", 60 },
	}
	for _, u in ipairs(units) do
		local n = out:match("(%d+)%s+" .. u[1])
		if n then
			secs = secs + tonumber(n) * u[2]
			found = true
		end
	end
	if found then
		return secs
	end
	if out:match("up%s+%d+%s+sec") or out:match("up%s*$") then
		return 0
	end
	return nil
end

local function format(secs)
	secs = math.floor(secs)
	local d = math.floor(secs / 86400)
	local h = math.floor((secs % 86400) / 3600)
	local m = math.floor((secs % 3600) / 60)
	if d > 0 then
		return string.format("%dd %dh %dm", d, h, m)
	elseif h > 0 then
		return string.format("%dh %dm", h, m)
	end
	return string.format("%dm", m)
end

-- current value (can be requested at any time, e.g. when opening the popup)
function M.value()
	local p = read_proc_uptime()
	if p then
		return format(p)
	end
	if cached_secs then
		-- add up what happened since the last reading
		return format(cached_secs + (os.time() - cached_at))
	end
	return format(os.time() - started)
end

local function emit()
	awesome.emit_signal("signal::uptime", M.value())
end

local cmds = {
	{ "uptime", "-p" },
	{ "/data/data/com.termux/files/usr/bin/uptime", "-p" },
}

local function spawn_uptime(i)
	local cmd = cmds[i]
	if not cmd then
		return
	end
	local ok = pcall(function()
		awful.spawn.easy_async(cmd, function(stdout)
			local secs = parse_uptime_p(stdout)
			if secs then
				cached_secs = secs
				cached_at = os.time()
				emit()
			else
				spawn_uptime(i + 1)
			end
		end)
	end)
	if not ok then
		spawn_uptime(i + 1)
	end
end

-- re-reads the source (when opening the popup and every minute)
function M.refresh()
	if read_proc_uptime() then
		emit()
	else
		emit() -- show something right away
		spawn_uptime(1)
	end
end

-- delayed_call: the first emission goes AFTER rc.lua loads (signal gets
-- loaded before ui, and the popup wouldn't be listening yet)
gears.timer.delayed_call(M.refresh)

gears.timer({
	timeout = 60,
	autostart = true,
	callback = M.refresh,
})

return M
