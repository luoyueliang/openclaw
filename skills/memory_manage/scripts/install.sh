#!/bin/bash
# Memory Manage Skill 一键安装脚本
# 使用 openclaw agents list 获取准确的 agent 和 workspace 信息

echo ""
echo "============================================"
echo "      Memory Manage Skill 一键安装"
echo "============================================"
echo ""

# ========== 1. 找 OpenClaw ==========
OS=$(uname -s)
echo "检测操作系统: $OS"

if [ "$OS" = "Darwin" ]; then
    paths=("$HOME/.openclaw" "$HOME/Library/Application Support/openclaw")
else
    paths=("$HOME/.openclaw" "/root/.openclaw")
fi

OPENCLAW_ROOT=""
for path in "${paths[@]}"; do
    if [ -d "$path" ]; then
        OPENCLAW_ROOT="$path"
        echo "✓ 找到: $path"
        break
    fi
done

if [ -z "$OPENCLAW_ROOT" ]; then
    echo "✗ 未找到 OpenClaw"
    exit 1
fi

cd "$OPENCLAW_ROOT"

# ========== 2. 获取 Agent 列表（优先 CLI，fallback 扫目录）==========
echo ""
echo "获取 Agent 列表..."

# 尝试从多个常见路径找到 openclaw CLI
OPENCLAW_BIN=""
for bin in openclaw /usr/bin/openclaw /usr/local/bin/openclaw \
           /opt/homebrew/bin/openclaw "$HOME/.local/bin/openclaw"; do
    if command -v "$bin" >/dev/null 2>&1 || [ -x "$bin" ]; then
        OPENCLAW_BIN="$bin"
        break
    fi
done

> /tmp/openclaw_agents_$$.txt

if [ -n "$OPENCLAW_BIN" ]; then
    AGENT_OUTPUT=$("$OPENCLAW_BIN" agents list 2>/dev/null)
fi

if [ -n "$AGENT_OUTPUT" ]; then
    echo "Agent 列表 (via CLI):"
    echo "$AGENT_OUTPUT"
    echo ""
    echo "解析 Workspace..."

    CURRENT_AGENT=""
    while IFS= read -r line; do
        if [[ "$line" =~ ^-\ (.+)\ \(default\) ]]; then
            CURRENT_AGENT="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^-\ (.+)$ ]]; then
            CURRENT_AGENT="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ Workspace:\ (.+) ]]; then
            ws="${BASH_REMATCH[1]}"
            ws=$(eval echo "$ws")
            if [ -n "$CURRENT_AGENT" ]; then
                echo "$CURRENT_AGENT|$ws" >> /tmp/openclaw_agents_$$.txt
                CURRENT_AGENT=""
            fi
        fi
    done <<< "$AGENT_OUTPUT"
fi

