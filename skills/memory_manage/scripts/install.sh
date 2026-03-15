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

# ========== 2. 使用 openclaw agents list 获取信息 ==========
echo ""
echo "获取 Agent 列表..."

AGENT_OUTPUT=$(openclaw agents list 2>/dev/null)

if [ -z "$AGENT_OUTPUT" ]; then
    echo "✗ 无法获取 agent 列表，请确保 openclaw 已安装"
    exit 1
fi

echo "官方 Agent 列表:"
echo "$AGENT_OUTPUT"

# ========== 3. 解析 ==========
echo ""
echo "解析 Workspace..."

# 提取 agent 和 workspace
declare -A AGENT_WORKSPACES
CURRENT_AGENT=""

echo "$AGENT_OUTPUT" | while IFS= read -r line; do
    # Agent 行: - name (default)
    if [[ "$line" =~ ^-\ (.+)\ \(default\) ]]; then
        CURRENT_AGENT="${BASH_REMATCH[1]}"
    # Agent 行: - name
    elif [[ "$line" =~ ^-\ (.+)$ ]]; then
        CURRENT_AGENT="${BASH_REMATCH[1]}"
    # Workspace 行
    elif [[ "$line" =~ Workspace:\ (.+) ]]; then
        ws="${BASH_REMATCH[1]}"
        # 展开 ~
        ws=$(eval echo "$ws")
        if [ -n "$CURRENT_AGENT" ]; then
            echo "$CURRENT_AGENT|$ws"
        fi
    fi
done > /tmp/openclaw_agents.txt

# 读取结果
mapfile -t AGENT_LIST < /tmp/openclaw_agents.txt

if [ ${#AGENT_LIST[@]} -eq 0 ]; then
    echo "✗ 未找到 agent"
    exit 1
fi

# 显示
echo ""
echo "可用的 Agent:"
i=1
for entry in "${AGENT_LIST[@]}"; do
    agent="${entry%%|*}"
    ws="${entry##*|}"
    echo "  $i. $agent → $ws"
    ((i++))
done

# ========== 4. 选择 ==========
echo ""
echo "选择 Agent (输入编号):"
read -p "> " choice

if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#AGENT_LIST[@]} ]; then
    idx=$((choice-1))
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
echo "实例名称 (GitHub 备份区分)"
echo "============================================"
echo "格式: openclaw-<后缀>"
echo ""

read -p "输入后缀 (4-12字符) [mac]: " INSTANCE_SUFFIX
INSTANCE_SUFFIX=${INSTANCE_SUFFIX:-mac}

[ ${#INSTANCE_SUFFIX} -lt 4 ] || [ ${#INSTANCE_SUFFIX} -gt 12 ] && echo "错误: 4-12字符" && exit 1

INSTANCE_NAME="openclaw-$INSTANCE_SUFFIX"

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
download "$GITHUB_RAW/config/sync.yaml.example" "$SKILLS_DIR/memory_manage/config/sync.yaml.example"

chmod +x "$SKILLS_DIR/memory_manage/scripts/"*.sh

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
