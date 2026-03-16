#!/bin/bash
# 关键词监控脚本
# 监控 OpenClaw 会话日志，当用户消息包含 keywords.md 中的关键词时，
# 自动提取内容并写入 memory/ 目录，由 sync.sh 在下次同步时一并备份

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config/sync.yaml"

# ========== 检测 OpenClaw 根目录（跨平台）==========
detect_openclaw_root() {
    local OS
    OS=$(uname -s)
    if [ "$OS" = "Darwin" ]; then
        local paths=("$HOME/.openclaw" "$HOME/Library/Application Support/openclaw")
    else
        local paths=("$HOME/.openclaw" "/root/.openclaw")
    fi
    for p in "${paths[@]}"; do
        if [ -d "$p" ]; then
            echo "$p"
            return
        fi
    done
    echo ""
}

OPENCLAW_ROOT=$(detect_openclaw_root)
if [ -z "$OPENCLAW_ROOT" ]; then
    echo "[ERROR] 未找到 OpenClaw 安装目录"
    exit 1
fi

# ========== 读取配置 ==========
AGENT_NAME="main"
if [ -f "$CONFIG_FILE" ]; then
    AGENT_NAME=$(grep -A1 "agent:" "$CONFIG_FILE" | grep "name:" | awk -F': ' '{print $2}' | tr -d ' ')
    AGENT_NAME=${AGENT_NAME:-main}
fi

# ========== 路径设置 ==========
# 优先用 agent 专属 workspace，单 Agent 模式用根 workspace
if [ -d "$OPENCLAW_ROOT/agents/$AGENT_NAME/workspace" ]; then
    WORKSPACE="$OPENCLAW_ROOT/agents/$AGENT_NAME/workspace"
else
    WORKSPACE="$OPENCLAW_ROOT/workspace"
fi

KEYWORDS_FILE="$WORKSPACE/memory/keywords.md"
MEMORY_DIR="$WORKSPACE/memory"
SESSIONS_DIR="$OPENCLAW_ROOT/agents/$AGENT_NAME/sessions"
STATE_DIR="$SCRIPT_DIR/../state"
STATE_FILE="$STATE_DIR/keyword-monitor-state.json"

# ========== 日志 ==========
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }

# ========== 1. 读取关键词 ==========
load_keywords() {
    if [ ! -f "$KEYWORDS_FILE" ]; then
        log "⚠ keywords.md 不存在: $KEYWORDS_FILE"
        return 1
    fi
    # 提取所有 "- 关键词" 行，去掉前缀 "- "
    KEYWORDS=()
    while IFS= read -r line; do
        if [[ "$line" =~ ^-\ (.+)$ ]]; then
            KEYWORDS+=("${BASH_REMATCH[1]}")
        fi
    done < "$KEYWORDS_FILE"
    log "加载关键词: ${#KEYWORDS[@]} 个 (${KEYWORDS[*]:0:5}...)"
}

# ========== 2. 读取/保存 state（记录已处理的文件行数）==========
get_processed_lines() {
    local file="$1"
    if [ -f "$STATE_FILE" ] && command -v python3 >/dev/null 2>&1; then
        python3 -c "
import json
try:
    d = json.load(open('$STATE_FILE'))
    print(d.get('$file', 0))
except:
    print(0)
" 2>/dev/null || echo 0
    else
        echo 0
    fi
}

save_processed_lines() {
    local file="$1"
    local lines="$2"
    mkdir -p "$STATE_DIR"
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "
import json, os
state_file = '$STATE_FILE'
try:
    d = json.load(open(state_file)) if os.path.exists(state_file) else {}
except:
    d = {}
d['$file'] = $lines
json.dump(d, open(state_file, 'w'), ensure_ascii=False, indent=2)
" 2>/dev/null
    fi
}

# ========== 3. 提取用户消息文本 ==========
extract_user_text() {
    local json_line="$1"
    python3 -c "
import json, sys
try:
    d = json.loads(sys.argv[1])
    if d.get('type') != 'message':
        sys.exit(1)
    msg = d.get('message', {})
    if msg.get('role') != 'user':
        sys.exit(1)
    content = msg.get('content', '')
    if isinstance(content, list):
        texts = []
        for c in content:
            if isinstance(c, dict) and c.get('type') == 'text':
                texts.append(c.get('text', ''))
        print('\n'.join(texts))
    elif isinstance(content, str):
        print(content)
    sys.exit(0)
except:
    sys.exit(1)
" "$json_line" 2>/dev/null
}

