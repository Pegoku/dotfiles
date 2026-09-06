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

    async def test_resume_rehydrates_history(self):
        b = self.bridge
        b.rpc = AsyncMock(return_value={'model': 'model', 'thread': {'id': 'saved', 'cwd': self.tmp.name, 'turns': [{'items': [{'id': 'u', 'type': 'userMessage', 'content': [{'type': 'text', 'text': 'remember me'}]}]}]}})
        await b.action(dict(action='resume', thread='saved', cwd=self.tmp.name))
        self.assertEqual(b.items[0]['text'], 'remember me')
        self.assertEqual(b.thread, 'saved')
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
