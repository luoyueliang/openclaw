#!/usr/bin/env node
// restore.js — 从 GitHub 备份仓库恢复 OpenClaw 记忆或配置
// 用法: node restore.js [--instance=<name>] [--mode=config|memory|both] [--agent=<name>] [--dry-run]
'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');
const readline = require('readline');
const { execSync } = require('child_process');
const yaml = require('js-yaml');

const SCRIPT_DIR = __dirname;
const CONFIG_FILE = path.join(SCRIPT_DIR, '..', 'config', 'sync.yaml');

const CORE_FILES = [
  'MEMORY.md', 'AGENTS.md', 'SOUL.md', 'USER.md',
  'TOOLS.md', 'HEARTBEAT.md', 'IDENTITY.md', 'BOOTSTRAP.md',
];

// ─── 颜色 ─────────────────────────────────────────────────
const C = {
  reset: '\x1b[0m', bold: '\x1b[1m',
  green: '\x1b[32m', yellow: '\x1b[33m', red: '\x1b[31m', cyan: '\x1b[36m', gray: '\x1b[90m',
};
const ok    = (s) => `${C.green}✓${C.reset} ${s}`;
const warn  = (s) => `${C.yellow}⚠${C.reset} ${s}`;
const err   = (s) => `${C.red}✗${C.reset} ${s}`;
const info  = (s) => `${C.cyan}→${C.reset} ${s}`;
const bold  = (s) => `${C.bold}${s}${C.reset}`;
const gray  = (s) => `${C.gray}${s}${C.reset}`;

// ─── 工具函数 ─────────────────────────────────────────────
function run(cmd, opts = {}) {
  return execSync(cmd, { encoding: 'utf8', stdio: opts.stdio || 'pipe', cwd: opts.cwd });
}
function runSafe(cmd, opts = {}) {
  try { return run(cmd, opts); } catch { return null; }
}

function detectOpenclawRoot() {
  const candidates = os.platform() === 'darwin'
    ? [path.join(os.homedir(), '.openclaw'),
       path.join(os.homedir(), 'Library', 'Application Support', 'openclaw')]
    : [path.join(os.homedir(), '.openclaw'), '/root/.openclaw'];
  return candidates.find(p => fs.existsSync(p)) || null;
}

function loadConfig() {
  if (!fs.existsSync(CONFIG_FILE)) throw new Error(`配置文件不存在: ${CONFIG_FILE}`);
  return yaml.load(fs.readFileSync(CONFIG_FILE, 'utf8'));
}

function ask(rl, question) {
  return new Promise(resolve => rl.question(question, resolve));
}

function parseArgs() {
  const args = {};
  for (const a of process.argv.slice(2)) {
    const m = a.match(/^--(\w[\w-]*)(?:=(.+))?$/);
    if (m) args[m[1]] = m[2] ?? true;
  }
  return args;
}

// ─── 文件恢复（带内容比较）──────────────────────────────
function restoreFile(src, dest, dryRun) {
  if (!fs.existsSync(src)) return null; // 不存在
  const srcBuf = fs.readFileSync(src);
  if (fs.existsSync(dest)) {
    if (fs.readFileSync(dest).equals(srcBuf)) return 'same'; // 内容相同
    const backupPath = dest + `.bak.${Date.now()}`;
    if (!dryRun) fs.copyFileSync(dest, backupPath);
    if (!dryRun) { fs.mkdirSync(path.dirname(dest), { recursive: true }); fs.writeFileSync(dest, srcBuf); }
    return 'updated';
  }
  if (!dryRun) { fs.mkdirSync(path.dirname(dest), { recursive: true }); fs.writeFileSync(dest, srcBuf); }
  return 'created';
}

// ─── 刷新本地 repo ────────────────────────────────────────
function pullRepo(repoDir, githubRepo, githubToken) {
  if (!fs.existsSync(path.join(repoDir, '.git'))) {
    console.log(info('本地备份仓库不存在，正在 clone...'));
    const remoteUrl = githubRepo.replace('https://', `https://${githubToken}@`);
    fs.mkdirSync(repoDir, { recursive: true });
    run(`git -C "${repoDir}" init`);
    run(`git -C "${repoDir}" remote add origin "${remoteUrl}"`);
  } else {
    const remoteUrl = githubRepo.replace('https://', `https://${githubToken}@`);
    runSafe(`git -C "${repoDir}" remote set-url origin "${remoteUrl}"`);
  }
  console.log(info('拉取最新备份...'));
  const result = runSafe(`git -C "${repoDir}" pull --depth 1 origin main`);
  if (result !== null) {
    console.log(ok('备份仓库已更新'));
  } else {
    console.log(warn('pull 失败（可能是首次），尝试 fetch...'));
    runSafe(`git -C "${repoDir}" fetch --depth 1 origin main`);
    runSafe(`git -C "${repoDir}" checkout FETCH_HEAD`);
  }
}

