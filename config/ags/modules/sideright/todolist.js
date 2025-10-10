import Widget from 'resource:///com/github/Aylur/ags/widget.js';
import * as Utils from 'resource:///com/github/Aylur/ags/utils.js';
const { Box, Button, Label, Revealer } = Widget;
import { MaterialIcon } from '../.commonwidgets/materialicon.js';
import { TabContainer } from '../.commonwidgets/tabcontainer.js';
import Todo from "../../services/todo.js";
import { setupCursorHover } from '../.widgetutils/cursorhover.js';

// Local state for filtering and sorting
let filterText = '';
// sortMode: 'alpha-asc' | 'alpha-desc' | 'date-asc' | 'date-desc'
let sortMode = 'date-asc';
// whether to prioritize favorites first in sorting
let favoritesFirst = true;

const normalize = (s) => (s || '').toString().toLowerCase();

function parseDue(due) {
    if (!due) return null;
    if (typeof due === 'string' && /^0001-01-01/.test(due)) return null; // Vikunja sentinel
    const d = new Date(due);
    if (isNaN(d.getTime())) return null;
    if (d.getUTCFullYear() <= 1) return null;
    return d;
}

function sameDayUTC(dateObj, y, m, d) {
    return (
        dateObj.getUTCFullYear() === y &&
        dateObj.getUTCMonth() + 1 === m &&
        dateObj.getUTCDate() === d
    );
}

function formatDDMMYY(y, m, d) {
    const yy = String(y).slice(-2);
    const mm = String(m).padStart(2, '0');
    const dd = String(d).padStart(2, '0');
    return `${dd}-${mm}-${yy}`;
}

function applyFilterAndSort(tasks, isDone) {
    const ft = normalize(filterText);
    const df = Todo.date_filter; // 'YYYY-MM-DD' or null
    let arr = tasks.filter(t => {
        if (t.done !== isDone) return false;
        if (ft !== '' && !normalize(t.content).includes(ft)) return false;
        if (df) {
            if (!t.due) return false;
            const d = parseDue(t.due);
            if (!d) return false;
            const [y, m, day] = df.split('-').map(x => parseInt(x, 10));
            if (!sameDayUTC(d, y, m, day)) return false;
        }
        return true;
    });
    arr.sort((a, b) => {
        // Favorites first (optional)
        if (favoritesFirst) {
            const favDiff = (b.fav === true) - (a.fav === true);
            if (favDiff !== 0) return favDiff;
        }
        if (sortMode.startsWith('date-')) {
            const da = parseDue(a.due);
            const db = parseDue(b.due);
            // Nulls last for asc, last for desc too but reverse order
            if (da && !db) return -1;
            if (!da && db) return 1;
            if (!da && !db) return 0;
            const diff = da.getTime() - db.getTime();
            return sortMode === 'date-desc' ? -diff : diff;
        }
        const A = normalize(a.content);
        const B = normalize(b.content);
        const cmp = A.localeCompare(B);
        return sortMode === 'alpha-desc' ? -cmp : cmp;
    });
    return arr;
}

