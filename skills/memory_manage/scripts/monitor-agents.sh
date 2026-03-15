#!/bin/bash
# Agent 监控检查脚本
# 检测 agent 变更 + memory 配置 + 发送通知

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config/sync.yaml"
STATE_FILE="$SCRIPT_DIR/../state/agents.json"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo "[$(date)] $1"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
log_err() { echo -e "${RED}✗${NC} $1"; }
log_ok() { echo -e "${GREEN}✓${NC} $1"; }

# ========== 1. 获取当前 Agent 列表 ==========
get_current_agents() {
    cd "$HOME/.openclaw" 2>/dev/null || cd "/root/.openclaw"
    
    openclaw agents list 2>/dev/null | grep -E "^- " | sed 's/- //' | sed 's/ (default)//' | while read -r line; do
        echo "$line"
    done
}

# ========== 2. 获取 Agent 的 Workspace ==========
get_workspace() {
    local agent=$1
    cd "$HOME/.openclaw" 2>/dev/null || cd "/root/.openclaw"
    
    openclaw agents list 2>/dev/null | grep -A5 "^- $agent" | grep "Workspace:" | sed 's/.*Workspace: //' | tr -d ' '
}

# ========== 3. 检查 Memory 文件 ==========
check_memory() {
    local workspace=$1
    workspace=$(eval echo "$workspace")
    
    local result=()
    
    for file in MEMORY.md AGENTS.md SOUL.md USER.md; do
        if [ -f "$workspace/$file" ]; then
            result+=("$file:OK")
        else
            result+=("$file:MISSING")
        fi
    done
    
    echo "${result[*]}"
}

# ========== 4. 读取旧状态 ==========
read_old_state() {
    if [ -f "$STATE_FILE" ]; then
        cat "$STATE_FILE"
    else
        echo '{"last_check": null, "agents": {}}'
    fi
}

# ========== 5. 检测变更 ==========
detect_changes() {
    local old_state="$1"
    local current_agents=("$@")
    
    # 解析旧状态
    # 比对变更
    # 返回变更类型：NEW | DELETED | MODIFIED | OK
}

# ========== 6. 发送通知 ==========
notify() {
    local title="$1"
    local message="$2"
    
    # 6.1 飞书通知
    if [ -n "$FEISHU_WEBHOOK" ]; then
        curl -s -X POST "$FEISHU_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{\"msg_type\": \"text\", \"content\": {\"text\": \"$title\n$message\"}}"
    fi
    
    # 6.2 邮件通知
    if [ -n "$EMAIL_TO" ] && command -v sendmail &> /dev/null; then
        echo -e "Subject: $title\n\n$message" | sendmail "$EMAIL_TO"
    fi
}

# ========== 7. 主流程 ==========
main() {
    log "========== Agent 监控检查 =========="
    
    # 1. 获取当前 agent 列表
    echo "获取当前 Agent 列表..."
    CURRENT_AGENTS=$(get_current_agents)
    
    echo "当前 Agents: $CURRENT_AGENTS"
    
    # 2. 检查每个 agent
    declare -A AGENT_STATUS
    
    for agent in $CURRENT_AGENTS; do
        echo ""
        echo "=== 检查 Agent: $agent ==="
        
        workspace=$(get_workspace "$agent")
        echo "Workspace: $workspace"
        
        # 检查 memory 文件
        memory_status=$(check_memory "$workspace")
        echo "Memory: $memory_status"
        
        # 记录状态
        AGENT_STATUS[$agent]="$memory_status"
    done
    
    # 3. 读取旧状态
    echo ""
    echo "对比上次状态..."
    OLD_STATE=$(read_old_state)
    
    # 4. 检测变更并通知
    # NEW: 新增 agent
    # MISSING_MEMORY: 缺少 memory 文件
    # OK: 正常
    
    # 5. 保存新状态
    echo ""
    echo "保存状态..."
    
    # 6. 输出报告
    echo ""
    echo "========== 检查完成 =========="
    echo "状态文件: $STATE_FILE"
}

main "$@"
