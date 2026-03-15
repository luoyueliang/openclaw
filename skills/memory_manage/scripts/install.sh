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
    OPENCLAW_PATHS=("$HOME/.openclaw" "$HOME/Library/Application Support/openclaw")
elif [ "$OS" = "Linux" ]; then
    OPENCLAW_PATHS=("$HOME/.openclaw" "/root/.openclaw")
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
    read -p "请输入 OpenClaw 路径: " OPENCLAW_ROOT
fi

if [ ! -d "$OPENCLAW_ROOT" ]; then
    echo "✗ 目录不存在"
    exit 1
fi

echo "使用: $OPENCLAW_ROOT"

# ========== 3. 检测 Agent ==========
echo ""
echo "检测 Agent..."

AGENTS_DIR="$OPENCLAW_ROOT/agents"
AVAILABLE_AGENTS=()

if [ -d "$AGENTS_DIR" ]; then
    for dir in "$AGENTS_DIR"/*/; do
        if [ -d "$dir/workspace" ]; then
            agent=$(basename "$dir")
            AVAILABLE_AGENTS+=("$agent")
        fi
    done
fi

if [ ${#AVAILABLE_AGENTS[@]} -gt 0 ]; then
    echo "可用的 Agent:"
    for i in "${!AVAILABLE_AGENTS[@]}"; do
        echo "  $((i+1)). ${AVAILABLE_AGENTS[$i]}"
    done
    
    echo ""
    echo "选择 Agent (输入编号或名称):"
    select AGENT_NAME in "${AVAILABLE_AGENTS[@]}"; do
        if [ -n "$AGENT_NAME" ]; then
            break
        fi
    done
else
    echo "未找到有 workspace 的 Agent"
    read -p "请输入 Agent 名称: " AGENT_NAME
fi

AGENT_NAME=${AGENT_NAME:-main}

# ========== 4. 实例名 ==========
echo ""
echo "============================================"
echo "实例名称 (用于 GitHub 备份仓库区分)"
echo "============================================"
echo ""
echo "格式: openclaw-<后缀>"
echo "示例: openclaw-home, openclaw-mac, openclaw-pro"
echo ""

read -p "输入后缀 (4-12字符) [mac]: " INSTANCE_SUFFIX
INSTANCE_SUFFIX=${INSTANCE_SUFFIX:-mac}

# 验证长度
if [ ${#INSTANCE_SUFFIX} -lt 4 ] || [ ${#INSTANCE_SUFFIX} -gt 12 ]; then
    echo "错误: 后缀长度必须是 4-12 字符"
    exit 1
fi

INSTANCE_NAME="openclaw-$INSTANCE_SUFFIX"

# ========== 5. 确认 ==========
echo ""
echo "============================================"
echo "确认信息"
echo "============================================"
echo ""
echo "  OpenClaw: $OPENCLAW_ROOT"
echo "  Agent:    $AGENT_NAME"
echo "  实例:     $INSTANCE_NAME"
echo ""
read -p "确认安装? (y/n): " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "已取消"
    exit 0
fi

# ========== 6. 安装目录 ==========
SKILLS_DIR="$OPENCLAW_ROOT/workspace/skills"
mkdir -p "$SKILLS_DIR/memory_manage/config"
mkdir -p "$SKILLS_DIR/memory_manage/scripts"
echo ""
echo "安装目录: $SKILLS_DIR/memory_manage"

# ========== 7. 下载 Skill ==========
echo ""
echo "下载 Skill..."
GITHUB_RAW="https://raw.githubusercontent.com/luoyueliang/openclaw/main/skills/memory_manage"

download() {
    if curl -sL "$1" -o "$2" 2>/dev/null; then
        echo "✓ $(basename $2)"
    else
        echo "✗ $(basename $2)"
    fi
}

download "$GITHUB_RAW/SKILL.md" "$SKILLS_DIR/memory_manage/SKILL.md"
download "$GITHUB_RAW/scripts/sync.sh" "$SKILLS_DIR/memory_manage/scripts/sync.sh"
download "$GITHUB_RAW/scripts/init-check.sh" "$SKILLS_DIR/memory_manage/scripts/init-check.sh"
download "$GITHUB_RAW/scripts/keywords-check.sh" "$SKILLS_DIR/memory_manage/scripts/keywords-check.sh"
download "$GITHUB_RAW/config/sync.yaml.example" "$SKILLS_DIR/memory_manage/config/sync.yaml.example"

chmod +x "$SKILLS_DIR/memory_manage/scripts/"*.sh

# ========== 8. GitHub 配置 ==========
echo ""
echo "============================================"
echo "GitHub 配置"
echo "============================================"
echo ""

read -p "GitHub 用户名: " GH_USER
read -p "备份仓库名 [ai_openclaw_memory]: " GH_REPO
GH_REPO=${GH_REPO:-ai_openclaw_memory}
echo ""
echo "Token 仅用于推送到你的私有备份仓库"
read -s -p "GitHub PAT: " GH_TOKEN
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

# ========== 9. 完成 ==========
echo ""
echo "============================================"
echo "✓ 安装完成"
echo "============================================"
echo ""
echo "配置确认:"
echo "  - 实例:   $INSTANCE_NAME"
echo "  - Agent: $AGENT_NAME"
echo "  - 仓库:   $GH_USER/$GH_REPO"
echo "  - Token: ${GH_TOKEN:0:4}...${GH_TOKEN: -4}"
echo ""
echo "位置: $SKILLS_DIR/memory_manage"
echo ""
