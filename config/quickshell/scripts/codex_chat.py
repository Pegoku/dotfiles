#!/usr/bin/env python3
"""Private JSONL bridge between Quickshell and the installed Codex app-server."""
import asyncio
import json
import os
from pathlib import Path
import shutil
import signal
import sys


def render_item(item):
    kind = item.get('type', '')
    text = item.get('text', '')
    title = {'userMessage': 'You', 'agentMessage': 'Codex', 'reasoning': 'Thinking',
             'commandExecution': 'Command', 'fileChange': 'File changes',
             'webSearch': 'Web search', 'mcpToolCall': 'Tool'}.get(kind, kind)
    if kind == 'userMessage':
        text = '\n'.join(c.get('text', '') for c in item.get('content', []))
    elif kind == 'commandExecution':
        text = item.get('command', '') + '\n' + (item.get('aggregatedOutput') or '')
    elif kind == 'fileChange':
        text = '\n\n'.join(c.get('path', '') + '\n' + c.get('diff', '') for c in item.get('changes', []))
    elif kind == 'reasoning':
        text = '\n'.join(item.get('summary', []))
    elif kind == 'webSearch':
        text = item.get('query', '') or json.dumps(item.get('action', {}), ensure_ascii=False)
    elif kind == 'mcpToolCall':
        title = item.get('server', '') + ' / ' + item.get('tool', '')
        text = json.dumps(item.get('result') or item.get('arguments', {}), ensure_ascii=False, indent=2)
    elif not text:
        text = json.dumps(item, ensure_ascii=False, indent=2)
    return dict(id=item['id'], kind=kind, title=title, text=text[-60000:], status=item.get('status', ''))


