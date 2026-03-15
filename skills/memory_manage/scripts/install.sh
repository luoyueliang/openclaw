#!/bin/bash
# Memory Manage Skill 交互式安装脚本

# 颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo_ok() { echo -e "${GREEN}✓${NC} $1"; }
echo_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
echo_info() { echo -e "${BLUE}ℹ${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/config"

echo ""
echo_info "========== Memory Manage 安装 =========="
echo ""

# 交互式配置
echo "请配置以下信息："
echo ""

read -p "实例名 [openclaw-home]: " INSTANCE_NAME
INSTANCE_NAME=${INSTANCE_NAME:-openclaw-home}

read -p "Agent 名 [main]: " AGENT_NAME
AGENT_NAME=${AGENT_NAME:-main}

read -p "记忆备份仓库地址 [https://github.com/luoyueliang/ai_openclaw_memory]: " GITHUB_REPO
GITHUB_REPO=${GITHUB_REPO:-https://github.com/luoyueliang/ai_openclaw_memory}

echo ""
echo_warn "注意：Token 仅用于推送到你的私有备份仓库，不会外泄"
read -s -p "GitHub Token: " GITHUB_TOKEN
echo ""

# 创建配置
mkdir -p "$CONFIG_DIR"

cat > "$CONFIG_DIR/sync.yaml" << EOF
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
chmod +x "$SCRIPT_DIR/scripts/"*.sh 2>/dev/null

echo_ok "权限已设置"

# 运行初始化检查
echo ""
echo_info "========== 初始化检查 =========="
"$SCRIPT_DIR/scripts/init-check.sh"

echo ""
echo_ok "========== 安装完成 =========="
echo ""
echo "配置: $CONFIG_DIR/sync.yaml"
echo "同步: $SCRIPT_DIR/scripts/sync.sh"
echo ""
