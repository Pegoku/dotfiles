import App from 'resource:///com/github/Aylur/ags/app.js';
import Widget from 'resource:///com/github/Aylur/ags/widget.js';
import { monitors } from '../.commondata/hyprlanddata.js';
const { Box, EventBox } = Widget;

export const clickCloseRegion = ({ name, multimonitor = true, monitor = 0, expand = true, fillMonitor = '' }) => {
    const monitorData = monitors[monitor] || { width: 1920, height: 1080 };
    return EventBox({
        child: Box({
            expand: expand,
            css: `
                min-width: ${fillMonitor.includes('h') ? monitorData.width : 0}px;
                min-height: ${fillMonitor.includes('v') ? monitorData.height : 0}px;
            `,
        }),
        setup: (self) => self.on('button-press-event', (self, event) => { // Any mouse button
            if (multimonitor) closeWindowOnAllMonitors(name);
            else App.closeWindow(name);
        }),
    })
}

export default clickCloseRegion;

