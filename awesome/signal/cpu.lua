-- Provides:
-- signal::cpu
--      used percentage (integer)
--
-- Android 8+ blocks /proc/stat for apps (Termux included), so:
--   1) if /proc/stat is readable -> real CPU usage (2 samples)
--   2) if not -> load average (/proc/loadavg) relative to the cores
--   3) if that fails too -> 0
local awful = require("awful")

local update_interval = 5
local cpu_script = [[
sh -c '
if head -1 /proc/stat 2>/dev/null | grep -q "^cpu "; then
  s1=$(head -1 /proc/stat); sleep 1; s2=$(head -1 /proc/stat)
  printf "%s\n%s\n" "$s1" "$s2" | awk "
    NR==1{t1=\$2+\$3+\$4+\$5+\$6+\$7+\$8; i1=\$5+\$6}
    NR==2{t2=\$2+\$3+\$4+\$5+\$6+\$7+\$8; i2=\$5+\$6;
          d=t2-t1; if (d>0) printf \"%d\", (1-(i2-i1)/d)*100; else print 0}"
elif [ -r /proc/loadavg ]; then
  n=$(nproc 2>/dev/null || echo 1)
  awk -v n="$n" "{v=\$1*100/n; if (v>100) v=100; printf \"%d\", v}" /proc/loadavg
else
  echo 0
fi
']]

awful.widget.watch(cpu_script, update_interval, function(_, stdout)
	local used = tonumber(stdout:match("%d+")) or 0
	awesome.emit_signal("signal::cpu", math.max(0, math.min(100, used)))
end)
