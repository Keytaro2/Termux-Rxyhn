#!/data/data/com.termux/files/usr/bin/bash
# music.sh - music window (ncmpcpp + decoration from ui/decorations/music.lua)
# Called by the menu (right click > Music) and rc.lua (music_client).
#
#   1. fixes whatever usually keeps it from opening: pulseaudio, missing music
#      folder, visualizer fifo output, mpd being off
#   2. focuses the window if it's already open; otherwise, opens a terminal w/
#      class/instance "music" running ncmpcpp
#   3. if ncmpcpp fails, the window does NOT close: it shows the error and the mpd log
#
# Force a terminal:  MUSIC_TERM=xterm sh ~/.config/awesome/scripts/music.sh

SELF="$(readlink -f "$0" 2>/dev/null || echo "$0")"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
MPD_CONF="$HOME/.config/mpd/mpd.conf"
NC_CONF="$HOME/.config/ncmpcpp/config"
FIFO="$PREFIX/tmp/mpd.fifo"

# ---- window mode: what runs INSIDE the terminal --------------------
if [ "$1" = "--run" ]; then
  ncmpcpp && exit 0
  {
    echo "== pgrep mpd =="; pgrep -a mpd || echo "mpd is NOT running"
    echo "== mpc status =="; mpc status 2>&1 | head -n 3
    echo "== mpd error (stderr.log) =="; tail -n 12 "$HOME/.config/mpd/stderr.log" 2>/dev/null || echo "(empty)"
    echo "== mpd log =="; tail -n 8 "$HOME/.config/mpd/log" 2>/dev/null || echo "(empty)"
    echo "== ncmpcpp says =="
    TERM=dumb timeout 3 ncmpcpp </dev/null 2>&1 | tr -d '\000-\010\013-\037' | grep -a -i "error\|unknown\|refused\|invalid" | head -n 5
  } > "$HOME/music-debug.txt" 2>&1
  cat "$HOME/music-debug.txt"
  echo
  echo "(saved in ~/music-debug.txt)"
  printf "Press Enter to close... "
  read -r _
  exit 1
fi

mkdir -p "$PREFIX/tmp" "$HOME/.config/mpd/playlists" "$HOME/.config/ncmpcpp"
RESTART_MPD=0

# ---- audio ---------------------------------------------------------------
if command -v pulseaudio >/dev/null 2>&1; then
  pulseaudio --check 2>/dev/null || pulseaudio --start --exit-idle-time=-1 >/dev/null 2>&1
fi

# ---- mpd.conf ------------------------------------------------------------
if [ ! -f "$MPD_CONF" ]; then
  cat > "$MPD_CONF" <<MPD
music_directory    "$HOME/Music"
playlist_directory "$HOME/.config/mpd/playlists"
db_file            "$HOME/.config/mpd/database"
state_file         "$HOME/.config/mpd/state"
log_file           "$HOME/.config/mpd/log"
bind_to_address    "127.0.0.1"
port               "6600"
auto_update        "yes"

audio_output {
    type        "pulse"
    name        "PulseAudio"
}
MPD
fi

# music folder: if the configured one doesn't exist (no termux-setup-storage),
# mpd refuses to start -> ~/Music gets used
mdir="$(grep -m1 '^[[:space:]]*music_directory' "$MPD_CONF" | sed 's/^[^"]*"\(.*\)".*/\1/')"
case "$mdir" in "~"*) mdir="$HOME${mdir#\~}" ;; esac

# your music in ~/storage/music (termux-setup-storage) takes priority over the
# ~/Music fallback that's used when that folder doesn't exist yet
if [ -d "$HOME/storage/music" ] && [ "$mdir" = "$HOME/Music" ]; then
  cp "$MPD_CONF" "$MPD_CONF.bak-storage"
  sed -i "s|^\([[:space:]]*music_directory[[:space:]]*\).*|\1\"$HOME/storage/music\"|" "$MPD_CONF"
  [ -f "$NC_CONF" ] && sed -i "s|^mpd_music_dir .*|mpd_music_dir     = $HOME/storage/music|" "$NC_CONF"
  mdir="$HOME/storage/music"
  RESTART_MPD=1
fi

# this mpd version on Termux doesn't recognize buffer_time and refuses to start
if grep -q 'buffer_time' "$MPD_CONF"; then
  cp "$MPD_CONF" "$MPD_CONF.bak-buffer"
  sed -i '/buffer_time/d' "$MPD_CONF"
  RESTART_MPD=1
fi

# if the configured folder doesn't exist, mpd refuses to start -> ~/Music
if [ -n "$mdir" ] && [ ! -d "$mdir" ]; then
  mkdir -p "$HOME/Music"
  cp "$MPD_CONF" "$MPD_CONF.bak-music"
  sed -i "s|^\([[:space:]]*music_directory[[:space:]]*\).*|\1\"$HOME/Music\"|" "$MPD_CONF"
  [ -f "$NC_CONF" ] && sed -i "s|^mpd_music_dir .*|mpd_music_dir     = $HOME/Music|" "$NC_CONF"
  RESTART_MPD=1
