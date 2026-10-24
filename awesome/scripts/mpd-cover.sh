#!/data/data/com.termux/files/usr/bin/sh
# mpd-cover.sh <file>   (the relative path mpd shows, e.g.: "Artist/song.mp3")
#
# Prints the path of a cover (jpg/png) for that song, or prints nothing.
# Used by signal/playerctl_termux (MPD doesn't provide covers by itself). Looks, in order:
#   1. cache               ~/.cache/awesome-covers
#   2. embedded image      mpc readpicture   (mp3/flac/m4a w/ a cover inside)
#   3. album cover.jpg     mpc albumart      (cover.jpg/png next to the song)
#   4. cover/folder/front/album .jpg/.png in the music folder
#   5. ffmpeg (optional)   pulls the embedded cover if mpc couldn't
# If there's no cover anywhere, the widget keeps the default logo.

uri="$1"
[ -n "$uri" ] || exit 0

cache="${XDG_CACHE_HOME:-$HOME/.cache}/awesome-covers"
mkdir -p "$cache" 2>/dev/null || exit 0

key="$(printf '%s' "$uri" | md5sum | cut -d' ' -f1)"
out="$cache/$key.jpg"      # extension doesn't matter: GdkPixbuf looks at the content
none="$cache/$key.none"    # "already looked, no cover"
tmp="$cache/$key.tmp.$$"
trap 'rm -f "$tmp" "$tmp.jpg"' EXIT

if [ -s "$out" ]; then printf '%s\n' "$out"; exit 0; fi
[ -e "$none" ] && exit 0

# jpg / png / gif (by the first bytes, not the extension)
is_image() {
  case "$(head -c 4 "$1" 2>/dev/null | od -An -tx1 | tr -d ' \n')" in
    ffd8ff*|89504e47|47494638) return 0 ;;
  esac
  return 1
}

# try <command...>: runs the command, saves its output in $tmp and says whether it's an image
try() {
  : > "$tmp"
  "$@" > "$tmp" 2>/dev/null
  [ -s "$tmp" ] && is_image "$tmp"
}

found=0

if command -v mpc >/dev/null 2>&1; then
  if try timeout 5 mpc readpicture "$uri"; then
    found=1
  elif try timeout 5 mpc albumart "$uri"; then
    found=1
  fi
fi

if [ "$found" = 0 ]; then
  conf="$HOME/.config/mpd/mpd.conf"
  mdir=""
  [ -f "$conf" ] && mdir="$(grep -m1 '^[[:space:]]*music_directory' "$conf" | sed 's/^[^"]*"\(.*\)".*/\1/')"
  case "$mdir" in "~"*) mdir="$HOME${mdir#\~}" ;; esac
  [ -n "$mdir" ] || mdir="$HOME/storage/music"

  song="$mdir/$uri"
  if [ -f "$song" ]; then
    d="$(dirname "$song")"
    for n in cover folder front album Cover Folder Front Album; do
      for e in jpg jpeg png; do
        if [ -f "$d/$n.$e" ] && is_image "$d/$n.$e" && cp "$d/$n.$e" "$tmp"; then
          found=1
          break 2
        fi
      done
    done

    if [ "$found" = 0 ] && command -v ffmpeg >/dev/null 2>&1; then
      rm -f "$tmp.jpg"
      timeout 8 ffmpeg -nostdin -loglevel error -y -i "$song" -an -frames:v 1 "$tmp.jpg" >/dev/null 2>&1
      if [ -s "$tmp.jpg" ] && is_image "$tmp.jpg"; then
        mv -f "$tmp.jpg" "$tmp"
        found=1
      fi
    fi
  fi
fi

if [ "$found" = 1 ]; then
  mv -f "$tmp" "$out" || exit 0
  # don't let the cache grow unbounded (~300 covers)
  ls -t "$cache"/*.jpg 2>/dev/null | tail -n +301 | while read -r old; do rm -f "$old"; done
  printf '%s\n' "$out"
else
  # only remember "no cover" if mpd was responding (otherwise, retry next time)
  if command -v mpc >/dev/null 2>&1 && timeout 3 mpc -q status >/dev/null 2>&1; then
    : > "$none"
  fi
fi
exit 0
