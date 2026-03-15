# Memory Manage Skill - 记忆管理技能

## 功能概述

### 1. 记忆同步
- 自动备份 MEMORY.md、AGENTS.md 等核心文件到私有 GitHub 仓库
- 支持多实例多 Agent

### 2. Agent 监控
- 检测 agent 变更（新增/删除/修改）
- 检查每个 agent 的 memory 配置
- 问题实时通知（飞书 + 邮件）

---

## 脚本说明

### install.sh
一键安装脚本，自动检测 OpenClaw 安装路径和 agent 列表

### init-check.sh  
初始化检查脚本，检查配置和文件

### sync.sh
同步脚本，执行记忆备份

### monitor-agents.sh
**Agent 监控脚本**
- 每小时运行一次
- 检测 agent 变更
- 检查 memory 文件配置
- 异常情况通知

---

## 监控逻辑

### 检测项目

| 检测项 | 说明 |
|--------|------|
| Agent 新增 | 新增的 agent |
| Agent 删除 | 被删除的 agent |
| Workspace 变更 | agent 的 workspace 路径变化 |
| Memory 文件 | MEMORY.md, AGENTS.md, SOUL.md, USER.md |

### 通知策略

| 情况 | 通知方式 | 严重程度 |
|------|---------|---------|
| 新增 agent | 飞书 + 邮件 | INFO |
| 删除 agent | 飞书 + 邮件 | WARN |
| Memory 文件缺失 | 飞书 + 邮件 | ERROR |
| 同步失败 | 飞书 + 邮件 | ERROR |

---

## 配置

### sync.yaml

```yaml
instance:
  name: openclaw-mac

agent:
  name: main

github:
  repo: https://github.com/xxx/ai_openclaw_memory
  token: ghp_xxx

# 通知配置
notify:
  feishu_webhook: "https://open.feishu.cn/..."
  email:
    enabled: true
    to: "user@example.com"
```

---

## 自动运行

通过 cron 设置每小时检查：

```bash
# 每小时运行监控
0 * * * * /path/to/monitor-agents.sh

# 每小时运行同步
30 * * * * /path/to/sync.sh
```

---

*🤖 记忆管理 + Agent 监控*