fi

# fifo output for the visualizer (valid path on Termux: /tmp doesn't exist)
if ! grep -q 'type[[:space:]]*"fifo"' "$MPD_CONF"; then
  cat >> "$MPD_CONF" <<MPD

audio_output {
    type   "fifo"
    name   "Visualizer"
    format "44100:16:2"
    path   "$FIFO"
}
MPD
  RESTART_MPD=1
else
  # extras/mpd.conf ships w/ a generic path: leave it at $PREFIX/tmp
  if grep -q '~/../usr/tmp/mpd.fifo' "$MPD_CONF"; then
    sed -i "s|~/../usr/tmp/mpd.fifo|$FIFO|" "$MPD_CONF"
    RESTART_MPD=1
  fi
fi

# ncmpcpp 0.10 doesn't know visualizer_sync_interval and refuses to start
if [ -f "$NC_CONF" ] && grep -q '^visualizer_sync_interval' "$NC_CONF"; then
  sed -i '/^visualizer_sync_interval/d' "$NC_CONF"
fi
# any other unknown option that ncmpcpp reports when reading the config
if [ -f "$NC_CONF" ] && command -v ncmpcpp >/dev/null 2>&1; then
  for o in $(TERM=dumb timeout 3 ncmpcpp </dev/null 2>&1 | tr -d '\000-\010\013-\037' \
             | grep -a '^Unknown option: ' | sed 's/^Unknown option: //' | sort -u); do
    sed -i "/^$o[[:space:]]*=/d" "$NC_CONF"
  done
fi

# ncmpcpp: read the right fifo
if [ -f "$NC_CONF" ]; then
  sed -i "s|^visualizer_data_source .*|visualizer_data_source = \"$FIFO\"|" "$NC_CONF"
fi

# ---- mpd -----------------------------------------------------------------
if [ "$RESTART_MPD" = 1 ] && pgrep -x mpd >/dev/null 2>&1; then
  mpd --kill >/dev/null 2>&1
  pkill -x mpd 2>/dev/null
  sleep 0.5
fi
if ! pgrep -x mpd >/dev/null 2>&1; then
  : > "$HOME/.config/mpd/stderr.log"
  if command -v setsid >/dev/null 2>&1; then
    setsid nohup mpd --no-daemon --stderr "$MPD_CONF" >> "$HOME/.config/mpd/stderr.log" 2>&1 < /dev/null &
  else
    nohup mpd --no-daemon --stderr "$MPD_CONF" >> "$HOME/.config/mpd/stderr.log" 2>&1 < /dev/null &
  fi
  sleep 1
fi
if command -v mpc >/dev/null 2>&1; then
  i=0
  while ! mpc -q status >/dev/null 2>&1 && [ "$i" -lt 20 ]; do sleep 0.25; i=$((i + 1)); done
  # freshly started mpd = empty queue: update the db and load the whole
  # library (w/o hitting play) so ncmpcpp and the buttons have something to play
  ( mpc -q update --wait >/dev/null 2>&1
    [ -z "$(mpc playlist 2>/dev/null | head -n 1)" ] && mpc -q add / >/dev/null 2>&1 ) >/dev/null 2>&1 &
fi

# ---- window already open? ------------------------------------------------
if command -v xdotool >/dev/null 2>&1; then
  win="$(xdotool search --classname '^music$' 2>/dev/null | head -n1)"
  [ -z "$win" ] && win="$(xdotool search --class '^[Mm]usic$' 2>/dev/null | head -n1)"
  if [ -n "$win" ]; then
    xdotool windowactivate "$win" 2>/dev/null
    exit 0
  fi
fi

# ---- terminal ------------------------------------------------------------
term="${MUSIC_TERM:-}"
if [ -z "$term" ]; then
  for t in xfce4-terminal alacritty xterm kitty; do
    command -v "$t" >/dev/null 2>&1 && { term="$t"; break; }
  done
fi

case "$term" in
  xfce4-terminal) exec xfce4-terminal --disable-server --hide-menubar --hide-scrollbar \
                    --class=music --name=music --title=Music -e "$SELF --run" ;;
  alacritty)      exec alacritty --class music,music -T Music -e "$SELF" --run ;;
  xterm)          exec xterm -name music -class Music -T Music -e "$SELF" --run ;;
  kitty)          exec kitty --class music --title Music "$SELF" --run ;;
  *) echo "Couldn't find a terminal (pkg install xfce4-terminal  or  pkg install xterm)" >&2; exit 1 ;;
esac
