local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local beautiful = require("beautiful")
local dpi = beautiful.xresources.apply_dpi
local helpers = require("helpers")
local cairo = require("lgi").cairo
local lock_screen = require("ui.lockscreen")
lock_screen.init()

-- Icons
local icon_font = "icomoon bold 45"
local poweroff_text_icon = ""
local reboot_text_icon = ""
local suspend_text_icon = ""
local exit_text_icon = ""
local lock_text_icon = ""

local button_bg = beautiful.xbackground
local button_size = dpi(120)

-- Resting colors (more visible than the original: the icon used to be ~33% and the
-- border same as the background, on a transparent background the buttons were barely visible)
local idle_icon = beautiful.xforeground .. "bb"
local idle_border = beautiful.xforeground .. "33"

-- Our OWN blurred background (no picom): the screen is captured before opening the
-- menu, shrunk and stretched back (that's what blurs it) and darkened. Same values
-- as the Termux-Desktop-Awesome powermenu.
local blur_div = 14 -- higher = blurrier
local dim = 0.30 -- darkening on top (0 = none, 1 = black)

local function blurred_snapshot(g)
	local ok, out = pcall(function()
		local src = gears.surface(root.content())
		local function step(img, ox, oy, k, w, h)
			local nw, nh = math.max(1, math.floor(w / k)), math.max(1, math.floor(h / k))
			local o = cairo.ImageSurface(cairo.Format.ARGB32, nw, nh)
			local cr = cairo.Context(o)
			cr:scale(nw / w, nh / h)
			cr:set_source_surface(img, -ox, -oy)
			cr:paint()
			return o
		end
		local a = step(src, g.x, g.y, 4, g.width, g.height) -- 1/4 of the screen
		local aw, ah = gears.surface.get_size(a)
		return step(a, 0, 0, blur_div / 4, aw, ah) -- and then down to 1/blur_div
	end)
	if ok then
		return out
	end
	return nil
end

-- true  = Poweroff, Reboot and Exit are visual only (they just close the widget).
-- false = Poweroff closes awesome and Termux:X11, Reboot restarts awesome and
--         Exit ends the awesome session.
-- Lock and Suspend always open the lockscreen (password, then it goes away).
local visual_only = true

-- Commands
local poweroff_command = function()
	if not visual_only then
		awful.spawn.with_shell("pkill -x awesome; pkill -f '[c]om.termux.x11.CmdEntryPoint'")
	end
	awesome.emit_signal("module::exit_screen:hide")
end

local reboot_command = function()
	if not visual_only then
		awful.spawn.with_shell("pkill -HUP -x awesome")
	end
	awesome.emit_signal("module::exit_screen:hide")
end

local suspend_command = function()
	awesome.emit_signal("module::exit_screen:hide")
	lock_screen_show()
end

local exit_command = function()
	if visual_only then
		awesome.emit_signal("module::exit_screen:hide")
	else
		awesome.quit()
	end
end

local lock_command = function()
	awesome.emit_signal("module::exit_screen:hide")
	lock_screen_show()
end

-- Helpers
local create_button = function(symbol, hover_color, text, command)
	local icon = wibox.widget({
		forced_height = button_size,
		forced_width = button_size,
		align = "center",
		valign = "center",
		font = icon_font,
		markup = helpers.colorize_text(symbol, idle_icon),
		widget = wibox.widget.textbox(),
	})

	local button = wibox.widget({
		{
			nil,
			icon,
			expand = "none",
			layout = wibox.layout.align.horizontal,
		},
		forced_height = button_size,
		forced_width = button_size,
		border_width = dpi(8),
		border_color = idle_border,
		shape = helpers.rrect(dpi(20)),
		bg = button_bg,
		widget = wibox.container.background,
	})

	button:buttons(gears.table.join(awful.button({}, 1, function()
		command()
	end)))

	button:connect_signal("mouse::enter", function()
		icon.markup = helpers.colorize_text(icon.text, hover_color)
		button.border_color = hover_color
	end)
	button:connect_signal("mouse::leave", function()
		icon.markup = helpers.colorize_text(icon.text, idle_icon)
		button.border_color = idle_border
	end)

	helpers.add_hover_cursor(button, "hand1")

	return button
end

-- Create the buttons
local poweroff = create_button(poweroff_text_icon, beautiful.xcolor1, "Poweroff", poweroff_command)
local reboot = create_button(reboot_text_icon, beautiful.xcolor2, "Reboot", reboot_command)
local suspend = create_button(suspend_text_icon, beautiful.xcolor3, "Suspend", suspend_command)
local exit = create_button(exit_text_icon, beautiful.xcolor4, "Exit", exit_command)
local lock = create_button(lock_text_icon, beautiful.xcolor5, "Lock", lock_command)

local create_exit_screen = function(s)
	s.exit_screen = wibox({
		screen = s,
		type = "splash",
		visible = false,
		ontop = true,
		bg = beautiful.darker_bg or "#0a1419",
		fg = beautiful.fg_normal,
		height = s.geometry.height,
		width = s.geometry.width,
		x = s.geometry.x,
		y = s.geometry.y,
	})

	s.exit_screen:buttons(gears.table.join(
		awful.button({}, 2, function()
			awesome.emit_signal("module::exit_screen:hide")
		end),
		awful.button({}, 3, function()
			awesome.emit_signal("module::exit_screen:hide")
		end)
	))

	s.exit_screen:setup({
		nil,
		{
			nil,
			{
				poweroff,
				reboot,
				suspend,
				exit,
				lock,
				spacing = dpi(50),
				layout = wibox.layout.fixed.horizontal,
			},
			expand = "none",
			layout = wibox.layout.align.horizontal,
		},
		expand = "none",
		layout = wibox.layout.align.vertical,
	})
end

screen.connect_signal("request::desktop_decoration", function(s)
	create_exit_screen(s)
end)

screen.connect_signal("removed", function(s)
	create_exit_screen(s)
end)

local exit_screen_grabber = awful.keygrabber({
	auto_start = true,
	stop_event = "release",
	keypressed_callback = function(self, mod, key, command)
		if screenshot_key and screenshot_key(mod, key) then
			return
		end
		if key == "s" then
			suspend_command()
		elseif key == "e" then
			exit_command()
		elseif key == "l" then
			lock_command()
		elseif key == "p" then
			poweroff_command()
		elseif key == "r" then
			reboot_command()
		elseif key == "Escape" or key == "q" or key == "x" then
			awesome.emit_signal("module::exit_screen:hide")
		end
	end,
})

awesome.connect_signal("module::exit_screen:show", function()
	for s in screen do
		s.exit_screen.visible = false
	end
	local s = awful.screen.focused()
	-- the capture happens BEFORE showing the menu, so the menu itself doesn't show up in the background
	local snap = blurred_snapshot(s.geometry)
	if snap then
		local sw, sh = gears.surface.get_size(snap)
		s.exit_screen.bgimage = function(_, cr, w, h)
			cr:save()
			cr:scale(w / sw, h / sh)
			cr:set_source_surface(snap, 0, 0)
			cr:paint()
			cr:restore()
			cr:set_source_rgba(0, 0, 0, dim)
			cr:paint()
		end
	else
		s.exit_screen.bgimage = nil
	end
	s.exit_screen.visible = true
	exit_screen_grabber:start()
end)

awesome.connect_signal("module::exit_screen:hide", function()
	exit_screen_grabber:stop()
	for s in screen do
		s.exit_screen.visible = false
	end
end)
