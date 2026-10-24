-- Weather from Open-Meteo (https://open-meteo.com): free, no account or API key.
--
-- Provides:
-- signal::weather
--      temperature (integer)
--      description (string)
--      icon_code (string)
local awful = require("awful")
local gears = require("gears")
local beautiful = require("beautiful")
local helpers = require("helpers")

-- Configuration (rc.lua): weather_units and, optionally, weather_lat + weather_lon.
-- W/o fixed coordinates the location is auto-detected on every update:
--   1) termux-location (Termux:API + location permission), network / last known point
--   2) by IP w/ https://ipwho.is (free, no key; sends your IP to that service)
local fixed_lat = tonumber(weather_lat)
local fixed_lon = tonumber(weather_lon)
local units = weather_units or "metric"
local update_interval = 900 -- 15 min (Open-Meteo doesn't need a key)
local retry_interval = 60 -- if it fails (no network at startup, etc.)

local sun_icon = ""
local moon_icon = ""
local dcloud_icon = ""
local ncloud_icon = ""
local cloud_icon = ""
local rain_icon = ""
local storm_icon = ""
local snow_icon = ""
local mist_icon = ""
local whatever_icon = ""

local weather_icons = {
	["01d"] = { icon = sun_icon, color = beautiful.xcolor3 },
	["01n"] = { icon = moon_icon, color = beautiful.xcolor4 },
	["02d"] = { icon = dcloud_icon, color = beautiful.xcolor3 },
	["02n"] = { icon = ncloud_icon, color = beautiful.xcolor6 },
	["03d"] = { icon = cloud_icon, color = beautiful.xforeground },
	["03n"] = { icon = cloud_icon, color = beautiful.xforeground },
	["04d"] = { icon = cloud_icon, color = beautiful.xforeground },
	["04n"] = { icon = cloud_icon, color = beautiful.xforeground },
	["09d"] = { icon = rain_icon, color = beautiful.xcolor4 },
	["09n"] = { icon = rain_icon, color = beautiful.xcolor4 },
	["10d"] = { icon = rain_icon, color = beautiful.xcolor4 },
	["10n"] = { icon = rain_icon, color = beautiful.xcolor4 },
	["11d"] = { icon = storm_icon, color = beautiful.xforeground },
	["11n"] = { icon = storm_icon, color = beautiful.xforeground },
	["13d"] = { icon = snow_icon, color = beautiful.xcolor6 },
	["13n"] = { icon = snow_icon, color = beautiful.xcolor6 },
	["40d"] = { icon = mist_icon, color = beautiful.xcolor5 },
	["40n"] = { icon = mist_icon, color = beautiful.xcolor5 },
	["50d"] = { icon = mist_icon, color = beautiful.xcolor5 },
	["50n"] = { icon = mist_icon, color = beautiful.xcolor5 },
	["_"] = { icon = whatever_icon, color = beautiful.xcolor2 },
}


-- Open-Meteo WMO codes -> description + icon code (OpenWeatherMap style)
local function wmo(code)
	if code == 0 then return "Clear sky", "01" end
	if code == 1 then return "Mainly clear", "02" end
	if code == 2 then return "Partly cloudy", "03" end
	if code == 3 then return "Overcast", "04" end
	if code == 45 or code == 48 then return "Fog", "50" end
	if code >= 51 and code <= 55 then return "Drizzle", "09" end
	if code == 56 or code == 57 then return "Freezing drizzle", "09" end
	if code >= 61 and code <= 65 then return "Rain", "10" end
	if code == 66 or code == 67 then return "Freezing rain", "10" end
	if code >= 71 and code <= 77 then return "Snow", "13" end
	if code >= 80 and code <= 82 then return "Rain showers", "09" end
	if code == 85 or code == 86 then return "Snow showers", "13" end
	if code >= 95 and code <= 99 then return "Thunderstorm", "11" end
	return "Unknown", nil
end

local function weather_cmd(lat, lon)
	local url = string.format(
		"https://api.open-meteo.com/v1/forecast?latitude=%s&longitude=%s&current=temperature_2m,weather_code,is_day&temperature_unit=%s",
		tostring(lat),
		tostring(lon),
		units == "imperial" and "fahrenheit" or "celsius"
	)
	return "curl -sf --max-time 12 '" .. url .. "'"
end

-- Location detection (prints a JSON w/ "latitude" and "longitude")
local location_cmd = [[
sh -c '
loc=""
if command -v termux-location >/dev/null 2>&1; then
  loc=$(timeout 15 termux-location -p network -r last 2>/dev/null)
  echo "$loc" | grep -q "\"latitude\"" || loc=$(timeout 25 termux-location -p network -r once 2>/dev/null)
fi
echo "$loc" | grep -q "\"latitude\"" || loc=$(curl -sf --max-time 10 https://ipwho.is/ 2>/dev/null)
echo "$loc"
']]

local last_lat, last_lon -- last known location (in case detection fails)

local function with_location(callback)
	if fixed_lat and fixed_lon then
		callback(fixed_lat, fixed_lon)
		return
	end
	awful.spawn.easy_async_with_shell(location_cmd, function(out)
		local lat = tonumber(out:match('"latitude"%s*:%s*(-?[%d%.]+)'))
		local lon = tonumber(out:match('"longitude"%s*:%s*(-?[%d%.]+)'))
		if lat and lon then
			last_lat, last_lon = lat, lon
		end
		callback(last_lat, last_lon)
	end)
end

local have_data = false
local timer

local function emit_unavailable()
	local icon = weather_icons["_"]
	awesome.emit_signal("signal::weather", 999, "Weather unavailable", helpers.colorize_text(icon.icon, icon.color))
end

local function update()
	with_location(function(lat, lon)
		if not lat or not lon then
			-- couldn't get a location (no network / no permission): retry soon
			if not have_data then
				emit_unavailable()
			end
			timer.timeout = retry_interval
			timer:again()
			return
		end
		awful.spawn.easy_async_with_shell(weather_cmd(lat, lon), function(stdout)
		local temp = tonumber(stdout:match('"temperature_2m"%s*:%s*(-?[%d%.]+)'))
		local code = tonumber(stdout:match('"weather_code"%s*:%s*(%d+)'))
		local is_day = stdout:match('"is_day"%s*:%s*(%d)') ~= "0"

		if not temp or not code then
			-- No data: show "unavailable" only if there never was any, and retry soon
			if not have_data then
				emit_unavailable()
			end
			timer.timeout = retry_interval
			timer:again()
			return
		end

		have_data = true
		local description, prefix = wmo(code)
		local entry = prefix and weather_icons[prefix .. (is_day and "d" or "n")] or weather_icons["_"]
		local temperature = math.floor(temp + 0.5)
		if temperature == 0 then
			temperature = 0 -- avoids "-0"
		end
		awesome.emit_signal(
			"signal::weather",
			temperature,
			description,
			helpers.colorize_text(entry.icon, entry.color)
		)
		timer.timeout = update_interval
		timer:again()
		end)
	end)
end

timer = gears.timer({
	timeout = update_interval,
	single_shot = true,
	callback = update,
})
update()
