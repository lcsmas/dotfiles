#!/usr/bin/env node
// lazy-mcp — start a stdio MCP server only when an agent actually CALLS it.
//
//   lazy-mcp.mjs -- <server command> [args...]
//
// Until the first tool call, the handshake (initialize, tools/prompts/resources
// lists, ping) is answered from a cache recorded on a previous real run, so an
// agent that never uses the server never spawns it. Cache miss → the server is
// spawned eagerly once and its answers are recorded for next time.
// Cache: ${XDG_CACHE_HOME:-~/.cache}/lazy-mcp/<hash of command+args>.json

import { spawn } from 'node:child_process';
import { createHash } from 'node:crypto';
import { mkdirSync, readFileSync, renameSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { createInterface } from 'node:readline';

const sep = process.argv.indexOf('--');
const cmd = sep === -1 ? process.argv.slice(2) : process.argv.slice(sep + 1);
if (cmd.length === 0) {
  process.stderr.write('usage: lazy-mcp.mjs -- <command> [args...]\n');
  process.exit(2);
}

const CACHED = ['initialize', 'tools/list', 'prompts/list', 'resources/list', 'resources/templates/list'];
const cacheDir = join(process.env.XDG_CACHE_HOME || join(homedir(), '.cache'), 'lazy-mcp');
const cacheFile = join(cacheDir, createHash('sha256').update(JSON.stringify(cmd)).digest('hex').slice(0, 16) + '.json');
const log = (m) => process.env.LAZY_MCP_DEBUG && process.stderr.write(`[lazy-mcp] ${m}\n`);

let cache = null;
try {
  cache = JSON.parse(readFileSync(cacheFile, 'utf8'));
  if (!cache?.results?.initialize || !cache.results['tools/list']) cache = null;
} catch {}
const fresh = { command: cmd, results: {} };
function saveCache() {
  if (!fresh.results.initialize || !fresh.results['tools/list']) return;
  const merged = { command: cmd, savedAt: new Date().toISOString(), results: { ...(cache?.results ?? {}), ...fresh.results } };
  try {
    mkdirSync(cacheDir, { recursive: true });
    const tmp = `${cacheFile}.${process.pid}.tmp`;
    writeFileSync(tmp, JSON.stringify(merged));
    renameSync(tmp, cacheFile);
  } catch (e) {
    log(`cache write failed: ${e.message}`);
  }
}

const out = (msg) => process.stdout.write(JSON.stringify(msg) + '\n');

let child = null;
let state = 'lazy'; // lazy → spawning → live
let clientInit = null; // the client's initialize params, replayed to the real server
const queue = []; // client messages held until the real server is initialized
const pendingList = new Map(); // client request id → cached method, to record answers
const INIT_ID = '__lazy_mcp_init__';
const REFRESH_ID = '__lazy_mcp_tools__';

function startChild() {
  if (child) return;
  state = 'spawning';
  log(`spawning: ${cmd.join(' ')}`);
  child = spawn(cmd[0], cmd.slice(1), { stdio: ['pipe', 'pipe', 'inherit'] });
  child.on('error', (e) => {
    process.stderr.write(`[lazy-mcp] failed to start ${cmd[0]}: ${e.message}\n`);
    process.exit(1);
  });
  child.on('exit', (code, sig) => process.exit(code ?? (sig ? 1 : 0)));
  createInterface({ input: child.stdout }).on('line', onServerLine);
  send({ jsonrpc: '2.0', id: INIT_ID, method: 'initialize', params: clientInit ?? defaultInit() });
}

function defaultInit() {
  return { protocolVersion: '2025-06-18', capabilities: {}, clientInfo: { name: 'lazy-mcp', version: '1' } };
}

const send = (msg) => child.stdin.write(JSON.stringify(msg) + '\n');

function onServerLine(line) {
  let msg;
  try {
    msg = JSON.parse(line);
  } catch {
    return process.stdout.write(line + '\n');
  }
  if (msg.id === INIT_ID) {
    if (msg.result) fresh.results.initialize = msg.result;
    send({ jsonrpc: '2.0', method: 'notifications/initialized' });
    state = 'live';
    for (const m of queue.splice(0)) forward(m);
    if (cache) send({ jsonrpc: '2.0', id: REFRESH_ID, method: 'tools/list', params: {} });
    return;
  }
  if (msg.id === REFRESH_ID) {
    if (msg.result) {
      fresh.results['tools/list'] = msg.result;
      if (JSON.stringify(msg.result) !== JSON.stringify(cache?.results['tools/list'])) {
        out({ jsonrpc: '2.0', method: 'notifications/tools/list_changed' });
      }
      saveCache();
    }
    return;
  }
  if (msg.id !== undefined && !msg.method && pendingList.has(msg.id)) {
    const method = pendingList.get(msg.id);
    pendingList.delete(msg.id);
    if (msg.result) {
      fresh.results[method] = msg.result;
      saveCache();
    }
  }
  out(msg);
}

function forward(msg) {
  if (msg.method === 'initialize') {
    // the real server was already initialized with these params; answer from its result
    return out({ jsonrpc: '2.0', id: msg.id, result: fresh.results.initialize });
  }
  if (msg.method === 'notifications/initialized') return;
  if (msg.id !== undefined && CACHED.includes(msg.method)) pendingList.set(msg.id, msg.method);
  send(msg);
}

function onClientLine(line) {
  if (!line.trim()) return;
  let msg;
  try {
    msg = JSON.parse(line);
  } catch {
    return;
  }
  if (msg.method === 'initialize') clientInit = msg.params ?? null;

  if (state === 'live') return forward(msg);
  const isResponse = msg.id !== undefined && !msg.method;
  if (state === 'spawning') {
    if (isResponse) return send(msg); // answer to a server→client request during init
    return queue.push(msg);
  }
  // lazy: answer what the cache can, spawn on anything else
  if (cache) {
    if (msg.method === 'initialize') return out({ jsonrpc: '2.0', id: msg.id, result: cache.results.initialize });
    if (msg.method === 'notifications/initialized') return;
    if (msg.method === 'ping') return out({ jsonrpc: '2.0', id: msg.id, result: {} });
    if (msg.id !== undefined && CACHED.includes(msg.method) && cache.results[msg.method]) {
      return out({ jsonrpc: '2.0', id: msg.id, result: cache.results[msg.method] });
    }
    if (msg.method?.startsWith('notifications/')) return; // nothing to notify yet
  }
  queue.push(msg);
  startChild();
}

createInterface({ input: process.stdin }).on('line', onClientLine).on('close', () => {
  if (child) child.stdin.end();
  else process.exit(0);
});
