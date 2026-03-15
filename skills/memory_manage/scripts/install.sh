#!/bin/bash
# Memory Manage Skill 一键安装脚本
# 自动下载 Skill + 交互式配置

echo ""
echo "========== Memory Manage 一键安装 =========="
echo ""

# 检测当前用户
CURRENT_USER=$(whoami)
CURRENT_HOME=$(echo ~)
echo "当前用户: $CURRENT_USER"
echo "用户目录: $CURRENT_HOME"
echo ""

# 先尝试常见路径
OPENCLAW_ROOT=""
possible_paths=(
    "$CURRENT_HOME/.openclaw"
    "$CURRENT_HOME/Library/Application Support/openclaw"
    "$HOME/.openclaw"
    "/root/.openclaw"
)

echo "检测 OpenClaw 路径..."
for path in "${possible_paths[@]}"; do
    if [ -d "$path" ]; then
        OPENCLAW_ROOT="$path"
        echo "找到: $path"
        break
    fi
done

# 如果没找到，让用户输入
if [ -z "$OPENCLAW_ROOT" ]; then
    echo "未找到 OpenClaw，请手动输入路径"
    echo "（Mac 常见: ~/.openclaw 或 ~/Library/Application Support/openclaw）"
    read -p "OpenClaw 路径: " OPENCLAW_ROOT
fi

# 检测安装目录
if [ -d "$OPENCLAW_ROOT/agents/main/workspace" ]; then
    MODE="multi"
    SKILLS_DIR="$OPENCLAW_ROOT/agents/main/workspace/skills"
else
    MODE="single"
    SKILLS_DIR="$OPENCLAW_ROOT/workspace/skills"
fi

echo ""
echo "安装模式: $MODE"
echo "安装目录: $SKILLS_DIR"
echo ""

# 如果目录不存在，尝试创建
if [ ! -d "$SKILLS_DIR" ]; then
    echo "创建目录..."
    mkdir -p "$SKILLS_DIR" 2>/dev/null || {
        echo "错误: 无法创建目录 $SKILLS_DIR"
        echo "请检查权限或手动创建"
        read -p "直接回车退出，或输入新路径: " NEW_PATH
        if [ -n "$NEW_PATH" ]; then
            SKILLS_DIR="$NEW_PATH"
            mkdir -p "$SKILLS_DIR"
        else
            exit 1
        fi
    }
fi

# 下载 Skill
echo "========== 下载 Skill =========="
GITHUB_RAW="https://raw.githubusercontent.com/luoyueliang/openclaw/main/skills/memory_manage"

mkdir -p "$SKILLS_DIR/memory_manage"
mkdir -p "$SKILLS_DIR/memory_manage/config"
mkdir -p "$SKILLS_DIR/memory_manage/scripts"

download() {
    local url=$1
    local file=$2
    if curl -sL "$url" -o "$file" 2>/dev/null; then
        echo "✓ $(basename $file)"
    else
        echo "✗ $(basename $file) 下载失败"
    fi
}

download "$GITHUB_RAW/SKILL.md" "$SKILLS_DIR/memory_manage/SKILL.md"
download "$GITHUB_RAW/scripts/sync.sh" "$SKILLS_DIR/memory_manage/scripts/sync.sh"
download "$GITHUB_RAW/scripts/init-check.sh" "$SKILLS_DIR/memory_manage/scripts/init-check.sh"
download "$GITHUB_RAW/scripts/keywords-check.sh" "$SKILLS_DIR/memory_manage/scripts/keywords-check.sh"
download "$GITHUB_RAW/config/sync.yaml.example" "$SKILLS_DIR/memory_manage/config/sync.yaml.example"

chmod +x "$SKILLS_DIR/memory_manage/scripts/"*.sh 2>/dev/null

echo ""
echo "✓ Skill 安装完成"

# 交互式配置
echo ""
echo "========== 配置 =========="
echo ""

read -p "实例名 [openclaw-home]: " INSTANCE_NAME
INSTANCE_NAME=${INSTANCE_NAME:-openclaw-home}

read -p "Agent 名 [main]: " AGENT_NAME
AGENT_NAME=${AGENT_NAME:-main}

read -p "记忆备份仓库地址 [https://github.com/luoyueliang/ai_openclaw_memory]: " BACKUP_REPO
BACKUP_REPO=${BACKUP_REPO:-https://github.com/luoyueliang/ai_openclaw_memory}

echo ""
echo "Token 仅用于推送到你的私有备份仓库"
read -s -p "GitHub Token: " GITHUB_TOKEN
echo ""

# 创建配置
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
echo "✓ 配置文件已创建"

# 运行初始化检查
echo ""
echo "========== 初始化检查 =========="
"$SKILLS_DIR/memory_manage/scripts/init-check.sh" 2>/dev/null || true

echo ""
echo "========== 安装完成 =========="
echo ""
echo "Skill: memory_manage"
echo "模式: $MODE"
echo "位置: $SKILLS_DIR/memory_manage"
echo ""
