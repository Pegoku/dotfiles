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
    _activeDateFilter = null; // 'YYYY-MM-DD' or null

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

    async _postTask(id, body) {
        const url = `${this._vikunjaServer}/api/v1/tasks/${id}`;
        return await this._curlJson('POST', url, body);
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
    get date_filter() { return this._activeDateFilter; }
    _save() { Utils.writeFile(JSON.stringify(this._todoJson), this._todoPath).catch(print); }

    _parseDateFilter(dateStr) {
        if (!dateStr || typeof dateStr !== 'string') return null;
        const t = dateStr.trim().toLowerCase();
        if (!t) return null;
        // Special clear sentinel
        if (t === '31-12-0') return null;

        // Natural language
        const now = new Date();
        const toISODate = (d) => `${d.getUTCFullYear()}-${String(d.getUTCMonth()+1).padStart(2,'0')}-${String(d.getUTCDate()).padStart(2,'0')}`;
        if (t === 'today' || t === 't') {
            const d = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
            return toISODate(d);
        }
        if (t === 'tomorrow' || t === 'tmr' || t === 'tom') {
            const d = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()+1));
            return toISODate(d);
        }
        const plusMatch = t.match(/^(\+|in\s+)(\d{1,3})(d|day|days)?$/);
        if (plusMatch) {
            const n = parseInt(plusMatch[2], 10);
            const d = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()+n));
            return toISODate(d);
        }

        // Accept separators '-', '/', '.', ' '
        const norm = t.replace(/[\/.\s]/g, '-');
        if (/^\d{2}-\d{2}-\d{2}$/.test(norm)) {
            const [dd, mm, yy] = norm.split('-');
            const yyyy = `20${yy}`;
            return `${yyyy}-${mm}-${dd}`;
        }
        if (/^\d{2}-\d{2}-\d{4}$/.test(norm)) {
            const [dd, mm, yyyy] = norm.split('-');
            return `${yyyy}-${mm}-${dd}`;
        }
        if (/^\d{4}-\d{2}-\d{2}$/.test(norm)) return norm;

        // Bare digits: dd, ddmm, ddmmyy, ddmmyyyy
        const digits = t.replace(/\D/g, '');
        const Y = now.getUTCFullYear();
        const M = String(now.getUTCMonth()+1).padStart(2,'0');
        if (digits.length === 2) {
            // dd -> current month/year
            const dd = digits;
            return `${Y}-${M}-${dd}`;
        }
        if (digits.length === 4) {
            // ddmm -> current year
            const dd = digits.slice(0,2);
            const mm = digits.slice(2,4);
            return `${Y}-${mm}-${dd}`;
        }
        if (digits.length === 6) {
            // ddmmyy -> 20yy
            const dd = digits.slice(0,2);
            const mm = digits.slice(2,4);
            const yy = digits.slice(4,6);
            const yyyy = `20${yy}`;
            return `${yyyy}-${mm}-${dd}`;
        }
        if (digits.length === 8) {
            // ddmmyyyy
            const dd = digits.slice(0,2);
            const mm = digits.slice(2,4);
            const yyyy = digits.slice(4,8);
            return `${yyyy}-${mm}-${dd}`;
        }

        // Fallback to Date parsing
        const d = new Date(t);
        if (!isNaN(d.getTime())) return toISODate(new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate())));
        return null;
    }

    setDateFilter(dateStr) {
        const parsed = this._parseDateFilter(dateStr);
        this._activeDateFilter = parsed;
        this.emit('updated');
    }

    clearDateFilter() {
        this._activeDateFilter = null;
        this.emit('updated');
    }

    async add(content) {
        if (this._vikunjaEnabled) {
            try {
                const url = `${this._vikunjaServer}/api/v1/projects/${this._vikunjaProjectId}/tasks`;
                const payload = { title: content, project_id: this._vikunjaProjectId };
                if (this._activeDateFilter) payload.due_date = `${this._activeDateFilter}T00:00:00Z`;
                const res = await this._curlJson('PUT', url, payload);
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
            let due = null;
            if (this._activeDateFilter) due = `${this._activeDateFilter}T00:00:00Z`;
            this._todoJson.push({ id: Date.now(), content, done: false, fav: false, due });
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

        // Normalize manual inputs using extended parser
        let payloadDate = null;
        if (typeof dateStr === 'string') {
            const parsed = this._parseDateFilter(dateStr); // returns 'YYYY-MM-DD' or null
            if (parsed) payloadDate = `${parsed}T00:00:00Z`;
            else payloadDate = null; // includes sentinel 31-12-0 and empty
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
                try { console.log(`[Vikunja] POST due_date curl (token masked): curl -sS -X POST '${url}' -H 'Authorization: Bearer ${masked}' -H 'Content-Type: application/json' -d '${dataStr}'`); } catch {}
                const r = await this._postTask(id, body);
                try { console.log(`[Vikunja] POST status=${r.status} body=${(r.body || '').slice(0, 500)}`); } catch {}
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