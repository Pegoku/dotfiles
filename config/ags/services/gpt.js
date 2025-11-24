import Service from 'resource:///com/github/Aylur/ags/service.js';
import * as Utils from 'resource:///com/github/Aylur/ags/utils.js';

import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Soup from 'gi://Soup?version=3.0';
import { fileExists } from '../modules/.miscutils/files.js';
import userOptions from '../user_options.js';
const ByteArray = imports.byteArray;

const PROVIDERS = Object.assign({
    // Built-in providers can go here if needed
}, userOptions?.ai?.extraGptModels || {})

// Simple debug toggle (enable by adding ai.debug = true in user options)
const DEBUG = !!userOptions?.ai?.debug;
function dbg(...args) { if (DEBUG) print('[AI DEBUG]', ...args); }
dbg('Loaded providers:', Object.keys(PROVIDERS));

// Custom prompt
const initMessages =
    [
        { role: "assistant", content: "Hi, you are ChatGPT, an AI assistant.", }
    ];

Utils.exec(`mkdir -p ${GLib.get_user_state_dir()}/ags/user/ai`);

class GPTMessage extends Service {
    static {
        Service.register(this,
            {
                'delta': ['string'],
            },
            {
                'content': ['string'],
                'thinking': ['boolean'],
                'done': ['boolean'],
                'meta': ['string'],
            });
    }

    _role = '';
    _content = '';
    _thinking;
    _done = false;
    _meta = '';

    constructor(role, content, thinking = true, done = false) {
        super();
        this._role = role;
        this._content = content;
        this._thinking = thinking;
        this._done = done;
    }

    get done() { return this._done }
    set done(isDone) { this._done = isDone; this.notify('done') }

    get role() { return this._role }
    set role(role) { this._role = role; this.emit('changed') }

    get content() { return this._content }
    set content(content) {
        this._content = content;
        this.notify('content')
        this.emit('changed')
    }

    get meta() { return this._meta }
    set meta(value) {
        this._meta = value ?? '';
        this.notify('meta');
        this.emit('changed');
    }

    get label() { return this._parserState.parsed + this._parserState.stack.join('') }

    get thinking() { return this._thinking }
    set thinking(value) {
        this._thinking = value;
        this.notify('thinking')
        this.emit('changed')
    }

    addDelta(delta) {
        if (this.thinking) {
            this.thinking = false;
            this.content = delta;
        }
        else {
            this.content += delta;
        }
        this.emit('delta', delta);
    }
}

class GPTService extends Service {
    static {
        Service.register(this, {
            'initialized': [],
            'clear': [],
            'newMsg': ['int'],
            'hasKey': ['boolean'],
            'providerChanged': [],
        });
    }

    _assistantPrompt = true;
    _currentProvider = userOptions.ai.defaultGPTProvider in PROVIDERS
        ? userOptions.ai.defaultGPTProvider
        : Object.keys(PROVIDERS)[0];
    _requestCount = 0;
    _temperature = userOptions.ai.defaultTemperature;
    _messages = [];
    _key = '';
    _key_file_location = `${GLib.get_user_state_dir()}/ags/user/ai/${PROVIDERS[this._currentProvider]['key_file']}`;
    _url = GLib.Uri.parse(PROVIDERS[this._currentProvider]['base_url'], GLib.UriFlags.NONE);

    _decoder = new TextDecoder();

    _initChecks() {
        this._key_file_location = `${GLib.get_user_state_dir()}/ags/user/ai/${PROVIDERS[this._currentProvider]['key_file']}`;
        if (fileExists(this._key_file_location)) this._key = Utils.readFile(this._key_file_location).trim();
        else this.emit('hasKey', false);
        this._url = GLib.Uri.parse(PROVIDERS[this._currentProvider]['base_url'], GLib.UriFlags.NONE);
    }

    constructor() {
        super();
        this._initChecks();

        if (this._assistantPrompt) this._messages = [...initMessages];
        else this._messages = [];

        this.emit('initialized');
        dbg('GPTService initialized', {
            assistantPrompt: this._assistantPrompt,
            provider: this._currentProvider,
            model: PROVIDERS[this._currentProvider]?.model,
            keyPresent: this._key.length > 0,
        });
    }

    get modelName() { return PROVIDERS[this._currentProvider]['model'] }
    get getKeyUrl() { return PROVIDERS[this._currentProvider]['key_get_url'] }
    get providerID() { return this._currentProvider }
    set providerID(value) {
        this._currentProvider = value;
        this.emit('providerChanged');
        this._initChecks();
        dbg('Provider changed', {
            provider: this._currentProvider,
            model: PROVIDERS[this._currentProvider]?.model,
            base_url: PROVIDERS[this._currentProvider]?.base_url,
        });
    }
    get providers() { return PROVIDERS }

