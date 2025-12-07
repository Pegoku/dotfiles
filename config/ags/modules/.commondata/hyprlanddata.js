const { Gdk } = imports.gi;
import * as Utils from 'resource:///com/github/Aylur/ags/utils.js';
const { execAsync, exec } = Utils;

// Initialize monitors synchronously to ensure data is available at import time
function initMonitors() {
    try {
        const result = exec('hyprctl monitors -j');
        const monitorList = JSON.parse(result);
        const display = Gdk.Display.get_default();
        monitorList.forEach((monitor, i) => {
            const gdkMonitor = display.get_monitor(i);
            monitor.realWidth = monitor.width;
            monitor.realHeight = monitor.height;
            if (userOptions.monitors.scaleMethod.toLowerCase == "gdk") {
                monitor.width = gdkMonitor.get_geometry().width;
                monitor.height = gdkMonitor.get_geometry().height;
            }
            else { // == "division"
                monitor.width = Math.ceil(monitor.realWidth / monitor.scale);
                monitor.height = Math.ceil(monitor.realHeight / monitor.scale);
            }
        });
        return monitorList;
    } catch (e) {
        print(`Error initializing monitors: ${e}`);
        // Return a default monitor if initialization fails
        return [{ width: 1920, height: 1080, realWidth: 1920, realHeight: 1080, scale: 1 }];
    }
}

export const monitors = initMonitors();

