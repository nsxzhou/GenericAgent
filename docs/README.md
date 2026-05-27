# GenericAgent 使用文档

本文只覆盖日常使用需要的最小步骤：安装依赖、配置模型、启动前端，以及微信和 Telegram（纸飞机）Bot 的常用命令。

## 1. 基础准备

进入项目目录：

```bash
cd /Users/zhouzirui/code/AI/claw/GenericAgent
```

建议先创建虚拟环境并安装常用 UI 依赖：

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -e ".[ui]"
```

首次使用需要配置模型 Key：

```bash
cp mykey_template.py mykey.py
python assets/configure_mykey.py
```

也可以直接编辑 `mykey.py`，填入你要使用的 LLM 配置。

## 2. 启动方式

桌面 / Web 界面：

```bash
python launch.pyw
```

终端交互：

```bash
python agentmain.py
```

终端 TUI：

```bash
python frontends/tuiapp_v2.py
```

如果只想启动某个聊天平台 Bot，也可以直接运行对应前端脚本。

## 3. 微信 Bot

安装微信 Bot 依赖：

```bash
pip install -e ".[wechat]"
```

手动启动：

```bash
python frontends/wechatapp.py
```

首次启动会要求扫码登录；登录信息会保存到 `~/.wxbot/token.json`。

### macOS 开机自启

安装微信 LaunchAgent：

```bash
bash assets/install-wechat-launchagent.sh
```

管理微信服务：

```bash
ga wechat start
ga wechat stop
ga wechat status
ga wechat update
```

也可以直接使用脚本：

```bash
bash assets/start-wechat-launchagent.sh
bash assets/stop-wechat-launchagent.sh
bash assets/status-wechat-launchagent.sh
bash assets/update-wechat-launchagent.sh
```

卸载微信自启：

```bash
bash assets/uninstall-wechat-launchagent.sh
```

微信内可发送：

```text
更新微信bot
```

日志位置：

```text
~/Library/Logs/GenericAgent/wechatapp.launchd.log
~/Library/Logs/GenericAgent/wechatapp.launchd.out.log
~/Library/Logs/GenericAgent/wechatapp.launchd.err.log
temp/wechatapp.log
```

## 4. Telegram（纸飞机）Bot

先找 Telegram 的 `@BotFather` 创建 Bot，拿到 `Bot Token`。

再获取自己的 Telegram 数字用户 ID，然后在 `mykey.py` 中配置：

```python
tg_bot_token = "你的 Bot Token"
tg_allowed_users = [123456789]
```

如果本机访问 Telegram 需要代理，可额外配置：

```python
proxy = "http://127.0.0.1:2082"
```

安装 Telegram Bot 依赖：

```bash
pip install -e ".[telegram]"
```

手动启动：

```bash
python frontends/tgapp.py
```

### macOS 开机自启

安装 Telegram LaunchAgent：

```bash
bash assets/install-telegram-launchagent.sh
```

管理 Telegram 服务：

```bash
ga telegram start
ga telegram stop
ga telegram status
ga telegram update
```

也可以直接使用脚本：

```bash
bash assets/start-telegram-launchagent.sh
bash assets/stop-telegram-launchagent.sh
bash assets/status-telegram-launchagent.sh
bash assets/update-telegram-launchagent.sh
```

卸载 Telegram 自启：

```bash
bash assets/uninstall-telegram-launchagent.sh
```

Telegram 内可发送：

```text
更新纸飞机bot
```

日志位置：

```text
~/Library/Logs/GenericAgent/telegramapp.launchd.log
~/Library/Logs/GenericAgent/telegramapp.launchd.out.log
~/Library/Logs/GenericAgent/telegramapp.launchd.err.log
temp/tgapp.log
```

## 5. 常用聊天命令

微信和 Telegram 都支持通过普通消息与 Agent 对话。Telegram 还支持菜单命令：

```text
/help       查看帮助
/status     查看当前状态
/stop       停止当前任务
/new        开启新对话
/restore    恢复上次对话历史
/continue   列出可恢复会话
/llm        查看模型列表
/llm 1      切换到第 1 个模型
/next       切换到下一个模型
```

## 6. 排查问题

查看服务状态：

```bash
ga wechat status
ga telegram status
```

如果 Bot 没响应，优先检查：

1. `mykey.py` 是否配置了可用模型。
2. Telegram 是否配置了 `tg_bot_token` 和非空 `tg_allowed_users`。
3. 是否需要配置 `proxy` 才能访问 Telegram。
4. LaunchAgent 日志中是否有依赖安装、网络或权限错误。
