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
    ├── install.sh           # 一键交互安装
    ├── init-check.sh        # 初始化检查
    ├── sync.sh              # 记忆同步（主功能）
    ├── keyword-monitor.sh   # 关键词监控 → 自动写入记忆
    ├── monitor-agents.sh    # Agent 监控
    └── keywords-check.sh    # 关键词检查工具
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

### keyword-monitor.sh

**功能：** 监控 OpenClaw 会话日志，当用户消息包含 `keywords.md` 中的关键词时，自动提取内容并写入 `memory/keyword-YYYYMMDD.md`，由 `sync.sh` 在下次同步时一并推送到 GitHub。

**执行逻辑：**
1. 加载 `workspace/memory/keywords.md` 中所有 `- 关键词` 行
2. 扫描最近 24 小时内修改过的 `sessions/*.jsonl` 文件
3. 只读取上次运行后的新增行（状态保存在 `state/keyword-monitor-state.json`）
4. 提取 `type=message, role=user` 的消息文本（去除 Feishu/Telegram 元数据前缀）
5. 匹配关键词 → 写入 `memory/keyword-YYYYMMDD.md`

**关键词文件格式：**
```markdown
### 记住类
- 帮我记住
- 记住
```

**输出文件格式：**
```markdown
### [2026-03-15 14:00:00] 触发关键词: 帮我记住

每周五同步一次数据到 GitHub

---
```

**依赖：** `python3`（用于解析 jsonl 和清洗消息内容）

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

通过一条命令添加所有 cron 任务（不覆盖已有任务）：

**Linux（openclaw-home）：**
```bash
(crontab -l 2>/dev/null; echo "0 * * * * /root/.openclaw/workspace/skills/memory_manage/scripts/sync.sh >> /tmp/openclaw-sync.log 2>&1"; echo "*/5 * * * * /root/.openclaw/workspace/skills/memory_manage/scripts/keyword-monitor.sh >> /tmp/openclaw-keyword.log 2>&1") | crontab -
```

**macOS（openclaw-macpro，替换 yue 为实际用户名）：**
```bash
(crontab -l 2>/dev/null; echo "0 * * * * /Users/yue/.openclaw/workspace/skills/memory_manage/scripts/sync.sh >> /tmp/openclaw-sync.log 2>&1"; echo "*/5 * * * * /Users/yue/.openclaw/workspace/skills/memory_manage/scripts/keyword-monitor.sh >> /tmp/openclaw-keyword.log 2>&1") | crontab -
```

| 任务 | 频率 | 说明 |
|------|------|------|
| `sync.sh` | 每小时 | 推送 memory → GitHub 备份 |
| `keyword-monitor.sh` | 每 5 分钟 | 监控关键词 → 写入 memory/ |

---

## 已知问题与历史

| 版本 | 修复内容 |
|------|---------|
| v5.0 | 初始版本，`OPENCLAW_ROOT` 硬编码 `/root/.openclaw`，macOS 无法使用 |
| v5.1 | 修复动态检测 `OPENCLAW_ROOT`；修复 git remote URL 双 `github.com` bug；修复 `stat -c%s` 跨平台 |
| v5.2 | 修复 `discover_agents` log 输出污染 stdout，导致日志文本被当 agent 名解析 |
| v5.2+ | 新增 `IDENTITY.md` / `BOOTSTRAP.md` 到同步清单；`install.sh` 默认选 main；增加 bash 3.2 兼容 |
| v5.3 | 新增 `keyword-monitor.sh`：监控 session 关键词 → 自动写入 `memory/keyword-YYYYMMDD.md`；`install.sh` 增加 `keywords.md` 初始化和 cron 安装提示 |

---

*🤖 记忆管理 + 关键词监控 - 支持 macOS (bash 3.2) / Linux*
