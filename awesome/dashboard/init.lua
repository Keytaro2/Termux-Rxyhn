-- VERSION: rxyhn-widgets-v1 (if you don't see this line, the file is the old one)
-- dashboard/init.lua
-- Floating panel that slides in next to the bar when toggle() is called (the
-- icon at the top of the bar calls it, or Mod4+Shift+D). The PANEL and its
-- rubato animation are the ones from your previous zip, unchanged; what
-- changed is the CONTENT: now it's rxyhn's original widgets
-- (ui/dashboard/*.lua: profile, stats, date, todo, weather, music,
-- mediakeys, notifs), hooked up to the signals in signal/*.lua.
--
-- rubato: lib/rubato is a shortcut to module/rubato (already included).

local wibox     = require("wibox")
local gears     = require("gears")
local beautiful = require("beautiful")
-- rubato is optional: if it's not in ~/.config/awesome/lib/rubato the
-- dashboard still starts, it just pops in/out instantly instead
-- of sliding. To install it:
--   git clone https://github.com/andOrlando/rubato.git ~/.config/awesome/lib/rubato
local rubato_ok, rubato = pcall(require, "lib.rubato")
if not rubato_ok then
  pcall(function()
    require("naughty").notification {
      title   = "Dashboard",
      message = "Couldn't find lib.rubato, the panel won't animate.",
    }
  end)
end

local helpers   = require("helpers")

-- rxyhn's original widgets
local profile = require("ui.dashboard.profile")
local music   = require("ui.dashboard.music")
local media   = require("ui.dashboard.mediakeys")
local date    = require("ui.dashboard.date")
local todo    = require("ui.dashboard.todo")
local weather = require("ui.dashboard.weather")
local stats   = require("ui.dashboard.stats")
local notifs  = require("ui.dashboard.notifs")

local M = {}

-- Helper: each card goes in a box w/ a background and margins (same as rxyhn)
local function create_boxed_widget(widget_to_be_boxed, width, height, bg_color)
  local box_container = wibox.container.background()
  box_container.bg = bg_color
  box_container.forced_height = height
  box_container.forced_width = width
  box_container.shape = helpers.rrect(dpi(5))

  local outer = wibox.widget({
    {
      {
        widget_to_be_boxed,
        top = dpi(9), bottom = dpi(9), left = dpi(10), right = dpi(10),
        widget = wibox.container.margin,
      },
      widget = box_container,
    },
    margins = dpi(10),
    color = "#FF000000",
    widget = wibox.container.margin,
  })
  return outer, box_container
end

-- Builds the panel's inner content (same measurements as the
-- original rxyhn dashboard). panel_height lets the notifications card
-- fill whatever height is left.
local function build_content(panel_height)
  local date_boxed    = create_boxed_widget(date,    dpi(120), dpi(58),  beautiful.dashboard_box_bg)
  local todo_boxed    = create_boxed_widget(todo,    dpi(120), dpi(120), beautiful.dashboard_box_bg)
  local weather_boxed = create_boxed_widget(weather, dpi(120), dpi(120), beautiful.dashboard_box_bg)
  local stats_boxed   = create_boxed_widget(stats,   dpi(120), dpi(198), beautiful.dashboard_box_bg)
  local notifs_boxed, notifs_inner = create_boxed_widget(notifs, dpi(260), math.max(dpi(80), panel_height - dpi(478)), beautiful.dashboard_box_bg)

  local content = wibox.widget({
    {
      nil,
      {
        {
          {
            profile,
            stats_boxed,
            layout = wibox.layout.fixed.vertical,
          },
          {
            date_boxed,
            todo_boxed,
            weather_boxed,
            layout = wibox.layout.fixed.vertical,
          },
          layout = wibox.layout.fixed.horizontal,
        },
        {
          music,
          media,
          layout = wibox.layout.fixed.horizontal,
        },
        notifs_boxed,
        layout = wibox.layout.fixed.vertical,
      },
      expand = "none",
      layout = wibox.layout.align.horizontal,
    },
    margins = dpi(10),
    widget = wibox.container.margin,
  })
  return content, notifs_inner
end

-- opts.bar_width / opts.bar_margin: to know where the
-- bar ends and avoid overlapping it.
-- opts.gap: spacing between the bar and the dashboard.
-- opts.width: panel width.
-- opts.duration: animation duration in seconds.
-- opts.*_provider / opts.on_*: optional hooks for the widgets
-- inside (see each dashboard/widgets/*.lua).
function M.build(s, opts)
  opts = opts or {}

  -- rxyhn's bar measurements: wibar_width wide, offset from the edge by
  -- useless_gap*5 (see ui/bar/init.lua).
  local bar_margin = opts.bar_margin or (beautiful.useless_gap * 5)
  local bar_width  = opts.bar_width or beautiful.wibar_width
  local gap        = opts.gap or bar_margin
  local width      = opts.width or dpi(300)
  local radius     = opts.radius or beautiful.dashboard_radius
  local duration   = opts.duration or 0.35
  local rate       = opts.rate or 60 -- animation fps (same as notif-center)

  local geo           = s.geometry
  local panel_y        = geo.y + bar_margin
  local panel_height   = geo.height - (bar_margin * 2)

  local shown_x  = geo.x + bar_margin + bar_width + gap
  local hidden_x = geo.x - width -- off-screen, to the left

  local content, notifs_inner = build_content(panel_height)

  local box = wibox({
    screen  = s,
    type    = "dock", -- no picom shadow/fade: moves smoother
    x       = hidden_x,
    y       = panel_y,
    width   = width,
    height  = panel_height,
    visible = false,
    ontop   = true,
    -- transparent background + rounded background inside (like the
    -- notification center): no XShape on the window, moves smoother
    bg      = beautiful.transparent,
  })

  box:setup {
    content,
    bg     = beautiful.dashboard_bg,
    shape  = function(cr, w, h)
      gears.shape.rounded_rect(cr, w, h, radius)
    end,
    widget = wibox.container.background,
  }

  local open = false

  -- Clipping: on Termux:X11 the panel sometimes ends up half-painted after
  -- sliding (goes away when you move the mouse). We repaint the whole panel when
  -- it finishes opening and every time the pointer enters.
  local function force_redraw()
    gears.timer.start_new(0.05, function()
      pcall(function()
        local root = box.widget
        if root then root:emit_signal("widget::redraw_needed") end
      end)
      return false
    end)
  end
  box:connect_signal("mouse::enter", force_redraw)

  -- Android keyboard / resolution change: recalculate height, position and
  -- size of the notifications card so the panel doesn't get cut off.
  local function relayout()
    if not s.valid then return end
    local g = s.geometry
    panel_y      = g.y + bar_margin
    panel_height = g.height - (bar_margin * 2)
    shown_x      = g.x + bar_margin + bar_width + gap
    hidden_x     = g.x - width
    box.y        = panel_y
    box.height   = panel_height
    notifs_inner.forced_height = math.max(dpi(80), panel_height - dpi(478))
    box.x = open and shown_x or hidden_x
    force_redraw()
  end
  s:connect_signal("property::geometry", function()
    gears.timer.start_new(0.2, function()
      pcall(relayout)
      return false
    end)
  end)

  -- Same animation as the notification center (ui/notifs/notif-center):
  -- same rubato params (intro 0.2, duration 0.6, 60 fps, quadratic
  -- easing, awestore_compat) and same exit: once it finishes hiding
  -- the panel gets hidden entirely (visible = false) so widgets aren't redrawn
  -- off-screen.
  local toggle
  if rubato_ok then
    local last_x = hidden_x
    local anim = rubato.timed({
      pos             = hidden_x,
      rate            = rate,
      intro           = 0.1,
      duration        = duration,
      easing          = rubato.quadratic,
      awestore_compat = true,
      subscribed      = function(pos)
        -- integer x so the panel doesn't "jitter" between pixels
        local x = math.floor(pos + 0.5)
        if x ~= last_x then
          last_x = x
          box.x = x
        end
      end,
    })
    -- While the panel slides, the pointer (touch) stays still and the
    -- widgets pass underneath: each one fires mouse::enter/leave (hover,
    -- cursor, repaint) on EVERY frame and that makes the animation lag. So the
    -- panel ignores the pointer while it moves (input_passthrough) and gets it back
    -- when done. The timer is a failsafe in case "ended" never arrives.
    local function release_input()
      pcall(function() box.input_passthrough = false end)
    end
    anim.ended:subscribe(function()
      release_input()
      if not open then
        box.visible = false
      else
        force_redraw()
      end
    end)
    toggle = function()
      open = not open
      pcall(function() box.input_passthrough = true end)
      gears.timer.start_new(duration + 0.3, function() release_input(); return false end)
      -- shown_x/width are passed along so the notification center
      -- (ui/notifs/notif-center) knows where the dashboard ends and
      -- sits next to it w/o overlapping.
      awesome.emit_signal("panel::visible", "dashboard", open, shown_x, width)
      if open then
        if box.visible then
          anim:set(shown_x)
        else
          -- first the panel gets mapped and drawn (off-screen) and only
          -- then does the slide start: that way the cost of drawing all
          -- the widgets doesn't land on the first frame and there's no stutter.
          box.visible = true
          gears.timer.start_new(0.08, function()
            if open then anim:set(shown_x) end
            return false
          end)
        end
      else
        anim:set(hidden_x)
      end
    end
  else
    toggle = function()
      open = not open
      awesome.emit_signal("panel::visible", "dashboard", open, shown_x, width)
      box.visible = open
      box.x = open and shown_x or hidden_x
      if open then force_redraw() end
    end
  end

  return {
    box     = box,
    toggle  = toggle,
    refresh = {}, -- rxyhn's widgets update on their own w/ the signals from signal/
  }
end

return M
