-- Standard Awesome Library
local awful = require("awful")
local gears = require("gears")
local hotkeys_popup = require("awful.hotkeys_popup")
local beautiful = require("beautiful")

-- ===========================================================================
-- Context menu (right click on the desktop): rxyhn's ORIGINAL awful.menu,
-- w/ the same items. 2 things got fixed w/o changing the menu:
--
--  1) Rounded corners: awful.menu draws rectangular windows and the original
--     rounding was done by picom (which doesn't run on Termux:X11). Now
--     every menu window (and its submenus) gets a rounded `shape`,
--     so it looks the same w/ or w/o picom.
--
--  2) Keyboard w/ the menu open: awful.menu grabs the whole keyboard and
--     swallowed Alt + / and the other shortcuts. Below, ONLY its grabber gets wrapped
--     so the screenshot and global shortcuts (Alt + -, etc.) work.
--
-- The highlighted (blue) item is painted by the theme: menu_bg_focus / menu_fg_focus
-- (theme.lua). The item under the pointer turns blue.
-- ===========================================================================

local RADIUS = beautiful.border_radius or dpi(12)

-- ---- Items ----
local awesomemenu = {
	{
		"Hotkeys",
		function()
			hotkeys_popup.show_help(nil, awful.screen.focused())
		end,
	},
	{
		"Manual",
		function()
			awful.spawn.with_shell(terminal .. " -e man awesome")
		end,
	},
	{
		"Edit Config",
		function()
			awful.spawn.with_shell(editor .. " " .. awesome.conffile)
		end,
	},
	{
		"Restart",
		function()
			awesome.restart()
		end,
	},
	{
		"Quit",
		function()
			awesome.quit()
		end,
	},
}

local powermenu = {
	{
		"Power OFF",
		function()
			awful.spawn.with_shell("pkill -x awesome; pkill -f '[c]om.termux.x11.CmdEntryPoint'")
		end,
	},
	{
		"Reboot",
		function()
			awful.spawn.with_shell("pkill -HUP -x awesome")
		end,
	},
	{
		"Suspend",
		function()
			lock_screen_show()
		end,
	},
	{
		"Lock Screen",
		function()
			lock_screen_show()
		end,
	},
}

mymainmenu = awful.menu({
	items = {
		{ "Terminal", function() awful.spawn.with_shell(terminal) end },
		{ "Code Editor", function() awful.spawn.with_shell(vscode) end },
		{ "File Manager", function() awful.spawn.with_shell(file_manager) end },
		{ "Web Browser", function() awful.spawn.with_shell(browser) end },
		{ "Music", function() awful.spawn.with_shell(music_client) end },
		{ "AwesomeWM", awesomemenu },
		{ "Power Menu", powermenu },
	},
})

-- ---- 1) Rounded corners ----
local rounded = setmetatable({}, { __mode = "k" })

local function round_wibox(w)
	if not w or rounded[w] then
		return
	end
	rounded[w] = true

	local busy = false
	local function apply()
		if busy then
			return
		end
		busy = true
		w.shape = function(cr, width, height)
			gears.shape.rounded_rect(cr, width, height, RADIUS)
		end
		busy = false
	end

	apply()
	-- when resized or shown, it gets recalculated w/ the current size
	w:connect_signal("property::geometry", apply)
	w:connect_signal("property::visible", apply)
end

local function round_menu(m, visited)
	visited = visited or {}
	if type(m) ~= "table" or visited[m] then
		return
	end
	visited[m] = true
	round_wibox(m.wibox)
	if type(m.items) == "table" then
		for _, item in pairs(m.items) do
			if type(item) == "table" then
				round_menu(item.child, visited)
			end
		end
	end
	if type(m.child) == "table" then
		for _, ch in pairs(m.child) do
			round_menu(ch, visited)
		end
	end
end

local function round_all()
	pcall(round_menu, mymainmenu)
end

round_all()

-- Submenus are created ONLY once the pointer hovers them (awful.menu makes them
-- lazy), so while the menu is open we keep re-checking to
-- round each submenu as soon as it shows up.
local function menu_open()
	local w = mymainmenu and mymainmenu.wibox
	if w == nil then
		return true -- can't tell: assume it's open
	end
	return w.visible and true or false
end

local round_timer
round_timer = gears.timer({
	timeout = 0.05,
	callback = function()
		round_all()
		if not menu_open() then
			round_timer:stop()
		end
	end,
})

