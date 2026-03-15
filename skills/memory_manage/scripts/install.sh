#!/bin/bash
# Memory Manage Skill 一键安装脚本
# 从 openclaw.json 读取 agent 和 workspace 配置

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

[ -z "$OPENCLAW_ROOT" ] && echo "✗ 未找到" && exit 1

CONFIG_FILE="$OPENCLAW_ROOT/openclaw.json"

[ ! -f "$CONFIG_FILE" ] && echo "✗ 配置文件不存在: $CONFIG_FILE" && exit 1

# ========== 2. 解析 agents.list ==========
echo ""
echo "解析 Agent 配置..."

# 用 grep + awk 简单解析（不用 jq）
DEFAULT_WORKSPACE=$(grep -o '"workspace": *"[^"]*"' "$CONFIG_FILE" | head -1 | sed 's/.*: *"\([^"]*\)"/\1/')

echo "默认 Workspace: $DEFAULT_WORKSPACE"

# 提取所有 agent
echo ""
echo "可用的 Agent:"
AGENT_COUNT=0
AGENT_NAMES=()
AGENT_WORKSPACES=()

# 解析 agents.list
while IFS= read -r line; do
    if [[ "$line" =~ \"id\":\ *\"([^\"]+)\" ]]; then
        AGENT_NAMES+=("${BASH_REMATCH[1]}")
    fi
    if [[ "$line" =~ \"workspace\":\ *\"([^\"]+)\" ]]; then
        AGENT_WORKSPACES+=("${BASH_REMATCH[1]}")
    fi
done < <(grep -o '{[^}]*}' "$CONFIG_FILE" | grep '"id":' || true)

# 显示
i=1
for agent in "${AGENT_NAMES[@]}"; do
    ws="${AGENT_WORKSPACES[$((i-1))]:-$DEFAULT_WORKSPACE}"
    echo "  $i. $agent → $ws"
    ((i++))
done

# ========== 3. 选择 Agent ==========
echo ""
echo "选择 Agent (输入编号):"
read -p "> " choice

if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#AGENT_NAMES[@]} ]; then
    idx=$((choice-1))
    AGENT_NAME="${AGENT_NAMES[$idx]}"
    WORKSPACE="${AGENT_WORKSPACES[$idx]:-$DEFAULT_WORKSPACE}"
else
    AGENT_NAME="main"
    WORKSPACE="$DEFAULT_WORKSPACE"
fi

echo "选择: $AGENT_NAME"
echo "Workspace: $WORKSPACE"

# ========== 4. 实例名 ==========
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

# ========== 5. 确认 ==========
echo ""
echo "============================================"
echo "确认"
echo "============================================"
echo ""
echo "  OpenClaw: $OPENCLAW_ROOT"
echo "  Agent:    $AGENT_NAME"
echo "  实例:     $INSTANCE_NAME"
echo ""
read -p "确认? (y/n): " confirm
[ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && exit 0

# ========== 6. 安装 ==========
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

# ========== 7. GitHub ==========
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

# ========== 8. 完成 ==========
echo ""
echo "============================================"
echo "✓ 安装完成"
echo "============================================"
echo ""
echo "  实例: $INSTANCE_NAME"
echo "  Agent: $AGENT_NAME"
echo "  仓库: $GH_USER/$GH_REPO"
echo ""
