#!/usr/bin/env node
// sync.js — 记忆同步脚本（Node.js 版，替代 sync.sh）
// 支持多实例多 Agent，跨平台 macOS / Linux
'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');
const https = require('https');
const { execSync } = require('child_process');
const yaml = require('js-yaml');

const SCRIPT_DIR = __dirname;
const CONFIG_FILE = path.join(SCRIPT_DIR, '..', 'config', 'sync.yaml');

const CORE_FILES = [
  'MEMORY.md', 'AGENTS.md', 'SOUL.md', 'USER.md',
  'TOOLS.md', 'HEARTBEAT.md', 'IDENTITY.md', 'BOOTSTRAP.md',
];

// ─── 工具函数 ─────────────────────────────────────────────
function log(msg) {
  const ts = new Date().toISOString().replace('T', ' ').slice(0, 19);
  console.log(`[${ts}] ${msg}`);
}

function run(cmd, opts = {}) {
  return execSync(cmd, {
    encoding: 'utf8',
    stdio: opts.stdio || 'pipe',
    cwd: opts.cwd,
  });
}

function runSafe(cmd, opts = {}) {
  try { return run(cmd, opts); } catch { return null; }
}

// ─── Telegram 通知 ────────────────────────────────────────
function readTelegramConfig(openclawRoot) {
  try {
    const cfgPath = path.join(openclawRoot, '..', 'openclaw.json');
    if (!fs.existsSync(cfgPath)) return null;
    const cfg = JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
    const tg = cfg?.channels?.telegram;
    if (!tg?.enabled || !tg?.botToken) return null;
    // 找第一个纯数字的 allowFrom 作为 chat_id（私聊 user_id = chat_id）
    const chatId = (tg.allowFrom || []).find(x => /^\d+$/.test(String(x)));
    return chatId ? { botToken: tg.botToken, chatId: String(chatId) } : null;
  } catch { return null; }
}

function sendTelegram(botToken, chatId, text) {
  return new Promise((resolve) => {
    const body = JSON.stringify({ chat_id: chatId, text, parse_mode: 'HTML' });
    const req = https.request({
      hostname: 'api.telegram.org',
      path: `/bot${botToken}/sendMessage`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body) },
    }, (res) => {
      res.resume();
      resolve(res.statusCode === 200);
    });
    req.on('error', () => resolve(false));
    req.setTimeout(8000, () => { req.destroy(); resolve(false); });
    req.write(body);
    req.end();
  });
}

// ─── 路径检测 ─────────────────────────────────────────────
function detectOpenclawRoot() {
  const candidates = os.platform() === 'darwin'
    ? [path.join(os.homedir(), '.openclaw'),
       path.join(os.homedir(), 'Library', 'Application Support', 'openclaw')]
    : [path.join(os.homedir(), '.openclaw'), '/root/.openclaw'];
  return candidates.find(p => fs.existsSync(p)) || null;
}

// ─── 配置读取 ─────────────────────────────────────────────
function loadConfig() {
  if (!fs.existsSync(CONFIG_FILE)) throw new Error(`配置文件不存在: ${CONFIG_FILE}`);
  return yaml.load(fs.readFileSync(CONFIG_FILE, 'utf8'));
}

// ─── Agent 发现 ───────────────────────────────────────────
function discoverAgents(openclawRoot) {
  const agentsDir = path.join(openclawRoot, 'agents');
  const agents = [];

  if (fs.existsSync(agentsDir)) {
    for (const entry of fs.readdirSync(agentsDir, { withFileTypes: true })) {
      if (!entry.isDirectory()) continue;
      const ws = path.join(agentsDir, entry.name, 'workspace');
      if (fs.existsSync(ws)) agents.push({ name: entry.name, workspace: ws });
    }
  }

  if (agents.length === 0) {
    const ws = path.join(openclawRoot, 'workspace');
    if (fs.existsSync(ws)) {
      log('未发现多 Agent workspace，使用单 Agent 模式 (main)');
      agents.push({ name: 'main', workspace: ws });
    }
  } else {
    log(`发现 ${agents.length} 个 Agent: ${agents.map(a => a.name).join(', ')}`);
  }
  return agents;
}