local orig_toggle = mymainmenu.toggle
mymainmenu.toggle = function(self, ...)
	local r = orig_toggle(self, ...)
	round_all()
	if menu_open() and not round_timer.started then
		round_timer:start()
	end
	return r
end

-- ---- 2) Keyboard w/ the menu open ----
-- awful.menu grabs the ENTIRE keyboard while it's open. Here we wrap
-- ONLY the menu's grabber so that:
--   * Alt + / (or Print) takes the screenshot w/o closing the menu;
--   * any other global shortcut (Alt + -, Mod4 + ..., etc.) closes the menu
--     and runs, instead of being ignored;
--   * if the menu already closed and the keyboard is still grabbed, it lets go on its own.
-- The menu's own keys (arrows, Enter, Esc) work the same as before.
local kg = awful.keygrabber

local function is_menu_grabber(g)
	local ok, info = pcall(debug.getinfo, g, "S")
	return ok
		and type(info) == "table"
		and type(info.source) == "string"
		and info.source:find("awful/menu", 1, true) ~= nil
end

local function mods_set(mods)
	local t = {}
	if type(mods) == "table" then
		for k, v in pairs(mods) do
			local name = (type(k) == "number") and v or ((v and type(k) == "string") and k or nil)
			if name and name ~= "Mod2" and name ~= "Lock" then
				t[name] = true
			end
		end
	end
	return t
end

local function same_set(a, b)
	for k in pairs(a) do
		if not b[k] then
			return false
		end
	end
	for k in pairs(b) do
		if not a[k] then
			return false
		end
	end
	return true
end

local function is_menu_nav_key(key)
	local mk = awful.menu and awful.menu.menu_keys
	if type(mk) ~= "table" then
		return false
	end
	for _, list in pairs(mk) do
		if type(list) == "table" then
			for _, k in ipairs(list) do
				if k == key then
					return true
				end
			end
		end
	end
	return false
end

local function global_keys()
	local ok, list = pcall(function()
		if awful.keyboard and awful.keyboard.get_global_keybindings then
			return awful.keyboard.get_global_keybindings()
		end
		return root.keys()
	end)
	return (ok and type(list) == "table") and list or {}
end

local function forward_to_global_key(mod, key)
	local want = mods_set(mod)
	-- Only "bare" keys (Enter, arrows, Esc) belong to the menu. With a
	-- modifier (Ctrl + Enter, Alt + ..., etc.) it's a global shortcut.
	if next(want) == nil and is_menu_nav_key(key) then
		return false
	end
	for _, k in ipairs(global_keys()) do
		local ok, kkey, kmods = pcall(function()
			return k.key, k.modifiers
		end)
		if ok and kkey == key and same_set(mods_set(kmods), want) then
			mymainmenu:hide()
			gears.timer.delayed_call(function()
				pcall(function()
					if type(k.trigger) == "function" then
						k:trigger()
					else
						k:emit_signal("press")
					end
				end)
			end)
			return true
		end
	end
	return false
end

if kg and not rawget(_G, "__menu_kg_hook") then
	local ok_run, run = pcall(function()
		return kg.run
	end)
	local ok_stop, stop = pcall(function()
		return kg.stop
	end)

	if ok_run and type(run) == "function" then
		__menu_kg_hook = true
		-- one wrapper per grabber: that way stop(g) always finds the same one
		local wrapped = setmetatable({}, { __mode = "k" })
		local handles = setmetatable({}, { __mode = "k" })

		pcall(function()
			kg.run = function(g, ...)
				if type(g) ~= "function" or not is_menu_grabber(g) then
					return run(g, ...)
				end
				local w = wrapped[g]
				if not w then
					w = function(mod, key, event, ...)
						if not menu_open() then
							if ok_stop and type(stop) == "function" then
								pcall(stop, handles[w] or w)
							end
							return false
						end
						if event == "press" then
							if screenshot_key and screenshot_key(mod, key) then
								return true
							end
							if forward_to_global_key(mod, key) then
								return true
							end
						end
						return g(mod, key, event, ...)
					end
					wrapped[g] = w
				end
				local handle = run(w, ...)
				handles[w] = handle
				return handle
			end

			if ok_stop and type(stop) == "function" then
				kg.stop = function(g, ...)
					if type(g) == "function" and wrapped[g] then
						g = wrapped[g]
					end
					return stop(g, ...)
				end
			end
		end)
	end
end
