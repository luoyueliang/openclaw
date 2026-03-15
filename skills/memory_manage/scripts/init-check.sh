#!/bin/bash
# 记忆同步 - 初始化检查脚本
# 使用官方 openclaw agents list 获取 agent 信息

# 颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_ok() { echo -e "${GREEN}✓${NC} $1" || true; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1" || true; }
log_err() { echo -e "${RED}✗${NC} $1" || true; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config/sync.yaml"

echo "========== 初始化检查 =========="
echo ""

# 检测 OpenClaw
OS=$(uname -s)
if [ "$OS" = "Darwin" ]; then
    paths=("$HOME/.openclaw" "$HOME/Library/Application Support/openclaw")
else
    paths=("$HOME/.openclaw" "/root/.openclaw")
fi

OPENCLAW_ROOT=""
for path in "${paths[@]}"; do
    if [ -d "$path" ]; then
        OPENCLAW_ROOT="$path"
        break
    fi
done

if [ -z "$OPENCLAW_ROOT" ]; then
    log_err "未找到 OpenClaw"
    exit 1
fi

log_ok "OpenClaw: $OPENCLAW_ROOT"

# 读取配置
if [ -f "$CONFIG_FILE" ]; then
    AGENT_NAME=$(grep -A1 "agent:" "$CONFIG_FILE" | grep "name:" | awk -F': ' '{print $2}' | tr -d ' ')
    INSTANCE_NAME=$(grep -A1 "instance:" "$CONFIG_FILE" | grep "name:" | awk -F': ' '{print $2}' | tr -d ' ')
fi

AGENT_NAME=${AGENT_NAME:-main}

echo ""
echo "Agent: $AGENT_NAME"
echo "实例: $INSTANCE_NAME"

# 获取 workspace
WORKSPACE_DIR=""
if [ -d "$OPENCLAW_ROOT/agents/$AGENT_NAME/workspace" ]; then
    WORKSPACE_DIR="$OPENCLAW_ROOT/agents/$AGENT_NAME/workspace"
elif [ -d "$OPENCLAW_ROOT/workspace" ]; then
    WORKSPACE_DIR="$OPENCLAW_ROOT/workspace"
fi

echo ""
echo "========== 检查文件 =========="

if [ -d "$WORKSPACE_DIR" ]; then
    log_ok "工作空间: $WORKSPACE_DIR"
else
    log_err "工作空间不存在"
fi

# 检查核心文件
for file in MEMORY.md AGENTS.md SOUL.md USER.md; do
    if [ -f "$WORKSPACE_DIR/$file" ]; then
        log_ok "$file"
    else
        log_warn "$file (不存在)"
    fi
done

# 检查配置
echo ""
echo "========== 检查配置 =========="

if [ -f "$CONFIG_FILE" ]; then
    log_ok "配置文件存在"
    
    token=$(grep "token:" "$CONFIG_FILE" | awk -F': ' '{print $2}' | tr -d ' ')
    repo=$(grep "repo:" "$CONFIG_FILE" | awk -F': ' '{print $2}' | tr -d ' ')
    
    echo ""
    echo "配置信息:"
    echo "  - 实例: $INSTANCE_NAME"
    echo "  - Agent: $AGENT_NAME"
    echo "  - 仓库: $repo"
    echo "  - Token: ${token:0:4}...${token: -4}"
    
    # 验证 GitHub
    if [ -n "$token" ] && [ "$token" != "ghp_xxx" ]; then
        response=$(curl -s -o /dev/null -w "%{http_code}" "https://api.github.com/user" -H "Authorization: token $token" 2>/dev/null)
        if [ "$response" = "200" ]; then
            log_ok "GitHub Token 有效"
        else
            log_warn "GitHub Token 无效 (HTTP $response)"
        fi
    fi
else
    log_err "配置文件不存在"
fi

echo ""
echo "========== 检查完成 =========="
