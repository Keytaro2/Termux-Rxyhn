local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local beautiful = require("beautiful")
local dpi = beautiful.xresources.apply_dpi
local helpers = require("helpers")

-- Taglist
-------------

local get_taglist = function(s)
	-- Taglist buttons
	local taglist_buttons = gears.table.join(
		awful.button({}, 1, function(t)
			t:view_only()
		end),
		awful.button({ ctrl }, 1, function(t)
			if client.focus then
				client.focus:move_to_tag(t)
			end
		end),
		awful.button({}, 3, awful.tag.viewtoggle),
		awful.button({ ctrl }, 3, function(t)
			if client.focus then
				client.focus:toggle_tag(t)
			end
		end),
		awful.button({}, 4, function(t)
			awful.tag.viewnext(t.screen)
		end),
		awful.button({}, 5, function(t)
			awful.tag.viewprev(t.screen)
		end)
	)

	-- Pacman w/o the little dot: assets/pacman.png image (painted w/ the theme
	-- color). If it doesn't exist, the font icon is used like before.
	local pacman_path = gears.filesystem.get_configuration_dir() .. "assets/pacman.png"
	local pacman_surface = nil
	if gears.filesystem.file_readable(pacman_path) then
		pcall(function()
			pacman_surface = gears.color.recolor_image(pacman_path, beautiful.taglist_icon_focused)
		end)
	end
	-- image size relative to the font icon (tweak to taste)
	local PACMAN_SCALE = 0.8
	local pacman_size = dpi(16)
	pcall(function()
		local probe = wibox.widget({
			markup = "󰮯",
			font = beautiful.font_taglist,
			widget = wibox.widget.textbox,
		})
		local pw = wibox.widget.base.fit_widget(probe, { dpi = beautiful.xresources.get_dpi() }, probe, 1000, 1000)
		if pw and pw > 0 then
			pacman_size = math.floor(pw * PACMAN_SCALE + 0.5)
		end
	end)

	-- Function to update the tags
	local update_tags = function(self, tag)
		local textbox = self:get_children_by_id("index_role")[1]
		local glyph = self:get_children_by_id("glyph_role")[1]
		local img = self:get_children_by_id("pacman_role")[1]
		if tag.selected then
			textbox.markup = helpers.colorize_text("󰮯", beautiful.taglist_icon_focused)
			if pacman_surface then
				-- the font icon stays invisible (to keep the size)
				glyph.opacity = 0
				img.image = pacman_surface
			else
				glyph.opacity = 1
				img.image = nil
			end
			return
		end
		glyph.opacity = 1
		img.image = nil
		if #tag:clients() == 0 then
			textbox.markup = helpers.colorize_text("󰽢", beautiful.taglist_icon_empty)
		else
			textbox.markup = helpers.colorize_text("󰊠", beautiful.taglist_icon_occupied)
		end
	end

	local taglist = awful.widget.taglist({
		screen = s,
		filter = awful.widget.taglist.filter.all,
		style = {
			shape = helpers.rrect(beautiful.border_radius),
		},
		layout = { spacing = 0, layout = wibox.layout.fixed.vertical },
		widget_template = {
			{
				{
					{
						{
							id = "index_role",
							align = "center",
							font = beautiful.font_taglist,
							widget = wibox.widget.textbox,
						},
						id = "glyph_role",
						widget = wibox.container.background,
					},
					{
						{
							id = "pacman_role",
							resize = true,
							forced_width = pacman_size,
							forced_height = pacman_size,
							widget = wibox.widget.imagebox,
						},
						halign = "center",
						valign = "center",
						widget = wibox.container.place,
					},
					layout = wibox.layout.stack,
				},
				id = "margin_role",
				margins = {
					top = dpi(8),
					bottom = dpi(8),
					left = dpi(6),
					right = dpi(6),
				},
				widget = wibox.container.margin,
			},
			id = "background_role",
			widget = wibox.container.background,
			create_callback = function(self, c3, index, objects)
				update_tags(self, c3)
				self:connect_signal("mouse::enter", function()
					if #c3:clients() > 0 then
						awesome.emit_signal("bling::tag_preview::update", c3)
						awesome.emit_signal("bling::tag_preview::visibility", s, true)
					end
				end)
				self:connect_signal("mouse::leave", function()
					awesome.emit_signal("bling::tag_preview::visibility", s, false)
				end)
			end,
			update_callback = function(self, c3, index, objects)
				update_tags(self, c3)
			end,
		},
		buttons = taglist_buttons,
	})

	return taglist
end

return get_taglist
