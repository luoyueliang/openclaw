#!/usr/bin/env node
// keyword-history.js — 一次性历史会话关键词扫描
//
// 用途：首次安装时，扫描全部历史会话，把包含关键词的消息补录到
//       memory/keyword-YYYY-MM-DD.md。日常运行由 Agent 自身处理，
//       无需此脚本持续执行。
//
// 用法：
//   node keyword-history.js              # 增量扫描（跳过已处理的行）
//   node keyword-history.js --reset      # 重置状态，重新扫描全部
//   node keyword-history.js --days=7     # 只扫描最近 7 天的会话
'use strict';

const fs       = require('fs');
const path     = require('path');
const os       = require('os');
const readline = require('readline');
const yaml     = require('js-yaml');

const SCRIPT_DIR  = __dirname;
const CONFIG_FILE = path.join(SCRIPT_DIR, '..', 'config', 'sync.yaml');
const STATE_FILE  = path.join(SCRIPT_DIR, '..', 'state', 'keyword-history-state.json');

function log(msg) {
  process.stdout.write(`[${new Date().toISOString().replace('T', ' ').slice(0, 19)}] ${msg}\n`);
}

// ─── 路径检测 ─────────────────────────────────────────────
function detectOpenclawRoot() {
  const candidates = os.platform() === 'darwin'
    ? [path.join(os.homedir(), '.openclaw'),
       path.join(os.homedir(), 'Library', 'Application Support', 'openclaw')]
    : [path.join(os.homedir(), '.openclaw'), '/root/.openclaw'];
  return candidates.find(p => fs.existsSync(p)) || null;
}

// ─── 状态持久化 ───────────────────────────────────────────
function loadState() {
  try { return JSON.parse(fs.readFileSync(STATE_FILE, 'utf8')); } catch { return {}; }
}
function saveState(state) {
  fs.mkdirSync(path.dirname(STATE_FILE), { recursive: true });
  fs.writeFileSync(STATE_FILE, JSON.stringify(state, null, 2));
}

// ─── 关键词加载 ───────────────────────────────────────────
function loadKeywords(keywordsFile) {
  if (!fs.existsSync(keywordsFile)) return [];
  return fs.readFileSync(keywordsFile, 'utf8').split('\n')
    .filter(l => /^-\s+\S/.test(l))
    .map(l => l.replace(/^-\s+/, '').trim())
    .filter(Boolean);
}

// ─── JSONL 解析：提取用户文本 ─────────────────────────────
function extractUserText(line) {
  try {
    const d = JSON.parse(line);
    if (d.type !== 'message') return null;
    const msg = d.message || {};
    if (msg.role !== 'user') return null;
    const content = msg.content;
    if (Array.isArray(content)) {
      return content.filter(c => c.type === 'text').map(c => c.text || '').join('\n') || null;
    }
    return typeof content === 'string' ? content : null;
  } catch { return null; }
}

// ─── 清洗 Feishu/Telegram 元数据前缀 ─────────────────────
function cleanMessage(text) {
  // 去除 ```...``` 代码块（JSON 元数据）
  let clean = text.replace(/```[\s\S]*?```/g, '');
  // 去除元数据标题行
  clean = clean.replace(/^(Conversation info|Sender|History)\s+\(untrusted metadata\):.*$/gm, '');
  // 保留非空行，最多 20 行
  return clean.split('\n').map(l => l.trimEnd()).filter(l => l.trim()).slice(0, 20).join('\n');
}

// ─── 写入关键词记忆 ───────────────────────────────────────
function writeKeywordMemory(memoryDir, keyword, message, fileDate) {
  const clean = cleanMessage(message);
  if (!clean) return;

  const date = fileDate.toISOString().slice(0, 10);
  const time = fileDate.toISOString().replace('T', ' ').slice(11, 19);
  const memFile = path.join(memoryDir, `keyword-${date}.md`);

  fs.mkdirSync(memoryDir, { recursive: true });
  fs.appendFileSync(memFile, `\n### [${time}] 关键词: ${keyword}\n\n${clean}\n\n---\n`, 'utf8');
}