const TodoListItem = (task, id, isDone, isEven = false) => {
    const taskName = Widget.Label({
        hexpand: true,
        xalign: 0,
        wrap: true,
        className: 'txt txt-small sidebar-todo-txt',
        label: task.content,
        selectable: true,
    });
    const dueText = (() => {
        const d = parseDue(task.due);
        if (!d) return 'No date';
        // Show DD-MM-YY per request
        const y = String(d.getUTCFullYear()).slice(-2);
        const m = String(d.getUTCMonth() + 1).padStart(2, '0');
        const day = String(d.getUTCDate()).padStart(2, '0');
        return `${day}-${m}-${y}`;
    })();
    const dueLabel = Button({
        className: 'txt txt-subtext sidebar-todo-due',
        child: Label({ className: 'txt txt-subtext', label: dueText, xalign: 0 }),
        hpack: 'start',
        onClicked: () => {
            dueEditorRevealer.revealChild = !dueEditorRevealer.revealChild;
            if (dueEditorRevealer.revealChild) dueEntry.grab_focus();
        },
        setup: setupCursorHover,
    });

    // Inline editor for due date
    const dueEntry = Widget.Entry({
        className: 'txt-small sidebar-todo-due-entry',
        placeholderText: 'DD-MM-YY',
        text: (() => {
            const d = parseDue(task.due);
            if (!d) return '';
            const y = String(d.getUTCFullYear()).slice(-2);
            const m = String(d.getUTCMonth() + 1).padStart(2, '0');
            const day = String(d.getUTCDate()).padStart(2, '0');
            return `${day}-${m}-${y}`;
        })(),
        onAccept: ({ text }) => {
            const v = (text || '').trim();
            Todo.setDueDate(task.id ?? id, v === '' ? null : v);
        },
    });
    const dueEditToggle = Button({
        className: 'txt-small sidebar-todo-item-action',
        child: MaterialIcon('event', 'norm', { vpack: 'center' }),
        onClicked: () => {
            dueEditorRevealer.revealChild = !dueEditorRevealer.revealChild;
            if (dueEditorRevealer.revealChild) dueEntry.grab_focus();
        },
        setup: setupCursorHover,
    });
    const dueClearBtn = Button({
        className: 'txt-small sidebar-todo-item-action',
        child: MaterialIcon('event_busy', 'norm', { vpack: 'center' }),
        tooltipText: 'Clear date',
        onClicked: () => Todo.setDueDate(task.id ?? id, null),
        setup: setupCursorHover,
    });
    const dueSaveBtn = Button({
        className: 'txt-small sidebar-todo-item-action',
        child: MaterialIcon('save', 'norm', { vpack: 'center' }),
        tooltipText: 'Save date',
        onClicked: () => {
            const v = (dueEntry.text || '').trim();
            Todo.setDueDate(task.id ?? id, v === '' ? null : v);
        },
        setup: setupCursorHover,
    });
    // Quick picks for faster date setting
    const quickPick = (days) => {
        const now = new Date();
        const d = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + days));
        const y = d.getUTCFullYear();
        const m = d.getUTCMonth() + 1;
        const day = d.getUTCDate();
        return formatDDMMYY(y, m, day);
    };
    const quickRow = Box({
        className: 'spacing-h-5',
        children: [
            Button({ className: 'txt-small sidebar-todo-item-action', child: Label({ label: 'Today' }), onClicked: () => Todo.setDueDate(task.id ?? id, quickPick(0)), setup: setupCursorHover }),
            Button({ className: 'txt-small sidebar-todo-item-action', child: Label({ label: 'Tomorrow' }), onClicked: () => Todo.setDueDate(task.id ?? id, quickPick(1)), setup: setupCursorHover }),
            Button({ className: 'txt-small sidebar-todo-item-action', child: Label({ label: '+7d' }), onClicked: () => Todo.setDueDate(task.id ?? id, quickPick(7)), setup: setupCursorHover }),
        ]
    });
    const dueEditor = Box({
        className: 'spacing-h-5',
        children: [
            dueEntry,
            // spacer to push clear to the far right
            Box({ hexpand: true }),
            quickRow,
            dueSaveBtn,
            dueClearBtn,
        ],
    });
    const dueEditorRevealer = Revealer({
        transition: 'slide_down',
        transitionDuration: userOptions.animations.durationLarge,
        revealChild: false,
        child: dueEditor,
    });
    // Use Unicode stars to avoid GTK CSS errors and guarantee visible filled/outline
    const starIcon = Label({ className: 'txt txt-norm', label: task.fav ? '★' : '☆', vpack: 'center' });
    const actions = Box({
        hpack: 'end',
        className: 'spacing-h-5 sidebar-todo-actions',
        children: [
            Widget.Button({ // Favorite / Unfavorite
                vpack: 'center',
                className: 'txt sidebar-todo-item-action',
                child: starIcon,
                onClicked: () => {
                    const newFav = !(task.fav === true);
                    // update icon immediately by switching glyph
                    starIcon.label = newFav ? '★' : '☆';
                    Todo.toggleFavorite(task.id ?? id);
                },
                setup: setupCursorHover,
            }),
            Widget.Button({ // Check/Uncheck
                vpack: 'center',
                className: 'txt sidebar-todo-item-action',
                child: MaterialIcon(`${isDone ? 'remove_done' : 'check'}`, 'norm', { vpack: 'center' }),
                onClicked: (self) => {
                    const contentWidth = todoContent.get_allocated_width();
                    crosser.toggleClassName('sidebar-todo-crosser-crossed', true);
                    crosser.css = `margin-left: -${contentWidth}px;`;
                    Utils.timeout(200, () => {
                        widgetRevealer.revealChild = false;
                    })
                    Utils.timeout(350, () => {
                        if (isDone)
                            Todo.uncheck(task.id ?? id);
                        else
                            Todo.check(task.id ?? id);
                    })
                },
                setup: setupCursorHover,
            }),
            Widget.Button({ // Remove
                vpack: 'center',
                className: 'txt sidebar-todo-item-action',
                child: MaterialIcon('delete_forever', 'norm', { vpack: 'center' }),
                onClicked: () => {
                    const contentWidth = todoContent.get_allocated_width();
                    crosser.toggleClassName('sidebar-todo-crosser-removed', true);
                    crosser.css = `margin-left: -${contentWidth}px;`;
                    Utils.timeout(200, () => {
                        widgetRevealer.revealChild = false;
                    })
                    Utils.timeout(350, () => {
                        Todo.remove(task.id ?? id);
                    })
                },
                setup: setupCursorHover,
            }),
            dueEditToggle,
        ]
    })
    const crosser = Widget.Box({
        className: 'sidebar-todo-crosser',
    });
    const todoContent = Widget.Box({
        className: 'sidebar-todo-item spacing-h-5',
        children: [
            Widget.Box({
                vertical: true,
                hexpand: true,
                children: [
                    // Title row
                    taskName,
                    // Bottom row: due (left) + actions (right)
                    Box({
                        className: 'spacing-h-5',
                        children: [
                            Box({ hexpand: true, children: [dueLabel] }),
                            actions,
                        ]
                    }),
                    // Hidden editor
                    dueEditorRevealer,
                ]
            }),
            crosser,
        ]
    });
    const widgetRevealer = Widget.Revealer({
        revealChild: true,
        transition: 'slide_down',
        transitionDuration: userOptions.animations.durationLarge,
        child: todoContent,
    })
    return Box({
        homogeneous: true,
        children: [widgetRevealer]
    });
}

