#!/bin/bash
# 记忆同步脚本 v4.1
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
    
    # 读取配置（处理 YAML 格式）
    INSTANCE_NAME=$(grep -A1 "instance:" "$CONFIG_FILE" | grep "name:" | awk -F': ' '{print $2}' | tr -d ' ')
    AGENT_NAME=$(grep -A1 "agent:" "$CONFIG_FILE" | grep "name:" | awk -F': ' '{print $2}' | tr -d ' ')
    GITHUB_TOKEN=$(grep "token:" "$CONFIG_FILE" | awk -F': ' '{print $2}' | tr -d ' ')
    GITHUB_REPO=$(grep "repo:" "$CONFIG_FILE" | awk -F': ' '{print $2}' | tr -d ' ')
    
    if [ -z "$INSTANCE_NAME" ] || [ -z "$AGENT_NAME" ]; then
        log "错误: instance.name 或 agent.name 未配置"
        exit 1
    fi
    
    log "实例: $INSTANCE_NAME, Agent: $AGENT_NAME"
}

# 获取工作空间目录（支持两种路径）
get_workspace_dir() {
    # 优先使用 agent 专属路径
    if [ -d "$OPENCLAW_ROOT/agents/$AGENT_NAME/workspace" ]; then
        echo "$OPENCLAW_ROOT/agents/$AGENT_NAME/workspace"
    else
        # 使用共享工作空间（当前实际路径）
        echo "$OPENCLAW_ROOT/workspace"
    fi
}

# 初始化 Git 仓库
init_repo() {
    if [ ! -d "$TARGET_BASE_DIR/.git" ]; then
        log "初始化 GitHub 仓库..."
        cd "$TARGET_BASE_DIR"
        git init
        git config user.name "Luo Yue Liang"
        git config user.email "luoyueliang@example.com"
        git remote add origin "https://${GITHUB_TOKEN}@github.com/${GITHUB_REPO#https://}.git"
        git branch -M master
    fi
}

# 检查源目录是否存在
check_source() {
    local source_dir=$(get_workspace_dir)
    
    if [ ! -d "$source_dir" ]; then
        log "错误: 工作空间目录不存在: $source_dir"
        return 1
    fi
    
    log "工作空间: $source_dir"
    return 0
}

# 同步核心文件
sync_core_files() {
    local source_dir=$(get_workspace_dir)
    local target_dir="$TARGET_BASE_DIR/$INSTANCE_NAME/$AGENT_NAME/core"
    
    mkdir -p "$target_dir"
    
    # 需要同步的核心文件
    local core_files=(
        "MEMORY.md"
        "AGENTS.md"
        "SOUL.md"
        "USER.md"
        "TOOLS.md"
        "HEARTBEAT.md"
    )
    
    for file in "${core_files[@]}"; do
        if [ -f "$source_dir/$file" ]; then
            cp "$source_dir/$file" "$target_dir/"
            log "✓ 已同步: $file"
        fi
    done
}

# 同步工作区文件（过滤大文件）
sync_workspace() {
    local source_dir=$(get_workspace_dir)
    local target_dir="$TARGET_BASE_DIR/$INSTANCE_NAME/$AGENT_NAME/workspace/memory"
    
    mkdir -p "$target_dir"
    
    # 同步 memory 目录下的文件
    if [ -d "$source_dir/memory" ]; then
        for item in "$source_dir/memory"/*; do
            if [ -f "$item" ]; then
                local size=$(stat -c%s "$item" 2>/dev/null || echo 0)
                # 只同步小于 1MB 的文件
                if [ "$size" -lt 1048576 ]; then
                    cp "$item" "$target_dir/"
                    log "✓ 已同步: memory/$(basename $item)"
                else
                    log "跳过（大文件）: memory/$(basename $item) ($size bytes)"
                fi
            fi
        done
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
    
    COMMIT_MSG="🤖 自动同步记忆 - $(date '+%Y-%m-%d %H:%M:%S') - $INSTANCE_NAME/$AGENT_NAME"
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
    log "========== 记忆同步开始 =========="
    
    load_config || exit 1
    check_source || exit 1
    init_repo
    sync_core_files
    sync_workspace
    commit_push
    
    log "========== 记忆同步完成 =========="
}

main
