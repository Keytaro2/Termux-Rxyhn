#!/data/data/com.termux/files/usr/bin/bash

# Kill open X11 processes
kill -9 $(pgrep -f "termux.x11") 2>/dev/null

# Enable PulseAudio over Network
pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1

# Wait for PulseAudio to respond
for i in 1 2 3 4 5 6 7 8 9 10; do
    pactl info >/dev/null 2>&1 && break
    sleep 0.5
done

# Make sure the TCP module is loaded (in case PulseAudio was already running w/o it)
pactl list short modules | grep -q module-native-protocol-tcp || \
    pactl load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1

# Unmute the sink
pactl set-sink-mute @DEFAULT_SINK@ 0

# mpd (only if it's not running)
mkdir -p "$HOME/.config/mpd/playlists"
pgrep -x mpd >/dev/null || mpd "$HOME/.config/mpd/mpd.conf" 2>>"$HOME/.config/mpd/stderr.log"

echo $XCURSOR_PATH

# Prepare termux-x11 session
export XDG_RUNTIME_DIR=${TMPDIR}
termux-x11 :0 >/dev/null &

# Wait a bit until termux-x11 gets started.
sleep 3

# Launch Termux X11 main activity
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity > /dev/null 2>&1
sleep 1

# Set audio server
export PULSE_SERVER=127.0.0.1

# Hardware Acceleration for Mali GPU (only if virglrenderer-android is installed;
# if you exported GALLIUM_DRIVER=virpipe w/o a server, GTK apps like xfce4-terminal
# die on open)
if command -v virgl_test_server_android >/dev/null 2>&1; then
    if ! pgrep -x "virgl_test_ser" > /dev/null; then
        virgl_test_server_android &
        sleep 1
    fi
    export GALLIUM_DRIVER=virpipe
    export MESA_GL_VERSION_OVERRIDE=4.0
fi

# Required configuration for Watch Music
#pkill -f '/data/data/com.termux/files/home/.config/eww/scripts/watch_music.sh'
# START THE SCRIPT AGAIN IN THE BACKGROUND
#bash /data/data/com.termux/files/home/.config/eww/scripts/watch_music.sh &

# Run awesome Desktop
env DISPLAY=:0 dbus-launch --exit-with-session awesome & > /dev/null 2>&1
exit 0
