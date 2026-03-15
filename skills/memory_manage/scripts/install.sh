#!/bin/bash
# Memory Manage Skill 一键安装脚本

echo ""
echo "========== Memory Manage 一键安装 =========="
echo ""

# 强制获取当前用户的真实家目录
CURRENT_USER=$(whoami)
CURRENT_HOME=$(eval echo ~$CURRENT_USER)

echo "当前用户: $CURRENT_USER"
echo "用户目录: $CURRENT_HOME"
echo ""

# 尝试多个可能的路径
possible_paths=(
    "$CURRENT_HOME/.openclaw"
    "$CURRENT_HOME/Library/Application Support/openclaw"
    "/Users/$CURRENT_USER/.openclaw"
)

OPENCLAW_ROOT=""
for path in "${possible_paths[@]}"; do
    if [ -d "$path" ]; then
        OPENCLAW_ROOT="$path"
        echo "找到 OpenClaw: $path"
        break
    fi
done

# 如果没找到
if [ -z "$OPENCLAW_ROOT" ]; then
    echo "未找到 OpenClaw，请手动输入路径"
    echo "常见路径："
    echo "  - ~/.openclaw"
    echo "  - ~/Library/Application Support/openclaw"
    echo ""
    read -p "OpenClaw 路径: " OPENCLAW_ROOT
fi

echo "使用路径: $OPENCLAW_ROOT"
echo ""

# 检测模式
if [ -d "$OPENCLAW_ROOT/agents/main/workspace" ]; then
    MODE="multi"
    SKILLS_DIR="$OPENCLAW_ROOT/agents/main/workspace/skills"
else
    MODE="single"
    SKILLS_DIR="$OPENCLAW_ROOT/workspace/skills"
fi

echo "安装模式: $MODE"
echo "目标目录: $SKILLS_DIR"
echo ""

# 创建目录
echo "创建目录..."
if ! mkdir -p "$SKILLS_DIR/memory_manage" 2>/dev/null; then
    echo "错误: 无法创建 $SKILLS_DIR"
    echo "请手动创建目录或检查权限"
    exit 1
fi
mkdir -p "$SKILLS_DIR/memory_manage/config"
mkdir -p "$SKILLS_DIR/memory_manage/scripts"
echo "✓ 目录创建完成"
echo ""

# 下载 Skill
echo "========== 下载 Skill =========="
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

# 配置
echo ""
echo "========== 配置 =========="
echo ""

read -p "实例名 [openclaw-home]: " INSTANCE_NAME
INSTANCE_NAME=${INSTANCE_NAME:-openclaw-home}

read -p "Agent 名 [main]: " AGENT_NAME
AGENT_NAME=${AGENT_NAME:-main}

read -p "备份仓库地址 [https://github.com/luoyueliang/ai_openclaw_memory]: " BACKUP_REPO
BACKUP_REPO=${BACKUP_REPO:-https://github.com/luoyueliang/ai_openclaw_memory}

echo ""
read -s -p "GitHub Token: " GITHUB_TOKEN
echo ""

cat > "$SKILLS_DIR/memory_manage/config/sync.yaml" << EOF
instance:
  name: $INSTANCE_NAME

agent:
  name: $AGENT_NAME

github:
  repo: $BACKUP_REPO
  token: $GITHUB_TOKEN
EOF

echo ""
echo "✓ 配置完成"
echo ""
echo "========== 安装完成 =========="
echo "Skill: memory_manage"
echo "位置: $SKILLS_DIR/memory_manage"
echo ""
