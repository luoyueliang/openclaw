# Memory Manage Skill - 记忆管理技能

## 私有 Skill Hub

**地址：** https://github.com/luoyueliang/openclaw/tree/main/skills/

## 安装

### 1. 安装位置

| 模式 | 安装路径 |
|------|---------|
| 单 Agent | `/root/.openclaw/workspace/skills/memory_manage/` |
| 多 Agent | `/root/.openclaw/agents/main/workspace/skills/memory_manage/` |

### 2. 安装步骤

```bash
# 创建目录
mkdir -p /root/.openclaw/workspace/skills/memory_manage

# 克隆或复制 scripts
# 从 GitHub: https://github.com/luoyueliang/openclaw/tree/main/skills/memory_manage

# 创建配置文件
cp config/sync.yaml.example config/sync.yaml

# 编辑配置（填入你的信息）
vim config/sync.yaml

# 运行初始化检查
./scripts/init-check.sh

# 测试同步
./scripts/sync.sh
```

### 3. 初始化检查

运行 `init-check.sh` 检查：
- OpenClaw 目录是否存在
- workspace 是否存在
- 配置文件是否有效
- GitHub Token 是否有效

## 功能

### 1. 记忆同步
- 自动备份 MEMORY.md、AGENTS.md、SOUL.md 等核心文件
- 备份 memory/ 目录下的日常记忆
- 推送到私有 GitHub 仓库

### 2. 关键词触发
当检测到以下关键词时，自动更新记忆：

| 关键词类型 | 关键词 |
|----------|--------|
| 记住类 | 帮我记住、记住、记录、存一下 |
| 原则类 | 原则、守则、规则 |
| 禁止类 | 禁止、严禁、不许、不能做 |
| 偏好类 | 我喜欢、我讨厌、我想要、我偏好 |
| 重要类 | 重要、别忘了、提醒我 |

### 3. 多 Agent 管理

只有 **main** Agent 能管理其他 Agent 的记忆。

| Agent | 能管理的范围 |
|-------|------------|
| main | 所有 Agent |
| 其他 | 只能管自己 |

## 目录结构

```
memory_manage/
├── SKILL.md                    # 本文档
├── config/
│   ├── sync.yaml.example       # 配置示例
│   └── sync.yaml               # 实际配置（不推送到公开仓库）
└── scripts/
    ├── init-check.sh           # 初始化检查
    └── sync.sh                 # 同步脚本
```

## 配置说明

详见 `config/sync.yaml.example`

## 自动同步

通过 OpenClaw cron 设置每小时自动同步：

```bash
# 设置定时任务
openclaw cron add --schedule "every 1h" --message "运行记忆同步脚本"
```

---

*🤖 记忆管理技能 - 自动备份到 GitHub*
