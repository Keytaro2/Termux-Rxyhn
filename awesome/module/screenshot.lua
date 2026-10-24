-- module/screenshot.lua
-- Screenshots w/ NO external programs (no need for maim): uses
-- awesome's root.content(), which returns the image of the whole screen, and
-- saves it as PNG. Then it shows a notification w/ the screenshot (icon) and
-- Open / Delete buttons, like rxyhn's original script (screensht).
--
-- Exposes the global  screenshot_take()  (Alt+/ shortcut, Print key and the control
-- center button).
--
-- Folder: ~/storage/downloads (Android's Downloads folder; you need to have
-- run `termux-setup-storage` once). If it doesn't exist yet,
-- ~/Pictures/Screenshots is used so the screenshot isn't lost.
local awful = require("awful")
local gears = require("gears")
local naughty = require("naughty")

local function screenshot_dir()
	local home = os.getenv("HOME") or ""
	local downloads = home .. "/storage/downloads"
	if gears.filesystem.dir_readable(downloads) then
		return downloads .. "/"
	end
	return home .. "/Pictures/Screenshots/"
end

local function file_exists(path)
	local f = io.open(path, "rb")
	if f then
		f:close()
		return true
	end
	return false
end

local function notify(title, message, path)
	local actions = {}
	if path then
		local open_image = naughty.action({ name = "Open", icon_only = false })
		local delete_image = naughty.action({ name = "Delete", icon_only = false })
		open_image:connect_signal("invoked", function()
			awful.spawn.with_shell(
				"if command -v termux-open >/dev/null 2>&1; then termux-open '" .. path .. "'; " ..
				"else xdg-open '" .. path .. "'; fi"
			)
		end)
		delete_image:connect_signal("invoked", function()
			os.remove(path)
		end)
		actions = { open_image, delete_image }
	end
	naughty.notification({
		app_name = "Screenshot Tool",
		icon = path,
		timeout = 10,
		title = title,
		message = message,
		actions = actions,
	})
end

-- Saves the full screen. Returns the path or nil.
local function save_with_awesome(path)
	local ok, err = pcall(function()
		local surface = gears.surface(root.content())
		surface:write_to_png(path)
		surface:finish()
	end)
	if ok and file_exists(path) then
		return path
	end
	return nil, err
end

function screenshot_take()
	local dir = screenshot_dir()
	gears.filesystem.make_directories(dir)
	local path = dir .. os.date("screensht_%Y-%m-%d_%H-%M-%S") .. ".png"

	local saved = save_with_awesome(path)
	if not saved then
		-- Fallback: if awesome couldn't (unlikely) and maim is there, use it
		awful.spawn.easy_async_with_shell("command -v maim >/dev/null 2>&1 && maim '" .. path .. "'", function()
			if file_exists(path) then
				notify("<b>Screensht!</b>", "Screenshot saved to " .. dir, path)
			else
				notify("<b>Screensht!</b>", "Couldn't save the screenshot.", nil)
			end
		end)
		return
	end

	-- to the clipboard, if xclip is there (optional)
	awful.spawn.with_shell(
		"command -v xclip >/dev/null 2>&1 && xclip -selection clipboard -t image/png -i '" .. path .. "'"
	)
	notify("<b>Screensht!</b>", "Screenshot saved to " .. dir, path)
end

-- screenshot_key(mod, key): for screens that grab the keyboard (lockscreen,
-- power screen) and where the global shortcuts from keys.lua don't reach.
-- `mod` can be a list {"Mod1"} or a table {Mod1 = true} depending on who calls it.
-- Returns true if the key was a screenshot key (Print or Alt + /).
function screenshot_key(mod, key)
	local alt = false
	if type(mod) == "table" then
		alt = (mod.Mod1 or mod.Alt) and true or false
		if not alt then
			for _, m in ipairs(mod) do
				if m == "Mod1" or m == "Alt" then
					alt = true
				end
			end
		end
	end
	if key == "Print" or (alt and (key == "slash" or key == "/")) then
		pcall(screenshot_take)
		return true
	end
	return false
end
