# Memory Manage Skill - 记忆管理技能

## 功能概述

### 1. 记忆同步 (`sync.sh`)
- 自动备份所有核心 Memory 文件到私有 GitHub 仓库
- 支持多实例独立区分（`openclaw-macpro`、`openclaw-home` 各占独立子目录）
- 跨平台：macOS (bash 3.2) / Linux (bash 5.x) 均可运行
- 按实例和 Agent 组织目录：`<instance>/<agent>/core/` 和 `<instance>/<agent>/workspace/memory/`

### 2. 初始化检查 (`init-check.sh`)
- 检测 OpenClaw 安装路径（macOS / Linux 自动识别）
- 检查 Memory 核心文件是否完整
- 验证 GitHub Token 有效性
- 输出可读性强的检查报告

### 3. Agent 监控 (`monitor-agents.sh`)
- 检测 agent 变更（新增 / 删除 / workspace 变化）
- 检查每个 agent 的 memory 文件配置
- 问题实时通知（飞书 + 邮件，可选）

### 4. 关键词检查 (`keywords-check.sh`)
- 检查消息中是否包含触发记忆更新的关键词
- 可接入主流程做自动触发逻辑

---

## 目录结构

```
memory_manage/
├── SKILL.md          # 本技术文档
├── README.md         # 用户安装文档
├── config/
│   ├── sync.yaml     # 实际配置（不提交，含真实 token）
│   └── sync.yaml.example  # 配置模板
└── scripts/
    ├── install.sh         # 一键交互安装
    ├── init-check.sh      # 初始化检查
    ├── sync.sh            # 记忆同步（主功能）
    ├── monitor-agents.sh  # Agent 监控
    └── keywords-check.sh  # 关键词检查
```

---

## 脚本说明

### install.sh

**交互流程：**
1. 自动检测 OpenClaw 安装路径（macOS / Linux 双路径）
2. 获取 Agent 列表（优先 `openclaw agents list` CLI，fallback 扫描 `~/.openclaw/agents/` 目录）
3. 显示可用 Agent，默认选中 `main`
4. 输入实例名（如：`openclaw-macpro`、`openclaw-home`）
5. 下载最新 Skill 文件
6. 交互式输入 GitHub 配置并生成 `config/sync.yaml`

**bash 兼容性：** 支持 bash 3.2+（macOS 默认），不使用 `mapfile`

### init-check.sh

运行后输出各项检查结果：
- OpenClaw 路径
- Workspace 是否存在
- 核心文件（MEMORY.md / AGENTS.md / SOUL.md / USER.md）是否存在
- sync.yaml 配置信息
- GitHub Token 有效性（HTTP 200）

### sync.sh

**同步逻辑：**
1. 读取 `config/sync.yaml` 获取 instance、agent、GitHub 配置
2. 动态检测 `OPENCLAW_ROOT`（macOS vs Linux）
3. 发现 Agent（扫描 `agents/*/workspace`；单 Agent 模式使用根 workspace）
4. 依次同步每个 Agent 的核心文件和 memory/ 目录（文件 < 1MB）
5. `git add + commit + pull --rebase + push`（支持多实例同仓库不冲突）
6. push 失败时自动尝试 force push

**同步的文件清单：**
```
核心文件：MEMORY.md, AGENTS.md, SOUL.md, USER.md,
          TOOLS.md, HEARTBEAT.md, IDENTITY.md, BOOTSTRAP.md

子目录：  workspace/memory/*.md (< 1MB)
```

**目标目录结构（GitHub 仓库）：**
```
<instance>/
└── <agent>/
    ├── core/           ← 核心 Memory 文件
    └── workspace/
        └── memory/     ← memory/ 子目录文件
```

### monitor-agents.sh

检测 Agent 变更并通知。可结合 cron 每小时运行监控。

---

## 配置

### sync.yaml

```yaml
instance:
  name: openclaw-macpro    # 每台机器唯一，区分 GitHub 备份目录

agent:
  name: main               # 默认 main，主 Agent

github:
  repo: https://github.com/用户名/ai_openclaw_memory
  token: ghp_你的GitHubPAT

# 可选：通知配置
notify:
  feishu_webhook: "https://open.feishu.cn/open-apis/bot/v2/hook/xxx"
  email:
    enabled: false
    to: "user@example.com"
```

### 两个实例的标准配置

| 字段 | openclaw-macpro (Mac) | openclaw-home (Linux VPS) |
|------|-----------------------|--------------------------|
| instance.name | `openclaw-macpro` | `openclaw-home` |
| agent.name | `main` | `main` |
| github.repo | 同一个备份仓库 | 同一个备份仓库 |
| github.token | 同一个 PAT | 同一个 PAT |

---

## 安装路径

| 平台 | OPENCLAW_ROOT | Skill 安装路径 |
|------|--------------|---------------|
| macOS | `$HOME/.openclaw` | `$HOME/.openclaw/workspace/skills/memory_manage/` |
| Linux (root) | `/root/.openclaw` | `/root/.openclaw/workspace/skills/memory_manage/` |
| Linux (user) | `$HOME/.openclaw` | `$HOME/.openclaw/workspace/skills/memory_manage/` |

---

## 自动运行

通过 cron 设置定时同步：

```bash
# 编辑 crontab
crontab -e

# Linux（openclaw-home）
30 * * * * /root/.openclaw/workspace/skills/memory_manage/scripts/sync.sh >> /tmp/sync.log 2>&1
0  * * * * /root/.openclaw/workspace/skills/memory_manage/scripts/monitor-agents.sh >> /tmp/monitor.log 2>&1

# macOS（openclaw-macpro，替换 yue 为实际用户名）
30 * * * * /Users/yue/.openclaw/workspace/skills/memory_manage/scripts/sync.sh >> /tmp/sync.log 2>&1
```

---

## 已知问题与历史

| 版本 | 修复内容 |
|------|---------|
| v5.0 | 初始版本，`OPENCLAW_ROOT` 硬编码 `/root/.openclaw`，macOS 无法使用 |
| v5.1 | 修复动态检测 `OPENCLAW_ROOT`；修复 git remote URL 双 `github.com` bug；修复 `stat -c%s` 跨平台 |
| v5.2 | 修复 `discover_agents` log 输出污染 stdout，导致日志文本被当 agent 名解析 |
| v5.2+ | 新增 `IDENTITY.md` / `BOOTSTRAP.md` 到同步清单；`install.sh` 默认选 main；增加 bash 3.2 兼容 |

---

*🤖 记忆管理 + Agent 监控 - 支持 macOS (bash 3.2) / Linux*
