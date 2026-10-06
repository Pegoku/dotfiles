# Pegoku Dotfiles
Laptop branch (v2)

## Hyprland configuration

Hyprland 0.56+ uses `config/hypr/hyprland.lua`, with modules in
`config/hypr/hyprland/`. Edit the Lua files for monitors, rules, bindings,
startup commands, and environment settings. Hyprland prefers the Lua entry
point on startup. A session already using the legacy parser needs a logout
and login to switch; `hyprctl reload` does not switch parsers.

The old Hyprland `.conf` files remain as a fallback for existing legacy
sessions. They are not loaded by the Lua entry point. Wallpaper colors are
generated in both formats during this transition. Hypridle, Hyprlock, and
xdg-desktop-portal-hyprland still use their own `.conf` files.

Optional machine-specific settings belong in the ignored
`config/hypr/hyprland/env.local.lua`, for example:

```lua
hl.env("MY_VARIABLE", "value")
```

Validate before logging back in:

```sh
Hyprland --verify-config -c ~/.config/hypr/hyprland.lua
```

The keybinding overlay reads the Lua bindings using the `lua` interpreter,
including generated workspace shortcuts. Use `--#! Section name` headings,
`-- help: Description` on callback bindings, and `-- [hidden]` to hide a
binding. The help reader uses inert dispatcher stubs and does not run commands.

## System updates and T3 Code

Run `up` in Zsh to update with Yay and then synchronize the separately installed
T3 background service with the installed `t3code-bin` desktop package version.
Package operations show a consent dialog and use Polkit authentication.
The T3 update runs as your user and may restart the service, interrupting active
agent work. It runs only after a successful package update.

Other modes (run from this repository):

```sh
scripts/t3-system-update pacman   # official packages, then T3 synchronization
scripts/t3-system-update sync     # synchronize T3 after a separate yay/pacman update
```

Pacman does not update AUR packages; use Yay to update `t3code-bin`.
Ordinary `yay`/`pacman` commands do not trigger synchronization automatically.
The script pins T3 to the installed desktop version instead of downloading a
possibly newer backend. Unsupported package versions and download failures are
reported as errors. Downgrades require an explicit manual T3 update.

## Screenshots
![alt text](image.png)
![alt text](image-1.png)

## Credits

https://github.com/end-4/dots-hyprland
