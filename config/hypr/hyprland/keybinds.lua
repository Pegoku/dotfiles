-- Append `-- [hidden]` to hide a binding from the cheatsheet.
-- Use --#! for section headings and -- help: for callback descriptions.


local workspaces = require("hyprland.workspaces")

hl.bind("ALT + XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_SOURCE@ toggle"), { locked = true })
hl.bind("SUPER + XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_SOURCE@ toggle"), { locked = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("SUPER+SHIFT + M", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })

-- Uncomment these if you can't get AGS to work
--bindle=, XF86MonBrightnessUp, exec, brightnessctl set '12.75+'
--bindle=, XF86MonBrightnessDown, exec, brightnessctl set '12.75-'

--!
--#! Essentials for beginner

hl.bind("SUPER + T", hl.dsp.exec_cmd("foot"))
hl.bind("Super_L", hl.dsp.exec_cmd("true"))
hl.bind("CTRL+SHIFT+SUPER + P", hl.dsp.exec_cmd("~/.config/hypr/scripts/color_generation/switchwall.sh"))
--#! Capture and Clipboard
hl.bind("SUPER + V", hl.dsp.exec_cmd("pkill fuzzel || cliphist list | fuzzel --dmenu | cliphist decode | wl-copy"))
hl.bind("SUPER + Period", hl.dsp.exec_cmd("pkill fuzzel || ~/.local/bin/fuzzel-emoji"))
hl.bind("CTRL+SHIFT+ALT + Delete", hl.dsp.exec_cmd("pkill wlogout || wlogout -p layer-shell"))
hl.bind("SUPER+SHIFT + S", hl.dsp.exec_cmd("~/.config/hypr/scripts/grimblast.sh --freeze copy area"))
hl.bind("SUPER+SHIFT+ALT + S", hl.dsp.exec_cmd("grim -g \"$(slurp)\" - | swappy -f -"))
-- OCR
hl.bind("SUPER+SHIFT + T", hl.dsp.exec_cmd("grim -g \"$(slurp $SLURP_ARGS)\" \"tmp.png\" && tesseract -l eng \"tmp.png\" - | wl-copy && rm \"tmp.png\""))
hl.bind("CTRL+SUPER+SHIFT + S", hl.dsp.exec_cmd("grim -g \"$(slurp $SLURP_ARGS)\" \"tmp.png\" && tesseract \"tmp.png\" - | wl-copy && rm \"tmp.png\""))
-- Color picker
hl.bind("SUPER+SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"))
hl.bind("SUPER+SHIFT + Z", hl.dsp.exec_cmd("~/.config/hypr/scripts/hyprland/toggle_cursor_zoom.sh"))
-- Fullscreen screenshot
--bind=, Print, exec, grimshot copy anything # Screenshot >> clipboard
hl.bind("Print", hl.dsp.exec_cmd("~/.config/hypr/scripts/grimblast.sh copysave area ~/Pictures/Screenshots/Screenshot_\"$(date '+%Y-%m-%d_%H.%M.%S')\".png"))
hl.bind("XF86Calculator", hl.dsp.exec_cmd("~/.config/hypr/scripts/grimblast.sh copysave area ~/Pictures/Screenshots/Screenshot_\"$(date '+%Y-%m-%d_%H.%M.%S')\".png"))
hl.bind("CTRL + Print", hl.dsp.exec_cmd("bash -lc 'f=\"$HOME/Pictures/Screenshots/Screenshot_$(date +\\\"%Y-%m-%d_%H.%M.%S\\\").png\"; ~/.config/hypr/scripts/grimblast.sh copysave area \"$f\" && swappy -f \"$f\"'"))
--bind= CTRL,Print, exec, mkdir -p ~/Pictures/Screenshots && ~/.config/hypr/scripts/grimblast.sh copysave screen ~/Pictures/Screenshots/Screenshot_"$(date '+%Y-%m-%d_%H.%M.%S')".png # Screenshot >> clipboard & file
--#! Recording
hl.bind("SUPER+ALT + R", hl.dsp.exec_cmd("~/.config/hypr/scripts/record-script.sh"))
hl.bind("CTRL+ALT + R", hl.dsp.exec_cmd("~/.config/hypr/scripts/record-script.sh --fullscreen"))
hl.bind("SUPER+SHIFT+ALT + R", hl.dsp.exec_cmd("~/.config/hypr/scripts/record-script.sh --fullscreen-sound"))
--#! Session
hl.bind("CTRL+SUPER + L", hl.dsp.exec_cmd("ags run-js 'lock.lock()'"))
hl.bind("SUPER + L", hl.dsp.exec_cmd("loginctl lock-session"))
hl.bind("SUPER+SHIFT + L", hl.dsp.exec_cmd("loginctl lock-session"))
hl.bind("SUPER+SHIFT + L", hl.dsp.exec_cmd("loginctl lock-session"), { locked = true })
hl.bind("CTRL+SHIFT+ALT+SUPER + Delete", hl.dsp.exec_cmd("systemctl poweroff || loginctl poweroff"))

