-- Notification Center bell: turns "Do Not Disturb" on / off
-- (same state as the DND button in the control center).
local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")
local dpi = beautiful.xresources.apply_dpi
local clickable_container = require("ui.widgets.clickable-container")
local icon_dir = gears.filesystem.get_configuration_dir() .. "ui/widgets/dont-disturb/icons/"

local bell_icon = wibox.widget({
	image = gears.color.recolor_image(icon_dir .. "notify.svg", beautiful.xforeground),
	resize = true,
	forced_height = dpi(20),
	forced_width = dpi(20),
	widget = wibox.widget.imagebox,
})

local bell_button = wibox.widget({
	{
		bell_icon,
		margins = dpi(7),
		widget = wibox.container.margin,
	},
	widget = clickable_container,
})

local bell_bg = wibox.widget({
	bell_button,
	bg = beautiful.notif_center_notifs_bg,
	shape = gears.shape.circle,
	widget = wibox.container.background,
})

local function update(state)
	if state then
		bell_bg.bg = beautiful.accent
		bell_icon.image = gears.color.recolor_image(icon_dir .. "dont-disturb.svg", beautiful.xforeground)
	else
		bell_bg.bg = beautiful.notif_center_notifs_bg
		bell_icon.image = gears.color.recolor_image(icon_dir .. "notify.svg", beautiful.xforeground)
	end
end

awesome.connect_signal("dnd::changed", update)
update(_G.dont_disturb_state)

bell_button:buttons(gears.table.join(awful.button({}, 1, nil, function()
	awesome.emit_signal("dnd::toggle")
end)))

return wibox.widget({
	nil,
	bell_bg,
	nil,
	expand = "none",
	layout = wibox.layout.align.vertical,
})