// ─── 恢复配置（openclaw.json 结构合并）────────────────────
function restoreConfig(repoDir, instanceName, openclawRoot, dryRun) {
  const srcPath = path.join(repoDir, instanceName, 'config', 'openclaw.json');
  if (!fs.existsSync(srcPath)) {
    console.log(warn('备份中无 config/openclaw.json，跳过'));
    return 0;
  }

  // 备份的是脱敏版（token 已替换为 ***），需要与现有配置合并
  const backedUp = JSON.parse(fs.readFileSync(srcPath, 'utf8'));
  const destPath = path.join(openclawRoot, 'openclaw.json');
  const current = fs.existsSync(destPath) ? JSON.parse(fs.readFileSync(destPath, 'utf8')) : {};

  // 深度合并：备份为主，但 token/secret 字段保留当前值
  function merge(base, overlay) {
    const result = { ...base };
    for (const [k, v] of Object.entries(overlay)) {
      if (['token', 'botToken', 'appSecret', 'apiKey', 'secret', 'password'].includes(k)) {
        continue; // 跳过敏感字段，保留 base（当前配置）中的值
      }
      if (v && typeof v === 'object' && !Array.isArray(v) && base[k] && typeof base[k] === 'object') {
        result[k] = merge(base[k], v);
      } else {
        result[k] = v;
      }
    }
    return result;
  }

  const merged = merge(current, backedUp);
  const newContent = Buffer.from(JSON.stringify(merged, null, 2));
  const currentContent = fs.existsSync(destPath) ? fs.readFileSync(destPath) : Buffer.alloc(0);

  if (newContent.equals(currentContent)) {
    console.log(gray('  openclaw.json 无变更'));
    return 0;
  }

  if (!dryRun) {
    if (fs.existsSync(destPath)) fs.copyFileSync(destPath, destPath + `.bak.${Date.now()}`);
    fs.writeFileSync(destPath, newContent);
  }
  console.log(ok(`openclaw.json → ${dryRun ? '[dry-run] ' : ''}已恢复`));
  return 1;
}

// ─── 恢复记忆（core + memory/）───────────────────────────
function restoreMemory(repoDir, instanceName, agentName, openclawRoot, dryRun) {
  // 确定 workspace 路径
  const agentsWs = path.join(openclawRoot, 'agents', agentName, 'workspace');
  const singleWs = path.join(openclawRoot, 'workspace');
  const workspace = fs.existsSync(agentsWs) ? agentsWs : singleWs;

  const agentRepo = path.join(repoDir, instanceName, agentName);
  if (!fs.existsSync(agentRepo)) {
    console.log(warn(`备份中无 ${instanceName}/${agentName} 数据`));
    return 0;
  }

  let restored = 0, skipped = 0;

  // 核心文件
  const coreDir = path.join(agentRepo, 'core');
  if (fs.existsSync(coreDir)) {
    for (const f of CORE_FILES) {
      const src = path.join(coreDir, f);
      const dest = path.join(workspace, f);
      const status = restoreFile(src, dest, dryRun);
      if (status === 'updated') { console.log(ok(`${f} → 已更新${dryRun ? ' [dry-run]' : ''}`)); restored++; }
      else if (status === 'created') { console.log(ok(`${f} → 已创建${dryRun ? ' [dry-run]' : ''}`)); restored++; }
      else if (status === 'same') { skipped++; }
    }
  }

  // memory/ 目录
  const memSrcDir = path.join(agentRepo, 'workspace', 'memory');
  const memDestDir = path.join(workspace, 'memory');
  if (fs.existsSync(memSrcDir)) {
    const files = fs.readdirSync(memSrcDir).filter(f => f.endsWith('.md'));
    for (const f of files) {
      const src = path.join(memSrcDir, f);
      const dest = path.join(memDestDir, f);
      const status = restoreFile(src, dest, dryRun);
      if (status === 'updated') { console.log(ok(`memory/${f} → 已更新${dryRun ? ' [dry-run]' : ''}`)); restored++; }
      else if (status === 'created') { console.log(ok(`memory/${f} → 已创建${dryRun ? ' [dry-run]' : ''}`)); restored++; }
      else if (status === 'same') { skipped++; }
    }
  }

  if (skipped > 0) console.log(gray(`  ${skipped} 个文件内容相同，已跳过`));
  return restored;
}

