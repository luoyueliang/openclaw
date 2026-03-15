#!/bin/bash
# Memory Manage Skill 一键安装脚本

echo ""
echo "============================================"
echo "      Memory Manage Skill 一键安装"
echo "============================================"
echo ""

# ========== 1. 检测操作系统 ==========
OS=$(uname -s)
echo "检测操作系统: $OS"

if [ "$OS" = "Darwin" ]; then
    # Mac
    OPENCLAW_PATHS=(
        "$HOME/.openclaw"
        "$HOME/Library/Application Support/openclaw"
    )
elif [ "$OS" = "Linux" ]; then
    # Linux
    OPENCLAW_PATHS=(
        "$HOME/.openclaw"
        "/root/.openclaw"
    )
else
    echo "不支持的操作系统: $OS"
    exit 1
fi

# ========== 2. 查找 OpenClaw 目录 ==========
echo ""
echo "检测 OpenClaw 安装目录..."
OPENCLAW_ROOT=""
for path in "${OPENCLAW_PATHS[@]}"; do
    if [ -d "$path" ]; then
        OPENCLAW_ROOT="$path"
        echo "✓ 找到: $path"
        break
    fi
done

if [ -z "$OPENCLAW_ROOT" ]; then
    echo "✗ 未找到 OpenClaw 目录"
    echo "请手动输入 OpenClaw 路径:"
    read -p "> " OPENCLAW_ROOT
fi

if [ ! -d "$OPENCLAW_ROOT" ]; then
    echo "✗ 目录不存在: $OPENCLAW_ROOT"
    exit 1
fi

echo "使用目录: $OPENCLAW_ROOT"

# ========== 3. 检测 Agent ==========
echo ""
echo "检测 Agent..."
AGENTS_DIR="$OPENCLAW_ROOT/agents"

if [ -d "$AGENTS_DIR" ]; then
    # 找出所有有 workspace 的 agent
    AVAILABLE_AGENTS=()
    for dir in "$AGENTS_DIR"/*/; do
        if [ -d "$dir/workspace" ]; then
            agent_name=$(basename "$dir")
            AVAILABLE_AGENTS+=("$agent_name")
            echo "  - $agent_name"
        fi
    done
fi

if [ ${#AVAILABLE_AGENTS[@]} -eq 0 ]; then
    echo "未找到有 workspace 的 Agent"
    echo "请手动输入 Agent 名称:"
    read -p "> " AGENT_NAME
else
    echo ""
    echo "选择 Agent (输入编号或名称):"
    select choice in "${AVAILABLE_AGENTS[@]}"; do
        if [ -n "$choice" ]; then
            AGENT_NAME="$choice"
            break
        fi
    done
fi

AGENT_NAME=${AGENT_NAME:-main}
echo "选择 Agent: $AGENT_NAME"

# ========== 4. 确认实例名 ==========
echo ""
echo "============================================"
read -p "实例名称 (用于备份仓库区分) [openclaw-$AGENT_NAME]: " INSTANCE_NAME
INSTANCE_NAME=${INSTANCE_NAME:-openclaw-$AGENT_NAME}

echo ""
echo "确认信息:"
echo "  - OpenClaw: $OPENCLAW_ROOT"
echo "  - Agent: $AGENT_NAME"
echo "  - 实例: $INSTANCE_NAME"
echo ""
read -p "确认继续? (y/n): " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "已取消"
    exit 0
fi

# ========== 5. 安装目录 ==========
SKILLS_DIR="$OPENCLAW_ROOT/workspace/skills"

echo ""
echo "创建目录..."
mkdir -p "$SKILLS_DIR/memory_manage/config"
mkdir -p "$SKILLS_DIR/memory_manage/scripts"
echo "✓ 安装目录: $SKILLS_DIR/memory_manage"

# ========== 6. 下载 Skill ==========
echo ""
echo "下载 Skill..."
GITHUB_RAW="https://raw.githubusercontent.com/luoyueliang/openclaw/main/skills/memory_manage"

download() {
    local url=$1
    local file=$2
    if curl -sL "$url" -o "$file" 2>/dev/null; then
        echo "✓ $(basename $file)"
    else
        echo "✗ $(basename $file)"
    fi
}

download "$GITHUB_RAW/SKILL.md" "$SKILLS_DIR/memory_manage/SKILL.md"
download "$GITHUB_RAW/scripts/sync.sh" "$SKILLS_DIR/memory_manage/scripts/sync.sh"
download "$GITHUB_RAW/scripts/init-check.sh" "$SKILLS_DIR/memory_manage/scripts/init-check.sh"
download "$GITHUB_RAW/scripts/keywords-check.sh" "$SKILLS_DIR/memory_manage/scripts/keywords-check.sh"
download "$GITHUB_RAW/config/sync.yaml.example" "$SKILLS_DIR/memory_manage/config/sync.yaml.example"

chmod +x "$SKILLS_DIR/memory_manage/scripts/"*.sh 2>/dev/null

# ========== 7. 配置 ==========
echo ""
echo "============================================"
echo "配置 GitHub"
echo "============================================"

read -p "GitHub 用户名 (用于备份仓库): " GH_USER
read -p "备份仓库名 [ai_openclaw_memory]: " GH_REPO
GH_REPO=${GH_REPO:-ai_openclaw_memory}
read -s -p "GitHub PAT (Token): " GH_TOKEN
echo ""

# 生成配置
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
echo "配置确认:"
echo "  - 实例: $INSTANCE_NAME"
echo "  - Agent: $AGENT_NAME"
echo "  - GitHub: $GH_USER/$GH_REPO"
echo "  - Token: ${GH_TOKEN:0:4}...${GH_TOKEN: -4}"
echo ""
echo "Skill 位置: $SKILLS_DIR/memory_manage"
echo ""
