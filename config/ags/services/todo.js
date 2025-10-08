const { Gio, GLib } = imports.gi;
import Service from 'resource:///com/github/Aylur/ags/service.js';
import * as Utils from 'resource:///com/github/Aylur/ags/utils.js';
const { exec, execAsync } = Utils;

class TodoService extends Service {
    static {
        Service.register(this, { 'updated': [] });
    }

    _todoPath = '';
    _todoJson = [];
    _vikunjaEnabled = false;
    _vikunjaServer = '';
    _vikunjaToken = '';
    _vikunjaProjectId = null;

    async _curlJson(method, url, bodyObj = null) {
        try {
            const args = ['curl', '-sS', '-X', method, url,
                '-H', `Authorization: Bearer ${this._vikunjaToken}`,
                '-H', 'Content-Type: application/json',
                '-w', 'HTTPSTATUS:%{http_code}'];
            if (bodyObj) args.push('-d', JSON.stringify(bodyObj));
            const resp = await execAsync(args);
            const split = resp.split('HTTPSTATUS:');
            const body = split[0] ?? '';
            const status = parseInt((split[1] || '0').trim()) || 0;
            let json;
            try { json = body ? JSON.parse(body) : null; } catch { json = null; }
            return { status, body, json };
        } catch (e) {
            print(e);
            return { status: 0, body: '', json: null };
        }
    }

    async _patchTask(id, body) {
        const url = `${this._vikunjaServer}/api/v1/tasks/${id}`;
        return await this._curlJson('PATCH', url, body);
    }

    _normalizeDue(due) {
        if (!due) return null;
        if (typeof due === 'string') {
            if (/^0001-01-01/.test(due)) return null; // Vikunja sentinel for no date
        }
        try {
            const d = new Date(due);
            const y = d.getUTCFullYear();
            if (!isNaN(d.getTime()) && y <= 1) return null; // very early year -> treat as no date
        } catch {}
        return due;
    }

    refresh() { this.emit('updated'); }
    connectWidget(widget, callback) { this.connect(widget, callback, 'updated'); }
    get todo_json() { return this._todoJson; }
    _save() { Utils.writeFile(JSON.stringify(this._todoJson), this._todoPath).catch(print); }

    async add(content) {
        if (this._vikunjaEnabled) {
            try {
                const url = `${this._vikunjaServer}/api/v1/projects/${this._vikunjaProjectId}/tasks`;
                const res = await this._curlJson('PUT', url, { title: content, project_id: this._vikunjaProjectId });
                if (res.status >= 200 && res.status < 300 && res.json?.id) {
                    const task = res.json;
                    this._todoJson.push({
                        id: task.id,
                        content: task.title,
                        done: !!task.done,
                        fav: !!(task.is_favorite || task.favorite || task.isFavorite),
                        due: this._normalizeDue(task.due_date || task.dueDate || null),
                    });
                } else {
                    Utils.execAsync(['notify-send', 'Vikunja', `Failed to add task (HTTP ${res.status})`]).catch(print);
                    console.log(`Failed to add task, status: ${res.status}, body: ${res.body}`);
                }
            } catch (e) { print(e); Utils.execAsync(['notify-send', 'Vikunja', 'Error adding task']).catch(print); }
        } else {
            this._todoJson.push({ id: Date.now(), content, done: false, fav: false, due: null });
            this._save();
        }
        this.emit('updated');
    }

    async check(id) {
        const idx = this._todoJson.findIndex(t => t.id === id);
        if (idx === -1) return;
        if (this._vikunjaEnabled) {
            try {
                await execAsync([
                    'curl', '-sS', '-X', 'PATCH', `${this._vikunjaServer}/api/v1/tasks/${id}`,
                    '-H', `Authorization: Bearer ${this._vikunjaToken}`,
                    '-H', 'Content-Type: application/json',
                    '-d', JSON.stringify({ done: true }),
                ]);
                this._todoJson[idx].done = true;
            } catch (e) { print(e); }
        } else {
            this._todoJson[idx].done = true;
            this._save();
        }
        this.emit('updated');
    }

