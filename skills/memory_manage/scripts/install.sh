#!/bin/bash
# Memory Manage Skill 一键安装脚本
# 自动下载 Skill 并交互式配置

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo_ok() { echo -e "${GREEN}✓${NC} $1"; }
echo_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
echo_info() { echo -e "${BLUE}ℹ${NC} $1"; }

HUB_REPO="https://github.com/luoyueliang/openclaw"
SKILLS_BASE="/root/.openclaw/workspace/skills"
SKILL_NAME="memory_manage"

echo ""
echo_info "========== 一键安装 Memory Manage =========="
echo ""

# 1. 下载 Skill（只下载单个目录）
echo_info "下载 Skill..."

temp_dir="/tmp/skill-install-$$"
mkdir -p "$temp_dir"

# 使用 git init + fetch 方式下载单个目录
cd "$temp_dir"
git init -q
git remote add origin "$HUB_REPO.git"
git config core.sparseCheckout true
echo "$SKILL_NAME/" > .git/info/sparse-checkout
git fetch --depth 1 origin main
git checkout -q main

if [ ! -d "$SKILL_NAME" ]; then
    echo_warn "下载失败，请检查网络"
    rm -rf "$temp_dir"
    exit 1
fi

# 2. 复制到目标目录
mkdir -p "$SKILLS_BASE"
cp -r "$SKILL_NAME" "$SKILLS_BASE/"
echo_ok "已安装: $SKILLS_BASE/$SKILL_NAME"

rm -rf "$temp_dir"

# 3. 交互式配置
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
mkdir -p "$SKILLS_BASE/$SKILL_NAME/config"
cat > "$SKILLS_BASE/$SKILL_NAME/config/sync.yaml" << EOF
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
chmod +x "$SKILLS_BASE/$SKILL_NAME/scripts/"*.sh 2>/dev/null

# 运行初始化检查
echo ""
echo_info "========== 初始化检查 =========="
"$SKILLS_BASE/$SKILL_NAME/scripts/init-check.sh"

echo ""
echo_ok "========== 安装完成 =========="
echo ""
echo "Skill: $SKILL_NAME"
echo "位置: $SKILLS_BASE/$SKILL_NAME"
echo ""
