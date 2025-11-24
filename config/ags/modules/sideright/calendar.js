const { Gio, Gtk } = imports.gi;
import Widget from 'resource:///com/github/Aylur/ags/widget.js';
import * as Utils from 'resource:///com/github/Aylur/ags/utils.js';
const { Box, Button, Label } = Widget;
import { MaterialIcon } from '../.commonwidgets/materialicon.js';
import { setupCursorHover } from '../.widgetutils/cursorhover.js';

import { TodoWidget } from "./todolist.js";
import Todo from "../../services/todo.js";
import { getCalendarLayout } from "./calendar_layout.js";

let calendarJson = getCalendarLayout(undefined, true);
let monthshift = 0;

function getDateInXMonthsTime(x) {
    var currentDate = new Date(); // Get the current date
    var targetMonth = currentDate.getMonth() + x; // Calculate the target month
    var targetYear = currentDate.getFullYear(); // Get the current year

    // Adjust the year and month if necessary
    targetYear += Math.floor(targetMonth / 12);
    targetMonth = (targetMonth % 12 + 12) % 12;

    // Create a new date object with the target year and month
    var targetDate = new Date(targetYear, targetMonth, 1);

    // Set the day to the last day of the month to get the desired date
    // targetDate.setDate(0);

    return targetDate;
}

const weekDays = [ // MONDAY IS THE FIRST DAY OF THE WEEK :HESRIGHTYOUKNOW:
    { day: 'Mo', today: 0 },
    { day: 'Tu', today: 0 },
    { day: 'We', today: 0 },
    { day: 'Th', today: 0 },
    { day: 'Fr', today: 0 },
    { day: 'Sa', today: 0 },
    { day: 'Su', today: 0 },
]

function formatDMY(y, m, d) {
    const mm = String(m).padStart(2, '0');
    const dd = String(d).padStart(2, '0');
    return `${y}-${mm}-${dd}`;
}

function taskDueOn(y, m, d, tasks) {
    const key = formatDMY(y, m, d);
    return (tasks || []).filter(t => {
        if (!t.due) return false;
        // Compare date part only, use UTC to avoid tz skew
        try {
            const dt = new Date(t.due);
            const ty = dt.getUTCFullYear();
            const tm = dt.getUTCMonth() + 1;
            const td = dt.getUTCDate();
            return `${ty}-${String(tm).padStart(2,'0')}-${String(td).padStart(2,'0')}` === key;
        } catch { return false; }
    });
}

// Build an array of up to 4 project colors for tasks due on a date.
// If more than 4 colors exist, pick the top 4 by task count on that day.
function dayProjectColors(y, m, d) {
    const dueTasks = taskDueOn(y, m, d, Todo.todo_json);
    if (dueTasks.length === 0) return [];
    // Map project id -> hexColor
    const projects = Array.isArray(Todo.projects) ? Todo.projects : [];
    const colorByPid = new Map(projects.map(p => [p.id, p.hexColor || null]));
    const counts = new Map(); // color -> count
    for (const t of dueTasks) {
        const pid = t.project_id ?? t.projectId ?? null;
        const color = colorByPid.get(pid) || null;
        if (!color) continue;
        counts.set(color, (counts.get(color) || 0) + 1);
    }
    const arr = Array.from(counts.entries());
    if (arr.length === 0) return [];
    arr.sort((a, b) => b[1] - a[1]);
    return arr.slice(0, 4).map(([color, _]) => color);
}

function hexToRGBA(hex) {
    if (!hex || typeof hex !== 'string') return null;
    let v = hex.trim().toLowerCase();
    if (v.startsWith('#')) v = v.slice(1);
    if (!/^[0-9a-f]{3}([0-9a-f]{3})?$/.test(v)) return null;
    if (v.length === 3) v = v.split('').map(c => c + c).join('');
    const r = parseInt(v.slice(0, 2), 16) / 255;
    const g = parseInt(v.slice(2, 4), 16) / 255;
    const b = parseInt(v.slice(4, 6), 16) / 255;
    return { r, g, b, a: 1 };
}

