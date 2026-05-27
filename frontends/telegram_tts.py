import base64
import json
import os
import re
import shutil
import subprocess
import threading
import time
import uuid

import requests


MIMO_TTS_MODEL = "mimo-v2.5-tts"
MIMO_TTS_VOICE = "冰糖"
MIMO_TTS_STYLE = (
    "请使用自然、清晰的普通话朗读，语速适中，语气像可靠的聊天助理；"
    "技术内容保持克制，不要夸张表演。"
)
MIMO_API_BASE = "https://api.xiaomimimo.com/v1"
MAX_TTS_CHUNKS = 3
MAX_TTS_CHARS = 1000
MAX_VOICE_BYTES = 950_000
REQUEST_TIMEOUT = (15, 180)
VOICE_BITRATES = ("24k", "16k", "12k")

_TAG_RE = re.compile(r"<(?:thinking|summary|tool_use|file_content)>[\s\S]*?</(?:thinking|summary|tool_use|file_content)>")
_CODE_BLOCK_RE = re.compile(r"(`{3,}|~{3,})[\s\S]*?\1")
_UNCLOSED_CODE_BLOCK_RE = re.compile(r"(`{3,}|~{3,})[\s\S]*$")
_FILE_MARKER_RE = re.compile(r"\[FILE:[^\]]+\]")
_TURN_MARKER_RE = re.compile(r"^\s*\*{0,2}LLM Running \(Turn \d+\) \.\.\.\*{0,2}\s*$", re.MULTILINE)
_MARKDOWN_LINK_RE = re.compile(r"\[([^\]]+)\]\(([^)\n]+)\)")
_INLINE_CODE_RE = re.compile(r"`([^`\n]+)`")
_MD_DECORATION_RE = re.compile(r"(\*\*|__|~~|\*)")
_GENERATED_FILE_RE = re.compile(r"^\s*(生成文件|已生成附件|附件)[:：].*$", re.MULTILINE)
_WHITESPACE_RE = re.compile(r"[ \t\r\f\v]+")
_PARAGRAPH_RE = re.compile(r"\n{3,}")


