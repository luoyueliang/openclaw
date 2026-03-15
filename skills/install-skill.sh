#!/bin/bash
# OpenClaw Skill 一键安装脚本
# 从 GitHub 私有/公开 Skill Hub 拉取并安装 Skill

# ========== 配置 ==========
HUB_REPO="https://github.com/luoyueliang/openclaw.git"
SKILLS_BASE="/root/.openclaw/workspace/skills"

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo_ok() { echo -e "${GREEN}✓${NC} $1"; }
echo_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
echo_err() { echo -e "${RED}✗${NC} $1"; }

# 用法说明
usage() {
    echo "用法: $0 <skill-name> [instance-name]"
    echo ""
    echo "示例:"
    echo "  $0 memory_manage           # 安装 memory_manage 到当前实例"
    echo "  $0 memory_manage openclaw-vps  # 安装到指定实例名"
    exit 1
}

# 拉取 Skill
pull_skill() {
    local skill_name=$1
    local skill_dir="$SKILLS_BASE/$skill_name"
    
    echo "========== 拉取 Skill: $skill_name =========="
    
    # 创建目录
    mkdir -p "$SKILLS_BASE"
    
    # 克隆仓库（如果还没有）
    local hub_dir="/tmp/openclaw-hub-$$"
    
    echo "从 GitHub 拉取..."
    git clone --depth 1 "$HUB_REPO" "$hub_dir" 2>/dev/null
    
    if [ ! -d "$hub_dir/skills/$skill_name" ]; then
        echo_err "Skill '$skill_name' 不存在"
        rm -rf "$hub_dir"
        exit 1
    fi
    
    # 复制 Skill
    cp -r "$hub_dir/skills/$skill_name" "$SKILLS_BASE/"
    echo_ok "已安装: $skill_dir"
    
    # 清理
    rm -rf "$hub_dir"
}

# 初始化配置
init_config() {
    local skill_name=$1
    local skill_dir="$SKILLS_BASE/$skill_name"
    
    echo "========== 初始化配置 =========="
    
    # 创建配置目录
    mkdir -p "$skill_dir/config"
    
    # 复制配置示例
    if [ -f "$skill_dir/config/sync.yaml.example" ]; then
        cp "$skill_dir/config/sync.yaml.example" "$skill_dir/config/sync.yaml"
        echo_ok "配置文件已创建: config/sync.yaml"
        echo_warn "请编辑配置文件填入你的信息"
    fi
    
    # 设置执行权限
    chmod +x "$skill_dir/scripts/"*.sh 2>/dev/null
    echo_ok "脚本权限已设置"
}

# 运行初始化检查
run_init_check() {
    local skill_name=$1
    local skill_dir="$SKILLS_BASE/$skill_name"
    
    echo ""
    echo "========== 运行初始化检查 =========="
    
    if [ -f "$skill_dir/scripts/init-check.sh" ]; then
        "$skill_dir/scripts/init-check.sh"
    else
        echo_warn "没有初始化检查脚本"
    fi
}

# 主流程
main() {
    if [ -z "$1" ]; then
        usage
    fi
    
    local skill_name=$1
    
    pull_skill "$skill_name"
    init_config "$skill_name"
    run_init_check "$skill_name"
    
    echo ""
    echo_ok "========== 安装完成 =========="
    echo "Skill: $skill_name"
    echo "位置: $SKILLS_BASE/$skill_name"
    echo ""
    echo "下一步:"
    echo "  1. 编辑 config/sync.yaml 填入你的配置"
    echo "  2. 运行 ./scripts/sync.sh 测试同步"
}

main "$@"