// A DrawingArea that paints a circle split into equal wedges with the given colors
function DayCircle(colors = []) {
    const area = Widget.DrawingArea({
        className: 'sidebar-calendar-day-circle',
        setup: (area) => {
            const draw = (area, cr) => {
                // dimensions
                const sc = area.get_style_context();
                const minW = sc.get_property('min-width', Gtk.StateFlags.NORMAL) || 28;
                const minH = sc.get_property('min-height', Gtk.StateFlags.NORMAL) || 28;
                const width = Math.max(minW, area.get_allocated_width() || 0) || minW;
                const height = Math.max(minH, area.get_allocated_height() || 0) || minH;
                area.set_size_request(width, height);
                const cx = width / 2;
                const cy = height / 2;
                const radius = Math.min(width, height) / 2 - 1;

                const cols = area._colors || [];
                const n = Math.max(1, cols.length);
                const step = (2 * Math.PI) / n;

                // Fill background using style's background-color so it matches the calendar cell
                const bg = sc.get_property('background-color', Gtk.StateFlags.NORMAL);
                cr.setSourceRGBA(bg.red, bg.green, bg.blue, bg.alpha);
                cr.rectangle(0, 0, width, height);
                cr.fill();

                // Draw wedges (or single full circle)
                let start = -Math.PI / 2; // start at top
                for (let i = 0; i < n; i++) {
                    const col = cols[i] || cols[0];
                    const rgba = hexToRGBA(col);
                    if (!rgba) continue;
                    const end = start + step;
                    cr.setSourceRGBA(rgba.r, rgba.g, rgba.b, rgba.a);
                    cr.moveTo(cx, cy);
                    cr.arc(cx, cy, radius, start, end);
                    cr.closePath();
                    cr.fill();
                    start = end;
                }
                return false;
            };
            area.connect('draw', draw);
            area._colors = colors.slice();
        }
    });
    area.setColors = (arr) => { area._colors = Array.isArray(arr) ? arr.slice() : []; area.queue_repaint?.(); area.queue_draw?.(); };
    return area;
}

const CalendarDay = (cell) => {
    const { day, today, month, year } = cell;
    const countLabel = Label({ className: 'txt-tiny sidebar-calendar-day-count', label: '' });
    const numberLabel = Label({
        hpack: 'center',
        className: 'txt-smallie txt-semibold sidebar-calendar-btn-txt',
        label: String(day),
    });
    const circle = DayCircle([]);
    // Mirror the same background classes as the day button so the circle inherits background colors
    circle.toggleClassName('sidebar-calendar-btn', true);
    if (today == 1) circle.toggleClassName('sidebar-calendar-btn-today', true);
    else if (today == -1) circle.toggleClassName('sidebar-calendar-btn-othermonth', true);
    const dayBox = Widget.Button({
        className: `sidebar-calendar-btn ${today == 1 ? 'sidebar-calendar-btn-today' : (today == -1 ? 'sidebar-calendar-btn-othermonth' : '')}`,
        child: Widget.Overlay({ child: circle, overlays: [numberLabel, Box({ hpack: 'end', vpack: 'end', children: [countLabel] })] }),
        onClicked: () => {
            // Set date filter and switch to Todo tab
            const key = formatDMY(year, month, day);
            Todo.setDateFilter(key); // service accepts YYYY-MM-DD
            // Find the stack and switch shown child to 'todo'
            try {
                contentStack.shown = 'todo';
            } catch {}
        },
        setup: (btn) => btn.hook(Todo, () => {
            const dueTasks = taskDueOn(year, month, day, Todo.todo_json);
            countLabel.label = dueTasks.length > 0 ? String(dueTasks.length) : '';
            btn.tooltipText = dueTasks.length > 0 ? dueTasks.map(t => `• ${t.content}`).join('\n') : '';
            // Update circle colors based on tasks/projects
            const cols = dayProjectColors(year, month, day);
            circle.setColors(cols);
        }, 'updated'),
    });
    return dayBox;
}

