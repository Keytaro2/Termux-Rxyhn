#!/data/data/com.termux/files/usr/bin/sh
# Starts Termux:X11 + awesome.   Usage:  sh ~/start-awesome.sh
# (install it w/ install.sh; after that you can set up an alias:
#   echo "alias rice='sh ~/start-awesome.sh'" >> ~/.bashrc )

export PATH="$HOME/.local/bin:$PATH"
export DISPLAY=:0
export XDG_RUNTIME_DIR="${TMPDIR:-${PREFIX:-/data/data/com.termux/files/usr}/tmp}"
SOCKET_DIR="${PREFIX:-/data/data/com.termux/files/usr}/tmp/.X11-unix"

# clean up old sessions
pkill -x awesome 2>/dev/null
pkill -f '[c]om.termux.x11.CmdEntryPoint' 2>/dev/null
sleep 0.5

# keep Android from putting the process to sleep while you use the desktop
command -v termux-wake-lock >/dev/null 2>&1 && termux-wake-lock

# X server
termux-x11 :0 >/dev/null 2>&1 &
i=0
while [ ! -S "$SOCKET_DIR/X0" ] && [ "$i" -lt 40 ]; do sleep 0.25; i=$((i + 1)); done

# bring the Termux:X11 app to the front
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1

# colors/dpi for the theme (awesome's autostart does it too)
command -v xrdb >/dev/null 2>&1 && [ -f "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources"

# awesome (w/ a session bus if dbus is there: notifications use it)
if command -v dbus-launch >/dev/null 2>&1; then
  exec dbus-launch --exit-with-session awesome
else
  exec awesome
fi