    async uncheck(id) {
        const idx = this._todoJson.findIndex(t => t.id === id);
        if (idx === -1) return;
        if (this._vikunjaEnabled) {
            try {
                await execAsync([
                    'curl', '-sS', '-X', 'PATCH', `${this._vikunjaServer}/api/v1/tasks/${id}`,
                    '-H', `Authorization: Bearer ${this._vikunjaToken}`,
                    '-H', 'Content-Type: application/json',
                    '-d', JSON.stringify({ done: false }),
                ]);
                this._todoJson[idx].done = false;
            } catch (e) { print(e); }
        } else {
            this._todoJson[idx].done = false;
            this._save();
        }
        this.emit('updated');
    }

    async remove(id) {
        const idx = this._todoJson.findIndex(t => t.id === id);
        if (idx === -1) return;
        if (this._vikunjaEnabled) {
            try {
                await execAsync([
                    'curl', '-sS', '-X', 'DELETE', `${this._vikunjaServer}/api/v1/tasks/${id}`,
                    '-H', `Authorization: Bearer ${this._vikunjaToken}`,
                ]);
            } catch (e) { print(e); }
        }
        this._todoJson.splice(idx, 1);
        if (!this._vikunjaEnabled) {
            Utils.writeFile(JSON.stringify(this._todoJson), this._todoPath).catch(print);
        }
        this.emit('updated');
    }

    async toggleFavorite(id) {
        const idx = this._todoJson.findIndex(t => t.id === id);
        if (idx === -1) return;
        const newFav = !this._todoJson[idx].fav;
        this._todoJson[idx].fav = newFav; // optimistic
        if (!this._vikunjaEnabled) {
            this._save();
            this.emit('updated');
            return;
        }
        this.emit('updated');
        try {
            const favUrl = `${this._vikunjaServer}/api/v1/tasks/${id}`;
            const res = await this._curlJson('POST', favUrl, { is_favorite: newFav });
            if (!(res.status >= 200 && res.status < 300)) {
                this._todoJson[idx].fav = !newFav; // rollback
                this.emit('updated');
                Utils.execAsync(['notify-send', 'Vikunja', `Failed to ${newFav ? 'favorite' : 'unfavorite'} task (HTTP ${res.status})`]).catch(print);
            }
        } catch (e) {
            this._todoJson[idx].fav = !newFav; // rollback
            this.emit('updated');
            print(e);
            Utils.execAsync(['notify-send', 'Vikunja', 'Error updating favorite']).catch(print);
        }
    }

    async favorite(id) { const idx = this._todoJson.findIndex(t => t.id === id); if (idx !== -1 && !this._todoJson[idx].fav) return await this.toggleFavorite(id); }
    async unfavorite(id) { const idx = this._todoJson.findIndex(t => t.id === id); if (idx !== -1 && this._todoJson[idx].fav) return await this.toggleFavorite(id); }

    async syncFromVikunja() {
        if (!this._vikunjaEnabled) return;
        try {
            let res = await this._curlJson('GET', `${this._vikunjaServer}/api/v1/projects/${this._vikunjaProjectId}/tasks`);
            let list = Array.isArray(res.json) ? res.json : null;
            if (!list) {
                res = await this._curlJson('GET', `${this._vikunjaServer}/api/v1/lists/${this._vikunjaProjectId}/tasks`);
                list = Array.isArray(res.json) ? res.json : [];
            }
            if (!Array.isArray(list)) list = [];
            const favMap = new Map(this._todoJson.map(t => [t.id, !!t.fav]));
            this._todoJson = list.map(t => ({
                id: t.id,
                content: t.title,
                done: !!t.done,
                fav: typeof t.is_favorite !== 'undefined' ? !!t.is_favorite : (typeof t.favorite !== 'undefined' ? !!t.favorite : (favMap.get(t.id) || false)),
                due: this._normalizeDue(t.due_date || t.dueDate || t.due || null),
            }));
            this.emit('updated');
        } catch (e) { print(e); }
    }