// ─── 扫描单个会话文件 ─────────────────────────────────────
async function scanFile(sessionFile, keywords, memoryDir, state) {
  const fname = path.basename(sessionFile);
  const startLine = state[fname] || 0;

  // 统计总行数
  let totalLines = 0;
  await new Promise(resolve => {
    const rl = readline.createInterface({ input: fs.createReadStream(sessionFile) });
    rl.on('line', () => totalLines++);
    rl.on('close', resolve);
  });

  if (totalLines <= startLine) return 0; // 无新行

  const fileMtime = fs.statSync(sessionFile).mtime;
  let lineNum = 0;
  let hits = 0;

  const rl = readline.createInterface({
    input: fs.createReadStream(sessionFile),
    crlfDelay: Infinity,
  });

  for await (const line of rl) {
    lineNum++;
    if (lineNum <= startLine || !line.trim()) continue;

    const text = extractUserText(line);
    if (!text) continue;

    for (const kw of keywords) {
      if (text.includes(kw)) {
        writeKeywordMemory(memoryDir, kw, text, fileMtime);
        hits++;
        break; // 一条消息只记录一次
      }
    }
  }

  state[fname] = totalLines;
  return hits;
}

// ─── 主流程 ───────────────────────────────────────────────
async function main() {
  const args     = process.argv.slice(2);
  const reset    = args.includes('--reset');
  const daysArg  = args.find(a => a.startsWith('--days='));
  const days     = daysArg ? parseInt(daysArg.split('=')[1], 10) : 0;

  log('========== 关键词历史扫描开始 ==========');
  if (reset) log('⚠ --reset 模式：重新扫描全部历史');
  log(`扫描范围: ${days > 0 ? `最近 ${days} 天` : '全部历史'}`);

  const openclawRoot = detectOpenclawRoot();
  if (!openclawRoot) { log('✗ 未找到 OpenClaw 根目录'); process.exit(1); }

  let config;
  try { config = yaml.load(fs.readFileSync(CONFIG_FILE, 'utf8')); }
  catch (e) { log(`✗ 配置错误: ${e.message}`); process.exit(1); }

  const agentName   = config?.agent?.name || 'main';
  const workspace   = fs.existsSync(path.join(openclawRoot, 'agents', agentName, 'workspace'))
    ? path.join(openclawRoot, 'agents', agentName, 'workspace')
    : path.join(openclawRoot, 'workspace');
  const sessionsDir = fs.existsSync(path.join(openclawRoot, 'agents', agentName, 'sessions'))
    ? path.join(openclawRoot, 'agents', agentName, 'sessions')
    : path.join(openclawRoot, 'sessions');

  const keywordsFile = path.join(workspace, 'memory', 'keywords.md');
  const memoryDir    = path.join(workspace, 'memory');

  const keywords = loadKeywords(keywordsFile);
  if (keywords.length === 0) {
    log(`✗ 未找到关键词，请检查: ${keywordsFile}`);
    process.exit(1);
  }
  log(`加载关键词: ${keywords.length} 个 (${keywords.slice(0, 5).join(', ')}...)`);

  if (!fs.existsSync(sessionsDir)) {
    log(`⚠ sessions 目录不存在: ${sessionsDir}`);
    process.exit(0);
  }

  const state  = reset ? {} : loadState();
  const cutoff = days > 0 ? Date.now() - days * 86400 * 1000 : 0;

  const files = fs.readdirSync(sessionsDir)
    .filter(f => f.endsWith('.jsonl') && !f.includes('.reset.'))
    .map(f => path.join(sessionsDir, f))
    .filter(f => cutoff === 0 || fs.statSync(f).mtimeMs >= cutoff)
    .sort((a, b) => fs.statSync(a).mtimeMs - fs.statSync(b).mtimeMs); // 旧→新

  log(`找到 ${files.length} 个 session 文件`);

  let totalHits = 0;
  for (const f of files) {
    const hits = await scanFile(f, keywords, memoryDir, state);
    if (hits > 0) log(`  ${path.basename(f)}: 命中 ${hits} 条`);
    totalHits += hits;
  }

  saveState(state);

  log(`扫描完成: 命中 ${totalHits} 条，已写入 memory/keyword-YYYY-MM-DD.md`);
  if (totalHits > 0) log('提示: 运行 sync.js 可将关键词记忆推送到 GitHub');
  log('========== 扫描完成 ==========');
}

main().catch(e => { console.error('FATAL:', e.message); process.exit(1); });