const CalendarWidget = () => {
    const calendarMonthYear = Widget.Button({
        className: 'txt txt-large sidebar-calendar-monthyear-btn',
        onClicked: () => shiftCalendarXMonths(0),
        setup: (button) => {
            button.label = `${new Date().toLocaleString('default', { month: 'long' })} ${new Date().getFullYear()}`;
            setupCursorHover(button);
        }
    });
    const addCalendarChildren = (box, calendarJson) => {
        const children = box.get_children();
        for (let i = 0; i < children.length; i++) {
            const child = children[i];
            child.destroy();
        }
        box.children = calendarJson.map((row, i) => Widget.Box({
            className: 'spacing-h-5',
            children: row.map((cell, i) => CalendarDay(cell)),
        }))
    }
    function shiftCalendarXMonths(x) {
        if (x == 0) monthshift = 0;
        else monthshift += x;
        var newDate;
        if (monthshift == 0) newDate = new Date();
        else newDate = getDateInXMonthsTime(monthshift);

        calendarJson = getCalendarLayout(newDate, (monthshift == 0));
        calendarMonthYear.label = `${monthshift == 0 ? '' : '• '}${newDate.toLocaleString('default', { month: 'long' })} ${newDate.getFullYear()}`;
        addCalendarChildren(calendarDays, calendarJson);
    }
    const calendarHeader = Widget.Box({
        className: 'spacing-h-5 sidebar-calendar-header',
        setup: (box) => {
            box.pack_start(calendarMonthYear, false, false, 0);
            box.pack_end(Widget.Box({
                className: 'spacing-h-5',
                children: [
                    Button({
                        className: 'sidebar-calendar-monthshift-btn',
                        onClicked: () => shiftCalendarXMonths(-1),
                        child: MaterialIcon('chevron_left', 'norm'),
                        setup: setupCursorHover,
                    }),
                    Button({
                        className: 'sidebar-calendar-monthshift-btn',
                        onClicked: () => shiftCalendarXMonths(1),
                        child: MaterialIcon('chevron_right', 'norm'),
                        setup: setupCursorHover,
                    })
                ]
            }), false, false, 0);
        }
    })
    const calendarDays = Widget.Box({
        hexpand: true,
        vertical: true,
        className: 'spacing-v-5',
        setup: (box) => {
            addCalendarChildren(box, calendarJson);
        }
    });
    return Widget.EventBox({
        onScrollUp: () => shiftCalendarXMonths(-1),
        onScrollDown: () => shiftCalendarXMonths(1),
        child: Widget.Box({
            hpack: 'center',
            children: [
                Widget.Box({
                    hexpand: true,
                    vertical: true,
                    className: 'spacing-v-5',
                    children: [
                        calendarHeader,
                        Widget.Box({
                            homogeneous: true,
                            className: 'spacing-h-5',
                            children: weekDays.map((day, i) => CalendarDay(day))
                        }),
                        calendarDays,
                    ]
                })
            ]
        })
    });
};

const defaultShown = 'calendar';
const contentStack = Widget.Stack({
    hexpand: true,
    children: {
        'calendar': CalendarWidget(),
        'todo': TodoWidget(),
        // 'stars': Widget.Label({ label: 'GitHub feed will be here' }),
    },
    transition: 'slide_up_down',
    transitionDuration: userOptions.animations.durationLarge,
    setup: (stack) => Utils.timeout(1, () => {
        stack.shown = defaultShown;
    })
})

const StackButton = (stackItemName, icon, name) => Widget.Button({
    className: 'button-minsize sidebar-navrail-btn txt-small spacing-h-5',
    onClicked: (button) => {
        contentStack.shown = stackItemName;
        const kids = button.get_parent().get_children();
        for (let i = 0; i < kids.length; i++) {
            if (kids[i] != button) kids[i].toggleClassName('sidebar-navrail-btn-active', false);
            else button.toggleClassName('sidebar-navrail-btn-active', true);
        }
    },
    child: Box({
        className: 'spacing-v-5',
        vertical: true,
        children: [
            Label({
                className: `txt icon-material txt-hugeass`,
                label: icon,
            }),
            Label({
                label: name,
                className: 'txt txt-smallie',
            }),
        ]
    }),
    setup: (button) => Utils.timeout(1, () => {
        setupCursorHover(button);
        button.toggleClassName('sidebar-navrail-btn-active', defaultShown === stackItemName);
    })
});

export const ModuleCalendar = () => Box({
    className: 'sidebar-group spacing-h-5',
    setup: (box) => {
        box.pack_start(Box({
            vpack: 'center',
            homogeneous: true,
            vertical: true,
            className: 'sidebar-navrail spacing-v-10',
            children: [
                StackButton('calendar', 'calendar_month', 'Calendar'),
                StackButton('todo', 'done_outline', 'To Do'),
                // StackButton(box, 'stars', 'star', 'GitHub'),
            ]
        }), false, false, 0);
        box.pack_end(contentStack, false, false, 0);
    }
})

