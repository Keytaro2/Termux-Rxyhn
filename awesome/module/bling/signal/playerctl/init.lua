local awful = require("awful")
local gtimer = require("gears.timer")
local beautiful = require("beautiful")
local naughty = require("naughty")

-- Use CLI backend as default as it is supported on most if not all systems
local backend_config = beautiful.playerctl_backend or "playerctl_cli"
local backends = {
    playerctl_cli = require(... .. ".playerctl_cli"),
    playerctl_lib = require(... .. ".playerctl_lib"),
    -- Termux: MPD via mpc (misma API, sin dbus ni GObject)
    playerctl_mpc = require(... .. ".playerctl_mpc"),
    -- Termux: Audacious (audtool) + MPD (mpc) juntos
    playerctl_termux = require(... .. ".playerctl_termux"),
}

local backend = nil

local function enable_wrapper(args)
    local open = naughty.action { name = "Open" }

    open:connect_signal("invoked", function()
        awful.spawn("xdg-open https://blingcorp.github.io/bling/#/signals/pctl")
    end)

    gtimer.delayed_call(function()
        naughty.notify({
            title = "Bling Error",
            text = "Global signals are deprecated! Please take a look at the playerctl documentation.",
            app_name = "Bling Error",
            app_icon = "system-error",
            actions = { open }
        })
    end)

    backend_config = (args and args.backend) or backend_config
    backend = backends[backend_config](args)
    return backend
end

local function disable_wrapper()
    backend:disable()
end

-- `lib` usa la libreria Playerctl de GObject si existe; si no (Termux), cae
-- al backend de Audacious + MPD para que el dashboard y los atajos sigan funcionando.
local function smart_lib(...)
    local ok, Playerctl = pcall(function() return require("lgi").Playerctl end)
    if ok and Playerctl then
        return backends.playerctl_lib(...)
    end
    return backends.playerctl_termux(...)
end

return {
    lib = smart_lib,
    mpc = backends.playerctl_mpc,
    cli = backends.playerctl_cli,
    enable = enable_wrapper,
    disable = disable_wrapper
}