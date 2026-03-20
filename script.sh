#!/usr/bin/env bash
set -euo pipefail

USER_HOME="${HOME}"
CONFIG_DIR="${USER_HOME}/.config"
WALLPAPER="${USER_HOME}/Pictures/Wallpapers/wallpaper.jpg"

PACKAGES=(
  bspwm
  sxhkd
  xorg-server
  xorg-xinit
  alacritty
  picom
  dunst
  feh
  polybar
  rofi
  firefox
  thunar
  lxappearance
  qt5ct
  qt6ct
  xorg-xrandr
  ttf-jetbrains-mono-nerd
  noto-fonts
  noto-fonts-emoji
  papirus-icon-theme
)

info() {
  printf "\n[INFO] %s\n" "$1"
}

backup_if_exists() {
  local target="$1"
  if [ -e "$target" ]; then
    local backup="${target}.bak.$(date +%s)"
    cp -r "$target" "$backup"
    echo "[INFO] Backup created: $backup"
  fi
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[ERROR] Command not found: $1"
    exit 1
  }
}

info "Checking required commands"
need_cmd sudo
need_cmd pacman

info "Installing packages"
sudo pacman -Syu --needed --noconfirm "${PACKAGES[@]}"

info "Creating config directories"
mkdir -p \
  "${CONFIG_DIR}/bspwm" \
  "${CONFIG_DIR}/sxhkd" \
  "${CONFIG_DIR}/polybar" \
  "${CONFIG_DIR}/rofi" \
  "${CONFIG_DIR}/dunst" \
  "${CONFIG_DIR}/picom" \
  "${CONFIG_DIR}/alacritty" \
  "${USER_HOME}/Pictures/Wallpapers"

info "Backing up old configs"
backup_if_exists "${CONFIG_DIR}/bspwm/bspwmrc"
backup_if_exists "${CONFIG_DIR}/sxhkd/sxhkdrc"
backup_if_exists "${CONFIG_DIR}/polybar/config.ini"
backup_if_exists "${CONFIG_DIR}/rofi/config.rasi"
backup_if_exists "${CONFIG_DIR}/dunst/dunstrc"
backup_if_exists "${CONFIG_DIR}/picom/picom.conf"
backup_if_exists "${CONFIG_DIR}/alacritty/alacritty.toml"
backup_if_exists "${USER_HOME}/.xinitrc"
backup_if_exists "${USER_HOME}/.xprofile"

info "Writing bspwm config"
cat > "${CONFIG_DIR}/bspwm/bspwmrc" <<EOF
#!/bin/sh

pgrep -x sxhkd >/dev/null || sxhkd &
pgrep -x picom >/dev/null || picom --config "${CONFIG_DIR}/picom/picom.conf" &
pgrep -x dunst >/dev/null || dunst &
pkill polybar >/dev/null 2>&1 || true
polybar main &

xsetroot -cursor_name left_ptr

if [ -f "${WALLPAPER}" ]; then
  feh --bg-fill "${WALLPAPER}"
fi

bspc monitor -d I II III IV V VI VII VIII IX X

bspc config border_width 2
bspc config window_gap 12
bspc config split_ratio 0.52
bspc config borderless_monocle true
bspc config gapless_monocle true
bspc config focus_follows_pointer true
bspc config pointer_modifier mod1

# Temporary safety: auto-open terminal on login
alacritty &
EOF

chmod +x "${CONFIG_DIR}/bspwm/bspwmrc"

info "Writing sxhkd config"
cat > "${CONFIG_DIR}/sxhkd/sxhkdrc" <<'EOF'
# terminal
super + Return
    alacritty

alt + Return
    alacritty

# launcher
super + d
    rofi -show drun

alt + d
    rofi -show drun

# browser
super + b
    firefox

alt + b
    firefox

# file manager
super + e
    thunar

alt + e
    thunar

# close focused window
super + q
    bspc node -c

alt + q
    bspc node -c

# restart sxhkd
super + shift + r
    pkill sxhkd; sxhkd &

