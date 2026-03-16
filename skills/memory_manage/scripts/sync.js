#!/usr/bin/env node
// sync.js — 记忆同步脚本（Node.js 版，替代 sync.sh）
// 支持多实例多 Agent，跨平台 macOS / Linux
'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');
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

  // 核心文件 → <instance>/<agent>/core/
  const coreDir = path.join(repoDir, instanceName, name, 'core');
  for (const f of CORE_FILES) {
    if (copyFile(path.join(workspace, f), path.join(coreDir, f))) {
      log(`  ✓ ${f}`);
      changed++;
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

// ─── 主流程 ───────────────────────────────────────────────
function main() {
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

  commitPush(repoDir);
  log('========== 记忆同步完成 ==========');
}

main();
