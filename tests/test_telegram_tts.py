import json
import os
import tempfile
import unittest

from frontends.telegram_tts import TelegramTTS


class TelegramTTSTest(unittest.TestCase):
    def _tts(self, temp_dir, **kwargs):
        return TelegramTTS(
            temp_dir,
            api_key=kwargs.get("api_key", ""),
            ffmpeg_bin=kwargs.get("ffmpeg_bin", ""),
            proxy="",
        )

    def test_clean_text_for_tts_removes_non_speech_artifacts(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            tts = self._tts(temp_dir)
            raw = """LLM Running (Turn 1) ...
自然语言第一句。

```python
print("do not read")
```

请运行 `pytest`。
[FILE:temp/report.pdf]
生成文件: temp/report.pdf
<thinking>hidden</thinking>
[链接](https://example.com)
```text
unfinished code should not be read
"""
            cleaned = tts.clean_text_for_tts(raw)

        self.assertIn("自然语言第一句。", cleaned)
        self.assertIn("请运行 pytest。", cleaned)
        self.assertIn("链接", cleaned)
        self.assertNotIn("print", cleaned)
        self.assertNotIn("unfinished code", cleaned)
        self.assertNotIn("[FILE:", cleaned)
        self.assertNotIn("生成文件", cleaned)
        self.assertNotIn("hidden", cleaned)

    def test_split_text_for_tts_caps_chunks_and_marks_omission(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            tts = self._tts(temp_dir)
            text = "。".join([f"第{i}句内容" for i in range(300)])
            chunks = tts.split_text_for_tts(text, max_chunks=3, limit=120)

        self.assertEqual(len(chunks), 3)
        self.assertTrue(all(len(chunk) <= 120 for chunk in chunks))
        self.assertIn("后文较长，请查看文字回复。", chunks[-1])

    def test_state_persists_enabled_flag(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            tts = self._tts(temp_dir)
            self.assertFalse(tts.enabled)
            tts.set_enabled(True)
            with open(os.path.join(temp_dir, "telegram_tts_state.json"), encoding="utf-8") as f:
                payload = json.load(f)
            reloaded = self._tts(temp_dir)

        self.assertTrue(payload["enabled"])
        self.assertTrue(reloaded.enabled)


if __name__ == "__main__":
    unittest.main()
