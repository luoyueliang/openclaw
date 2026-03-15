# Memory Manage Skill - 记忆管理技能

## 一键安装

复制以下命令直接在服务器运行：

```bash
curl -sL https://raw.githubusercontent.com/luoyueliang/openclaw/main/skills/memory_manage/scripts/install.sh | bash
```

或者先下载再运行：

```bash
wget -O install.sh https://raw.githubusercontent.com/luoyueliang/openclaw/main/skills/memory_manage/scripts/install.sh
bash install.sh
```

## 安装过程

运行后会：
1. **自动检测**单 Agent / 多 Agent 模式
2. **自动选择**安装目录
3. **自动下载** Skill
4. **交互式配置**

## 交互式配置

```
实例名 [openclaw-home]: 
Agent 名 [main]: 
记忆备份仓库地址 [https://github.com/你的用户名/ai_openclaw_memory]: 
GitHub Token: ********
```

## 如何获取 GitHub Token

### 步骤 1：创建 Personal Access Token (PAT)

1. 登录 GitHub：https://github.com
2. 点击右上角头像 → **Settings**
3. 左侧菜单找到 **Developer settings**
4. 点击 **Personal access tokens** → **Tokens (classic)**
5. 点击 **Generate new token (classic)**

### 步骤 2：配置 Token

- **Note**：填写一个备注名，如 `OpenClaw Memory Backup`
- **Expiration**：建议选择 **No expiration**（永不过期）或 90 天
- **Select scopes**：勾选 `repo`（完整仓库权限）

### 步骤 3：复制 Token

生成后**立即复制保存**，只显示一次！

```
ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### 注意事项

- Token 只用于推送到**你自己的私有备份仓库**
- **不要**把 Token 推送到公开的 Skill Hub
- 安装脚本会在本地生成配置文件，不会推送到公开仓库

## 功能

- 自动备份 MEMORY.md、AGENTS.md 等核心文件
- 支持多实例多 Agent
- 关键词触发记忆更新

---

*🤖 记忆管理技能 - 自动备份到 GitHub*