alt + shift + r
    pkill sxhkd; sxhkd &

# restart bspwm
super + shift + b
    bspc wm -r

alt + shift + b
    bspc wm -r

# quit session
super + Escape
    bspc quit

alt + Escape
    bspc quit

# desktops
super + {1-9,0}
    bspc desktop -f '^{1-9,10}'

alt + {1-9,0}
    bspc desktop -f '^{1-9,10}'

# move node to desktop
super + shift + {1-9,0}
    bspc node -d '^{1-9,10}'

alt + shift + {1-9,0}
    bspc node -d '^{1-9,10}'

# focus windows
super + {h,j,k,l}
    bspc node -f {west,south,north,east}

alt + {h,j,k,l}
    bspc node -f {west,south,north,east}

# swap windows
super + shift + {h,j,k,l}
    bspc node -s {west,south,north,east}

alt + shift + {h,j,k,l}
    bspc node -s {west,south,north,east}

# fullscreen / floating / monocle
super + f
    bspc node -t fullscreen

alt + f
    bspc node -t fullscreen

super + shift + space
    bspc node -t floating

alt + shift + space
    bspc node -t floating

super + m
    bspc desktop -l next

alt + m
    bspc desktop -l next
EOF

info "Writing polybar config"
cat > "${CONFIG_DIR}/polybar/config.ini" <<'EOF'
[colors]
background = #CC0F111A
background-alt = #1A1D29
foreground = #E6E9EF
primary = #89B4FA
secondary = #F5C2E7
accent = #A6E3A1
urgent = #F38BA8

[bar/main]
width = 100%
height = 32
radius = 0
background = ${colors.background}
foreground = ${colors.foreground}
line-size = 0
border-size = 0
padding-left = 2
padding-right = 2
module-margin = 2
font-0 = JetBrainsMono Nerd Font:size=11;2
font-1 = Noto Color Emoji:size=11;1
modules-left = bspwm
modules-center = date
modules-right = cpu memory pulseaudio tray
cursor-click = pointer
cursor-scroll = ns-resize
enable-ipc = true

[module/bspwm]
type = internal/bspwm
label-focused = %name%
label-focused-background = ${colors.primary}
label-focused-foreground = #11111b
label-focused-padding = 2
label-occupied = %name%
label-occupied-padding = 2
label-urgent = %name%!
label-urgent-background = ${colors.urgent}
label-urgent-padding = 2
label-empty = %name%
label-empty-foreground = #6c7086
label-empty-padding = 2

[module/date]
type = internal/date
interval = 1
date = %H:%M  %d.%m.%Y
label = %date%

[module/cpu]
type = internal/cpu
interval = 2
label = CPU %percentage%%

[module/memory]
type = internal/memory
interval = 2
label = RAM %percentage_used%%

[module/pulseaudio]
type = internal/pulseaudio
format-volume = <label-volume>
label-volume = VOL %percentage%%
label-muted = muted

[module/tray]
type = internal/tray
tray-spacing = 8
EOF

info "Writing rofi config"
cat > "${CONFIG_DIR}/rofi/config.rasi" <<'EOF'
configuration {
  modi: "drun,run,window";
  show-icons: true;
  icon-theme: "Papirus";
  display-drun: "Apps";
  display-run: "Run";
  display-window: "Windows";
}

* {
  font: "JetBrainsMono Nerd Font 11";
  bg: #0f111aee;
  bg-alt: #1a1d29ff;
  fg: #e6e9ef;
  sel: #89b4faff;
  sel-fg: #11111bff;
  border: #89b4faff;
}

window {
  width: 40%;
  border: 2px;
  border-color: @border;
  border-radius: 12px;
  background-color: @bg;
}

mainbox {
  padding: 12px;
  background-color: @bg;
}

inputbar {
  padding: 10px;
  border-radius: 10px;
  background-color: @bg-alt;
}

listview {
  lines: 10;
  columns: 1;
  spacing: 8px;
  padding: 8px 0 0;
  background-color: @bg;
}