// ─── 文件复制（< 1 MB）─────────────────────────────────────
function copyFile(src, dest) {
  if (!fs.existsSync(src)) return false;
  if (fs.statSync(src).size > 1048576) return false;
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  fs.copyFileSync(src, dest);
  return true;
}

// ─── 单个 Agent 同步 ──────────────────────────────────────
function syncAgent(agent, repoDir, instanceName) {
  const { name, workspace } = agent;
  log(`=== 同步 Agent: ${name} ===`);

  let changed = 0;
  agent._syncedFiles = [];

  // 核心文件 → <instance>/<agent>/core/
  const coreDir = path.join(repoDir, instanceName, name, 'core');
  for (const f of CORE_FILES) {
    if (copyFile(path.join(workspace, f), path.join(coreDir, f))) {
      log(`  ✓ ${f}`);
      changed++;
      agent._syncedFiles.push(f);
    }
  }

  // memory/*.md → <instance>/<agent>/workspace/memory/
  const srcMem = path.join(workspace, 'memory');
  const destMem = path.join(repoDir, instanceName, name, 'workspace', 'memory');
  if (fs.existsSync(srcMem)) {
    fs.mkdirSync(destMem, { recursive: true });
    for (const f of fs.readdirSync(srcMem)) {
      if (!f.endsWith('.md')) continue;
      if (copyFile(path.join(srcMem, f), path.join(destMem, f))) {
        log(`  ✓ memory/${f}`);
        changed++;
        agent._syncedFiles.push(`memory/${f}`);
      }
    }
  }

  log(`Agent ${name}: ${changed} 个文件已复制`);
}

// ─── Git 初始化 ───────────────────────────────────────────
function initRepo(repoDir, githubRepo, githubToken) {
  fs.mkdirSync(repoDir, { recursive: true });

  const remoteUrl = githubRepo.replace('https://', `https://${githubToken}@`);
  const gitDir = path.join(repoDir, '.git');

  if (!fs.existsSync(gitDir)) {
    log('初始化本地 Git 仓库...');
    run(`git -C "${repoDir}" init`);
    run(`git -C "${repoDir}" config user.name "OpenClaw Sync"`);
    run(`git -C "${repoDir}" config user.email "sync@openclaw.local"`);
    run(`git -C "${repoDir}" remote add origin "${remoteUrl}"`);
    runSafe(`git -C "${repoDir}" pull --depth 1 origin main`);
  } else {
    // 每次刷新 token
    run(`git -C "${repoDir}" remote set-url origin "${remoteUrl}"`);
    run(`git -C "${repoDir}" config user.name "OpenClaw Sync"`);
    run(`git -C "${repoDir}" config user.email "sync@openclaw.local"`);
  }
}

// ─── Commit & Push ────────────────────────────────────────
function commitPush(repoDir) {
  const status = runSafe(`git -C "${repoDir}" status --porcelain`);
  if (!status || !status.trim()) {
    log('没有新变更需要提交');
    return;
  }

  run(`git -C "${repoDir}" add -A`);
  const ts = new Date().toISOString().replace('T', ' ').slice(0, 19);
  run(`git -C "${repoDir}" commit -m "🤖 自动同步 - ${ts}"`);

  // pull --rebase（多实例同仓库不冲突，各写各自目录）
  runSafe(`git -C "${repoDir}" pull --rebase origin main`);
  runSafe(`git -C "${repoDir}" pull --rebase origin master`);

  const pushed = runSafe(`git -C "${repoDir}" push origin HEAD:main`);
  if (pushed !== null) {
    log('✓ 同步成功！');
  } else {
    log('push 失败，尝试 force push...');
    if (runSafe(`git -C "${repoDir}" push --force origin HEAD:main`) !== null) {
      log('✓ 同步成功（force push）');
    } else {
      log('✗ 同步失败');
      process.exit(1);
    }
  }
}

