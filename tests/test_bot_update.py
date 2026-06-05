import json
import unittest
from pathlib import Path
from unittest.mock import Mock, mock_open, patch

import ga


ROOT = Path(__file__).resolve().parents[1]


def run_generator(gen):
    try:
        while True:
            next(gen)
    except StopIteration as exc:
        return exc.value


class BotUpdateTargetTests(unittest.TestCase):
    def test_current_target_resolves_from_wechat_source(self):
        target, err = ga.resolve_bot_update_target("current", "wechat")
        self.assertIsNone(err)
        self.assertEqual(target, "wechat")

    def test_current_target_resolves_from_telegram_source(self):
        target, err = ga.resolve_bot_update_target("current", "telegram")
        self.assertIsNone(err)
        self.assertEqual(target, "telegram")

    def test_explicit_targets_do_not_require_source(self):
        self.assertEqual(ga.resolve_bot_update_target("wechat", None), ("wechat", None))
        self.assertEqual(ga.resolve_bot_update_target("telegram", None), ("telegram", None))

    def test_unknown_source_with_current_target_returns_error(self):
        target, err = ga.resolve_bot_update_target("current", "cli")
        self.assertIsNone(target)
        self.assertIn("无法从当前来源", err)


class BotUpdateToolTests(unittest.TestCase):
    def _run_tool(self, source, target="current", wait_code=0):
        handler = ga.GenericAgentHandler(parent=object(), source=source)
        proc = Mock()
        proc.wait.return_value = wait_code
        with patch("ga.os.makedirs") as makedirs, \
             patch("builtins.open", mock_open()) as opened, \
             patch("ga.subprocess.Popen", return_value=proc) as popen:
            outcome = run_generator(handler.do_bot_update({"target": target}, response=None))
        return outcome, makedirs, opened, popen

    def test_current_wechat_runs_wechat_update_script(self):
        outcome, _makedirs, _opened, popen = self._run_tool("wechat")
        self.assertEqual(outcome.data["status"], "success")
        self.assertEqual(outcome.data["target"], "wechat")
        args, kwargs = popen.call_args
        self.assertEqual(args[0], ["/bin/bash", str(ROOT / "assets" / "update-wechat-launchagent.sh")])
        self.assertEqual(kwargs["cwd"], str(ROOT))
        self.assertEqual(kwargs["env"]["WECHAT_UPDATE_RESTART_DELAY"], "5")

    def test_current_telegram_runs_telegram_update_script(self):
        outcome, _makedirs, _opened, popen = self._run_tool("telegram")
        self.assertEqual(outcome.data["status"], "success")
        self.assertEqual(outcome.data["target"], "telegram")
        args, kwargs = popen.call_args
        self.assertEqual(args[0], ["/bin/bash", str(ROOT / "assets" / "update-telegram-launchagent.sh")])
        self.assertEqual(kwargs["cwd"], str(ROOT))
        self.assertEqual(kwargs["env"]["TELEGRAM_UPDATE_RESTART_DELAY"], "5")

    def test_explicit_target_overrides_source(self):
        outcome, _makedirs, _opened, popen = self._run_tool("wechat", target="telegram")
        self.assertEqual(outcome.data["status"], "success")
        self.assertEqual(outcome.data["target"], "telegram")
        args, _kwargs = popen.call_args
        self.assertEqual(args[0], ["/bin/bash", str(ROOT / "assets" / "update-telegram-launchagent.sh")])

    def test_unknown_source_with_current_target_does_not_run_subprocess(self):
        handler = ga.GenericAgentHandler(parent=object(), source="cli")
        with patch("ga.subprocess.Popen") as popen:
            outcome = run_generator(handler.do_bot_update({"target": "current"}, response=None))
        self.assertEqual(outcome.data["status"], "error")
        popen.assert_not_called()


class ToolSchemaTests(unittest.TestCase):
    def test_tool_schemas_are_valid_json_and_include_bot_update(self):
        for schema_name in ("tools_schema.json", "tools_schema_cn.json"):
            with self.subTest(schema=schema_name):
                data = json.loads((ROOT / "assets" / schema_name).read_text(encoding="utf-8"))
                names = [item["function"]["name"] for item in data]
                self.assertIn("bot_update", names)


if __name__ == "__main__":
    unittest.main()