const todoItems = (isDone) => Widget.Scrollable({
    hscroll: 'never',
    vscroll: 'automatic',
    child: Widget.Box({
        vertical: true,
        className: 'spacing-v-5',
        setup: (self) => self
            .hook(Todo, (self) => {
                const items = applyFilterAndSort(Todo.todo_json, isDone);
                self.children = items.map((task, i) => TodoListItem(task, task.id ?? i, isDone));
                if (self.children.length == 0) {
                    self.homogeneous = true;
                    self.children = [
                        Widget.Box({
                            hexpand: true,
                            vertical: true,
                            vpack: 'center',
                            className: 'txt txt-subtext',
                            children: [
                                MaterialIcon(`${isDone ? 'checklist' : 'check_circle'}`, 'gigantic'),
                                Label({ label: ftLabel(isDone) })
                            ]
                        })
                    ]
                }
                else self.homogeneous = false;
            }, 'updated')
        ,
    }),
    setup: (listContents) => {
        const vScrollbar = listContents.get_vscrollbar();
        vScrollbar.get_style_context().add_class('sidebar-scrollbar');
    }
});

function ftLabel(isDone) {
    const hasFilter = normalize(filterText) !== '';
    if (hasFilter) return 'No tasks match your search';
    return `${isDone ? 'Finished tasks will go here' : 'Nothing here!'}`;
}

