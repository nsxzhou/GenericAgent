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
     ▼ git merge upstream/main
origin/main              ← 跟上游保持同步，尽量不改
     │
     ▼ git checkout -b my-feature
my-feature               ← 你的所有修改在这里
```

## 日常操作

### 同步上游更新

```bash
git fetch upstream
git checkout main
git merge upstream/main
git push origin main
```

### 在自己的分支上开发

```bash
git checkout my-feature
# 修改、提交...
git push origin my-feature
```

### 将上游更新合入你的分支

```bash
git checkout main
git merge upstream/main
git checkout my-feature
git merge main           # 把最新 main 合入你的分支
# 解决冲突（如有）...
```

### 提 PR 贡献回上游

从 main 创建新分支，不从你的 feature 分支：

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
| 原项目发了新版本 | `merge upstream/main` → main → merge main 到你的分支 |
| 你的新功能 | 在 feature 分支上开发 |
| 某个修改想贡献回上游 | 从 main 建分支提 PR |
| 上游和本地冲突 | merge main 到你的分支，手动解决 |
| mykey.py 配置 | 直接在 main 上改即可（上游不会动这个文件） |

## 注意事项

- `mykey.py` 包含 API Key，不要提交到 GitHub（已加入 `.gitignore`）
- `mykey_template.py` 是模板，可以提交
- `ADVANCED_USAGE.md`、`FORK_WORKFLOW.md` 是你自己写的文档，留在 main 上即可
