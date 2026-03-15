# Memory Manage Skill - 记忆管理技能

## 一键安装（推荐）

```bash
# 方式 1：使用 install-skill.sh（通用 Hub 安装器）
bash -c "$(curl -sL https://raw.githubusercontent.com/luoyueliang/openclaw/main/skills/install-skill.sh)" _ memory_manage
```

```bash
# 方式 2：直接运行 install.sh
bash -c "$(curl -sL https://raw.githubusercontent.com/luoyueliang/openclaw/main/skills/memory_manage/scripts/install.sh)"
```

## 安装过程

运行后会交互式询问：

```
检测操作系统: Darwin / Linux
✓ 找到: /Users/yue/.openclaw

获取 Agent 列表...
可用的 Agent:
  1. main → /Users/yue/.openclaw/workspace
  ...

选择 Agent (输入编号) [1]:      ← 直接回车选 main

实例名称 (GitHub 备份区分不同机器)
(建议格式: openclaw-macpro / openclaw-home)
[openclaw-home]:                 ← 输入本机实例名

GitHub 用户名: yourname
备份仓库名 [ai_openclaw_memory]: 
GitHub PAT: ********            ← 密码输入不回显
```

## 配置说明

| 配置项 | 说明 | 示例 |
|--------|------|------|
| instance.name | **每台机器不同**，区分 GitHub 备份目录 | `openclaw-macpro`, `openclaw-home` |
| agent.name | Agent 名，通常为 main | `main` |
| github.repo | 记忆备份私有仓库 | `https://github.com/你/ai_openclaw_memory` |
| github.token | GitHub PAT（需 repo 权限） | `ghp_xxx` |

### 两台机器的配置示例

**openclaw-macpro (yue@192.168.8.207 macOS)**

```yaml
instance:
  name: openclaw-macpro
agent:
  name: main
github:
  repo: https://github.com/luoyueliang/ai_openclaw_memory
  token: ghp_你的Token
```

**openclaw-home (root@192.168.0.12 Linux)**

```yaml
instance:
  name: openclaw-home
agent:
  name: main
github:
  repo: https://github.com/luoyueliang/ai_openclaw_memory
  token: ghp_你的Token
```

## 安装后验证

```bash
# 运行初始化检查
~/.openclaw/workspace/skills/memory_manage/scripts/init-check.sh

# 手动运行一次同步
~/.openclaw/workspace/skills/memory_manage/scripts/sync.sh
```

## 设置自动同步（cron）

```bash
crontab -e

# Linux VPS（openclaw-home）
30 * * * * /root/.openclaw/workspace/skills/memory_manage/scripts/sync.sh >> /tmp/sync.log 2>&1

# macOS（openclaw-macpro）
30 * * * * /Users/yue/.openclaw/workspace/skills/memory_manage/scripts/sync.sh >> /tmp/sync.log 2>&1
```

## 功能

- ✅ 跨平台：macOS (bash 3.2) / Linux (bash 5.x)
- ✅ 自动备份 MEMORY.md、AGENTS.md、SOUL.md、USER.md、TOOLS.md、HEARTBEAT.md、IDENTITY.md
- ✅ 多实例同一 GitHub 仓库，各占独立子目录（不冲突）
- ✅ 支持 memory/ 子目录文件同步
- ✅ 多实例并发推送时自动 pull --rebase

---

*🤖 记忆管理技能 - 支持 macOS / Linux*