class Bridge:
    def __init__(self):
        self.proc = None
        self.pending = {}
        self.sequence = 0
        self.thread = ''
        self.turn = ''
        self.items = []
        self.received_message = ''
        self.pending_message = ''
        self.requests = {}
        self.busy = False
        self.stop_requested = False
        self.ready = False
        self.account = 'Connecting…'
        self.models = []
        self.model = ''
        self.effort = ''
        self.default_model = ''
        self.language_instructions = 'Respond in English by default, including for short or ambiguous messages. Use another language when the user explicitly asks for it.'
        self.error = ''
        self.cwd = str(Path.home())
        self.state_file = Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state'))) / 'quickshell/codex-chat.json'
        self.chats = []
        try:
            data = json.loads(self.state_file.read_text())
            self.chats = data.get('chats', [])
            self.cwd = data.get('cwd', self.cwd)
        except (OSError, ValueError, TypeError):
            pass
        self.dirty = False

    def emit(self):
        print(json.dumps(dict(type='state', ready=self.ready, busy=self.busy,
                              account=self.account, models=self.models, model=self.model, effort=self.effort, defaultModel=self.default_model,
                              error=self.error, cwd=self.cwd, thread=self.thread,
                              chats=self.chats, items=self.items, receivedMessage=self.received_message,
                              requests=list(self.requests.values())), ensure_ascii=False), flush=True)
        self.dirty = False

    def save(self):
        self.state_file.parent.mkdir(parents=True, exist_ok=True)
        tmp = self.state_file.with_suffix('.tmp')
        fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, 'w') as f:
            json.dump(dict(chats=self.chats, cwd=self.cwd), f)
        tmp.replace(self.state_file)

    async def write(self, data):
        self.proc.stdin.write((json.dumps(data) + '\n').encode())
        await self.proc.stdin.drain()

    async def rpc(self, method, params):
        self.sequence += 1
        ident = self.sequence
        future = asyncio.get_running_loop().create_future()
        self.pending[ident] = future
        try:
            await self.write(dict(id=ident, method=method, params=params))
            return await asyncio.wait_for(future, 60)
        finally:
            self.pending.pop(ident, None)

    async def read_server(self):
        while line := await self.proc.stdout.readline():
            msg = json.loads(line)
            if 'method' not in msg:
                future = self.pending.get(msg.get('id'))
                if future and not future.done():
                    if 'error' in msg:
                        future.set_exception(RuntimeError(msg['error']['message']))
                    else:
                        future.set_result(msg.get('result', {}))
                continue
            method, p = msg['method'], msg.get('params', {})
            if 'id' in msg:
                supported = ['item/commandExecution/requestApproval', 'item/fileChange/requestApproval',
                             'item/permissions/requestApproval', 'item/tool/requestUserInput']
                if method in supported:
                    self.requests[str(msg['id'])] = dict(id=msg['id'], method=method, params=p)
                    self.emit()
                else:
                    await self.write(dict(id=msg['id'], error=dict(code=-32601, message='This client does not support ' + method)))
                    self.error = 'Unsupported interaction: ' + method
                    self.emit()
                continue
            if method == 'account/updated':
                asyncio.create_task(self.refresh_account())
            if p.get('threadId') and p['threadId'] != self.thread:
                continue
            if method in ('item/started', 'item/completed'):
                self.upsert(render_item(p['item']))
            elif method == 'item/agentMessage/delta':
                self.delta(p['itemId'], p['delta'], 'agentMessage', 'Codex')
            elif method == 'item/commandExecution/outputDelta':
                self.delta(p['itemId'], p['delta'], 'commandExecution', 'Command')
            elif method == 'item/reasoning/summaryTextDelta':
                self.delta(p['itemId'], p['delta'], 'reasoning', 'Thinking')
            elif method == 'turn/started':
                self.turn = p['turn']['id']
                self.busy = True
            elif method == 'turn/completed':
                self.busy = False
                self.turn = ''
                self.requests.clear()
                err = p['turn'].get('error')
                if err:
                    self.error = err.get('message', str(err))
                self.emit()
            elif method == 'serverRequest/resolved':
                self.requests.pop(str(p.get('requestId')), None)
            elif method == 'error':
                self.error = p.get('error', {}).get('message', 'Codex error')
            self.dirty = True
        raise RuntimeError('Codex disconnected. Reconnect to continue your saved conversation.')

    def upsert(self, item):
        if item['kind'] == 'userMessage' and self.pending_message:
            for i, old in enumerate(self.items):
                if old['id'] == self.pending_message:
                    self.items[i] = item
                    self.pending_message = ''
                    return
        for i, old in enumerate(self.items):
            if old['id'] == item['id']:
                self.items[i] = item
                return
        self.items.append(item)

    def delta(self, ident, text, kind, title):
        for item in self.items:
            if item['id'] == ident:
                item['text'] = (item['text'] + text)[-60000:]
                return
        self.items.append(dict(id=ident, kind=kind, title=title, text=text, status='inProgress'))

    async def refresh_account(self):
        result = await self.rpc('account/read', {})
        account = result.get('account') or {}
        self.ready = account.get('type') in ('chatgpt', 'chatgptAuthTokens')
        self.account = ('ChatGPT · ' + (account.get('planType') or 'subscription')) if self.ready else 'Run codex login to connect your ChatGPT subscription'
        self.emit()

    def model_info(self, model):
        return next((m for m in self.models if m['id'] == model), {})

    def selection(self, data):
        model = data.get('model') or self.model or self.default_model
        info = self.model_info(model)
        effort = data.get('effort')
        if not effort:
            effort = (self.effort if model == self.model else '') or info.get('defaultEffort', '')
        supported = [e['id'] for e in info.get('efforts', [])]
        if effort and supported and effort not in supported:
            raise RuntimeError('Unsupported reasoning level for ' + model + ': ' + effort)
        return model, effort

    async def action(self, data):
        action = data.get('action')
        if action == 'stop':
            self.stop_requested = self.busy
            if self.turn:
                await self.rpc('turn/interrupt', dict(threadId=self.thread, turnId=self.turn))
            return
        if action == 'reply':
            request = self.requests.get(str(data.get('id')))
            if not request:
                return
            method = request['method']
            if method == 'item/tool/requestUserInput':
                result = dict(answers=data.get('answers', {}))
            elif method == 'item/permissions/requestApproval':
                result = dict(permissions=request['params'].get('permissions', {}) if data.get('allow') else {}, scope='turn')
            else:
                result = dict(decision='accept' if data.get('allow') else 'decline')
            await self.write(dict(id=request['id'], result=result))
            self.requests.pop(str(request['id']), None)
            self.emit()
            return
        if action == 'refresh':
            await self.refresh_account()
            return
        if self.busy:
            raise RuntimeError('Stop the current response before changing conversations.')
        if action == 'new':
            self.thread, self.turn, self.items, self.error = '', '', [], ''
            self.pending_message = ''
            self.emit()
            return
        if action not in ('send', 'resume'):
            return
        if action == 'send' and data.get('text', '').strip():
            self.received_message = data.get('clientMessageId', '')
            self.pending_message = self.received_message or 'local-message'
            self.items.append(dict(id=self.pending_message, kind='userMessage', title='You',
                                   text=data['text'].strip(), status=''))
        if not self.ready:
            raise RuntimeError('Sign in with codex login, then reconnect.')
        cwd = str(Path(data.get('cwd') or self.cwd).expanduser().resolve())
        if not Path(cwd).is_dir():
            raise RuntimeError('Working folder does not exist: ' + cwd)
        self.busy, self.error = True, ''
        self.stop_requested = False
        self.emit()
        try:
            settings = dict(cwd=cwd, modelProvider='openai', approvalPolicy='on-request',
                            sandbox='workspace-write', config={'web_search': 'live'},
                            developerInstructions=self.language_instructions)
            model, effort = self.selection(data)
            if action == 'send' and model:
                settings['model'] = model
            if action == 'send' and effort:
                settings['config']['model_reasoning_effort'] = effort
            if action == 'resume':
                settings['threadId'] = data['thread']
                result = await self.rpc('thread/resume', settings)
                self.thread = result['thread']['id']
                self.pending_message = ''
                self.cwd = result['thread'].get('cwd', cwd)
                self.model = result.get('model', '')
                self.effort = result.get('reasoningEffort') or self.model_info(self.model).get('defaultEffort', '')
                self.items = [render_item(i) for t in result['thread'].get('turns', []) for i in t.get('items', [])]
                self.busy = False
            else:
                prompt = data.get('text', '').strip()
                if not prompt:
                    self.busy = False
                    return
                if not self.thread:
                    result = await self.rpc('thread/start', settings)
                    self.thread = result['thread']['id']
                    self.model = result.get('model', '')
                    self.effort = effort or result.get('reasoningEffort') or self.model_info(self.model).get('defaultEffort', '')
                    self.chats.insert(0, dict(id=self.thread, title=prompt[:70], cwd=cwd))
                    self.chats = self.chats[:50]
                    self.save()
                self.cwd = cwd
                params = dict(threadId=self.thread, cwd=cwd, input=[dict(type='text', text=prompt)])
                if model:
                    params['model'] = model
                if effort:
                    params['effort'] = effort
                result = await self.rpc('turn/start', params)
                self.model = model or self.model
                self.effort = effort
                self.turn = result['turn']['id'] if self.busy else ''
                if self.stop_requested and self.turn:
                    await self.rpc('turn/interrupt', dict(threadId=self.thread, turnId=self.turn))
                for chat in self.chats:
                    if chat['id'] == self.thread:
                        chat['cwd'] = cwd
            self.save()
        except Exception:
            self.busy = False
            raise
        finally:
            self.emit()

    async def read_ui(self):
        reader = asyncio.StreamReader()
        protocol = asyncio.StreamReaderProtocol(reader)
        await asyncio.get_running_loop().connect_read_pipe(lambda: protocol, sys.stdin)
        tasks = set()
        async def dispatch(data):
            try:
                await self.action(data)
            except Exception as exc:
                self.error = str(exc)
                self.emit()
        try:
            while line := await reader.readline():
                try:
                    data = json.loads(line)
                except ValueError:
                    continue
                task = asyncio.create_task(dispatch(data))
                tasks.add(task)
                task.add_done_callback(tasks.discard)
        finally:
            for task in tasks:
                task.cancel()

    async def flush(self):
        while True:
            await asyncio.sleep(.08)
            if self.dirty:
                self.emit()

    async def run(self):
        binary = shutil.which('codex')
        if not binary:
            for path in ['.local/bin/codex', '.bun/bin/codex', '.cache/.bun/bin/codex', '.npm-global/bin/codex']:
                candidate = Path.home() / path
                if candidate.is_file() and os.access(candidate, os.X_OK):
                    binary = str(candidate)
                    break
        if not binary:
            raise RuntimeError('Codex CLI was not found. Install codex and run codex login.')
        env = dict(os.environ)
        for name in ('OPENAI_API_KEY', 'OPENROUTER_API_KEY'):
            env.pop(name, None)
        self.proc = await asyncio.create_subprocess_exec(binary, 'app-server', '-c', 'forced_login_method="chatgpt"',
                    stdin=asyncio.subprocess.PIPE, stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.DEVNULL, env=env, limit=8 * 1024 * 1024, start_new_session=True)
        reader = asyncio.create_task(self.read_server())
        flusher = asyncio.create_task(self.flush())
        ui = None
        try:
            await self.rpc('initialize', dict(clientInfo=dict(name='quickshell_chat', title='Desktop Codex', version='1.0')))
            await self.write(dict(method='initialized', params={}))
            await self.refresh_account()
            result = await self.rpc('model/list', {})
            catalog = result.get('data', [])
            while result.get('nextCursor'):
                result = await self.rpc('model/list', {'cursor': result['nextCursor']})
                catalog.extend(result.get('data', []))
            self.models = [dict(id=m['model'], label=m['displayName'],
                                defaultEffort=m['defaultReasoningEffort'],
                                efforts=[dict(id=e['reasoningEffort'], description=e['description'])
                                         for e in m['supportedReasoningEfforts']])
                           for m in catalog if not m.get('hidden')]
            config = (await self.rpc('config/read', {})).get('config', {})
            self.default_model = config.get('model') or next((m['model'] for m in catalog if m.get('isDefault')), '')
            self.model = self.default_model
            self.effort = config.get('model_reasoning_effort') or self.model_info(self.model).get('defaultEffort', '')
            if config.get('developer_instructions'):
                self.language_instructions = config['developer_instructions'] + '\n\n' + self.language_instructions
            self.emit()
            ui = asyncio.create_task(self.read_ui())
            done, _ = await asyncio.wait([reader, ui], return_when=asyncio.FIRST_COMPLETED)
            for task in done:
                task.result()
        finally:
            for task in (reader, flusher, ui):
                if task:
                    task.cancel()
            if self.proc.returncode is None:
                os.killpg(self.proc.pid, signal.SIGTERM)
                try:
                    await asyncio.wait_for(self.proc.wait(), 3)
                except asyncio.TimeoutError:
                    os.killpg(self.proc.pid, signal.SIGKILL)
                    await self.proc.wait()


async def main():
    bridge = Bridge()
    try:
        task = asyncio.current_task()
        for sig in (signal.SIGTERM, signal.SIGINT):
            asyncio.get_running_loop().add_signal_handler(sig, task.cancel)
        await bridge.run()
    except asyncio.CancelledError:
        pass
    except Exception as exc:
        bridge.ready = bridge.busy = False
        bridge.error = str(exc)
        bridge.emit()


if __name__ == '__main__':
    asyncio.run(main())