    get keyPath() { return this._key_file_location }
    get key() { return this._key }
    set key(keyValue) {
        this._key = keyValue;
        Utils.writeFile(this._key, this._key_file_location)
            .then(this.emit('hasKey', true))
            .catch(print);
    }

    get temperature() { return this._temperature }
    set temperature(value) { this._temperature = value; }

    get messages() { return this._messages }
    get lastMessage() { return this._messages[this._messages.length - 1] }

    clear() {
        if (this._assistantPrompt)
            this._messages = [...initMessages];
        else
            this._messages = [];
        this.emit('clear');
    }

    get assistantPrompt() { return this._assistantPrompt; }
    set assistantPrompt(value) {
        this._assistantPrompt = value;
        if (value) this._messages = [...initMessages];
        else this._messages = [];
    }

    readResponse(stream, aiResponse) {
        aiResponse.thinking = false;
        stream.read_line_async(
            0, null,
            (stream, res) => {
                if (!stream) return;
                const [bytes] = stream.read_line_finish(res);
                const line = this._decoder.decode(bytes);
                if (line && line.length > 0) dbg('SSE line', line.slice(0, 160));
                if (line && line.trim() !== '') {
                    if (line.startsWith(':')) {
                        this.readResponse(stream, aiResponse);
                        return;
                    }
                    let data = line.startsWith('data: ') ? line.substr(6) : line;
                    if (data == '[DONE]') {
                        aiResponse.done = true;
                        if (aiResponse._startMono) {
                            const endMono = GLib.get_monotonic_time();
                            const elapsedMs = Math.max(0, Math.round((endMono - aiResponse._startMono) / 1000));
                            const timeStr = `${(elapsedMs / 1000).toFixed(1)}s`;
                            if (!aiResponse.meta || !aiResponse.meta.includes('time:'))
                                aiResponse.meta = `time: ${timeStr}`;
                        }
                        return;
                    }
                    try {
                        const result = JSON.parse(data);
                        dbg('Parsed SSE JSON delta', Object.keys(result));
                        const finishReason = result?.choices?.[0]?.finish_reason;
                        if (finishReason) {
                            aiResponse.done = true;
                            // time meta if available
                            if (aiResponse._startMono) {
                                const endMono = GLib.get_monotonic_time();
                                const elapsedMs = Math.max(0, Math.round((endMono - aiResponse._startMono) / 1000));
                                const timeStr = `${(elapsedMs / 1000).toFixed(1)}s`;
                                aiResponse.meta = `time: ${timeStr}`;
                            }
                            return;
                        }
                        const delta = result?.choices?.[0]?.delta?.content ?? '';
                        if (delta && delta.length > 0)
                            aiResponse.addDelta(delta);
                        // print(result.choices[0])
                    }
                    catch {
                        aiResponse.addDelta(line + '\n');
                    }
                }
                this.readResponse(stream, aiResponse);
            });
    }

    addMessage(role, message) {
        this._messages.push(new GPTMessage(role, message));
        this.emit('newMsg', this._messages.length - 1);
    }

