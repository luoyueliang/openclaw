#!/bin/bash
# 记忆同步脚本 v5.0
# 支持多实例多 Agent 的记忆管理

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config/sync.yaml"
OPENCLAW_ROOT="/root/.openclaw"
TARGET_BASE_DIR="$OPENCLAW_ROOT/workspace/memory-github"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# 读取配置
load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        log "配置文件不存在: $CONFIG_FILE"
        exit 1
    fi
    
    INSTANCE_NAME=$(grep -A1 "instance:" "$CONFIG_FILE" | grep "name:" | awk -F': ' '{print $2}' | tr -d ' ')
    AGENT_NAME=$(grep -A1 "agent:" "$CONFIG_FILE" | grep "name:" | awk -F': ' '{print $2}' | tr -d ' ')
    GITHUB_TOKEN=$(grep "token:" "$CONFIG_FILE" | awk -F': ' '{print $2}' | tr -d ' ')
    GITHUB_REPO=$(grep "repo:" "$CONFIG_FILE" | awk -F': ' '{print $2}' | tr -d ' ')
    
    if [ -z "$INSTANCE_NAME" ]; then
        log "错误: instance.name 未配置"
        exit 1
    fi
    
    log "实例: $INSTANCE_NAME"
}

# 自动发现所有 Agent
discover_agents() {
    local agents_dir="$OPENCLAW_ROOT/agents"
    local result=""
    
    if [ ! -d "$agents_dir" ]; then
        log "Agent 目录不存在"
        result="main"
        echo "$result"
        return
    fi
    
    # 查找所有有 workspace 的 Agent
    local count=0
    for agent_dir in "$agents_dir"/*/; do
        if [ -d "$agent_dir/workspace" ]; then
            local agent_name=$(basename "$agent_dir")
            result="$result $agent_name"
            count=$((count + 1))
        fi
    done
    
    if [ $count -eq 0 ]; then
        # 单 Agent 模式，使用根目录 workspace
        log "未发现多 Agent，使用根目录 workspace"
        echo "main"
    else
        # 多 Agent 模式
        log "发现 $count 个 Agent:$result"
        echo "$result" | sed 's/^ //'
    fi
}

# 获取 Agent 的 workspace 路径
get_workspace_path() {
    local agent=$1
    
    # 优先使用 Agent 专属路径
    if [ -d "$OPENCLAW_ROOT/agents/$agent/workspace" ]; then
        echo "$OPENCLAW_ROOT/agents/$agent/workspace"
    elif [ -d "$OPENCLAW_ROOT/workspace" ]; then
        # 回退到根目录（单 Agent 模式）
        echo "$OPENCLAW_ROOT/workspace"
    else
        echo ""
    fi
}

# 同步单个 Agent 的记忆
sync_agent() {
    local agent=$1
    local source_dir=$(get_workspace_path "$agent")
    
    if [ -z "$source_dir" ] || [ ! -d "$source_dir" ]; then
        log "⚠ Agent '$agent' 的 workspace 不存在，跳过"
        return 1
    fi
    
    log "=== 同步 Agent: $agent ==="
    log "源目录: $source_dir"
    
    local target_dir="$TARGET_BASE_DIR/$INSTANCE_NAME/$agent/core"
    mkdir -p "$target_dir"
    
    # 核心文件
    local core_files=("MEMORY.md" "AGENTS.md" "SOUL.md" "USER.md" "TOOLS.md" "HEARTBEAT.md")
    for file in "${core_files[@]}"; do
        if [ -f "$source_dir/$file" ]; then
            cp "$source_dir/$file" "$target_dir/"
            log "✓ $file"
        fi
    done
    
    # 工作区文件
    local mem_target="$TARGET_BASE_DIR/$INSTANCE_NAME/$agent/workspace/memory"
    mkdir -p "$mem_target"
    
    if [ -d "$source_dir/memory" ]; then
        for item in "$source_dir/memory"/*; do
            if [ -f "$item" ]; then
                local size=$(stat -c%s "$item" 2>/dev/null || echo 0)
                if [ "$size" -lt 1048576 ]; then
                    cp "$item" "$mem_target/"
                    log "✓ memory/$(basename $item)"
                fi
            fi
        done
    fi
    
    return 0
}

# 初始化 Git 仓库
init_repo() {
    if [ ! -d "$TARGET_BASE_DIR/.git" ]; then
        log "初始化 GitHub 仓库..."
        cd "$TARGET_BASE_DIR"
        git init
        git config user.name "Luo Yue Liang"
        git config user.email "luoyueliang@github.com"
        git remote add origin "https://${GITHUB_TOKEN}@github.com/${GITHUB_REPO#https://}.git"
        git branch -M master
    fi
}

# 提交并推送
commit_push() {
    cd "$TARGET_BASE_DIR"
    git add -A
    
    if git diff --cached --quiet; then
        log "没有新变更需要提交"
        return 0
    fi
    
    COMMIT_MSG="🤖 自动同步 - $(date '+%Y-%m-%d %H:%M:%S') - $INSTANCE_NAME"
    git commit -m "$COMMIT_MSG"
    
    if git push -u origin master 2>&1 | tee -a /tmp/sync.log; then
        log "✓ 同步成功！"
    else
        log "✗ 同步失败"
        return 1
    fi
}

# 主流程
main() {
    log "========== 记忆同步开始 (v5.0) =========="
    
    load_config || exit 1
    init_repo
    
    # 自动发现 Agent
    agents=$(discover_agents)
    
    # 同步每个 Agent
    for agent in $agents; do
        sync_agent "$agent"
    done
    
    commit_push
    
    log "========== 记忆同步完成 =========="
}

main
