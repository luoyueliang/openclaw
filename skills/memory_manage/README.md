# Memory Manage Skill - 记忆管理技能

## 一键安装（推荐）

```bash
# 方式 1：使用 install.sh（会自动下载 + 配置）
git clone https://github.com/luoyueliang/openclaw.git /tmp/skill
cp -r /tmp/skill/skills/memory_manage /root/.openclaw/workspace/skills/
/root/.openclaw/workspace/skills/memory_manage/scripts/install.sh
```

```bash
# 方式 2：一条命令完成（推荐）
bash -c "$(curl -sL https://raw.githubusercontent.com/luoyueliang/openclaw/main/skills/memory_manage/scripts/install.sh)"
```

## 安装过程

运行后会交互式询问：

```
实例名 [openclaw-home]: 
Agent 名 [main]: 
记忆备份仓库地址 [https://github.com/luoyueliang/ai_openclaw_memory]: 
GitHub Token: ********
```

## 配置说明

| 配置项 | 说明 | 示例 |
|--------|------|------|
| instance.name | 实例名，每台机器唯一 | openclaw-home, openclaw-vps |
| agent.name | Agent 名，只有 main 能管理其他 | main |
| github.repo | 记忆备份仓库 | https://github.com/.../ai_openclaw_memory |
| github.token | GitHub PAT | ghp_xxx |

## 功能

- 自动备份 MEMORY.md、AGENTS.md 等核心文件
- 支持多实例多 Agent
- 关键词触发记忆更新

---

*🤖 记忆管理技能*
