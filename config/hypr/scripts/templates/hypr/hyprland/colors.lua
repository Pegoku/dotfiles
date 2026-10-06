-- exec = export SLURP_ARGS='-d -c DDE1FFBB -b 3F456544 -s 00000000'


hl.config({
    general = {
        col = {
            active_border = "rgba({{ $onSurface }}39)",
            inactive_border = "rgba({{ $outline }}30)",
        },
    },
    misc = {
        background_color = "rgba({{ $surface }}FF)",
    },
})

if hl.plugin.hyprbars then
    hl.config({
        plugin = {
            hyprbars = {
                bar_text_font = "Rubik, Geist, AR One Sans, Reddit Sans, Inter, Roboto, Ubuntu, Noto Sans, sans-serif",
                bar_height = 30,
                bar_padding = 10,
                bar_button_padding = 5,
                bar_precedence_over_border = true,
                bar_part_of_window = true,
                bar_color = "rgba({{ $background }}FF)",
                col = { text = "rgba({{ $onBackground }}FF)" },
            },
        },
    })

    local button_color = "rgb({{ $onBackground }})"
    hl.plugin.hyprbars.add_button({ bg_color = button_color, fg_color = button_color, size = 13, icon = "󰆭", action = [[hyprctl dispatch 'hl.dsp.window.close()']] })
    hl.plugin.hyprbars.add_button({ bg_color = button_color, fg_color = button_color, size = 13, icon = "󰆯", action = [[hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" })']] })
    hl.plugin.hyprbars.add_button({ bg_color = button_color, fg_color = button_color, size = 13, icon = "󰆰", action = [[hyprctl dispatch 'hl.dsp.window.move({ workspace = "special", follow = false })']] })
end

hl.window_rule({
    match = { pin = true },
    border_color = "rgba({{ $primary }}AA) rgba({{ $primary }}77)",
})
