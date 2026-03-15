#!/bin/bash
# Memory Manage Skill 一键安装脚本
# 自动下载 Skill + 交互式配置 + 判断单/多 Agent

set -e

# 颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo_err() { echo -e "${RED}✗${NC} $1" || true; }
echo_ok() { echo -e "${GREEN}✓${NC} $1" || true; }
echo_warn() { echo -e "${YELLOW}⚠${NC} $1" || true; }
echo_info() { echo -e "${BLUE}ℹ${NC} $1" || true; }

# 配置
GITHUB_RAW="https://raw.githubusercontent.com/luoyueliang/openclaw/main/skills/memory_manage"

echo ""
echo_info "========== Memory Manage 一键安装 =========="
echo ""

# ========== 判断单/多 Agent ==========
echo_info "检测 Agent 模式..."

OPENCLAW_ROOT="/root/.openclaw"
AGENTS_DIR="$OPENCLAW_ROOT/agents"

agent_count=0
has_main=false

if [ -d "$AGENTS_DIR" ]; then
    for dir in "$AGENTS_DIR"/*/; do
        if [ -d "$dir/workspace" ]; then
            agent_count=$((agent_count + 1))
            agent_name=$(basename "$dir")
            if [ "$agent_name" = "main" ]; then
                has_main=true
            fi
        fi
    done
fi

if [ $agent_count -gt 1 ]; then
    MODE="multi"
    echo_warn "检测到多 Agent 模式: $agent_count 个 Agent"
    INSTALL_BASE="$AGENTS_DIR/main/workspace/skills"
elif [ "$has_main" = true ]; then
    MODE="single-main"
    INSTALL_BASE="$OPENCLAW_ROOT/workspace/skills"
else
    MODE="single"
    INSTALL_BASE="$OPENCLAW_ROOT/workspace/skills"
fi

echo_info "安装模式: $MODE"
echo_info "安装路径: $INSTALL_BASE"
echo ""

# ========== 下载 Skill（使用 curl）==========
echo_info "下载 Skill..."

SKILL_DIR="$INSTALL_BASE/memory_manage"
mkdir -p "$SKILL_DIR"
mkdir -p "$SKILL_DIR/config"
mkdir -p "$SKILL_DIR/scripts"

# 下载文件
download_file() {
    local url=$1
    local path=$2
    curl -sL "$url" -o "$path" 2>/dev/null && echo_ok "下载: $(basename $path)" || echo_err "失败: $(basename $path)"
}

download_file "$GITHUB_RAW/SKILL.md" "$SKILL_DIR/SKILL.md"
download_file "$GITHUB_RAW/scripts/sync.sh" "$SKILL_DIR/scripts/sync.sh"
download_file "$GITHUB_RAW/scripts/init-check.sh" "$SKILL_DIR/scripts/init-check.sh"
download_file "$GITHUB_RAW/scripts/keywords-check.sh" "$SKILL_DIR/scripts/keywords-check.sh"
download_file "$GITHUB_RAW/config/sync.yaml.example" "$SKILL_DIR/config/sync.yaml.example"

chmod +x "$SKILL_DIR/scripts/"*.sh 2>/dev/null

echo_ok "Skill 安装完成: $SKILL_DIR"

# ========== 交互式配置 ==========
echo ""
echo_info "========== 配置 =========="
echo ""

read -p "实例名 [openclaw-home]: " INSTANCE_NAME
INSTANCE_NAME=${INSTANCE_NAME:-openclaw-home}

read -p "Agent 名 [main]: " AGENT_NAME
AGENT_NAME=${AGENT_NAME:-main}

read -p "记忆备份仓库地址 [https://github.com/luoyueliang/ai_openclaw_memory]: " BACKUP_REPO
BACKUP_REPO=${BACKUP_REPO:-https://github.com/luoyueliang/ai_openclaw_memory}

echo ""
echo_warn "Token 仅用于推送到你的私有备份仓库，不会外泄"
read -s -p "GitHub Token: " GITHUB_TOKEN
echo ""

# 创建配置
cat > "$SKILL_DIR/config/sync.yaml" << EOF
instance:
  name: $INSTANCE_NAME

agent:
  name: $AGENT_NAME

github:
  repo: $BACKUP_REPO
  token: $GITHUB_TOKEN
EOF

echo_ok "配置文件已创建: $SKILL_DIR/config/sync.yaml"

# ========== 初始化检查 ==========
echo ""
echo_info "========== 初始化检查 =========="
"$SKILL_DIR/scripts/init-check.sh" 2>/dev/null || true

echo ""
echo_ok "========== 安装完成 =========="
echo ""
echo "Skill: memory_manage"
echo "模式: $MODE"
echo "位置: $SKILL_DIR"
echo ""
