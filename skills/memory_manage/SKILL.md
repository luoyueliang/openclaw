# Memory Sync Skill - 记忆同步技能

## 设计目的

管理多个 OpenClaw 实例上多个 Agent 的记忆和配置文件备份，防止数据丢失。

## 核心概念

### 三层实体

| 层级 | 说明 | 示例 |
|------|------|------|
| **Instance** | 运行 OpenClaw 的机器 | openclaw-home, openclaw-vps, openclaw-macmini |
| **Agent** | 实例上的 Agent | main, coder, researcher |
| **Workspace** | Agent 的工作空间 | 包含记忆、配置、文档 |

### Workspace 目录结构规则

```
# 单 Agent（当前）
/root/.openclaw/
└── workspace/                      # main 的工作空间，直接用

# 多 Agent（未来）
/root/.openclaw/
├── agents/
│   ├── main/workspace/            # main Agent
│   ├── coder/workspace/           # coder Agent
│   └── researcher/workspace/      # researcher Agent
└── workspace/                     # 不应存在，或移除
```

**重要规则：**
- 单 Agent → 使用根目录 `workspace/`
- 多 Agent → 每个 Agent 有专属 `workspace/`，根目录的应移除

### OpenClaw 完整目录结构

```
/root/.openclaw/                          # OpenClaw 根目录
│
├── agents/                               # Agent 目录
│   └── {agent_name}/                     # 每个 Agent
│       ├── agent/                        # Agent 运行时
│       │   ├── auth-profiles.json       # 认证配置
│       │   └── models.json              # 模型配置
│       ├── sessions/                     # 会话历史
│       └── workspace/                    # ★ Agent 专属工作空间
│           ├── MEMORY.md                 # 核心记忆
│           ├── AGENTS.md                 # Agent 定义
│           ├── SOUL.md                   # Agent 人设
│           ├── USER.md                   # 用户信息
│           ├── TOOLS.md                  # 工具配置
│           ├── HEARTBEAT.md              # 心跳配置
│           ├── memory/                   # 日常记忆
│           │   └── *.md
│           ├── docs/                     # 项目文档（大，排除）
│           └── skills/                   # 技能
│
├── identity/                             # 实例身份
├── config/                               # 系统配置
└── memory/                               # 系统级向量DB
```

## 备份范围

### 需要同步（必须）

| 文件/目录 | 说明 | 大小 |
|-----------|------|------|
| `MEMORY.md` | 核心记忆 | 小 |
| `AGENTS.md` | Agent 定义 | 小 |
| `SOUL.md` | Agent 人设 | 小 |
| `USER.md` | 用户信息 | 小 |
| `TOOLS.md` | 工具配置 | 小 |
| `HEARTBEAT.md` | 心跳配置 | 小 |
| `memory/*.md` | 日常记忆 | 小 |

### 不同步（过滤）

| 文件/目录 | 原因 |
|-----------|------|
| `docs/**` | 项目文档太大 |
| `skills/**` | 技能配置太大 |
| `*.log` | 日志文件 |
| `node_modules/` | 依赖包 |

## 配置文件

路径：`/root/.openclaw/workspace/skills/memory-sync/config/sync.yaml`

```yaml
# ========== 实例配置（每个 OpenClaw 实例不同）==========
instance:
  name: openclaw-home                    # 实例名（必填，每个实例唯一）
  
# ========== Agent 配置（每个 Agent 不同）==========
agent:
  name: main                             # Agent 名（必填）

# ========== GitHub 配置 ==========
github:
  repo: https://github.com/luoyueliang/ai_openclaw_memory
  token: ghp_xxx                         # Personal Access Token

# ========== 同步配置 ==========
sync:
  interval_ms: 3600000                   # 同步间隔（1小时）
  
# ========== 过滤规则 ==========
exclude:
  dirs:                                  # 不同步的目录
    - docs
    - skills
    - archive
    - node_modules
```

## GitHub 备份结构

```
ai_openclaw_memory/                      # GitHub 仓库根目录
│
├── openclaw-home/                       # 实例 1
│   └── main/                            # Agent: main
│       ├── core/
│       │   ├── MEMORY.md
│       │   ├── AGENTS.md
│       │   ├── SOUL.md
│       │   └── ...
│       │
│       └── workspace/
│           └── memory/
│
└── openclaw-vps/                        # 实例 2
    ├── main/
    └── coder/
```

## 脚本说明

### 1. init-check.sh - 初始化检查

检查内容：

| 检查项 | 说明 |
|--------|------|
| OpenClaw 目录存在 | `/root/.openclaw/` 是否存在 |
| agents 目录存在 | Agent 目录结构是否正确 |
| workspace 存在 | Agent 的 workspace 是否存在 |
| 必要文件存在 | MEMORY.md, AGENTS.md 等 |
| 配置文件有效 | sync.yaml 是否正确配置 |

### 2. sync.sh - 同步脚本

执行流程：
1. 读取配置（instance.name, agent.name）
2. 自动检测 workspace 位置（兼容两种路径）
3. 过滤大文件/目录
4. 复制到 GitHub 备份目录
5. 提交并推送到 GitHub

## 使用方法

### 首次使用（新实例）

```bash
# 1. 运行初始化检查
/root/.openclaw/workspace/skills/memory-sync/scripts/init-check.sh

# 2. 根据提示配置
# - 修改 instance.name 为当前实例名
# - 修改 agent.name 为目标 Agent 名

# 3. 运行手动同步测试
/root/.openclaw/workspace/skills/memory-sync/scripts/sync.sh

# 4. 设置自动同步（通过 OpenClaw cron）
```

### 发布到 Skill Hub（私有）

```bash
# 1. 创建 GitHub 仓库：openclaw-skills

# 2. 初始化 Hub
/root/.openclaw/workspace/skills/hub.sh init

# 3. 推送 Skills
/root/.openclaw/workspace/skills/hub.sh publish
```

---

## 私有 Skill Hub

### 架构

```
GitHub: github.com/luoyueliang/openclaw-skills
│
├── memory-sync/           # Skill 1
│   ├── SKILL.md
│   ├── config/
│   └── scripts/
│
├── another-skill/        # Skill 2
│   └── ...
│
└── README.md             # Hub 索引
```

### 管理命令

```bash
# 初始化 Hub
/root/.openclaw/workspace/skills/hub.sh init

# 列出可用 Skills
/root/.openclaw/workspace/skills/hub.sh list

# 安装 Skill
/root/.openclaw/workspace/skills/hub.sh install memory-sync

# 更新 Skill
/root/.openclaw/workspace/skills/hub.sh update memory-sync

# 发布更新
/root/.openclaw/workspace/skills/hub.sh publish
```

---

*🤖 自动同步记忆到 GitHub，防止数据丢失*
