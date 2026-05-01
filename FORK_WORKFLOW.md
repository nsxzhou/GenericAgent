# Fork 工作流指南

## 基本原则

**不要在 `main` 分支上直接修改。** 自己的修改放在独立分支上，`main` 只用于同步上游。

## Remote 配置

```
origin    → https://github.com/nsxzhou/GenericAgent.git  （你的 fork）
upstream  → https://github.com/lsdefine/GenericAgent.git  （原项目）
```

## 分支策略

```
upstream/main
     │
     ▼ git fetch + merge
origin/main              ← 只当中转站，不推送本地修改
     │
     ▼ git merge main
my-feature               ← 你的唯一工作分支，所有修改在这里
```

**核心原则：`main` 只同步上游，`my-feature` 是你唯一维护的分支。** 不要把自己的修改推到 main，不从 my-feature 合入 main。

## 日常操作

### 同步上游（一行搞定）

```bash
git fetch upstream && git merge upstream/main && git merge main
```

设置 alias 更简洁：

```bash
git config alias.sync '!git fetch upstream && git merge upstream/main && git merge main'
```

之后只需：

```bash
git checkout my-feature
git sync
```

### 在自己的分支上开发

```bash
git checkout my-feature
# 修改、提交...
git push origin my-feature
```

### 完整同步流程

```bash
# 1. 拉取上游最新
git fetch upstream

# 2. main 对齐上游
git checkout main
git merge upstream/main

# 3. 合入你的分支
git checkout my-feature
git merge main

# 4. 推送到 fork
git push origin my-feature
```

### 提 PR 贡献回上游

从上游 main 创建新分支，不从你的 feature 分支：

```bash
git checkout main
git checkout -b contribute/xxx
# 修改...
git push origin contribute/xxx
# 在 GitHub 上提 PR 给原项目
```

## 常见场景速查

| 场景 | 做法 |
|------|------|
| 原项目发了新版本 | `git sync`（fetch upstream → merge main） |
| 你的新功能 | 在 my-feature 分支上开发、提交、推送 |
| 某个修改想贡献回上游 | 从 main 建 `contribute/xxx` 分支提 PR |
| 上游和本地冲突 | merge main 到 my-feature，手动解决 |
| mykey.py 配置 | 直接在 my-feature 上改（上游不会动这个文件） |

## 注意事项

- `mykey.py` 包含 API Key，不要提交到 GitHub（已加入 `.gitignore`）
- `mykey_template.py` 是模板，可以提交
- `ADVANCED_USAGE.md`、`FORK_WORKFLOW.md` 是你自己写的文档，留在 my-feature 上
