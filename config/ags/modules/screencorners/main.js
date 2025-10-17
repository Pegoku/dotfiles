import Widget from 'resource:///com/github/Aylur/ags/widget.js';
import Hyprland from 'resource:///com/github/Aylur/ags/service/hyprland.js';
import { enableClickthrough } from "../.widgetutils/clickthrough.js";
import { RoundedCorner } from "../.commonwidgets/cairo_roundedcorner.js";
import Brightness from '../../services/brightness.js';
import Indicator from '../../services/indicator.js';
import userOptions from '../../user_options.js';

const fakeScreenRounding = userOptions?.appearance?.fakeScreenRounding ?? 0;

if(fakeScreenRounding === 2) Hyprland.connect('event', (service, name, data) => {
    if (name == 'fullscreen') {
        const monitor = Hyprland.active.monitor.id;
        if (data == '1') {
            for (const window of App.windows) {
                if (window.name.startsWith("corner") && window.name.endsWith(monitor)) {
                    App.closeWindow(window.name);
                }
            }
        } else {
            for (const window of App.windows) {
                if (window.name.startsWith("corner") && window.name.endsWith(monitor)) {
                    App.openWindow(window.name);
                }
            }
        }
    }
})

export default (monitor = 0, where = 'bottom left', useOverlayLayer = true) => {
    const positionString = where.replace(/\s/, ""); // remove space
    const isTopLeft = positionString === 'topleft';
    const brightnessStep = userOptions?.brightness?.cornerStep ?? 0.05;

    const adjustBrightness = (delta) => {
        const svc = Brightness?.[monitor];
        if (!svc) return;
        const current = svc.screen_value ?? 0;
        const next = Math.max(0, Math.min(1, current + delta));
        if (Math.abs(next - current) < 0.001) return;
        svc.screen_value = next;
        Indicator?.popup?.(1);
    };

    const cornerContent = isTopLeft
        ? Widget.EventBox({
            onScrollUp: () => adjustBrightness(brightnessStep),
            onScrollDown: () => adjustBrightness(-brightnessStep),
            onPrimaryClick: () => adjustBrightness(brightnessStep),
            onSecondaryClick: () => adjustBrightness(-brightnessStep),
            child: RoundedCorner(positionString, { className: 'corner-black' }),
        })
        : RoundedCorner(positionString, { className: 'corner-black' });
    return Widget.Window({
        monitor,
        name: `corner${positionString}${monitor}`,
        layer: useOverlayLayer ? 'overlay' : 'top',
        anchor: where.split(' '),
        exclusivity: 'ignore',
        visible: true,
        child: cornerContent,
        setup: (self) => {
            if (!isTopLeft) enableClickthrough(self);
        },
    });
}

