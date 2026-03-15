# Memory Manage Skill - 记忆管理技能

## 一键安装

复制以下命令直接在服务器运行：

```bash
curl -sL https://raw.githubusercontent.com/luoyueliang/openclaw/main/skills/memory_manage/scripts/install.sh | bash
```

或者下载后运行：

```bash
wget -O install.sh https://raw.githubusercontent.com/luoyueliang/openclaw/main/skills/memory_manage/scripts/install.sh
bash install.sh
```

## 安装过程

运行后会：
1. **自动检测**单 Agent / 多 Agent 模式
2. **自动选择**安装目录：
   - 单 Agent → `/root/.openclaw/workspace/skills/`
   - 多 Agent → `/root/.openclaw/agents/main/workspace/skills/`
3. **自动下载** Skill
4. **交互式配置**（实例名、Agent 名、GitHub 仓库、Token）

## 交互式配置

```
实例名 [openclaw-home]: 
Agent 名 [main]: 
记忆备份仓库地址 [https://github.com/luoyueliang/ai_openclaw_memory]: 
GitHub Token: ********
```

## 功能

- 自动备份 MEMORY.md、AGENTS.md 等核心文件
- 支持多实例多 Agent
- 关键词触发记忆更新

---

*🤖 记忆管理技能*
