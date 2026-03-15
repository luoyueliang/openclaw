#!/bin/bash
# 记忆同步 - 关键词检查
# 检查消息中是否包含触发记忆更新的关键词

# 关键词定义
KEYWORDS=(
    "记住"
    "记录"
    "原则"
    "禁止"
    "严禁"
    "我喜欢"
    "我讨厌"
    "重要"
    "别忘了"
    "提醒我"
)

# 检查是否包含关键词
check_keywords() {
    local text="$1"
    
    for keyword in "${KEYWORDS[@]}"; do
        if echo "$text" | grep -q "$keyword"; then
            echo "true"
            return 0
        fi
    done
    
    echo "false"
    return 1
}

# 测试用
if [ "$1" = "--test" ]; then
    echo "测试关键词检测:"
    for kw in "${KEYWORDS[@]}"; do
        echo -n "  $kw -> "
        check_keywords "这个是包含$kw的测试" && echo "✓ 触发" || echo "✗"
    done
fi