class TelegramTTS:
    def __init__(
        self,
        temp_dir,
        api_key="",
        api_base="",
        voice="",
        style="",
        ffmpeg_bin="",
        proxy="",
    ):
        self.temp_dir = temp_dir
        self.media_dir = os.path.join(temp_dir, "telegram_tts")
        self.state_path = os.path.join(temp_dir, "telegram_tts_state.json")
        self.api_key = (api_key or os.environ.get("MIMO_API_KEY") or "").strip()
        self.api_base = (api_base or MIMO_API_BASE).rstrip("/")
        self.voice = (voice or MIMO_TTS_VOICE).strip()
        self.style = (style or MIMO_TTS_STYLE).strip()
        self.ffmpeg_bin = (ffmpeg_bin or shutil.which("ffmpeg") or "").strip()
        self.proxy = (proxy or "").strip()
        self._lock = threading.Lock()
        os.makedirs(self.media_dir, exist_ok=True)
        self.enabled = self._load_enabled()

    def _load_enabled(self):
        try:
            with open(self.state_path, "r", encoding="utf-8") as f:
                data = json.load(f)
            return bool(data.get("enabled"))
        except FileNotFoundError:
            return False
        except Exception as exc:
            print(f"[TG TTS] load state failed: {type(exc).__name__}: {exc}", flush=True)
            return False

    def set_enabled(self, enabled):
        with self._lock:
            self.enabled = bool(enabled)
            os.makedirs(os.path.dirname(self.state_path), exist_ok=True)
            payload = {"enabled": self.enabled, "updated_at": int(time.time())}
            tmp_path = f"{self.state_path}.tmp"
            with open(tmp_path, "w", encoding="utf-8") as f:
                json.dump(payload, f, ensure_ascii=False, indent=2)
            os.replace(tmp_path, self.state_path)
        return self.enabled

    def is_private_chat(self, message):
        return getattr(getattr(message, "chat", None), "type", "") == "private"

    def should_speak(self, message):
        return self.enabled and self.is_private_chat(message)

    def missing_reason(self):
        if not self.api_key:
            return "未配置 mimo_api_key 或 MIMO_API_KEY"
        if not self.ffmpeg_bin:
            return "未找到 ffmpeg"
        return ""

    def status_text(self):
        missing = self.missing_reason()
        lines = [
            f"TTS: {'开启' if self.enabled else '关闭'}",
            "范围: Telegram 私聊中的 GA 任务回复",
            f"模型: {MIMO_TTS_MODEL}",
            f"音色: {self.voice}",
            f"MiMo Key: {'已配置' if self.api_key else '未配置'}",
            f"ffmpeg: {self.ffmpeg_bin or '未找到'}",
            f"状态文件: {self.state_path}",
        ]
        if missing:
            lines.append(f"不可用: {missing}")
        return "\n".join(lines)

    def clean_text_for_tts(self, raw_text):
        text = raw_text or ""
        text = _TAG_RE.sub("", text)
        text = _CODE_BLOCK_RE.sub("\n", text)
        text = _UNCLOSED_CODE_BLOCK_RE.sub("\n", text)
        text = _FILE_MARKER_RE.sub("", text)
        text = _TURN_MARKER_RE.sub("", text)
        text = _GENERATED_FILE_RE.sub("", text)
        text = _MARKDOWN_LINK_RE.sub(r"\1", text)
        text = _INLINE_CODE_RE.sub(r"\1", text)
        text = _MD_DECORATION_RE.sub("", text)
        text = text.replace("<_quote_>", "").replace("</_quote_>", "")
        text = _WHITESPACE_RE.sub(" ", text)
        text = "\n".join(line.strip() for line in text.splitlines())
        text = _PARAGRAPH_RE.sub("\n\n", text).strip()
        return text

    def split_text_for_tts(self, text, max_chunks=MAX_TTS_CHUNKS, limit=MAX_TTS_CHARS):
        text = self.clean_text_for_tts(text)
        if not text:
            return []
        chunks = []
        remaining = text
        while remaining and len(chunks) < max_chunks:
            if len(remaining) <= limit:
                chunks.append(remaining.strip())
                remaining = ""
                break
            cut = self._find_cut(remaining, limit)
            chunks.append(remaining[:cut].strip())
            remaining = remaining[cut:].strip()
        if remaining and chunks:
            suffix = "后文较长，请查看文字回复。"
            room = max(0, limit - len(suffix) - 1)
            chunks[-1] = (chunks[-1][:room].rstrip() + "\n" + suffix).strip()
        return [chunk for chunk in chunks if chunk]

    def _find_cut(self, text, limit):
        window = text[:limit]
        for pattern in ("\n\n", "\n", "。", "！", "？", "；", ";", ".", "!", "?"):
            idx = window.rfind(pattern)
            if idx >= int(limit * 0.55):
                return idx + len(pattern)
        idx = window.rfind(" ")
        if idx >= int(limit * 0.55):
            return idx + 1
        return limit

    def synthesize_wav(self, text):
        missing = self.missing_reason()
        if missing:
            raise RuntimeError(missing)
        url = f"{self.api_base}/chat/completions"
        payload = {
            "model": MIMO_TTS_MODEL,
            "messages": [
                {"role": "user", "content": self.style},
                {"role": "assistant", "content": text},
            ],
            "audio": {"format": "wav", "voice": self.voice},
        }
        headers = {"api-key": self.api_key, "Content-Type": "application/json"}
        proxies = {"http": self.proxy, "https": self.proxy} if self.proxy else None
        resp = requests.post(url, headers=headers, json=payload, timeout=REQUEST_TIMEOUT, proxies=proxies)
        if resp.status_code >= 400:
            raise RuntimeError(self._format_http_error(resp))
        try:
            body = resp.json()
        except ValueError as exc:
            raise RuntimeError(f"MiMo 返回非 JSON 响应: {exc}") from exc
        audio_b64 = self._extract_audio_data(body)
        try:
            audio_bytes = base64.b64decode(audio_b64)
        except Exception as exc:
            raise RuntimeError(f"MiMo 音频 base64 解码失败: {exc}") from exc
        if not audio_bytes:
            raise RuntimeError("MiMo 返回空音频")
        wav_path = os.path.join(self.media_dir, f"mimo_{uuid.uuid4().hex}.wav")
        with open(wav_path, "wb") as f:
            f.write(audio_bytes)
        return wav_path

    def _extract_audio_data(self, body):
        try:
            message = body["choices"][0]["message"]
        except (KeyError, IndexError, TypeError) as exc:
            raise RuntimeError("MiMo 响应缺少 choices[0].message") from exc
        audio = message.get("audio") if isinstance(message, dict) else None
        if isinstance(audio, dict):
            audio_data = audio.get("data")
        else:
            audio_data = audio
        if not isinstance(audio_data, str) or not audio_data.strip():
            raise RuntimeError("MiMo 响应缺少 message.audio.data")
        return audio_data.strip()

    def _format_http_error(self, resp):
        detail = ""
        try:
            payload = resp.json()
            detail = payload.get("error", {}).get("message") or payload.get("message") or str(payload)
        except Exception:
            detail = resp.text
        detail = re.sub(r"\s+", " ", detail or "").strip()
        if len(detail) > 180:
            detail = detail[:177].rstrip() + "..."
        return f"MiMo HTTP {resp.status_code}" + (f": {detail}" if detail else "")

    def convert_wav_to_voice(self, wav_path):
        if not self.ffmpeg_bin:
            raise RuntimeError("未找到 ffmpeg")
        last_error = ""
        for bitrate in VOICE_BITRATES:
            ogg_path = os.path.splitext(wav_path)[0] + f"_{bitrate}.ogg"
            cmd = [
                self.ffmpeg_bin,
                "-y",
                "-hide_banner",
                "-loglevel",
                "error",
                "-i",
                wav_path,
                "-vn",
                "-ac",
                "1",
                "-c:a",
                "libopus",
                "-b:a",
                bitrate,
                "-vbr",
                "on",
                "-compression_level",
                "10",
                "-application",
                "voip",
                ogg_path,
            ]
            proc = subprocess.run(cmd, capture_output=True, text=True, timeout=90)
            if proc.returncode != 0:
                last_error = (proc.stderr or proc.stdout or f"ffmpeg exited {proc.returncode}").strip()
                self._safe_remove(ogg_path)
                continue
            if os.path.getsize(ogg_path) <= MAX_VOICE_BYTES:
                return ogg_path
            last_error = f"转码后超过 Telegram 语音大小限制: {os.path.getsize(ogg_path)} bytes"
            self._safe_remove(ogg_path)
        raise RuntimeError(last_error or "ffmpeg 转码失败")

    def create_voice_file(self, text):
        wav_path = self.synthesize_wav(text)
        try:
            return self.convert_wav_to_voice(wav_path)
        finally:
            self._safe_remove(wav_path)

    def cleanup_voice_file(self, path):
        self._safe_remove(path)

    def _safe_remove(self, path):
        if not path:
            return
        try:
            os.remove(path)
        except FileNotFoundError:
            pass
        except Exception as exc:
            print(f"[TG TTS] cleanup failed {path}: {type(exc).__name__}: {exc}", flush=True)