    async setDueDate(id, dateStr) {
        const idx = this._todoJson.findIndex(t => t.id === id);
        if (idx === -1) return;

        // Normalize: DD-MM-YY, DD-MM-YYYY, YYYY-MM-DD, ISO; '31-12-0' sentinel clears
        let payloadDate = null;
        if (typeof dateStr === 'string') {
            const trimmed = dateStr.trim();
            if (trimmed.length > 0) {
                if (trimmed === '31-12-0') {
                    payloadDate = null;
                } else if (/^\d{2}-\d{2}-\d{2}$/.test(trimmed)) {
                    const [dd, mm, yy] = trimmed.split('-');
                    const yyyy = `20${yy}`;
                    payloadDate = `${yyyy}-${mm}-${dd}T00:00:00Z`;
                } else if (/^\d{2}-\d{2}-\d{4}$/.test(trimmed)) {
                    const [dd, mm, yyyy] = trimmed.split('-');
                    payloadDate = `${yyyy}-${mm}-${dd}T00:00:00Z`;
                } else if (/^\d{4}-\d{2}-\d{2}$/.test(trimmed)) {
                    payloadDate = `${trimmed}T00:00:00Z`;
                } else if (/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?(Z)?$/.test(trimmed)) {
                    payloadDate = trimmed.endsWith('Z') ? trimmed : `${trimmed}`;
                } else {
                    const d = new Date(trimmed);
                    if (!isNaN(d.getTime())) payloadDate = d.toISOString();
                }
            }
        }

        const oldDue = this._todoJson[idx].due;
        this._todoJson[idx].due = payloadDate; // optimistic
        this.emit('updated');

        if (!this._vikunjaEnabled) { this._save(); return; }

        try {
            const url = `${this._vikunjaServer}/api/v1/tasks/${id}`;
            const masked = this._vikunjaToken ? `${this._vikunjaToken.slice(0, 6)}...${this._vikunjaToken.slice(-4)}` : '';
            const attempt = async (body) => {
                const dataStr = JSON.stringify(body);
                try { console.log(`[Vikunja] PATCH due_date curl (token masked): curl -sS -X PATCH '${url}' -H 'Authorization: Bearer ${masked}' -H 'Content-Type: application/json' -d '${dataStr}'`); } catch {}
                const r = await this._patchTask(id, body);
                try { console.log(`[Vikunja] PATCH status=${r.status} body=${(r.body || '').slice(0, 500)}`); } catch {}
                return r;
            };

            // First try with payloadDate/null; if clearing and it fails, try empty string
            let res = await attempt({ due_date: payloadDate });
            if (!(res.status >= 200 && res.status < 300) && payloadDate === null) {
                res = await attempt({ due_date: '' });
            }
            if (!(res.status >= 200 && res.status < 300)) {
                this._todoJson[idx].due = oldDue ?? null; // rollback
                this.emit('updated');
                Utils.execAsync(['notify-send', 'Vikunja', `Failed to set due date (HTTP ${res.status})`]).catch(print);
            }
        } catch (e) {
            print(e);
            Utils.execAsync(['notify-send', 'Vikunja', 'Error setting due date']).catch(print);
        }
    }

    constructor() {
        super();
        this._todoPath = `${GLib.get_user_state_dir()}/ags/user/todo.json`;
        try {
            this._vikunjaEnabled = !!userOptions?.vikunja?.enabled;
            this._vikunjaServer = (userOptions?.vikunja?.server || '').replace(/\/$/, '');
            this._vikunjaToken = userOptions?.vikunja?.apiToken || '';
            this._vikunjaProjectId = userOptions?.vikunja?.projectId ?? null;
        } catch {}
        if (this._vikunjaEnabled && this._vikunjaServer && this._vikunjaToken && this._vikunjaProjectId) {
            this.syncFromVikunja();
            Utils.interval(60000, () => this.syncFromVikunja());
        } else {
            try {
                const fileContents = Utils.readFile(this._todoPath);
                this._todoJson = JSON.parse(fileContents);
            } catch {
                Utils.exec(`bash -c 'mkdir -p ${GLib.get_user_cache_dir()}/ags/user'`);
                Utils.exec(`touch ${this._todoPath}`);
                Utils.writeFile('[]', this._todoPath).then(() => {
                    this._todoJson = JSON.parse(Utils.readFile(this._todoPath));
                }).catch(print);
            }
        }
    }
}

const service = new TodoService();
globalThis.todo = service;
export default service;