--!
--#! Window management
-- Focusing
--/# bind = SUPER, ←/↑/→/↓,, # Move focus in direction
hl.bind("SUPER + Left", hl.dsp.focus({ direction = "left" }))
hl.bind("SUPER + Right", hl.dsp.focus({ direction = "right" }))
hl.bind("SUPER + Up", hl.dsp.focus({ direction = "up" }))
hl.bind("SUPER + Down", hl.dsp.focus({ direction = "down" }))
hl.bind("SUPER + BracketLeft", hl.dsp.focus({ direction = "left" }))
hl.bind("SUPER + BracketRight", hl.dsp.focus({ direction = "right" }))
hl.bind("SUPER + mouse:272", hl.dsp.window.drag())
hl.bind("SUPER + Z", hl.dsp.window.resize())
hl.bind("ALT + F4", hl.dsp.window.kill())
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER+SHIFT+ALT + Q", hl.dsp.exec_cmd("hyprctl kill"))
--#! Window layout
--/# bind = SUPER+SHIFT, ←/↑/→/↓,, # Window: move in direction
hl.bind("SUPER+SHIFT + Left", hl.dsp.window.move({ direction = "l" }))
hl.bind("SUPER+SHIFT + Right", hl.dsp.window.move({ direction = "r" }))
hl.bind("SUPER+SHIFT + Up", hl.dsp.window.move({ direction = "u" }))
hl.bind("SUPER+SHIFT + Down", hl.dsp.window.move({ direction = "d" }))
-- Window split ratio
--/# binde = SUPER, +/-,, # Window: split ratio +/- 0.1
hl.bind("SUPER + Minus", hl.dsp.layout("splitratio -0.1"), { repeating = true })
hl.bind("SUPER + Equal", hl.dsp.layout("splitratio +0.1"), { repeating = true })
hl.bind("SUPER + Semicolon", hl.dsp.layout("splitratio -0.1"), { repeating = true })
hl.bind("SUPER + Apostrophe", hl.dsp.layout("splitratio +0.1"), { repeating = true })
-- Positioning mode
hl.bind("SUPER+ALT + Space", hl.dsp.window.float({ action = "toggle" }))
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind("SUPER + D", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))

--!
--#! Workspace navigation
-- Switching
--/# bind = SUPER, Hash,, # Focus workspace # (1, 2, 3, 4, ...)
-- The digit picks a workspace inside the block the focused monitor shows, so
-- SUPER+3 is workspace 3 on the built-in panel and workspace 13 on the first
-- external one.
for offset = 1, workspaces.per_monitor do
    hl.bind("SUPER + " .. offset % 10, function() -- help: Focus workspace on current monitor
        hl.dispatch(hl.dsp.focus({ workspace = tostring(workspaces.workspace_for(offset)) }))
    end)
end

