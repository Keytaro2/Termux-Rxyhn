-- Provides:
-- signal::todo
--      total (integer)
--      done (integer)
--      undone (integer)
--
-- Directly reads a todo.txt file (todo.txt format: finished lines
-- start w/ "x "). Path: $TODO_PATH or ~/.todo/todo.txt. Doesn't need the
-- `todo` program or inotify-tools: it gets re-read every 5s.
local gears = require("gears")

local todo_file_path = os.getenv("TODO_PATH") or ((os.getenv("HOME") or "") .. "/.todo/todo.txt")

local function emit_todo_info()
	local done, undone = 0, 0
	local f = io.open(todo_file_path, "r")
	if f then
		for line in f:lines() do
			if line:match("%S") then
				if line:match("^x ") then
					done = done + 1
				else
					undone = undone + 1
				end
			end
		end
		f:close()
	end
	awesome.emit_signal("signal::todo", done + undone, done, undone)
end

gears.timer({
	timeout = 5,
	autostart = true,
	call_now = true,
	callback = emit_todo_info,
})
