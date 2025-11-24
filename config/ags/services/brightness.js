import Hyprland from 'resource:///com/github/Aylur/ags/service/hyprland.js';
import Service from 'resource:///com/github/Aylur/ags/service.js';
import * as Utils from 'resource:///com/github/Aylur/ags/utils.js';
const { exec, execAsync } = Utils;

import { clamp } from '../modules/.miscutils/mathfuncs.js';

class BrightnessServiceBase extends Service {
    static {
        Service.register(
            this,
            { 'screen-changed': ['float'], },
            { 'screen-value': ['float', 'rw'], },
        );
    }

    _screenValue = 0;

    // the getter has to be in snake_case
    get screen_value() { return this._screenValue; }

    // the setter has to be in snake_case too
    set screen_value(percent) {
        percent = clamp(percent, 0, 1);
        this._screenValue = percent;

        Utils.execAsync(this.setBrightnessCmd(percent))
            .then(() => {
                // signals has to be explicity emitted
                this.emit('screen-changed', percent);
                this.notify('screen-value');

                // or use Service.changed(propName: string) which does the above two
                // this.changed('screen');
            })
            .catch(print);
    }

    // overwriting connectWidget method, lets you
    // change the default event that widgets connect to
    connectWidget(widget, callback, event = 'screen-changed') {
        super.connectWidget(widget, callback, event);
    }
}

class BrightnessCtlService extends BrightnessServiceBase {
    static {
        Service.register(this);
    }

    constructor() {
        super();
        const current = Number(exec('brightnessctl g'));
        const max = Number(exec('brightnessctl m'));
        this._screenValue = current / max;
    }

    setBrightnessCmd(percent) {
        return `brightnessctl s ${percent * 100}% -q`;
    }
}

class BrightnessDdcService extends BrightnessServiceBase {
    static {
        Service.register(this);
    }

    constructor(busNum) {
        super();
        this._busNum = busNum;
        Utils.execAsync(`ddcutil -b ${this._busNum} getvcp 10 --brief`)
            .then((out) => {
                // only the last line is useful
                out = out.split('\n');
                out = out[out.length - 1];

                out = out.split(' ');
                const current = Number(out[3]);
                const max = Number(out[4]);
                this._screenValue = current / max;
            })
            .catch(print);
    }

    setBrightnessCmd(percent) {
        return `ddcutil -b ${this._busNum} setvcp 10 ${Math.round(percent * 100)}`;
    }
}

async function listDdcMonitorsSnBus() {
    let ddcSnBus = {};
    try {
        const out = await Utils.execAsync('ddcutil detect --brief');
        const displays = out.split('\n\n');
        displays.forEach(display => {
            const reg = /^Display \d+/;
            if (!reg.test(display))
                return;
            const lines = display.split('\n');
            const sn = lines[3].split(':')[3];
            const busNum = lines[1].split('/dev/i2c-')[1];
            ddcSnBus[sn] = busNum;
        });
    } catch (err) {
        print(err);
    }
    return ddcSnBus;
}

// Service instance
const numMonitors = Hyprland.monitors.length;
const service = Array(numMonitors);
const ddcSnBus = await listDdcMonitorsSnBus();
const hasDdcutilCmd = (() => {
    try {
        return !!exec(`bash -c 'command -v ddcutil'`).trim();
    } catch (err) {
        return false;
    }
})();
const isValidBus = (bus) => bus !== undefined && bus !== null && bus !== '' && !Number.isNaN(Number(bus));
const makeDdcService = (busNum, monitorName) => {
    if (!isValidBus(busNum)) {
        print(`Brightness: no valid I2C bus for monitor ${monitorName}, falling back to brightnessctl`);
        return null;
    }
    return new BrightnessDdcService(busNum);
};
for (let i = 0; i < service.length; i++) {
    const monitorName = Hyprland.monitors[i].name;
    const monitorSn = Hyprland.monitors[i].serial;
    const preferredController = userOptions.brightness.controllers[monitorName]
        || userOptions.brightness.controllers.default || "auto";
    let controller = null;
    if (preferredController) {
        const busNum = monitorSn ? ddcSnBus[monitorSn] : undefined;
        switch (preferredController) {
            case "brightnessctl":
                controller = new BrightnessCtlService();
                break;
            case "ddcutil":
                controller = makeDdcService(busNum, monitorName);
                break;
            case "auto":
                if (hasDdcutilCmd)
                    controller = makeDdcService(busNum, monitorName);
                if (!controller)
                    controller = new BrightnessCtlService();
                break;
            default:
                print(`Unknown brightness controller ${preferredController}, defaulting to brightnessctl`);
                controller = new BrightnessCtlService();
        }
    }
    service[i] = controller ?? new BrightnessCtlService();
}

// make it global for easy use with cli
globalThis.brightness = service[0];

// export to use in other modules
export default service;