--/# bind = CTRL+SUPER, ←/→,, # Workspace: focus left/right
hl.bind("CTRL+SUPER + Right", hl.dsp.focus({ workspace = "+1" }))
hl.bind("CTRL+SUPER + Left", hl.dsp.focus({ workspace = "-1" }))
--/# bind = SUPER, Scroll ↑/↓,, # Workspace: focus left/right
hl.bind("SUPER + mouse_up", hl.dsp.focus({ workspace = "-1" }))
hl.bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "+1" }))
hl.bind("CTRL+SUPER + mouse_up", hl.dsp.focus({ workspace = "+1" }))
hl.bind("CTRL+SUPER + mouse_down", hl.dsp.focus({ workspace = "-1" }))
--/# bind = SUPER, Page_↑/↓,, # Workspace: focus left/right
hl.bind("SUPER + Page_Down", hl.dsp.focus({ workspace = "+1" }))
hl.bind("SUPER + Page_Up", hl.dsp.focus({ workspace = "-1" }))
hl.bind("CTRL+SUPER + Page_Down", hl.dsp.focus({ workspace = "+1" }))
hl.bind("CTRL+SUPER + Page_Up", hl.dsp.focus({ workspace = "-1" }))
--# Special
hl.bind("SUPER + S", hl.dsp.workspace.toggle_special(""))
hl.bind("SUPER + mouse:275", hl.dsp.workspace.toggle_special(""))
hl.bind("SUPER + J", hl.dsp.exec_cmd("~/.config/hypr/scripts/hyprland/gromit-special.sh toggle-workspace"))
hl.bind("SUPER+SHIFT + J", hl.dsp.exec_cmd("~/.config/hypr/scripts/hyprland/gromit-special.sh paint"))
hl.bind("CTRL+SUPER + J", hl.dsp.exec_cmd("~/.config/hypr/scripts/hyprland/gromit-special.sh clear"))

--#! Workspace management
-- Move window to workspace SUPER + ALT + [0-9]
--/# bind = SUPER+ALT, Hash,, # Window: move to workspace # (1, 2, 3, 4, ...)
for offset = 1, workspaces.per_monitor do
    hl.bind("SUPER+ALT + " .. offset % 10, function() -- help: Move window to workspace on current monitor
        hl.dispatch(hl.dsp.window.move({
            workspace = tostring(workspaces.workspace_for(offset)),
            follow = false,
        }))
    end)
end

hl.bind("CTRL+SUPER+SHIFT + Up", hl.dsp.window.move({ workspace = "special", follow = false }))

hl.bind("CTRL+SUPER+SHIFT + Right", hl.dsp.window.move({ workspace = "+1" }))
hl.bind("CTRL+SUPER+SHIFT + Left", hl.dsp.window.move({ workspace = "-1" }))
hl.bind("CTRL+SUPER + BracketLeft", hl.dsp.focus({ workspace = "-1" }))
hl.bind("CTRL+SUPER + BracketRight", hl.dsp.focus({ workspace = "+1" }))
hl.bind("CTRL+SUPER + Up", hl.dsp.focus({ workspace = "-5" }))
hl.bind("CTRL+SUPER + Down", hl.dsp.focus({ workspace = "+5" }))
--/# bind = SUPER+SHIFT, Scroll ↑/↓,, # Window: move to workspace left/right
hl.bind("SUPER+SHIFT + mouse_down", hl.dsp.window.move({ workspace = "-1" }))
hl.bind("SUPER+SHIFT + mouse_up", hl.dsp.window.move({ workspace = "+1" }))
hl.bind("SUPER+ALT + mouse_down", hl.dsp.window.move({ workspace = "-1" }))
hl.bind("SUPER+ALT + mouse_up", hl.dsp.window.move({ workspace = "+1" }))
--/# bind = SUPER+SHIFT, Page_↑/↓,, # Window: move to workspace left/right
hl.bind("SUPER+ALT + Page_Down", hl.dsp.window.move({ workspace = "+1" }))
hl.bind("SUPER+ALT + Page_Up", hl.dsp.window.move({ workspace = "-1" }))
hl.bind("SUPER+SHIFT + Page_Down", hl.dsp.window.move({ workspace = "+1" }))
hl.bind("SUPER+SHIFT + Page_Up", hl.dsp.window.move({ workspace = "-1" }))
hl.bind("SUPER+ALT + S", hl.dsp.window.move({ workspace = "special", follow = false }))
-- bind = SUPER, P, pin

hl.bind("CTRL+SUPER + S", hl.dsp.workspace.toggle_special(""))
hl.bind("ALT + Tab", hl.dsp.window.cycle_next({ next = true }))
hl.bind("ALT + Tab", hl.dsp.window.bring_to_top())

