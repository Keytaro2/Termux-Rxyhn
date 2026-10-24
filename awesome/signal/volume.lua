-- Provides:
-- signal::volume
--      percentage (integer)
--      muted (boolean, always false: termux-volume has no mute)
--      silent (boolean, true if it's just the rounding of a command we just
--              sent ourselves: the popup doesn't show)
-- Listens:
-- signal::volume::set      (percentage) -> applies the volume w/ volume.sh
-- signal::volume::refresh               -> queries the volume right now
--
-- Uses ~/.local/bin/volume.sh (termux-volume + jq; termux-api and jq packages and
-- the Termux:API app).
--
-- The phone's volume buttons change Android's volume, and
-- awesome doesn't find out on its own: that's why termux-volume gets polled every
-- `poll_interval` seconds, ALWAYS (before it was only w/ a panel open). That way the
-- popup also shows up when you turn the volume up or down from the phone.
-- termux-volume launches a Java process (kinda heavy): if you want to spend less
-- battery raise `poll_interval` (e.g. 3); if you want it to react faster,
-- lower it (1).
local awful = require("awful")
local gears = require("gears")

local poll_interval = 1.5 -- seconds between queries

local script = "bash " .. (os.getenv("HOME") or "") .. "/.local/bin/volume.sh"

local volume_old = -1
local last_set = 0
local busy = false

local function emit_volume_info()
	-- don't launch another query if the previous one hasn't finished
	if busy then
		return
	end
	busy = true
	awful.spawn.easy_async_with_shell(script .. " 2>/dev/null", function(stdout)
		busy = false
		local volume = tonumber(stdout:match("(%d+)"))
		if not volume then
			return
		end
		local since_set = os.time() - last_set
		-- right after sending a volume, termux-volume takes a while to apply it:
		-- a reading at that moment would be the old value
		if since_set < 3 then
			return
		end
		if volume ~= volume_old then
			-- if we just changed it ourselves, rounding can be off by +-3%: don't notify
			local own = since_set < 8 and volume_old >= 0 and math.abs(volume - volume_old) <= 3
			volume_old = volume
			awesome.emit_signal("signal::volume", volume, false, own)
		end
	end)
end

awesome.connect_signal("signal::volume::set", function(value)
	value = math.max(0, math.min(100, math.floor(tonumber(value) or 0)))
	volume_old = value
	last_set = os.time()
	awful.spawn.with_shell(script .. " " .. value)
	-- silent = false: when moving the volume from the control center / dashboard
	-- the popup shows up too
	awesome.emit_signal("signal::volume", value, false, false)
end)

-- Shortcuts can request an immediate update
awesome.connect_signal("signal::volume::refresh", emit_volume_info)

gears.timer({
	timeout = poll_interval,
	autostart = true,
	call_now = true,
	callback = emit_volume_info,
})
