# OpenClaw Copilot Instructions

## 项目概述

OpenClaw 是一个 AI Agent 管理平台的**技能(Skill)发行系统**。  
本仓库为 Skill Hub，负责维护和分发可安装到 OpenClaw 实例的独立技能包。

### 核心概念

| 概念 | 说明 |
|------|------|
| **实例 (Instance)** | 每台运行 OpenClaw 的机器，有唯一 `instance.name` |
| **Agent** | OpenClaw 内的 AI Agent，主 Agent 叫 `main`，可管理其他 Agent |
| **Skill** | 可安装到实例的功能包，位于 `~/.openclaw/workspace/skills/<skill-name>/` |
| **Memory 文件** | Agent 的核心记忆：`MEMORY.md`、`AGENTS.md`、`SOUL.md`、`USER.md` |

### 目录规范

```
skills/
├── install-skill.sh          # 通用 Skill 安装器（从本 Hub 拉取）
├── README.md                 # Skill 列表说明
└── <skill-name>/
    ├── README.md             # 面向用户的安装和使用文档
    ├── SKILL.md              # 面向 Copilot/AI 的技术规范文档
    ├── config/
    │   ├── sync.yaml.example # 配置模板（必须提供）
    │   └── sync.yaml         # 实际配置（gitignore，不提交）
    └── scripts/
        ├── install.sh        # 一键安装脚本
        ├── init-check.sh     # 初始化检查脚本
        └── *.sh              # 其他功能脚本
```

---

## OpenClaw 运行时路径

```bash
# macOS
~/.openclaw/
~/Library/Application Support/openclaw/

# Linux / VPS
/root/.openclaw/
~/.openclaw/

# Agent workspace（多 Agent 模式）
~/.openclaw/agents/<agent-name>/workspace/

# Agent workspace（单 Agent 模式）
~/.openclaw/workspace/

# Skill 安装路径
~/.openclaw/workspace/skills/<skill-name>/
```

---

## Bash 脚本规范

### 文件头格式

```bash
#!/bin/bash
# <功能简述>
# <额外说明>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
```

### 颜色输出函数（所有脚本统一使用）

```bash
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_ok()   { echo -e "${GREEN}✓${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
log_err()  { echo -e "${RED}✗${NC} $1"; }
log()      { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }
```

> `install.sh` 中可用 `echo_ok` / `echo_warn` / `echo_err` 替代，保持风格一致。

### OS 检测模式

```bash
OS=$(uname -s)
if [ "$OS" = "Darwin" ]; then
    paths=("$HOME/.openclaw" "$HOME/Library/Application Support/openclaw")
else
    paths=("$HOME/.openclaw" "/root/.openclaw")
fi
```

### 获取 Agent 信息（优先使用 CLI）

```bash
# 获取 agent 列表
openclaw agents list 2>/dev/null

# 解析 agent 名
openclaw agents list 2>/dev/null | grep -E "^- " | sed 's/- //' | sed 's/ (default)//'
```

### YAML 配置读取（不依赖 yq，用 grep/awk）

```bash
INSTANCE_NAME=$(grep -A1 "instance:" "$CONFIG_FILE" | grep "name:" | awk -F': ' '{print $2}' | tr -d ' ')
AGENT_NAME=$(grep -A1 "agent:" "$CONFIG_FILE" | grep "name:" | awk -F': ' '{print $2}' | tr -d ' ')
GITHUB_TOKEN=$(grep "token:" "$CONFIG_FILE" | awk -F': ' '{print $2}' | tr -d ' ')
```

---

## Skill 开发规范

### 新建 Skill 必须包含

1. `README.md` — 用户文档（安装步骤、配置说明）
2. `SKILL.md` — AI/Copilot 技术规范（功能、脚本说明、配置结构）
3. `config/sync.yaml.example` — 配置模板，不含真实 token/密钥
4. `scripts/install.sh` — 交互式一键安装，检测 OpenClaw 路径并自动配置
5. `scripts/init-check.sh` — 初始化自检，验证依赖和文件完整性

### SKILL.md 结构模板

```markdown
# <Skill Name> - <中文名>

## 功能概述
...

## 脚本说明
### install.sh
### init-check.sh
### <其他脚本>.sh

## 配置

### sync.yaml
\`\`\`yaml
...示例...
\`\`\`

## 自动运行（cron 示例）
\`\`\`bash
0 * * * * /path/to/script.sh
\`\`\`
```

### config/sync.yaml.example 必须包含字段

```yaml
instance:
  name: openclaw-home        # 每台机器唯一

agent:
  name: main                 # 默认 main

github:
  repo: https://github.com/用户名/仓库名
  token: ghp_你的GitHubPAT   # 不提交真实 token

# 可选：通知配置
notify:
  feishu_webhook: ""
  email:
    enabled: false
    to: ""
```

---

## 通知规范

统一支持两种通知渠道，配置在 `sync.yaml` 中：

| 渠道 | 配置键 | 说明 |
|------|--------|------|
| 飞书 | `notify.feishu_webhook` | POST JSON 到 Webhook |
| 邮件 | `notify.email.to` | 依赖 `sendmail` 命令 |

通知函数模式：

```bash
notify() {
    local title="$1"
    local message="$2"
    
    if [ -n "$FEISHU_WEBHOOK" ]; then
        curl -s -X POST "$FEISHU_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{\"msg_type\": \"text\", \"content\": {\"text\": \"$title\n$message\"}}"
    fi
    
    if [ -n "$EMAIL_TO" ] && command -v sendmail &>/dev/null; then
        echo -e "Subject: $title\n\n$message" | sendmail "$EMAIL_TO"
    fi
}
```

---

## 安全规范

- `config/sync.yaml`（含真实 token）必须在 `.gitignore` 中
- 脚本中 **不硬编码** GitHub Token、Webhook URL 等敏感信息
- 所有敏感配置通过 `sync.yaml` 注入，`sync.yaml.example` 只放占位符
- Git clone 等网络操作使用 `--depth 1` 减少攻击面
- 临时目录使用 `$$` 加 PID 隔离：`/tmp/openclaw-hub-$$`，用后立即 `rm -rf`

---

## install.sh 标准交互流程

```
实例名 [openclaw-home]:        <- 提示默认值
Agent 名 [main]:
记忆备份仓库地址 [...]:
GitHub Token: ****             <- 密码输入不回显
```

使用 `read -p "提示 [默认]: " VAR` 收集输入，若为空则取默认值：

```bash
read -p "实例名 [openclaw-home]: " INSTANCE_NAME
INSTANCE_NAME=${INSTANCE_NAME:-"openclaw-home"}
```

---

## 扩展新 Skill 到 Hub

1. 在 `skills/` 下创建 `<skill-name>/` 目录
2. 按规范添加 `README.md`、`SKILL.md`、`config/`、`scripts/`
3. 在 `skills/README.md` 中添加 Skill 条目
4. 确保 `install.sh` 可以直接从 `curl | bash` 或本地运行
5. `install-skill.sh` 会从本仓库拉取并安装，无需修改该文件

---

## 代码风格

- 使用 `[[ ]]` 代替 `[ ]` 做条件判断
- 字符串变量始终加引号：`"$VAR"`
- 数组遍历使用 `for item in "${array[@]}"`
- 函数定义放在脚本顶部，`main()` 放在最后并由 `main "$@"` 调用
- 脚本出错时用 `exit 1`，正常结束用 `exit 0`