--!
--#! Shell and Widgets
--bindr = SUPER, R, exec, rofi -show drun; pkill ydotool; quickshell & # Restart shell widgets
hl.bind("CTRL+SUPER+ALT + R", hl.dsp.exec_cmd("hyprctl reload; killall quickshell ydotool; quickshell &"), { release = true })
hl.bind("CTRL+ALT + Slash", hl.dsp.exec_cmd("ags run-js 'cycleMode();'"))
hl.bind("SUPER + Tab", hl.dsp.exec_cmd("quickshell ipc call overview toggle"))
hl.bind("SUPER + SHIFT + H", hl.dsp.exec_cmd("quickshell ipc call keybinds toggle"))
hl.bind("SUPER + B", hl.dsp.exec_cmd("quickshell ipc call aichat toggle"))
hl.bind("SUPER + A", hl.dsp.exec_cmd("ags -t 'sideleft'"))
hl.bind("SUPER+SHIFT + O", hl.dsp.window.tag({ tag = "opaque_toggle" }))
hl.bind("CTRL+SHIFT+SUPER + O", hl.dsp.exec_cmd("~/.config/hypr/scripts/toggle-global-opacity.sh"))
hl.bind("SUPER + O", hl.dsp.exec_cmd("ags -t 'sideleft'"))
hl.bind("SUPER + N", hl.dsp.exec_cmd("ags -t 'sideright'"))
hl.bind("SUPER + M", hl.dsp.exec_cmd("env GTK_THEME=Adwaita:dark pavucontrol"))
hl.bind("SUPER + Comma", hl.dsp.exec_cmd("ags run-js 'openColorScheme.value = true; Utils.timeout(2000, () => openColorScheme.value = false);'"))
hl.bind("CTRL+SUPER + K", hl.dsp.exec_cmd("for ((i=0; i<$(hyprctl monitors -j | jq length); i++)); do ags -t \"osk\"\"$i\"; done"))
hl.bind("CTRL+ALT + Delete", hl.dsp.exec_cmd("quickshell ipc call powermenu toggle"))
hl.bind("XF86PowerOff", hl.dsp.exec_cmd("quickshell ipc call powermenu toggle"))
hl.bind("CTRL+SUPER + G", hl.dsp.exec_cmd("for ((i=0; i<$(hyprctl monitors -j | jq length); i++)); do ags -t \"crosshair\"\"$i\"; done"))
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set +5%"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { locked = true, repeating = true })
-- Testing
-- bind = SuperAlt, f12, exec, notify-send "Hyprland version: $(hyprctl version | head -2 | tail -1 | cut -f2 -d ' ')" "owo" -a 'Hyprland keybind'
-- bind = SUPER+ALT, f12, exec, notify-send "Millis since epoch" "$(date +%s%N | cut -b1-13)" -a 'Hyprland keybind'
-- bind = SUPER+ALT, f12, exec, notify-send 'Test notification' "Here's a really long message to test truncation and wrapping\nYou can middle click or flick this notification to dismiss it!" -a 'Shell' -A "Test1=I got it!" -A "Test2=Another action" -t 5000 # [hidden]
-- bind = SUPER+ALT, Equal, exec, notify-send "Urgent notification" "Ah hell no" -u critical -a 'Hyprland keybind' # [hidden]

