const { Gio, GLib } = imports.gi;
import Service from 'resource:///com/github/Aylur/ags/service.js';
import * as Utils from 'resource:///com/github/Aylur/ags/utils.js';
const { exec, execAsync } = Utils;

class TodoService extends Service {
    static {
        Service.register(
            this,
            { 'updated': [], },
        );
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

    refresh() {
        this.emit('updated');
    }

    connectWidget(widget, callback) {
        this.connect(widget, callback, 'updated');
    }

    get todo_json() {
        return this._todoJson;
    }

    _save() {
        Utils.writeFile(JSON.stringify(this._todoJson), this._todoPath)
            .catch(print);
    }

    async add(content) {
        if (this._vikunjaEnabled) {
            try {
                const url = `${this._vikunjaServer}/api/v1/projects/${this._vikunjaProjectId}/tasks`;
                // console.log('Adding task to Vikunja:', content);
                // console.log('Using URL:', url);
                // Prefer list_id (compatible with older & newer naming)
                let res = await this._curlJson('PUT', url, { title: content, project_id: this._vikunjaProjectId });
                if (res.status >= 200 && res.status < 300 && res.json?.id) {
                    const task = res.json;
                    this._todoJson.push({ id: task.id, content: task.title, done: !!task.done, fav: !!(task.is_favorite || task.favorite || task.isFavorite) });
                } else {
                    Utils.execAsync(['notify-send', 'Vikunja', `Failed to add task (HTTP ${res.status})`]).catch(print);
                    console.log(`Failed to add task, status: ${res.status}, body: ${res.body}`);
                }
            } catch (e) { print(e); Utils.execAsync(['notify-send', 'Vikunja', 'Error adding task']).catch(print); }
        } else {
            this._todoJson.push({ id: Date.now(), content, done: false, fav: false });
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
        // optimistic update
        this._todoJson[idx].fav = newFav;
        if (!this._vikunjaEnabled) {
            this._save();
            this.emit('updated');
            return;
        }
        this.emit('updated');
        try {
            // Match the user's working pattern exactly: POST /api/v1/tasks/{id} with { is_favorite: true/false }
            const favUrl = `${this._vikunjaServer}/api/v1/tasks/${id}`;
            const res = await this._curlJson('POST', favUrl, { is_favorite: newFav });
            if (!(res.status >= 200 && res.status < 300)) {
                // rollback
                this._todoJson[idx].fav = !newFav;
                this.emit('updated');
                Utils.execAsync(['notify-send', 'Vikunja', `Failed to ${newFav ? 'favorite' : 'unfavorite'} task (HTTP ${res.status})`]).catch(print);
            }
        } catch (e) {
            // rollback
            this._todoJson[idx].fav = !newFav;
            this.emit('updated');
            print(e);
            Utils.execAsync(['notify-send', 'Vikunja', 'Error updating favorite']).catch(print);
        }
    }

    async favorite(id) {
        const idx = this._todoJson.findIndex(t => t.id === id);
        if (idx === -1) return;
        if (this._todoJson[idx].fav) return;
        return await this.toggleFavorite(id);
    }

    async unfavorite(id) {
        const idx = this._todoJson.findIndex(t => t.id === id);
        if (idx === -1) return;
        if (!this._todoJson[idx].fav) return;
        return await this.toggleFavorite(id);
    }

    async syncFromVikunja() {
        if (!this._vikunjaEnabled) return;
        try {
            // Try projects route first, then lists route for older instances
            let res = await this._curlJson('GET', `${this._vikunjaServer}/api/v1/projects/${this._vikunjaProjectId}/tasks`);
            let list = Array.isArray(res.json) ? res.json : null;
            if (!list) {
                res = await this._curlJson('GET', `${this._vikunjaServer}/api/v1/lists/${this._vikunjaProjectId}/tasks`);
                list = Array.isArray(res.json) ? res.json : [];
            }
            if (!Array.isArray(list)) list = [];
            // Preserve local favorites on resync by id
            const favMap = new Map(this._todoJson.map(t => [t.id, !!t.fav]));
            this._todoJson = list.map(t => ({
                id: t.id,
                content: t.title,
                done: !!t.done,
                fav: typeof t.is_favorite !== 'undefined' ? !!t.is_favorite : (typeof t.favorite !== 'undefined' ? !!t.favorite : (favMap.get(t.id) || false)),
            }));
            this.emit('updated');
        } catch (e) { print(e); }
    }

    constructor() {
        super();
        this._todoPath = `${GLib.get_user_state_dir()}/ags/user/todo.json`;
        // Load config
        try {
            this._vikunjaEnabled = !!userOptions?.vikunja?.enabled;
            this._vikunjaServer = (userOptions?.vikunja?.server || '').replace(/\/$/, '');
            this._vikunjaToken = userOptions?.vikunja?.apiToken || '';
            this._vikunjaProjectId = userOptions?.vikunja?.projectId ?? null;
        } catch { }
        if (this._vikunjaEnabled && this._vikunjaServer && this._vikunjaToken && this._vikunjaProjectId) {
            // Initialize from Vikunja
            this.syncFromVikunja();
            // Periodic sync every 60s
            Utils.interval(60000, () => this.syncFromVikunja());
        } else {
            // Fallback to local JSON file
            try {
                const fileContents = Utils.readFile(this._todoPath);
                this._todoJson = JSON.parse(fileContents);
            }
            catch {
                Utils.exec(`bash -c 'mkdir -p ${GLib.get_user_cache_dir()}/ags/user'`);
                Utils.exec(`touch ${this._todoPath}`);
                Utils.writeFile("[]", this._todoPath).then(() => {
                    this._todoJson = JSON.parse(Utils.readFile(this._todoPath))
                }).catch(print);
            }
        }
    }
}

// the singleton instance
const service = new TodoService();

// make it global for easy use with cli
globalThis.todo = service;

// export to use in other modules
export default service;