    send(msg) {
        this._messages.push(new GPTMessage('user', msg, false, true));
        this.emit('newMsg', this._messages.length - 1);
        const aiResponse = new GPTMessage('assistant', '', true, false)

        // Safety: if no providers configured, mark response as error
        if (!this._currentProvider || !PROVIDERS[this._currentProvider]) {
            aiResponse.thinking = false;
            aiResponse.content = 'Error: No AI providers configured. Add ai.extraGptModels in user_options.js';
            aiResponse.done = true;
            this._messages.push(aiResponse);
            this.emit('newMsg', this._messages.length - 1);
            dbg('Abort send - no provider');
            return;
        }

        const providerInfo = PROVIDERS[this._currentProvider];
        const streamEnabled = providerInfo?.supports_stream === true;
        const body = {
            model: providerInfo['model'],
            messages: this._messages.map(msg => { let m = { role: msg.role, content: msg.content }; return m; }),
            temperature: this._temperature,
            // temperature: 2, // <- Nuts
            stream: streamEnabled,
        };
        dbg('Sending request', {
            provider: this._currentProvider,
            url: providerInfo['base_url'],
            model: body.model,
            messagesCount: body.messages.length,
            temperature: body.temperature,
            streaming: body.stream,
        });
        let session;
        const proxyUrl = userOptions.ai?.proxyUrl;
        if (proxyUrl && typeof proxyUrl === 'string' && proxyUrl.trim().length > 0) {
            try {
                const proxyResolver = new Gio.SimpleProxyResolver({ 'default-proxy': proxyUrl.trim() });
                session = new Soup.Session({ 'proxy-resolver': proxyResolver });
                dbg('Using proxy', proxyUrl.trim());
            } catch (e) {
                // Fallback silently without proxy if invalid
                session = new Soup.Session();
                dbg('Invalid proxy, falling back (error):', e?.message || e);
            }
        } else {
            session = new Soup.Session();
        }
        const message = new Soup.Message({
            method: 'POST',
            uri: this._url,
        });
        message.request_headers.append('Authorization', `Bearer ${this._key}`);
        message.request_headers.append('Content-Type', 'application/json');
        if (streamEnabled)
            message.request_headers.append('Accept', 'text/event-stream');
        const customHeaders = providerInfo?.headers;
        if (customHeaders && typeof customHeaders === 'object') {
            for (const [header, value] of Object.entries(customHeaders)) {
                if (typeof value === 'string' && value.length > 0)
                    message.request_headers.append(header, value);
            }
        }
        message.set_request_body_from_bytes('application/json', new GLib.Bytes(JSON.stringify(body)));
        const startMono = GLib.get_monotonic_time();
        aiResponse._startMono = startMono;
        if (streamEnabled) {
            session.send_async(message, GLib.PRIORITY_DEFAULT, null, (sess, res) => {
                try {
                    const stream = sess.send_finish(res);
                    const statusCode = message.get_status ? message.get_status() : (message.status_code || 0);
                    if (statusCode >= 400) {
                        dbg('Streaming HTTP error status', statusCode);
                        let errorText = '';
                        try {
                            const responseBody = message.get_response_body?.();
                            const bytes = responseBody?.flatten?.()?.get_as_bytes?.();
                            if (bytes) {
                                const uint8 = ByteArray.fromGBytes(bytes);
                                errorText = this._decoder.decode(uint8);
                            }
                        } catch { }
                        aiResponse.thinking = false;
                        aiResponse.content = errorText ? `Error ${statusCode}: ${errorText}` : `Error ${statusCode}`;
                        aiResponse.done = true;
                        return;
                    }
                    this.readResponse(new Gio.DataInputStream({
                        close_base_stream: true,
                        base_stream: stream
                    }), aiResponse);
                    dbg('Streaming response started');
                } catch (e) {
                    dbg('Streaming request failed', e?.message || e);
                    aiResponse.thinking = false;
                    aiResponse.content = `Error: failed to read streaming response.`;
                    aiResponse.done = true;
                }
            });
        } else {
            // For non-stream responses, read full body and parse JSON.
            session.send_and_read_async(message, GLib.PRIORITY_DEFAULT, null, (sess, res) => {
                try {
                    const bytes = sess.send_and_read_finish(res);
                    const uint8 = ByteArray.fromGBytes(bytes);
                    const text = this._decoder.decode(uint8);
                    dbg('HTTP response raw length', text.length);
                    let statusCode = 0;
                    try { statusCode = message.get_status ? message.get_status() : (message.status_code || 0); } catch { }
                    dbg('HTTP status', statusCode);
                    const result = JSON.parse(text);
                    const content = result?.choices?.[0]?.message?.content ?? '';
                    aiResponse.thinking = false;
                    aiResponse.content = content;
                    aiResponse.done = true;

                    const endMono = GLib.get_monotonic_time();
                    const elapsedMs = Math.max(0, Math.round((endMono - startMono) / 1000));
                    const usage = result?.usage ?? {};
                    const pt = usage.prompt_tokens ?? usage.input_tokens ?? 0;
                    const ct = usage.completion_tokens ?? usage.output_tokens ?? 0;
                    const tt = usage.total_tokens ?? (pt + ct);
                    const timeStr = `${(elapsedMs / 1000).toFixed(1)}s`;
                    aiResponse.meta = tt > 0 ? `time: ${timeStr} • tokens: ${tt} (in ${pt} + out ${ct})` : `time: ${timeStr}`;
                    dbg('Parsed JSON completion', { tokens: { prompt: pt, completion: ct, total: tt }, time: timeStr });
                }
                catch (e) {
                    dbg('Non-JSON response while expecting JSON', e?.message || e);
                    aiResponse.thinking = false;
                    aiResponse.content = `Error: failed to parse response.`;
                    aiResponse.done = true;
                }
            });
        }
        this._messages.push(aiResponse);
        this.emit('newMsg', this._messages.length - 1);
        dbg('Assistant placeholder message appended (waiting response)');
    }
}

export default new GPTService();