// ─── 构建 Telegram 通知消息 ──────────────────────────────
function buildNotifyMessage(instanceName, agents, success) {
  const ts = new Date().toLocaleString('zh-CN', { hour12: false,
    timeZone: 'Asia/Shanghai', year: 'numeric', month: '2-digit',
    day: '2-digit', hour: '2-digit', minute: '2-digit' });

  const totalFiles = agents.reduce((n, a) => n + (a._syncedFiles?.length || 0), 0);
  const statusIcon = success ? '✅' : '❌';
  const statusText = success ? '同步成功' : '同步失败';

  const fileLines = agents.flatMap(a =>
    (a._syncedFiles || []).slice(0, 5).map(f => `  · ${f}`)
  ).join('\n');
  const moreTip = totalFiles > 5 ? `\n  · ... 共 ${totalFiles} 个文件` : '';

  const TIP = `
💡 <b>说这些话让我更好记住你：</b>
• <code>帮我记住...</code> → 日记备忘
• <code>这很重要...</code> → 长期记忆
• <code>我喜欢 / 我偏好...</code> → 写入 USER.md
• <code>以后禁止 / 原则是...</code> → 写入 AGENTS.md`;

  return `${statusIcon} <b>[${instanceName}] 记忆${statusText}</b>\n` +
         `🕐 ${ts}\n` +
         (totalFiles > 0 ? `📁 已同步 ${totalFiles} 个文件\n${fileLines}${moreTip}` : `📁 无文件变更`) +
         TIP;
}

// ─── 主流程 ───────────────────────────────────────────────
async function main() {
  log('========== 记忆同步开始 ==========');

  const openclawRoot = detectOpenclawRoot();
  if (!openclawRoot) { log('✗ 未找到 OpenClaw 安装目录'); process.exit(1); }
  log(`OpenClaw: ${openclawRoot}`);

  let config;
  try { config = loadConfig(); } catch (e) { log(`✗ ${e.message}`); process.exit(1); }

  const instanceName = config?.instance?.name;
  const githubRepo   = config?.github?.repo;
  const githubToken  = config?.github?.token;

  if (!instanceName || !githubRepo || !githubToken) {
    log('✗ 配置不完整 (instance.name / github.repo / github.token)');
    process.exit(1);
  }
  log(`实例: ${instanceName}`);

  const agents = discoverAgents(openclawRoot);
  if (agents.length === 0) { log('✗ 未找到任何 Agent'); process.exit(1); }

  const repoDir = path.join(openclawRoot, 'workspace', 'memory-github');
  initRepo(repoDir, githubRepo, githubToken);

  for (const agent of agents) {
    syncAgent(agent, repoDir, instanceName);
  }

  let success = true;
  try { commitPush(repoDir); } catch { success = false; }
  log('========== 记忆同步完成 ==========');

  // ── Telegram 通知 ──
  // chat_id 优先读 sync.yaml notify.telegram_chat_id，否则从 openclaw.json 自动检测
  const manualChatId = config?.notify?.telegram_chat_id;
  const tgCfg = manualChatId
    ? { botToken: readTelegramConfig(openclawRoot)?.botToken, chatId: String(manualChatId) }
    : readTelegramConfig(openclawRoot);

  if (tgCfg?.botToken && tgCfg?.chatId) {
    const msg = buildNotifyMessage(instanceName, agents, success);
    const ok = await sendTelegram(tgCfg.botToken, tgCfg.chatId, msg);
    log(ok ? '✓ Telegram 通知已发送' : '⚠ Telegram 通知发送失败');
  } else {
    log('— 未配置 Telegram 通知，跳过');
  }
}

main();
