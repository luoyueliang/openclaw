# Memory Manage Skill - 记忆管理技能

## 两种安装方式

### 方式 1：官方 clawhub（推荐）

```bash
# 安装（需要先发布到 clawhub）
npx clawhub install memory_manage

# 或者指定版本
npx clawhub install memory_manage --version 1.0.0
```

### 方式 2：手动安装

```bash
# 克隆仓库
git clone https://github.com/luoyueliang/openclaw.git /tmp/openclaw-skills

# 复制 Skill
cp -r /tmp/openclaw-skills/skills/memory_manage /root/.openclaw/workspace/skills/

# 交互式配置
/root/.openclaw/workspace/skills/memory_manage/scripts/install.sh
```

## 交互式配置

运行安装脚本时会交互式询问：

```
实例名 [openclaw-home]: 
Agent 名 [main]: 
记忆备份仓库地址 [https://github.com/luoyueliang/ai_openclaw_memory]: 
GitHub Token: ********
```

填写后会：
1. 自动创建配置文件
2. 运行初始化检查
3. 测试同步

## 功能

- 自动备份记忆到私有 GitHub 仓库
- 支持多实例多 Agent
- 关键词触发记忆更新

---

*🤖 记忆管理技能 - 自动备份到 GitHub*
