import asyncio
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import AsyncMock, patch

spec = importlib.util.spec_from_file_location('codex_chat', Path(__file__).parents[1] / 'scripts/codex_chat.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class BridgeTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.env = patch.dict('os.environ', {'XDG_STATE_HOME': self.tmp.name})
        self.env.start()
        self.bridge = module.Bridge()
        self.bridge.emit = lambda: None
        self.bridge.ready = True
        self.bridge.write = AsyncMock()

    def tearDown(self):
        self.env.stop()
        self.tmp.cleanup()

    async def test_subscription_thread_and_context(self):
        b = self.bridge
        b.rpc = AsyncMock(side_effect=[{'thread': {'id': 'thread'}, 'model': 'default'}, {'turn': {'id': 'turn'}}, {'turn': {'id': 'next'}}])
        await b.action(dict(action='send', text='hello', cwd=self.tmp.name))
        self.assertEqual(b.rpc.call_args_list[0].args[0], 'thread/start')
        settings = b.rpc.call_args_list[0].args[1]
        self.assertEqual(settings['modelProvider'], 'openai')
        self.assertEqual(settings['sandbox'], 'workspace-write')
        self.assertEqual(settings['approvalPolicy'], 'on-request')
        self.assertEqual(settings['config']['web_search'], 'live')
        b.busy = False
        await b.action(dict(action='send', text='follow up', cwd=self.tmp.name))
        self.assertEqual(b.rpc.call_args.args[1]['threadId'], 'thread')
        self.assertEqual(len(b.chats), 1)
        self.assertEqual(b.state_file.stat().st_mode & 0o777, 0o600)
        self.assertEqual(module.Bridge().chats, b.chats)

    async def test_rejects_api_account_and_bad_folder(self):
        b = self.bridge
        b.rpc = AsyncMock(return_value={'account': {'type': 'apiKey'}})
        await b.refresh_account()
        self.assertFalse(b.ready)
        with self.assertRaisesRegex(RuntimeError, 'Sign in'):
            await b.action(dict(action='send', text='hello'))
        b.ready = True
        with self.assertRaisesRegex(RuntimeError, 'does not exist'):
            await b.action(dict(action='send', cwd=self.tmp.name + '/missing', text='hello'))
        self.assertFalse(b.busy)

    async def test_no_overlapping_turns_or_new_chat_during_work(self):
        self.bridge.busy = True
        for action in ('send', 'new', 'resume'):
            with self.assertRaisesRegex(RuntimeError, 'Stop'):
                await self.bridge.action(dict(action=action))

    async def test_cancel_and_approval_are_explicit(self):
        b = self.bridge
        b.thread, b.turn, b.busy = 'thread', 'turn', True
        b.rpc = AsyncMock(return_value={})
        await b.action(dict(action='stop'))
        b.rpc.assert_awaited_once_with('turn/interrupt', dict(threadId='thread', turnId='turn'))
        b.requests['1'] = dict(id=1, method='item/commandExecution/requestApproval', params={})
        await b.action(dict(action='reply', id=1, allow=False))
        b.write.assert_awaited_with(dict(id=1, result=dict(decision='decline')))
        self.assertFalse(b.requests)
        b.requests['2'] = dict(id=2, method='item/permissions/requestApproval', params={'permissions': {'network': {'enabled': True}}})
        await b.action(dict(action='reply', id=2, allow=True))
        b.write.assert_awaited_with(dict(id=2, result=dict(permissions={'network': {'enabled': True}}, scope='turn')))

    async def test_stop_during_startup_interrupts_created_turn(self):
        b = self.bridge
        entered = asyncio.Event()
        release = asyncio.Event()
        async def rpc(method, params):
            if method == 'thread/start':
                entered.set()
                await release.wait()
                return {'thread': {'id': 'new'}, 'model': 'default'}
            if method == 'turn/start':
                return {'turn': {'id': 'running'}}
            return {}
        b.rpc = AsyncMock(side_effect=rpc)
        task = asyncio.create_task(b.action(dict(action='send', text='hello', cwd=self.tmp.name)))
        await entered.wait()
        await b.action(dict(action='stop'))
        release.set()
        await task
        b.rpc.assert_awaited_with('turn/interrupt', dict(threadId='new', turnId='running'))

    async def test_model_change_uses_recommendation_and_slider_override(self):
        b = self.bridge
        b.models = [dict(id='fast', defaultEffort='low', efforts=[dict(id='low'), dict(id='high')]),
                    dict(id='deep', defaultEffort='medium', efforts=[dict(id='medium'), dict(id='high')])]
        b.model, b.effort, b.thread = 'fast', 'high', 'existing'
        self.assertEqual(b.selection({'model': 'deep'}), ('deep', 'medium'))
        self.assertEqual(b.selection({'model': 'deep', 'effort': 'high'}), ('deep', 'high'))
        b.rpc = AsyncMock(return_value={'turn': {'id': 'turn'}})
        await b.action(dict(action='send', model='deep', effort='high', text='test', cwd=self.tmp.name))
        self.assertEqual(b.rpc.call_args.args[1]['model'], 'deep')
        self.assertEqual(b.rpc.call_args.args[1]['effort'], 'high')
        self.assertEqual((b.model, b.effort), ('deep', 'high'))
        b.busy = False
        with self.assertRaisesRegex(RuntimeError, 'Unsupported reasoning'):
            await b.action(dict(action='send', model='deep', effort='ultra', text='test', cwd=self.tmp.name))
        self.assertFalse(b.busy)

    async def test_new_thread_receives_reasoning_and_english_preference(self):
        b = self.bridge
        b.rpc = AsyncMock(side_effect=[{'thread': {'id': 'thread'}, 'model': 'chosen'}, {'turn': {'id': 'turn'}}])
        await b.action(dict(action='send', model='chosen', effort='medium', text='test', cwd=self.tmp.name))
        settings = b.rpc.call_args_list[0].args[1]
        self.assertEqual(settings['config']['model_reasoning_effort'], 'medium')
        self.assertIn('English by default', settings['developerInstructions'])

    async def test_resume_rehydrates_history(self):
        b = self.bridge
        b.rpc = AsyncMock(return_value={'model': 'model', 'reasoningEffort': 'high', 'thread': {'id': 'saved', 'cwd': self.tmp.name, 'turns': [{'items': [{'id': 'u', 'type': 'userMessage', 'content': [{'type': 'text', 'text': 'remember me'}]}]}]}})
        await b.action(dict(action='resume', thread='saved', cwd=self.tmp.name))
        self.assertEqual(b.items[0]['text'], 'remember me')
        self.assertEqual(b.thread, 'saved')
        self.assertEqual((b.model, b.effort), ('model', 'high'))
        self.assertIn('English by default', b.rpc.call_args.args[1]['developerInstructions'])
        self.assertFalse(b.busy)

    async def test_failed_turn_can_retry(self):
        b = self.bridge
        b.thread = 'thread'
        b.rpc = AsyncMock(side_effect=RuntimeError('offline'))
        with self.assertRaisesRegex(RuntimeError, 'offline'):
            await b.action(dict(action='send', text='hello', cwd=self.tmp.name))
        self.assertFalse(b.busy)

    def test_stream_reconciles_with_final_item_without_duplicates(self):
        b = self.bridge
        b.delta('a', 'hello ', 'agentMessage', 'Codex')
        b.delta('a', 'world', 'agentMessage', 'Codex')
        b.upsert(module.render_item(dict(id='a', type='agentMessage', text='hello world')))
        self.assertEqual(len(b.items), 1)
        self.assertEqual(b.items[0]['text'], 'hello world')
        command = module.render_item(dict(id='c', type='commandExecution', command='pwd', aggregatedOutput='/tmp', status='completed'))
        self.assertEqual(command['text'], 'pwd\n/tmp')


if __name__ == '__main__':
    unittest.main()
