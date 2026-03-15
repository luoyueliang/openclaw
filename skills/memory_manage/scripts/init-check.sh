#!/bin/bash
# 记忆同步 - 初始化检查脚本
# 检查 OpenClaw 记忆管理的必要元素和目录结构

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config/sync.yaml"
OPENCLAW_ROOT="/root/.openclaw"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log_ok() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_err() {
    echo -e "${RED}✗${NC} $1"
}

# 读取配置获取 Agent 名
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        AGENT_NAME=$(grep -A1 "agent:" "$CONFIG_FILE" | grep "name:" | awk -F': ' '{print $2}' | tr -d ' ')
        INSTANCE_NAME=$(grep -A1 "instance:" "$CONFIG_FILE" | grep "name:" | awk -F': ' '{print $2}' | tr -d ' ')
        echo "当前配置: 实例=$INSTANCE_NAME, Agent=$AGENT_NAME"
    fi
}

# 检查 OpenClaw 根目录
check_openclaw_root() {
    log "========== 检查 OpenClaw 根目录 =========="
    
    if [ -d "$OPENCLAW_ROOT" ]; then
        log_ok "OpenClaw 根目录存在: $OPENCLAW_ROOT"
    else
        log_err "OpenClaw 根目录不存在: $OPENCLAW_ROOT"
        return 1
    fi
}

# 检查目录结构
check_structure() {
    log "========== 检查目录结构 =========="
    
    # 获取 Agent 名
    load_config
    local agent_name=${AGENT_NAME:-main}
    
    local required_items=(
        "$OPENCLAW_ROOT/agents/:Agent 目录"
        "$OPENCLAW_ROOT/agents/$agent_name/:Agent 目录"
        "$OPENCLAW_ROOT/agents/$agent_name/workspace/:Agent 工作空间"
    )
    
    local all_passed=true
    
    for item in "${required_items[@]}"; do
        path="${item%%:*}"
        desc="${item##*:}"
        
        if [ -e "$path" ]; then
            log_ok "$desc 存在: $path"
        else
            log_err "$desc 缺失: $path"
            all_passed=false
        fi
    done
    
    if [ "$all_passed" = true ]; then
        log_ok "目录结构检查通过"
        return 0
    else
        log_err "目录结构检查未通过"
        return 1
    fi
}

# 检查核心文件
check_core_files() {
    log "========== 检查核心文件 =========="
    
    load_config
    local agent_name=${AGENT_NAME:-main}
    local workspace_dir="$OPENCLAW_ROOT/agents/$agent_name/workspace"
    
    local required_files=(
        "$workspace_dir/MEMORY.md:核心记忆文件"
        "$workspace_dir/AGENTS.md:Agent 定义文件"
    )
    
    local all_passed=true
    
    for item in "${required_files[@]}"; do
        path="${item%%:*}"
        desc="${item##*:}"
        
        if [ -f "$path" ]; then
            log_ok "$desc 存在"
        else
            log_warn "$desc 不存在: $path"
            all_passed=false
        fi
    done
    
    if [ "$all_passed" = true ]; then
        log_ok "核心文件检查通过"
        return 0
    else
        log_warn "部分核心文件缺失"
        return 1
    fi
}

# 检查配置文件
check_config() {
    log "========== 检查配置文件 =========="
    
    if [ -f "$CONFIG_FILE" ]; then
        log_ok "配置文件存在: $CONFIG_FILE"
        
        # 检查必要配置项
        if grep -q "instance:" "$CONFIG_FILE" && grep -q "agent:" "$CONFIG_FILE" && grep -q "github:" "$CONFIG_FILE"; then
            log_ok "必要配置项完整"
            return 0
        else
            log_err "配置文件缺少必要项 (instance, agent, github)"
            return 1
        fi
    else
        log_err "配置文件不存在: $CONFIG_FILE"
        return 1
    fi
}

# 检查 GitHub Token
check_github() {
    log "========== 检查 GitHub 配置 =========="
    
    if [ ! -f "$CONFIG_FILE" ]; then
        log_err "配置文件不存在，无法检查 GitHub"
        return 1
    fi
    
    token=$(grep "token:" "$CONFIG_FILE" | awk -F': ' '{print $2}' | tr -d ' ')
    
    if [ -n "$token" ] && [ "$token" != "ghp_xxx" ]; then
        log_ok "GitHub Token 已配置"
        
        # 简单测试 token 是否有效
        response=$(curl -s -o /dev/null -w "%{http_code}" "https://api.github.com/user" -H "Authorization: token $token" 2>/dev/null)
        if [ "$response" = "200" ]; then
            log_ok "GitHub Token 有效"
            return 0
        else
            log_warn "GitHub Token 可能无效 (HTTP $response)"
            return 1
        fi
    else
        log_err "GitHub Token 未配置或为默认值"
        return 1
    fi
}

# 生成初始化建议
suggest_init() {
    log "========== 初始化建议 =========="
    
    load_config
    local agent_name=${AGENT_NAME:-main}
    
    echo "
要完成记忆管理配置，请执行以下步骤：

1. 确保 OpenClaw 已正确安装:
   - $OPENCLAW_ROOT/ 目录存在
   - $OPENCLAW_ROOT/agents/$agent_name/workspace/ 存在

2. 配置文件:
   - 编辑 $CONFIG_FILE
   - 设置 instance.name 为当前实例名（如 openclaw-home）
   - 设置 agent.name 为目标 Agent 名（如 main）
   - 设置 github.token 为你的 GitHub Token

3. 运行手动同步测试:
   - $SCRIPT_DIR/sync.sh
"
}

# 主流程
main() {
    log "========== 记忆同步初始化检查 =========="
    
    local exit_code=0
    
    check_openclaw_root || exit_code=1
    check_structure || exit_code=1
    check_core_files || exit_code=1
    check_config || exit_code=1
    check_github || exit_code=1
    
    if [ $exit_code -eq 0 ]; then
        log_ok "所有检查通过！记忆同步已就绪"
    else
        log_warn "部分检查未通过，请根据建议配置"
        suggest_init
    fi
    
    return $exit_code
}

main
