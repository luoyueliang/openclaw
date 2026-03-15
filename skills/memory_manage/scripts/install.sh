#!/bin/bash
# Memory Manage Skill 一键安装脚本
# 自动下载 Skill + 交互式配置 + 判断单/多 Agent

# 检测当前用户
CURRENT_USER=$(whoami)
CURRENT_HOME=$(echo ~)

echo ""
echo "========== Memory Manage 一键安装 =========="
echo ""
echo "当前用户: $CURRENT_USER"
echo "用户目录: $CURRENT_HOME"

# 判断 OpenClaw 可能在的位置
OPENCLAW_ROOT=""
for path in "$CURRENT_HOME/.openclaw" "/root/.openclaw" "$HOME/Library/Application Support/openclaw"; do
    if [ -d "$path" ]; then
        OPENCLAW_ROOT="$path"
        break
    fi
done

if [ -z "$OPENCLAW_ROOT" ]; then
    echo "错误: 未找到 OpenClaw 目录"
    echo "请手动指定 OpenClaw 路径:"
    read -p "OpenClaw 路径: " OPENCLAW_ROOT
fi

echo "OpenClaw 路径: $OPENCLAW_ROOT"
echo ""

# 检测 Agent 模式
AGENTS_DIR="$OPENCLAW_ROOT/agents"
SKILLS_DIR="$OPENCLAW_ROOT/workspace/skills"

# 如果是多 Agent，技能安装到 main 的 workspace 下
if [ -d "$AGENTS_DIR/main/workspace" ]; then
    MODE="multi"
    SKILLS_DIR="$AGENTS_DIR/main/workspace/skills"
    echo "检测到多 Agent 模式"
else
    MODE="single"
    echo "单 Agent 模式"
fi

echo "安装模式: $MODE"
echo "安装路径: $SKILLS_DIR"
echo ""

# 下载 Skill
echo "========== 下载 Skill =========="
GITHUB_RAW="https://raw.githubusercontent.com/luoyueliang/openclaw/main/skills/memory_manage"

mkdir -p "$SKILLS_DIR/memory_manage"
mkdir -p "$SKILLS_DIR/memory_manage/config"
mkdir -p "$SKILLS_DIR/memory_manage/scripts"

echo "下载文件..."

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
echo "Token 仅用于推送到你的私有备份仓库，不会外泄"
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