# 若 CLI 解析不到结果，降级扫描 agents 目录
if [ ! -s /tmp/openclaw_agents_$$.txt ]; then
    echo "⚠ CLI 未返回结果，扫描 $OPENCLAW_ROOT/agents/ ..."
    if [ -d "$OPENCLAW_ROOT/agents" ]; then
        for agent_dir in "$OPENCLAW_ROOT/agents"/*/; do
            [ -d "$agent_dir" ] || continue
            agent_name=$(basename "$agent_dir")
            ws="$OPENCLAW_ROOT/agents/$agent_name/workspace"
            [ -d "$ws" ] || ws="$OPENCLAW_ROOT/workspace"
            echo "$agent_name|$ws" >> /tmp/openclaw_agents_$$.txt
        done
    fi
fi

# 若仍为空，使用默认单 Agent 模式
if [ ! -s /tmp/openclaw_agents_$$.txt ]; then
    echo "main|$OPENCLAW_ROOT/workspace" > /tmp/openclaw_agents_$$.txt
fi

# ========== 3. 读取结果（bash 3.2 兼容，不用 mapfile）==========
AGENT_LIST=()
i=0
while IFS= read -r line; do
    AGENT_LIST[$i]="$line"
    i=$((i + 1))
done < /tmp/openclaw_agents_$$.txt
rm -f /tmp/openclaw_agents_$$.txt

if [ ${#AGENT_LIST[@]} -eq 0 ]; then
    echo "✗ 未找到任何 Agent"
    exit 1
fi

# 显示
echo ""
echo "可用的 Agent:"
DEFAULT_IDX=1
i=0
while [ $i -lt ${#AGENT_LIST[@]} ]; do
    entry="${AGENT_LIST[$i]}"
    agent="${entry%%|*}"
    ws="${entry##*|}"
    echo "  $((i+1)). $agent → $ws"
    # 找 main 作为默认
    if [ "$agent" = "main" ]; then
        DEFAULT_IDX=$((i+1))
    fi
    i=$((i + 1))
done

# ========== 4. 选择 ==========
echo ""
read -p "选择 Agent (输入编号) [$DEFAULT_IDX]: " choice
choice=${choice:-$DEFAULT_IDX}

if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#AGENT_LIST[@]} ]; then
    idx=$((choice - 1))
    entry="${AGENT_LIST[$idx]}"
    AGENT_NAME="${entry%%|*}"
    WORKSPACE="${entry##*|}"
else
    AGENT_NAME="main"
    WORKSPACE="$OPENCLAW_ROOT/workspace"
fi

echo "选择: $AGENT_NAME"
echo "Workspace: $WORKSPACE"

# ========== 5. 实例名 ==========
echo ""
echo "============================================"
echo "实例名称 (GitHub 备份区分不同机器)"
echo "============================================"
echo "建议格式: openclaw-<机器用途>，如 openclaw-macpro / openclaw-home"
echo ""

read -p "实例名称 [openclaw-home]: " INSTANCE_NAME
INSTANCE_NAME=${INSTANCE_NAME:-"openclaw-home"}

if [[ ! "$INSTANCE_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "✗ 实例名仅允许字母、数字、- 和 _"
    exit 1
fi

# ========== 6. 确认 ==========
echo ""
echo "============================================"
echo "确认"
echo "============================================"
echo ""
echo "  OpenClaw: $OPENCLAW_ROOT"
echo "  Agent:    $AGENT_NAME"
echo "  Workspace: $WORKSPACE"
echo "  实例:     $INSTANCE_NAME"
echo ""
read -p "确认? (y/n): " confirm
[ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && exit 0

# ========== 7. 安装 ==========
SKILLS_DIR="$WORKSPACE/skills"
mkdir -p "$SKILLS_DIR/memory_manage/config"
mkdir -p "$SKILLS_DIR/memory_manage/scripts"

echo ""
echo "安装到: $SKILLS_DIR/memory_manage"

# 下载
echo ""
echo "下载 Skill..."
GITHUB_RAW="https://raw.githubusercontent.com/luoyueliang/openclaw/main/skills/memory_manage"

download() {
    curl -sL "$1" -o "$2" 2>/dev/null && echo "✓ $(basename $2)" || echo "✗ $(basename $2)"
}

download "$GITHUB_RAW/SKILL.md" "$SKILLS_DIR/memory_manage/SKILL.md"
download "$GITHUB_RAW/scripts/sync.sh" "$SKILLS_DIR/memory_manage/scripts/sync.sh"
download "$GITHUB_RAW/scripts/init-check.sh" "$SKILLS_DIR/memory_manage/scripts/init-check.sh"
download "$GITHUB_RAW/scripts/keywords-check.sh" "$SKILLS_DIR/memory_manage/scripts/keywords-check.sh"
download "$GITHUB_RAW/scripts/keyword-monitor.sh" "$SKILLS_DIR/memory_manage/scripts/keyword-monitor.sh"
download "$GITHUB_RAW/config/sync.yaml.example" "$SKILLS_DIR/memory_manage/config/sync.yaml.example"

chmod +x "$SKILLS_DIR/memory_manage/scripts/"*.sh

# 若 keywords.md 不存在，创建默认版本
KEYWORDS_FILE="$WORKSPACE/memory/keywords.md"
mkdir -p "$WORKSPACE/memory"
if [ ! -f "$KEYWORDS_FILE" ]; then
    cat > "$KEYWORDS_FILE" << 'KWEOF'
# 记忆关键词配置

## 自动触发记忆的关键词
当用户发送的消息包含以下关键词时，自动提取并保存到 memory/ 目录：

### 记住类
- 帮我记住
- 记住
- 记录
- 存一下

### 原则类
- 原则
- 守则
- 规则

### 禁止类
- 禁止
- 严禁
- 不许
- 不能做

### 偏好类
- 我喜欢
- 我讨厌
- 我想要
- 我偏好

### 重要类
- 重要
- 别忘了
- 提醒我
- 标记

## 保存格式
当检测到关键词时，自动提取关键信息并保存到 memory/keyword-YYYYMMDD.md，格式：
```
### [时间] 关键词
用户要求记住的内容...
```
KWEOF
    echo "✓ keywords.md"
fi

# ========== 8. GitHub ==========
echo ""
echo "============================================"
echo "GitHub 配置"
echo "============================================"
echo ""

read -p "GitHub 用户名: " GH_USER
read -p "备份仓库名 [ai_openclaw_memory]: " GH_REPO
GH_REPO=${GH_REPO:-ai_openclaw_memory}
echo ""
read -s -p "GitHub PAT: " GH_TOKEN
echo ""

cat > "$SKILLS_DIR/memory_manage/config/sync.yaml" << EOF
instance:
  name: $INSTANCE_NAME

agent:
  name: $AGENT_NAME

github:
  repo: https://github.com/$GH_USER/$GH_REPO
  token: $GH_TOKEN
EOF

# ========== 9. 完成 ==========
echo ""
echo "============================================"
echo "✓ 安装完成"
echo "============================================"
echo ""
echo "  实例: $INSTANCE_NAME"
echo "  Agent: $AGENT_NAME"
echo "  仓库: $GH_USER/$GH_REPO"
echo ""
echo "============================================"
echo "建议设置定时任务（可选）"
echo "============================================"
echo ""
echo "每小时同步 memory → GitHub (复制运行):"
echo "  (crontab -l 2>/dev/null; echo \"0 * * * * $SKILLS_DIR/memory_manage/scripts/sync.sh >> /tmp/openclaw-sync.log 2>&1\") | crontab -"
echo ""
echo "每 5 分钟监控关键词:"
echo "  (crontab -l 2>/dev/null; echo \"*/5 * * * * $SKILLS_DIR/memory_manage/scripts/keyword-monitor.sh >> /tmp/openclaw-keyword.log 2>&1\") | crontab -"
echo ""
echo "查看关键词配置: $WORKSPACE/memory/keywords.md"
echo ""