const SearchSortControls = () => {
    // Search button and entry (like New task controls)
    const searchButton = Revealer({
        transition: 'slide_left',
        transitionDuration: userOptions.animations.durationLarge,
        revealChild: true,
        child: Button({
            className: 'txt-norm icon-material sidebar-todo-add',
            halign: 'start',
            vpack: 'center',
            label: 'search',
            setup: setupCursorHover,
            onClicked: () => {
                searchButton.revealChild = false;
                searchEntryRevealer.revealChild = true;
                searchCancel.revealChild = true;
                searchEntry.grab_focus();
            }
        })
    });
    const searchCancel = Revealer({
        transition: 'slide_right',
        transitionDuration: userOptions.animations.durationLarge,
        revealChild: false,
        child: Button({
            className: 'txt-norm icon-material sidebar-todo-add',
            halign: 'start',
            vpack: 'center',
            label: 'close',
            setup: setupCursorHover,
            onClicked: () => {
                searchEntryRevealer.revealChild = false;
                searchCancel.revealChild = false;
                searchButton.revealChild = true;
                filterText = '';
                Todo.refresh();
            }
        })
    });
    const searchEntry = Widget.Entry({
        vpack: 'center',
        className: 'txt-small sidebar-todo-entry',
        placeholderText: 'Filter tasks...',
        onChange: ({ text }) => { filterText = text; Todo.refresh(); },
    });
    const searchEntryRevealer = Revealer({
        transition: 'slide_right',
        transitionDuration: userOptions.animations.durationLarge,
        revealChild: false,
        child: searchEntry,
    });

    // Sort toggle button cycles modes: alpha-asc -> alpha-desc -> date-asc -> date-desc
    const sortIcon = Label({
        className: 'txt txt-norm',
        label: (sortMode === 'alpha-asc') ? 'A→Z' : (sortMode === 'alpha-desc') ? 'Z→A' : (sortMode === 'date-asc') ? 'Date ↑' : 'Date ↓'
    });
    const sortButton = Button({
        className: 'txt-norm sidebar-todo-add',
        halign: 'start',
        vpack: 'center',
        child: Box({
            className: 'spacing-h-3',
            children: [MaterialIcon('sort', 'norm', { vpack: 'center' }), sortIcon]
        }),
        setup: (btn) => {
            setupCursorHover(btn);
            btn.hook(Todo, () => {}, 'updated');
        },
        onClicked: () => {
            const order = ['alpha-asc', 'alpha-desc', 'date-asc', 'date-desc'];
            const idx = order.indexOf(sortMode);
            sortMode = order[(idx + 1) % order.length];
            // Update label
            if (sortMode === 'alpha-asc') sortIcon.label = 'A→Z';
            else if (sortMode === 'alpha-desc') sortIcon.label = 'Z→A';
            else if (sortMode === 'date-asc') sortIcon.label = 'Date ↑';
            else sortIcon.label = 'Date ↓';
            Todo.refresh();
        }
    });

    // Favorites-first toggle
    const favIcon = Label({ className: 'txt txt-norm', label: favoritesFirst ? '★1st' : '☆any' });
    const favoritesToggle = Button({
        className: 'txt-norm sidebar-todo-add',
        halign: 'start',
        vpack: 'center',
        tooltipText: 'Toggle favorites first',
        child: Box({ className: 'spacing-h-3', children: [MaterialIcon('grade', 'norm', { vpack: 'center' }), favIcon] }),
        setup: (btn) => setupCursorHover(btn),
        onClicked: () => {
            favoritesFirst = !favoritesFirst;
            favIcon.label = favoritesFirst ? '★1st' : '☆any';
            Todo.refresh();
        }
    });

    // Date filter chip (shows selected date or All dates), with a small editor revealer and quick picks
    const filterLabel = Label({ className: 'txt txt-norm', label: '' });
    const filterButton = Button({
        className: 'txt-norm sidebar-todo-add',
        halign: 'start',
        vpack: 'center',
        child: Box({ className: 'spacing-h-3', children: [MaterialIcon('event', 'norm', { vpack: 'center' }), filterLabel] }),
        setup: (btn) => btn.hook(Todo, () => {
            const df = Todo.date_filter;
            if (df) {
                const [y, m, d] = df.split('-').map(x => parseInt(x, 10));
                filterLabel.label = formatDDMMYY(y, m, d);
                btn.tooltipText = 'Click to clear date filter';
            } else {
                filterLabel.label = 'All dates';
                btn.tooltipText = 'Click to set a date filter';
            }
        }, 'updated'),
        onClicked: () => {
            const df = Todo.date_filter;
            if (df) {
                // Clear immediately when a filter is active
                Todo.clearDateFilter();
                filterEditorRevealer.revealChild = false;
            } else {
                // No filter: open editor to set one
                filterEditorRevealer.revealChild = !filterEditorRevealer.revealChild;
                if (filterEditorRevealer.revealChild) filterEntry.grab_focus();
            }
        },
    });
    const filterEntry = Widget.Entry({
        vpack: 'center',
        className: 'txt-small sidebar-todo-entry',
        placeholderText: 'Filter date (DD-MM-YY)',
        onAccept: ({ text }) => {
            const v = (text || '').trim();
            if (v === '') Todo.clearDateFilter();
            else Todo.setDateFilter(v);
        },
    });
    const filterQuickRow = Box({
        className: 'spacing-h-5',
        children: [
            Button({ className: 'txt-small sidebar-todo-item-action', child: Label({ label: 'Today' }), onClicked: () => { const n = new Date(); const d = new Date(Date.UTC(n.getUTCFullYear(), n.getUTCMonth(), n.getUTCDate())); Todo.setDateFilter(`${d.getUTCFullYear()}-${String(d.getUTCMonth()+1).padStart(2,'0')}-${String(d.getUTCDate()).padStart(2,'0')}`); }, setup: setupCursorHover }),
            Button({ className: 'txt-small sidebar-todo-item-action', child: Label({ label: 'Tomorrow' }), onClicked: () => { const n = new Date(); const d = new Date(Date.UTC(n.getUTCFullYear(), n.getUTCMonth(), n.getUTCDate()+1)); Todo.setDateFilter(`${d.getUTCFullYear()}-${String(d.getUTCMonth()+1).padStart(2,'0')}-${String(d.getUTCDate()).padStart(2,'0')}`); }, setup: setupCursorHover }),
            Button({ className: 'txt-small sidebar-todo-item-action', child: Label({ label: 'Clear' }), onClicked: () => Todo.clearDateFilter(), setup: setupCursorHover }),
        ]
    });
    const filterEditorRevealer = Revealer({
        transition: 'slide_right',
        transitionDuration: userOptions.animations.durationLarge,
        revealChild: false,
        child: Box({ className: 'spacing-h-5', children: [filterEntry, filterQuickRow] }),
    });

    // Small hoverable cheatsheet for date inputs
    const cheatText = [
        'Date input tips:',
        '• Formats: DD-MM-YY, DD-MM-YYYY, YYYY-MM-DD, 101025, 1010, 10',
        '• Words: today/now/n/0, yesterday/yes/y, tomorrow/tmr/tmrw/t',
        '• N: 0, +1, +7, in 3 days',
        '• Weekday: monday..sunday, mon/tues/wed/thu/fri/sat/sun',
        '• DOW numbers: 1..7 (Mon..Sun)',
        "• Prefix 'next' adds +7 (e.g., next fri, next 1)",
        '• Clear: empty input',
    ].join('\n');
    const helpBtn = Button({
        className: 'txt-norm sidebar-todo-add',
        halign: 'start',
        vpack: 'center',
        tooltipText: cheatText,
        child: MaterialIcon('help_outline', 'norm', { vpack: 'center' }),
        setup: setupCursorHover,
    });

    return Box({
        className: 'spacing-h-5',
        children: [searchCancel, searchEntryRevealer, searchButton, sortButton, favoritesToggle, filterButton, filterEditorRevealer, helpBtn]
    });
}