--#! Media
hl.bind("SUPER+SHIFT + N", hl.dsp.exec_cmd("playerctl next || playerctl position `bc <<< \"100 * $(playerctl metadata mpris:length) / 1000000 / 100\"`"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("bash -lc 'playerctl --player=spotify,%any previous || true; quickshell ipc call nowplaying pulse'"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("bash -lc 'playerctl --player=spotify,%any play-pause || true; quickshell ipc call nowplaying pulse'"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("bash -lc 'playerctl --player=spotify,%any next || playerctl --player=%any position `bc <<< \"100 * $(playerctl metadata mpris:length) / 1000000 / 100\"` || true; quickshell ipc call nowplaying pulse'"), { locked = true })
hl.bind("SUPER+SHIFT+ALT + mouse:275", hl.dsp.exec_cmd("playerctl previous"))
hl.bind("SUPER+SHIFT+ALT + mouse:276", hl.dsp.exec_cmd("playerctl next || playerctl position `bc <<< \"100 * $(playerctl metadata mpris:length) / 1000000 / 100\"`"))
hl.bind("SUPER+SHIFT + B", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind("SUPER+SHIFT + P", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })

--!
--#! Development Apps
--bind = SUPER, T, exec, # Launch foot (terminal)
--bind = SUPER, Z, exec, Zed # Launch Zed (editor)
hl.bind("SUPER + C", hl.dsp.exec_cmd("code --password-store=gnome --enable-features=UseOzonePlatform --ozone-platform=wayland"))
hl.bind("SUPER + E", hl.dsp.exec_cmd("nautilus --new-window"))
-- bind = SUPER+ALT, E, exec, thunar # [hidden]
--#! Browsers and Chat
hl.bind("CTRL+SUPER + W", hl.dsp.exec_cmd("brave"))
hl.bind("SUPER + W", hl.dsp.exec_cmd("firefox -P default-release"))
--bind = SUPER, X, exec, zapzap
hl.bind("SUPER + X", hl.dsp.exec_cmd("/usr/bin/firefoxpwa site launch 01JMMJ9598CX6H41DD4BG93B87 --protocol"))
hl.bind("CTRL+SUPER + X", hl.dsp.exec_cmd("slack"))
hl.bind("SHIFT+SUPER + X", hl.dsp.exec_cmd("discord"))
--#! Creative and Engineering Apps
--bind = SUPER, G, exec, env -u WAYLAND_DISPLAY -u QT_QPA_PLATFORM /usr/bin/freecad # Launch FreeCAD
hl.bind("SUPER + G", hl.dsp.exec_cmd("env env -u WAYLAND_DISPLAY -u QT_QPA_PLATFORM freecad"))
-- bind = SUPER, K, exec, bash /usr/share/applications/org.kicad.kicad.desktop
hl.bind("SUPER + K", hl.dsp.exec_cmd("kicad"))
--bind = SUPER, K, exec, env XDG_SESSION_TYPE=x11 env GDK_BACKEND=x11 sh -c "flatpak run org.kicad.KiCad" # Launch KiCad
--#! System and Launchers
hl.bind("SUPER + I", hl.dsp.exec_cmd("XDG_CURRENT_DESKTOP=\"gnome\" gnome-control-center"))
hl.bind("CTRL+SUPER + V", hl.dsp.exec_cmd("pavucontrol"))
-- bind = CTRL+SUPER+SHIFT, V, exec, easyeffects # Launch EasyEffects (equalizer & other audio effects)
hl.bind("CTRL+SHIFT + Escape", hl.dsp.exec_cmd("gnome-system-monitor"))
--bind = CTRL+SUPER, T, exec, pkill anyrun || anyrun # Toggle fallback launcher: anyrun
hl.bind("CTRL+SUPER + T", hl.dsp.exec_cmd("pgrep -x anyrun && pkill -x anyrun || anyrun"))
hl.bind("CTRL+SUPER + P", hl.dsp.exec_cmd("spotify", { workspace = "10 silent" }))
hl.bind("SUPER + P", hl.dsp.exec_cmd("feishin", { workspace = "10 silent" }))

-- Set passthrough for some keys to Hyprland
hl.bind("SUPER + code:197", hl.dsp.submap("passthru"))
hl.define_submap("passthru", function()
    hl.bind("SUPER + Escape", hl.dsp.submap("reset"))
end)

-- Cursed stuff
--# Make window not amogus large
hl.bind("CTRL+SUPER + Backslash", hl.dsp.window.resize({ x = 640, y = 480 }))

--#! Miscellaneous
-- Controller
hl.bind("CTRL+SHIFT+ALT + C", hl.dsp.focus({ workspace = 5 }))

--#! Overview Shortcuts
-- Gestures
-- hyprexpo-gesture = 3, up, expo
-- hyprexpo-gesture = 3, down, expo
hl.bind("SUPER + Super_L", hl.dsp.exec_cmd("quickshell ipc call overview toggle"))
hl.gesture({
    fingers = 3,
    direction = "up",
    action = function()
        hl.exec_cmd("quickshell ipc call overview toggle")
    end,
})
hl.gesture({
    fingers = 3,
    direction = "down",
    action = function()
        hl.exec_cmd("quickshell ipc call overview toggle")
    end,
})
hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace",
})

-- Passthrough
--bind = , F14, pass, ^discord$
