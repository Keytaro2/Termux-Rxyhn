-- Standard awesome library
local gears = require("gears")
local awful = require("awful")

-- Theme handling library
local beautiful = require("beautiful")

-- Notification handling library
local naughty = require("naughty")

-- Ruled
local ruled = require("ruled")

-- Helpers
local helpers = require("helpers")

-- Get screen geometry
local screen_width = awful.screen.focused().geometry.width
local screen_height = awful.screen.focused().geometry.height

ruled.client.connect_signal("request::rules", function()
	-- Global
	ruled.client.append_rule({
		id = "global",
		rule = {},
		properties = {
			focus = awful.client.focus.filter,
			raise = true,
			size_hints_honor = false,
			screen = awful.screen.preferred,
			titlebars_enabled = beautiful.titlebar_enabled,
			placement = awful.placement.no_overlap + awful.placement.no_offscreen,
		},
	})

	-- Tasklist order
	ruled.client.append_rule({
		id = "tasklist_order",
		rule = {},
		properties = {},
		callback = awful.client.setslave,
	})

	-- Titlebar rules
	ruled.client.append_rule({
		id = "titlebars",
		rule_any = {
			class = {
				"discord",
				"Spotify",
				"Org.gnome.Nautilus",
			},
			type = {
				"splash",
			},
			name = {
				"^discord.com is sharing your screen.$", -- Discord (running in browser) screen sharing popup
			},
		},
		properties = {
			titlebars_enabled = false,
		},
	})

	-- Float
	ruled.client.append_rule({
		id = "floating",
		rule_any = {
			instance = {
				"Devtools", -- Firefox devtools
			},
			class = {
				"Lxappearance",
				"Nm-connection-editor",
			},
			name = {
				"Event Tester", -- xev
			},
			role = {
				"AlarmWindow",
				"pop-up",
				"GtkFileChooserDialog",
				"conversation",
			},
			type = {
				"dialog",
			},
		},
		properties = { floating = true, placement = helpers.centered_client_placement },
	})

	-- Centered
	ruled.client.append_rule({
		id = "centered",
		rule_any = {
			type = {
				"dialog",
			},
			class = {
				-- "discord",
			},
			role = {
				"GtkFileChooserDialog",
				"conversation",
			},
		},
		properties = { placement = helpers.centered_client_placement },
	})

	-- Apps that open as a floating window, centered (not fullscreen)
	ruled.client.append_rule({
		id = "floating_apps",
		rule_any = {
			class = {
				"Xfce4-terminal",
				"xfce4-terminal",
				"Thunar",
				"thunar",
				"Audacious",
				"audacious",
				"firefox",
				"Firefox",
				"firefox-esr",
			},
			instance = {
				"xfce4-terminal",
				"thunar",
				"audacious",
				"Navigator",
			},
		},
		properties = { floating = true },
		callback = function(c)
			local wa = c.screen.workarea
			c.maximized = false
			c.fullscreen = false
			-- The terminal has its own size (the one from the screenshot: ~32% x 53% of the area).
			-- It gets applied again a split second later because xfce4-terminal
			-- resizes itself on open and left the window off-center.
			local is_term = string.find(string.lower(c.class or ""), "xfce4%-terminal") ~= nil
			local w_ratio, h_ratio = 0.62, 0.72
			if is_term then
				w_ratio, h_ratio = 0.32, 0.53
				c.size_hints_honor = false
			end
			local function fit()
				if not c.valid then return end
				local wa2 = c.screen.workarea
				c:geometry({
					width = math.floor(wa2.width * w_ratio),
					height = math.floor(wa2.height * h_ratio),
				})
				awful.placement.centered(c, { honor_padding = true, honor_workarea = true })
			end
			fit()
			if is_term then
				gears.timer.start_new(0.25, function() fit() return false end)
			end
		end,
	})

	-- Music clients (usually a terminal running ncmpcpp)
	-- This window's size is defined in ui/decorations/music.lua
	-- (music_win_width / music_win_height), already counting its bars.
	ruled.client.append_rule({
		rule_any = {
			class = {
				"music",
			},
			instance = {
				"music",
			},
		},
		properties = {
			floating = true,
			placement = helpers.centered_client_placement,
		},
	})

	-- Image viewers
	ruled.client.append_rule({
		rule_any = {
			class = {
				"feh",
				"imv",
			},
		},
		properties = {
			floating = true,
			width = screen_width * 0.7,
			height = screen_height * 0.75,
		},
		callback = function(c)
			awful.placement.centered(c, { honor_padding = true, honor_workarea = true })
		end,
	})

	-- Mpv
	ruled.client.append_rule({
		rule = { class = "mpv" },
		properties = {},
		callback = function(c)
			-- make it floating, ontop and move it out of the way if the current tag is maximized
			if awful.layout.get(awful.screen.focused()) == awful.layout.suit.floating then
				c.floating = true
				c.ontop = true
				c.width = screen_width * 0.30
				c.height = screen_height * 0.35
				awful.placement.bottom_right(c, {
					honor_padding = true,
					honor_workarea = true,
					margins = { bottom = beautiful.useless_gap * 2, right = beautiful.useless_gap * 2 },
				})
				awful.titlebar.hide(c, beautiful.titlebar_pos)
			end

			-- restore `ontop` after fullscreen is disabled
			c:connect_signal("property::fullscreen", function()
				if not c.fullscreen then
					c.ontop = true
				end
			end)
		end,
	})
end)
