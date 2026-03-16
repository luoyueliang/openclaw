#!/usr/bin/env node
// init-check.js — 初始化自检（Node.js 版，替代 init-check.sh）
'use strict';

const fs   = require('fs');
const path = require('path');
const os   = require('os');
const https = require('https');
const yaml = require('js-yaml');

const SCRIPT_DIR  = __dirname;
const CONFIG_FILE = path.join(SCRIPT_DIR, '..', 'config', 'sync.yaml');

const G = '\x1b[32m', Y = '\x1b[33m', R = '\x1b[31m', N = '\x1b[0m';
const ok   = msg => console.log(`${G}✓${N} ${msg}`);
const warn = msg => console.log(`${Y}⚠${N} ${msg}`);
const fail = msg => console.log(`${R}✗${N} ${msg}`);

function detectOpenclawRoot() {
  const candidates = os.platform() === 'darwin'
    ? [path.join(os.homedir(), '.openclaw'),
       path.join(os.homedir(), 'Library', 'Application Support', 'openclaw')]
    : [path.join(os.homedir(), '.openclaw'), '/root/.openclaw'];
  return candidates.find(p => fs.existsSync(p)) || null;
}

function checkGitHubToken(token, repo) {
  const m = repo.match(/github\.com\/([^/]+)\/([^/\s]+)/);
  if (!m) return Promise.resolve('invalid repo URL');
  const [, owner, repoName] = m;
  return new Promise(resolve => {
    const req = https.get({
      hostname: 'api.github.com',
      path: `/repos/${owner}/${repoName.replace(/\.git$/, '')}`,
      headers: { Authorization: `token ${token}`, 'User-Agent': 'openclaw-init-check' },
    }, res => resolve(res.statusCode === 200 ? 'ok' : `HTTP ${res.statusCode}`));
    req.on('error', e => resolve(e.message));
    req.setTimeout(5000, () => { req.destroy(); resolve('timeout'); });
  });
}

async function main() {
  console.log('\n========== OpenClaw Memory Manage 初始化检查 ==========\n');

  // OpenClaw root
  const openclawRoot = detectOpenclawRoot();
  if (openclawRoot) ok(`OpenClaw 根目录: ${openclawRoot}`);
  else { fail('未找到 OpenClaw 安装目录'); process.exit(1); }

  // Config file
  if (!fs.existsSync(CONFIG_FILE)) {
    fail(`配置文件不存在: ${CONFIG_FILE}`);
    console.log(`\n  请复制模板并填写:\n  cp ${path.join(SCRIPT_DIR, '..', 'config', 'sync.yaml.example')} ${CONFIG_FILE}`);
    process.exit(1);
  }
  ok(`配置文件: ${CONFIG_FILE}`);

  let config;
  try { config = yaml.load(fs.readFileSync(CONFIG_FILE, 'utf8')); }
  catch (e) { fail(`配置解析失败: ${e.message}`); process.exit(1); }

  const instanceName = config?.instance?.name;
  const agentName    = config?.agent?.name || 'main';
  const githubRepo   = config?.github?.repo;
  const githubToken  = config?.github?.token;

  instanceName ? ok(`实例名: ${instanceName}`) : fail('instance.name 未配置');
  ok(`Agent: ${agentName}`);
  githubRepo   ? ok(`GitHub 仓库: ${githubRepo}`) : fail('github.repo 未配置');
  githubToken  ? ok(`GitHub Token: ${githubToken.slice(0, 8)}...`) : fail('github.token 未配置');

  // Workspace
  const ws = fs.existsSync(path.join(openclawRoot, 'agents', agentName, 'workspace'))
    ? path.join(openclawRoot, 'agents', agentName, 'workspace')
    : path.join(openclawRoot, 'workspace');
  fs.existsSync(ws) ? ok(`Workspace: ${ws}`) : fail(`Workspace 不存在: ${ws}`);

  // Core files
  console.log('\n--- 核心文件 ---');
  for (const f of ['MEMORY.md', 'AGENTS.md', 'SOUL.md', 'USER.md', 'TOOLS.md']) {
    const fp = path.join(ws, f);
    fs.existsSync(fp) ? ok(f) : warn(`${f} 不存在`);
  }

  // keywords.md
  const kwFile = path.join(ws, 'memory', 'keywords.md');
  fs.existsSync(kwFile) ? ok('memory/keywords.md') : warn('memory/keywords.md 不存在（Agent 关键词触发不可用）');

  // Node modules
  console.log('\n--- Node.js 依赖 ---');
  const nmDir = path.join(SCRIPT_DIR, 'node_modules');
  fs.existsSync(nmDir) ? ok('node_modules 已安装') : warn('node_modules 不存在，请运行: npm install');

  // GitHub token validation
  if (githubToken && githubRepo) {
    console.log('\n--- GitHub 连通性 ---');
    const result = await checkGitHubToken(githubToken, githubRepo);
    result === 'ok' ? ok('GitHub Token 有效，仓库可访问') : fail(`GitHub 检查失败: ${result}`);
  }

  console.log('\n========== 检查完成 ==========\n');
}

main().catch(e => { console.error('FATAL:', e.message); process.exit(1); });
