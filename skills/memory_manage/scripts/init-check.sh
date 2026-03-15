#!/bin/bash
# 记忆同步 - 初始化检查脚本
# 自动检测正确的 OpenClaw 路径

# 颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }
log_ok() { echo -e "${GREEN}✓${NC} $1" || true; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1" || true; }
log_err() { echo -e "${RED}✗${NC} $1" || true; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config/sync.yaml"

# 自动检测 OpenClaw 根目录
detect_openclaw_root() {
    local user=$(whoami)
    local home=$(eval echo ~$user)
    
    local possible_paths=(
        "$home/.openclaw"
        "$home/Library/Application Support/openclaw"
        "/root/.openclaw"
    )
    
    for path in "${possible_paths[@]}"; do
        if [ -d "$path" ]; then
            echo "$path"
            return 0
        fi
    done
    
    return 1
}

OPENCLAW_ROOT=$(detect_openclaw_root)

if [ -z "$OPENCLAW_ROOT" ]; then
    log_err "未找到 OpenClaw 目录"
    exit 1
fi

log_ok "OpenClaw 目录: $OPENCLAW_ROOT"

# 读取配置
if [ -f "$CONFIG_FILE" ]; then
    AGENT_NAME=$(grep -A1 "agent:" "$CONFIG_FILE" | grep "name:" | awk -F': ' '{print $2}' | tr -d ' ')
    INSTANCE_NAME=$(grep -A1 "instance:" "$CONFIG_FILE" | grep "name:" | awk -F': ' '{print $2}' | tr -d ' ')
fi

AGENT_NAME=${AGENT_NAME:-main}
log "Agent: $AGENT_NAME, 实例: $INSTANCE_NAME"

# 检测工作空间路径
if [ -d "$OPENCLAW_ROOT/agents/$AGENT_NAME/workspace" ]; then
    WORKSPACE_DIR="$OPENCLAW_ROOT/agents/$AGENT_NAME/workspace"
elif [ -d "$OPENCLAW_ROOT/workspace" ]; then
    WORKSPACE_DIR="$OPENCLAW_ROOT/workspace"
else
    WORKSPACE_DIR=""
fi

log ""
log "========== 检查目录结构 =========="

if [ -d "$OPENCLAW_ROOT" ]; then
    log_ok "OpenClaw 根目录存在: $OPENCLAW_ROOT"
else
    log_err "OpenClaw 根目录不存在: $OPENCLAW_ROOT"
fi

if [ -d "$WORKSPACE_DIR" ]; then
    log_ok "工作空间存在: $WORKSPACE_DIR"
else
    log_err "工作空间不存在"
fi

# 检查核心文件
log ""
log "========== 检查核心文件 =========="

core_files=(
    "MEMORY.md:核心记忆"
    "AGENTS.md:Agent定义"
)

for item in "${core_files[@]}"; do
    file="${item%%:*}"
    desc="${item##*:}"
    
    if [ -f "$WORKSPACE_DIR/$file" ]; then
        log_ok "$desc 存在"
    else
        log_warn "$desc 不存在: $WORKSPACE_DIR/$file"
    fi
done

# 检查配置文件
log ""
log "========== 检查配置文件 =========="

if [ -f "$CONFIG_FILE" ]; then
    log_ok "配置文件存在: $CONFIG_FILE"
    
    if grep -q "instance:" "$CONFIG_FILE" && grep -q "agent:" "$CONFIG_FILE" && grep -q "github:" "$CONFIG_FILE"; then
        log_ok "必要配置项完整"
    else
        log_err "配置文件缺少必要项"
    fi
else
    log_err "配置文件不存在: $CONFIG_FILE"
fi

# 检查 GitHub
log ""
log "========== 检查 GitHub =========="

if [ -f "$CONFIG_FILE" ]; then
    token=$(grep "token:" "$CONFIG_FILE" | awk -F': ' '{print $2}' | tr -d ' ')
    
    if [ -n "$token" ] && [ "$token" != "ghp_xxx" ]; then
        log_ok "GitHub Token 已配置"
        
        response=$(curl -s -o /dev/null -w "%{http_code}" "https://api.github.com/user" -H "Authorization: token $token" 2>/dev/null)
        if [ "$response" = "200" ]; then
            log_ok "GitHub Token 有效"
        else
            log_warn "GitHub Token 无效 (HTTP $response)"
        fi
    else
        log_err "GitHub Token 未配置"
    fi
fi

log ""
log "========== 检查完成 =========="
