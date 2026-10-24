#!/data/data/com.termux/files/usr/bin/sh
# awesome-bar-termux-49 installer: your base from zip 16 + all of rxyhn's vertical rice
# widgets, signals and scripts (AestheticArch, April 2022),
# for Termux + Termux:X11 + awesome.
#
# Usage (from the folder where you unzipped the zip):
#     sh install.sh              # installs everything
#     sh install.sh --iosevka    # also downloads the Iosevka Nerd Font (~15 MB)
#     sh install.sh --no-pkg     # doesn't touch packages (just copies files)
#
# It's safe to run multiple times: it backs up whatever it replaces.

SRC="$(cd "$(dirname "$0")" && pwd)"
CFG="$HOME/.config/awesome"
FONTS="$HOME/.local/share/fonts"
STAMP="$(date +%Y%m%d-%H%M%S)"
WITH_IOSEVKA=0
DO_PKG=1
for a in "$@"; do
  case "$a" in
    --iosevka) WITH_IOSEVKA=1 ;;
    --no-pkg) DO_PKG=0 ;;
  esac
done

say()  { printf '\033[1;35m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m  %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------- packages
if [ "$DO_PKG" = 1 ]; then
  if ! have pkg; then
    warn "Can't find 'pkg'. This is meant for Termux; skipping package install."
  else
    say "Termux X11 repository"
    pkg install -y x11-repo >/dev/null 2>&1 || warn "couldn't add x11-repo (moving on)"
    # required
    for p in awesome termux-x11-nightly xorg-xrdb fontconfig-utils xfce4-terminal xterm curl; do
      say "pkg install $p"
      pkg install -y "$p" || warn "FAILED $p  (install it by hand: pkg install $p)"
    done
    # recommended: if one doesn't exist for your architecture, it's skipped
    for p in rofi picom thunar audacious mpd mpc ncmpcpp pulseaudio dbus jq maim xclip xdotool termux-api starship virglrenderer-android; do
      say "pkg install $p (optional)"
      pkg install -y "$p" >/dev/null 2>&1 || warn "optional not available: $p"
    done
  fi
fi

# ----------------------------------------------------------------- awesome
if [ -e "$CFG" ]; then
  say "Backing up your current config -> $CFG.bak-$STAMP"
  mv "$CFG" "$CFG.bak-$STAMP"
fi
say "Copying config to $CFG"
mkdir -p "$HOME/.config"
cp -r "$SRC/awesome" "$CFG"
chmod +x "$CFG/configuration/autostart" "$CFG/theme/themes" "$CFG/scripts/music.sh" "$CFG/scripts/mpd-cover.sh" 2>/dev/null

# ------------------------------------------------------------ bin scripts
say "Scripts (screensht, xcolor-pick, volume.sh) -> ~/.local/bin"
mkdir -p "$HOME/.local/bin"
for f in screensht xcolor-pick volume.sh; do
  [ -f "$SRC/extras/bin/$f" ] && cp "$SRC/extras/bin/$f" "$HOME/.local/bin/$f" && chmod +x "$HOME/.local/bin/$f"
done

# -------------------------------------------------------------- Xresources
if [ -f "$HOME/.Xresources" ]; then
  say "Backing up ~/.Xresources -> ~/.Xresources.bak-$STAMP"
  cp "$HOME/.Xresources" "$HOME/.Xresources.bak-$STAMP"
fi
cat "$SRC/extras/.Xresources" "$SRC/extras/Xresources.extra" > "$HOME/.Xresources"

# ---------------------------------------------------------------- fonts
say "Installing fonts in $FONTS"
mkdir -p "$FONTS"
cp "$SRC"/fonts/*.ttf "$FONTS"/

fetch() { # fetch URL DEST
  curl -fL --retry 2 -o "$2" "$1" >/dev/null 2>&1 && [ -s "$2" ]
}
if ! fc-list 2>/dev/null | grep -qi "Material Design Icons Desktop"; then
  say "Downloading Material Design Icons (bar icons)"
  if fetch "https://github.com/Templarian/MaterialDesign-Font/raw/master/MaterialDesignIconsDesktop.ttf" "$FONTS/MaterialDesignIconsDesktop.ttf"; then
    :
  elif fetch "https://cdn.jsdelivr.net/npm/@mdi/font@6.9.96/fonts/materialdesignicons-webfont.ttf" "$FONTS/materialdesignicons-webfont.ttf"; then
    warn "Used the Material Design Icons webfont variant (the theme already has it as a fallback)."
  else
    rm -f "$FONTS/MaterialDesignIconsDesktop.ttf" "$FONTS/materialdesignicons-webfont.ttf"
    warn "Couldn't download Material Design Icons. W/o that font the icons show up as little boxes."
    warn "Download it by hand from https://github.com/Templarian/MaterialDesign-Font and copy it to $FONTS"
  fi
fi
if [ "$WITH_IOSEVKA" = 1 ]; then
  say "Downloading Iosevka Nerd Font"
  TMPZ="${TMPDIR:-/tmp}/Iosevka.zip"
  if fetch "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Iosevka.zip" "$TMPZ" && have unzip; then
    unzip -oq "$TMPZ" '*NerdFontMono-Regular.ttf' '*NerdFontMono-Bold.ttf' '*NerdFontMono-Medium.ttf' -d "$FONTS" 2>/dev/null
    rm -f "$TMPZ"
  else
    warn "Couldn't download/unzip Iosevka ('pkg install unzip' is needed). Using FiraCode Nerd Font."
  fi
fi
have fc-cache && fc-cache -f "$FONTS" >/dev/null 2>&1

# ------------------------------------------------- Termux font (regular app)
# The above only covers X11 apps (fontconfig). The Termux app (w/o X11) uses its
# own font in ~/.termux/font.ttf; if it's not a Nerd Font, the prompt (starship)
# icons show up as empty boxes. We match it up here.
say "Termux app font (so the prompt looks the same w/o X11)"
mkdir -p "$HOME/.termux"
[ -f "$HOME/.termux/font.ttf" ] && [ ! -f "$HOME/.termux/font.ttf.bak-$STAMP" ] && cp "$HOME/.termux/font.ttf" "$HOME/.termux/font.ttf.bak-$STAMP"
TERMUX_FONT_SRC="$SRC/fonts/FiraCode-Regular-NerdFontMono.ttf"
if [ "$WITH_IOSEVKA" = 1 ] && [ -f "$FONTS/IosevkaNerdFontMono-Regular.ttf" ]; then
  TERMUX_FONT_SRC="$FONTS/IosevkaNerdFontMono-Regular.ttf"
fi
cp "$TERMUX_FONT_SRC" "$HOME/.termux/font.ttf"
warn "Font copied. Close and reopen Termux (the app, not X11) so it picks up the new font."

# ---------------------------------------------------- rxyhn's terminal (visual)
# xfce4-terminal + starship prompt w/ rxyhn's colors/style. Visual only:
# doesn't touch zsh, aliases or anything else (it only hooks starship into the shell if it wasn't there).
say "rxyhn's terminal (xfce4-terminal + starship)"
TERMSRC="$SRC/extras/terminal"
backup_file() { # backup_file PATH  (only if it exists)
  [ -f "$1" ] && cp "$1" "$1.bak-$STAMP"
}
mkdir -p "$HOME/.config/xfce4/terminal/colorschemes" \
         "$HOME/.config/xfce4/xfconf/xfce-perchannel-xml" \
         "$HOME/.config/gtk-3.0"
for f in terminal/terminalrc \
         terminal/colorschemes/Aesthetic-Night.theme \
         xfconf/xfce-perchannel-xml/xfce4-terminal.xml; do
  backup_file "$HOME/.config/xfce4/$f"
  cp "$TERMSRC/xfce4/$f" "$HOME/.config/xfce4/$f"
done
backup_file "$HOME/.config/starship.toml"
cp "$TERMSRC/starship.toml" "$HOME/.config/starship.toml"
# gtk.css: appended at the end (w/ a backup) w/o overwriting what you already have
if ! grep -q "rxyhn-terminal" "$HOME/.config/gtk-3.0/gtk.css" 2>/dev/null; then
  backup_file "$HOME/.config/gtk-3.0/gtk.css"
  cat "$TERMSRC/gtk-3.0/gtk.css" >> "$HOME/.config/gtk-3.0/gtk.css"
fi
# starship in the prompt (bash and zsh, only once; Termux uses bash by default)
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  case "$rc" in *zsh*) sh_name=zsh ;; *) sh_name=bash ;; esac
  [ "$sh_name" = zsh ] && [ ! -f "$rc" ] && continue
  touch "$rc"
  if ! grep -q "starship init" "$rc" 2>/dev/null; then
    printf '\n# starship (rxyhn)\ncommand -v starship >/dev/null 2>&1 && eval "$(starship init %s)"\n' "$sh_name" >> "$rc"
  fi
done

# -------------------------------------------------------------------- mpd
mkdir -p "$HOME/.config/mpd/playlists" "$HOME/.config/ncmpcpp"
[ -f "$HOME/.config/mpd/mpd.conf" ] || cp "$SRC/extras/mpd/mpd.conf" "$HOME/.config/mpd/mpd.conf"
[ -f "$HOME/.config/ncmpcpp/config" ] || cp "$SRC/extras/ncmpcpp/config" "$HOME/.config/ncmpcpp/config"
[ -f "$HOME/.config/ncmpcpp/bindings" ] || cp "$SRC/extras/ncmpcpp/bindings" "$HOME/.config/ncmpcpp/bindings"

# -------------------------------------------------------------------- todo
# Starter tasks for the dashboard's Todo widget (todo.txt format: lines
# starting w/ "x " count as done). Not overwritten if it already exists.
TODO_DIR="${TODO_PATH:+$(dirname "$TODO_PATH")}"
TODO_DIR="${TODO_DIR:-$HOME/.todo}"
TODO_FILE="${TODO_PATH:-$TODO_DIR/todo.txt}"
mkdir -p "$TODO_DIR"
if [ ! -f "$TODO_FILE" ]; then
  say "Creating starter tasks -> $TODO_FILE"
  cat > "$TODO_FILE" <<'TODO'
Dashboard
Notifications
x Actions
x Rubato
x Battery
TODO
else
  say "$TODO_FILE already exists, leaving it alone"
fi

# -------------------------------------------------------------- startup
cp "$SRC/start.sh" "$HOME/start-awesome.sh"
chmod +x "$HOME/start-awesome.sh"
[ -f "$HOME/start-awesome-sh" ] && cp "$SRC/start.sh" "$HOME/start-awesome-sh" && chmod +x "$HOME/start-awesome-sh"

if grep -q "rxyhn-widgets-v1" "$CFG/dashboard/init.lua" 2>/dev/null; then
  say "OK: new dashboard (rxyhn widgets + rubato) installed."
else
  warn "dashboard/init.lua isn't the new one; check that $SRC/awesome is complete."
fi
say "Done."
SRC_CLEAN="$SRC"
cat <<MSG

  Start it:     sh ~/start-awesome.sh
  Music:        right click > Music (or Mod+grave if you have it) opens the window
                termux-setup-storage   (once; gives access to /sdcard/Music)
                mpc update             (w/ mpd running)
  Weather:      edit ~/.config/awesome/rc.lua  (openweathermap_key / city_id)
  Looks tiny:   raise Xft.dpi in ~/.Xresources (120, 144, 160...)
  Terminal:     close any open terminals and restart awesome (starship: open a new one)
  Read the README.md for shortcuts and troubleshooting.

MSG

# remove the unzipped folder from ~ (everything's already in ~/.config/awesome)
cd "$HOME" && rm -rf "$SRC_CLEAN"