const UndoneTodoList = () => {
    const searchSort = SearchSortControls();
    const newTaskButton = Revealer({
        transition: 'slide_left',
        transitionDuration: userOptions.animations.durationLarge,
        revealChild: true,
        child: Button({
            className: 'txt-small sidebar-todo-new',
            halign: 'end',
            vpack: 'center',
            label: '+ New task',
            setup: setupCursorHover,
            onClicked: (self) => {
                newTaskButton.revealChild = false;
                newTaskEntryRevealer.revealChild = true;
                confirmAddTask.revealChild = true;
                cancelAddTask.revealChild = true;
                newTaskEntry.grab_focus();
            }
        })
    });
    const cancelAddTask = Revealer({
        transition: 'slide_right',
        transitionDuration: userOptions.animations.durationLarge,
        revealChild: false,
        child: Button({
            className: 'txt-norm icon-material sidebar-todo-add',
            halign: 'end',
            vpack: 'center',
            label: 'close',
            setup: setupCursorHover,
            onClicked: (self) => {
                newTaskEntryRevealer.revealChild = false;
                confirmAddTask.revealChild = false;
                cancelAddTask.revealChild = false;
                newTaskButton.revealChild = true;
                newTaskEntry.text = '';
            }
        })
    });
    const newTaskEntry = Widget.Entry({
        // hexpand: true,
        vpack: 'center',
        className: 'txt-small sidebar-todo-entry',
        placeholderText: 'Add a task...',
        onAccept: ({ text }) => {
            if (text == '') return;
            Todo.add(text)
            newTaskEntry.text = '';
        },
        onChange: ({ text }) => confirmAddTask.child.toggleClassName('sidebar-todo-add-available', text != ''),
    });
    const newTaskEntryRevealer = Revealer({
        transition: 'slide_right',
        transitionDuration: userOptions.animations.durationLarge,
        revealChild: false,
        child: newTaskEntry,
    });
    const confirmAddTask = Revealer({
        transition: 'slide_right',
        transitionDuration: userOptions.animations.durationLarge,
        revealChild: false,
        child: Button({
            className: 'txt-norm icon-material sidebar-todo-add',
            halign: 'end',
            vpack: 'center',
            label: 'arrow_upward',
            setup: setupCursorHover,
            onClicked: (self) => {
                if (newTaskEntry.text == '') return;
                Todo.add(newTaskEntry.text);
                newTaskEntry.text = '';
            }
        })
    });
    return Box({ // The list, with a New button
        vertical: true,
        className: 'spacing-v-5',
        setup: (box) => {
            box.pack_start(searchSort, false, false, 0);
            box.pack_start(todoItems(false), true, true, 0);
            box.pack_start(Box({
                setup: (self) => {
                    self.pack_start(cancelAddTask, false, false, 0);
                    self.pack_start(newTaskEntryRevealer, true, true, 0);
                    self.pack_start(confirmAddTask, false, false, 0);
                    self.pack_start(newTaskButton, false, false, 0);
                }
            }), false, false, 0);
        },
    });
}

const DoneTodoList = () => {
    const searchSort = SearchSortControls();
    return Box({
        vertical: true,
        className: 'spacing-v-5',
        setup: (box) => {
            box.pack_start(searchSort, false, false, 0);
            box.pack_start(todoItems(true), true, true, 0);
        },
    });
}

export const TodoWidget = () => TabContainer({
    icons: ['format_list_bulleted', 'task_alt'],
    names: ['Unfinished', 'Done'],
    children: [
        UndoneTodoList(),
        DoneTodoList(),
    ]
})
