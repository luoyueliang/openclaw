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

echo_err() { echo -e "${RED}✗${NC} $1"; }
echo_ok() { echo -e "${GREEN}✓${NC} $1"; }
echo_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
echo_info() { echo -e "${BLUE}ℹ${NC} $1"; }

# 配置
HUB_REPO="https://github.com/luoyueliang/openclaw"
SKILL_NAME="memory_manage"

echo ""
echo_info "========== Memory Manage 一键安装 =========="
echo ""

# ========== 判断单/多 Agent ==========
echo_info "检测 Agent 模式..."

OPENCLAW_ROOT="/root/.openclaw"
AGENTS_DIR="$OPENCLAW_ROOT/agents"

# 检测有多少个 Agent 有 workspace
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

# 判断安装模式
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

# ========== 下载 Skill ==========
echo_info "下载 Skill..."

temp_dir=$(mktemp -d)
cd "$temp_dir"

git init -q
git remote add origin "$HUB_REPO.git"
echo "$SKILL_NAME/" > .git/info/sparse-checkout
git config core.sparseCheckout true
git fetch --depth 1 origin main -q
git checkout -q main 2>/dev/null || git checkout -q master -q

if [ ! -d "$SKILL_NAME" ]; then
    echo_err "下载失败，请检查网络或仓库地址"
    rm -rf "$temp_dir"
    exit 1
fi

echo_ok "Skill 下载完成"

# ========== 安装 ==========
mkdir -p "$INSTALL_BASE"
cp -r "$SKILL_NAME" "$INSTALL_BASE/"
SKILL_DIR="$INSTALL_BASE/$SKILL_NAME"
echo_ok "已安装到: $SKILL_DIR"

rm -rf "$temp_dir"

# ========== 交互式配置 ==========
echo ""
echo_info "========== 配置 =========="
echo ""

read -p "实例名 [openclaw-home]: " INSTANCE_NAME
INSTANCE_NAME=${INSTANCE_NAME:-openclaw-home}

read -p "Agent 名 [main]: " AGENT_NAME
AGENT_NAME=${AGENT_NAME:-main}

read -p "记忆备份仓库地址 [https://github.com/luoyueliang/ai_openclaw_memory]: " GITHUB_REPO
GITHUB_REPO=${GITHUB_REPO:-https://github.com/luoyueliang/ai_openclaw_memory}

echo ""
echo_warn "Token 仅用于推送到你的私有备份仓库，不会外泄"
read -s -p "GitHub Token: " GITHUB_TOKEN
echo ""

# 创建配置
mkdir -p "$SKILL_DIR/config"
cat > "$SKILL_DIR/config/sync.yaml" << EOF
instance:
  name: $INSTANCE_NAME

agent:
  name: $AGENT_NAME

github:
  repo: $GITHUB_REPO
  token: $GITHUB_TOKEN
EOF

echo_ok "配置文件已创建"

# 设置权限
chmod +x "$SKILL_DIR/scripts/"*.sh 2>/dev/null

# ========== 初始化检查 ==========
echo ""
echo_info "========== 初始化检查 =========="
"$SKILL_DIR/scripts/init-check.sh"

echo ""
echo_ok "========== 安装完成 =========="
echo ""
echo "Skill: $SKILL_NAME"
echo "模式: $MODE"
echo "位置: $SKILL_DIR"
echo "配置: $SKILL_DIR/config/sync.yaml"
echo ""