// ─── 主流程 ───────────────────────────────────────────────
async function main() {
  const args = parseArgs();
  const dryRun = !!args['dry-run'];

  console.log(`\n${bold('═══════════════════════════════════════')}`);
  console.log(bold('     OpenClaw 记忆恢复工具'));
  if (dryRun) console.log(`${C.yellow}     [DRY-RUN 模式，不实际写入文件]${C.reset}`);
  console.log(`${bold('═══════════════════════════════════════')}\n`);

  // 读取配置
  const openclawRoot = detectOpenclawRoot();
  if (!openclawRoot) { console.log(err('未找到 OpenClaw 安装目录')); process.exit(1); }

  let config;
  try { config = loadConfig(); } catch (e) { console.log(err(e.message)); process.exit(1); }

  const githubRepo  = config?.github?.repo;
  const githubToken = config?.github?.token;
  if (!githubRepo || !githubToken) {
    console.log(err('sync.yaml 中缺少 github.repo 或 github.token'));
    process.exit(1);
  }

  const repoDir = path.join(openclawRoot, 'workspace', 'memory-github');

  // 拉取最新备份
  pullRepo(repoDir, githubRepo, githubToken);
  console.log();

  // 列出可用实例
  const instances = fs.existsSync(repoDir)
    ? fs.readdirSync(repoDir, { withFileTypes: true })
        .filter(e => e.isDirectory() && !e.name.startsWith('.'))
        .map(e => e.name)
    : [];

  if (instances.length === 0) {
    console.log(err('备份仓库中未找到任何实例数据'));
    process.exit(1);
  }

  // ── 选择实例 ──
  let instanceName = args.instance;
  if (!instanceName) {
    console.log(bold('可用实例：'));
    instances.forEach((inst, i) => console.log(`  ${C.cyan}[${i + 1}]${C.reset} ${inst}`));
    console.log();
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    const defaultInst = config?.instance?.name || instances[0];
    const choice = await ask(rl, `选择实例 [默认: ${defaultInst}]: `);
    rl.close();
    if (!choice.trim()) {
      instanceName = defaultInst;
    } else if (/^\d+$/.test(choice)) {
      instanceName = instances[parseInt(choice) - 1] || defaultInst;
    } else {
      instanceName = choice.trim();
    }
  }

  if (!instances.includes(instanceName)) {
    console.log(err(`实例 "${instanceName}" 不存在于备份中`));
    console.log(gray(`可用: ${instances.join(', ')}`));
    process.exit(1);
  }
  console.log(info(`实例: ${bold(instanceName)}\n`));

  // ── 列出该实例下的 agents ──
  const instanceDir = path.join(repoDir, instanceName);
  const agents = fs.readdirSync(instanceDir, { withFileTypes: true })
    .filter(e => e.isDirectory() && e.name !== 'config')
    .map(e => e.name);

  // ── 选择 agent ──
  let agentName = args.agent;
  if (!agentName && agents.length > 1) {
    const rl2 = readline.createInterface({ input: process.stdin, output: process.stdout });
    console.log(bold('可用 Agent：'));
    agents.forEach((a, i) => console.log(`  ${C.cyan}[${i + 1}]${C.reset} ${a}`));
    console.log(`  ${C.cyan}[0]${C.reset} 全部`);
    const ac = await ask(rl2, `\n选择 Agent [默认: 全部]: `);
    rl2.close();
    if (!ac.trim() || ac.trim() === '0') {
      agentName = null; // 全部
    } else if (/^\d+$/.test(ac)) {
      agentName = agents[parseInt(ac) - 1] || null;
    } else {
      agentName = ac.trim();
    }
  } else if (!agentName) {
    agentName = agents[0] || null;
  }

  const targetAgents = agentName ? [agentName] : agents;
  console.log(info(`Agent: ${bold(targetAgents.join(', '))}\n`));

  // ── 选择恢复模式 ──
  const MODES = { '1': 'config', '2': 'memory', '3': 'both' };
  let mode = args.mode;
  if (!mode || !Object.values(MODES).includes(mode)) {
    const rl3 = readline.createInterface({ input: process.stdin, output: process.stdout });
    console.log(bold('恢复内容：'));
    console.log(`  ${C.cyan}[1]${C.reset} 仅系统配置  (openclaw.json 结构/设置)`);
    console.log(`  ${C.cyan}[2]${C.reset} 仅记忆文件  (MEMORY.md / AGENTS.md / memory/*.md 等)`);
    console.log(`  ${C.cyan}[3]${C.reset} 全部恢复    (配置 + 记忆)`);
    const mc = await ask(rl3, `\n选择 [默认: 2]: `);
    rl3.close();
    mode = MODES[mc.trim()] || 'memory';
  }
  console.log(info(`模式: ${bold(mode)}\n`));

  // ── 执行恢复 ──
  let totalRestored = 0;

  if (mode === 'config' || mode === 'both') {
    console.log(bold('── 恢复系统配置 ──'));
    totalRestored += restoreConfig(repoDir, instanceName, openclawRoot, dryRun);
    console.log();
  }

  if (mode === 'memory' || mode === 'both') {
    for (const agent of targetAgents) {
      console.log(bold(`── 恢复 Agent [${agent}] 记忆 ──`));
      totalRestored += restoreMemory(repoDir, instanceName, agent, openclawRoot, dryRun);
      console.log();
    }
  }

  // ── 结果 ──
  console.log(`${bold('═══════════════════════════════════════')}`);
  if (totalRestored > 0) {
    console.log(ok(`恢复完成！共写入/更新 ${totalRestored} 个文件${dryRun ? ' [dry-run，未实际写入]' : ''}`));
    if (!dryRun && (mode === 'config' || mode === 'both')) {
      console.log(warn('系统配置已更新，建议重启 OpenClaw 使其生效'));
    }
  } else {
    console.log(info('所有文件内容与备份一致，无需恢复'));
  }
  console.log(`${bold('═══════════════════════════════════════')}\n`);
}

main().catch(e => {
  console.error(err(e.message));
  process.exit(1);
});