element {
  padding: 10px;
  border-radius: 10px;
  background-color: transparent;
  text-color: @fg;
}

element selected {
  background-color: @sel;
  text-color: @sel-fg;
}

element-icon {
  size: 1.1em;
}
EOF

info "Writing picom config"
cat > "${CONFIG_DIR}/picom/picom.conf" <<'EOF'
backend = "glx";
vsync = true;

shadow = true;
shadow-radius = 18;
shadow-opacity = 0.30;
shadow-offset-x = -10;
shadow-offset-y = -10;

corner-radius = 12;
round-borders = 10;

fading = true;
fade-in-step = 0.04;
fade-out-step = 0.04;

inactive-opacity = 0.95;
active-opacity = 1.0;
frame-opacity = 1.0;

blur-method = "dual_kawase";
blur-strength = 5;

opacity-rule = [
  "95:class_g = 'Alacritty'",
  "92:class_g = 'Rofi'"
];
EOF

info "Writing dunst config"
cat > "${CONFIG_DIR}/dunst/dunstrc" <<'EOF'
[global]
    monitor = 0
    follow = mouse
    width = 360
    height = 100
    origin = top-right
    offset = 20x50
    corner_radius = 12
    frame_width = 2
    gap_size = 8
    font = JetBrainsMono Nerd Font 10
    background = "#0F111A"
    foreground = "#E6E9EF"
    frame_color = "#89B4FA"
    separator_color = frame
    timeout = 5
    idle_threshold = 120
    markup = full
    format = "<b>%s</b>\n%b"

[urgency_low]
    timeout = 3

[urgency_normal]
    timeout = 5

[urgency_critical]
    background = "#1E1E2E"
    foreground = "#F38BA8"
    frame_color = "#F38BA8"
    timeout = 0
EOF

info "Writing alacritty config"
cat > "${CONFIG_DIR}/alacritty/alacritty.toml" <<'EOF'
[window]
opacity = 0.95
padding = { x = 12, y = 12 }

[font]
normal = { family = "JetBrainsMono Nerd Font", style = "Regular" }
bold = { family = "JetBrainsMono Nerd Font", style = "Bold" }
italic = { family = "JetBrainsMono Nerd Font", style = "Italic" }
size = 11.5

[colors.primary]
background = "#0F111A"
foreground = "#E6E9EF"

[colors.cursor]
text = "#0F111A"
cursor = "#89B4FA"

[colors.normal]
black = "#1A1D29"
red = "#F38BA8"
green = "#A6E3A1"
yellow = "#F9E2AF"
blue = "#89B4FA"
magenta = "#F5C2E7"
cyan = "#94E2D5"
white = "#BAC2DE"

[colors.bright]
black = "#585B70"
red = "#F38BA8"
green = "#A6E3A1"
yellow = "#F9E2AF"
blue = "#89B4FA"
magenta = "#F5C2E7"
cyan = "#94E2D5"
white = "#A6ADC8"
EOF

info "Writing .xprofile"
cat > "${USER_HOME}/.xprofile" <<'EOF'
export GTK_THEME=Adwaita:dark
export XCURSOR_SIZE=24
export QT_QPA_PLATFORMTHEME=qt5ct
EOF

info "Writing .xinitrc"
cat > "${USER_HOME}/.xinitrc" <<'EOF'
exec bspwm
EOF

info "Enabling NetworkManager"
sudo systemctl enable NetworkManager >/dev/null 2>&1 || true

info "Done"

echo
echo "Next steps:"
echo "1. Put wallpaper here:"
echo "   ${WALLPAPER}"
echo
echo "2. Start X session:"
echo "   startx"
echo
echo "3. Main hotkeys:"
echo "   Alt+Return   -> terminal"
echo "   Alt+d        -> rofi"
echo "   Alt+b        -> firefox"
echo "   Alt+e        -> thunar"
echo "   Alt+q        -> close window"
echo "   Alt+Escape   -> quit bspwm"
echo
echo "If Super works, the same hotkeys also work with Super."