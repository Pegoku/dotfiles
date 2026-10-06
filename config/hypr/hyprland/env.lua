-- ############ Themes #############

hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_ICON_THEME", "breeze-dark")
-- Optional machine-specific settings, kept out of Git.
local config_home = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
local local_path = config_home .. "/hypr/hyprland/env.local.lua"
local local_file = io.open(local_path, "r")
if local_file then
    local_file:close()
    dofile(local_path)
end
-- env = QT_STYLE_OVERRIDE,adw-gtk3-dark
--env = QT_STYLE_OVERRIDE,kvantum-dark
-- env = WLR_NO_HARDWARE_CURSORS, 1
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("HYPRCURSOR_SIZE", "24")

--env = QT_QPA_PLATFORMTHEME,qt6ct   # for Qt apps

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")

-- ######## Screen tearing #########
-- env = WLR_DRM_NO_ATOMIC, 1

-- ############ Others #############

hl.env("CLUTTER_BACKEND", "wayland")
--env = GTK2_RC_FILES,/usr/share/themes/AdwaitaDark/gtk-2.0/gtkrc
--env = QT_AUTO_SCREEN_SCALE_FACTOR,1
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
--env = QT_QPA_PLATFORMTHEME,gtk2
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("SWT_GTK3", "1")
hl.env("_JAVA_AWT_WM_NONREPARENTING", "1")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")

hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

hl.on("config.reloaded", function()
    hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme \"adw-gtk3-dark\"")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme \"prefer-dark\"")
end)