# ========== 4. 写入关键词记忆 ==========
write_keyword_memory() {
    local keyword="$1"
    local message="$2"
    local session_file="$3"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local date_str
    date_str=$(date '+%Y-%m-%d')
    local mem_file="$MEMORY_DIR/keyword-${date_str}.md"

    mkdir -p "$MEMORY_DIR"

    # 提取用户实际文本（去除 OpenClaw 系统元数据前缀）
    # 消息格式: "Conversation info (untrusted metadata):\n```json\n{...}\n```\n\nSender...```\n\n[用户实际内容]"
    # 实际文本出现在最后一个 ``` 关闭标签之后
    local clean_msg
    clean_msg=$(python3 -c "
import re, sys
msg = sys.argv[1]
# 去除所有 \`\`\`....\`\`\` 代码块
clean = re.sub(r'\`\`\`.*?\`\`\`', '', msg, flags=re.DOTALL)
# 去除 OpenClaw 元数据标题行
clean = re.sub(r'^(Conversation info|Sender|History)\s+\(untrusted metadata\):.*', '', clean, flags=re.MULTILINE)
# 清除空行和首尾空白
lines = [l.rstrip() for l in clean.split('\n') if l.strip()]
print('\n'.join(lines[:20]))
" "$message" 2>/dev/null)
    # 若 python3 提取失败，保留原始消息截断版
    [ -z "$clean_msg" ] && clean_msg=$(echo "$message" | tail -5)

    {
        echo ""
        echo "### [$timestamp] 触发关键词: $keyword"
        echo ""
        echo "$clean_msg"
        echo ""
        echo "---"
    } >> "$mem_file"

    log "✓ 写入记忆: [$keyword] → memory/keyword-${date_str}.md"
}

# ========== 5. 扫描 session 文件 ==========
scan_sessions() {
    if [ ! -d "$SESSIONS_DIR" ]; then
        log "⚠ sessions 目录不存在: $SESSIONS_DIR"
        return
    fi

    local scanned=0
    local hits=0

    # 只扫描最近 24 小时内修改的 jsonl 文件
    for session_file in "$SESSIONS_DIR"/*.jsonl; do
        [ -f "$session_file" ] || continue
        [[ "$session_file" == *".reset."* ]] && continue

        # 只处理最近更新的文件（24小时内）
        local now
        now=$(date +%s)
        local mtime
        if [ "$(uname -s)" = "Darwin" ]; then
            mtime=$(stat -f%m "$session_file" 2>/dev/null || echo 0)
        else
            mtime=$(stat -c%Y "$session_file" 2>/dev/null || echo 0)
        fi
        local age=$(( now - mtime ))
        [ "$age" -gt 86400 ] && continue

        local fname
        fname=$(basename "$session_file")
        local processed
        processed=$(get_processed_lines "$fname")
        local total_lines
        total_lines=$(wc -l < "$session_file" 2>/dev/null || echo 0)

        [ "$total_lines" -le "$processed" ] && continue

        scanned=$((scanned + 1))

        # 读取新增的行
        local line_num=0
        while IFS= read -r line; do
            line_num=$((line_num + 1))
            [ "$line_num" -le "$processed" ] && continue
            [ -z "$line" ] && continue

            # 提取用户消息
            local user_text
            user_text=$(extract_user_text "$line")
            [ -z "$user_text" ] && continue

            # 检查关键词
            for kw in "${KEYWORDS[@]}"; do
                if echo "$user_text" | grep -qF "$kw"; then
                    hits=$((hits + 1))
                    write_keyword_memory "$kw" "$user_text" "$fname"
                    break  # 一条消息只记录一次（按第一个匹配的关键词）
                fi
            done

        done < "$session_file"

        save_processed_lines "$fname" "$total_lines"
    done

    log "扫描完成: $scanned 个活跃 session，命中 $hits 条关键词消息"
}

# ========== 主流程 ==========
main() {
    log "========== 关键词监控开始 =========="
    log "Agent: $AGENT_NAME | Workspace: $WORKSPACE"

    load_keywords || exit 0

    scan_sessions

    log "========== 关键词监控完成 =========="
}

main "$@"
