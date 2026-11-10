// Checks the shell modules that run without Electron.
// Usage: node shell-check.mjs <module with killProcessTree> <log-retention.js> <log-writer.js>
// The first path is shell/process-tree.js or backends/utils.js of a build.
import { spawn } from 'node:child_process';
import { createRequire } from 'node:module';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const require = createRequire(import.meta.url);
const { killProcessTree } = require(path.resolve(process.argv[2]));
const { pruneLogs } = require(path.resolve(process.argv[3]));
const { createLogWriter } = require(path.resolve(process.argv[4]));
// asar-path.js is copied next to log-retention.js, in the shell and in a build.
const { unpackedRoot } = require(path.join(path.dirname(path.resolve(process.argv[3])), 'asar-path.js'));

let failed = 0;
function check(name, ok, detail = '') {
  console.log(`${ok ? 'PASS' : 'FAIL'} ${name} ${detail}`);
  if (!ok) failed += 1;
}

function alive(pid) {
  try { process.kill(pid, 0); return true; } catch { return false; }
}

// The leader exits on SIGTERM. Its child ignores SIGTERM, as a busy worker can.
const CHILD = "process.on('SIGTERM', () => {}); console.log(process.pid); setInterval(() => {}, 1000);";
const LEADER = `
  const { spawn } = require('node:child_process');
  spawn(process.execPath, ['-e', ${JSON.stringify(CHILD)}], { stdio: 'inherit' });
  setInterval(() => {}, 1000);
`;

const leader = spawn(process.execPath, ['-e', LEADER], {
  stdio: ['ignore', 'pipe', 'inherit'],
  detached: process.platform !== 'win32',
});
const childPid = await new Promise((resolve) => {
  leader.stdout.once('data', (chunk) => resolve(Number(String(chunk).trim())));
});
// The child starts its signal handler before it prints its PID.
await new Promise((resolve) => setTimeout(resolve, 200));

// The longest gap between timers shows a call that blocks the main process.
let last = Date.now();
let longestGap = 0;
const ticker = setInterval(() => {
  longestGap = Math.max(longestGap, Date.now() - last);
  last = Date.now();
}, 10);
const started = Date.now();
await killProcessTree(leader);
const elapsed = Date.now() - started;
clearInterval(ticker);

// main.js calls app.exit(0) at this point.
check('leader gone when the promise settles', !alive(leader.pid));
check('child gone when the promise settles', !alive(childPid), `${elapsed} ms`);
check('main process not blocked', longestGap < 250, `longest gap ${longestGap} ms`);
check('second request gets the same promise', killProcessTree(leader) === killProcessTree(leader));
if (alive(childPid)) process.kill(childPid, 'SIGKILL');

const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'saira-logs-'));
const now = Date.parse('2026-11-02T12:00:00Z');
const write = (name, bytes = 10) => fs.writeFileSync(path.join(dir, name), Buffer.alloc(bytes));
write('app-2026-11-02.log');
write('app-2026-10-04.log');
write('app-2026-10-02.log');
write('app-2020-01-01.log');
write('notes.txt');
write('app-old.log');
pruneLogs(dir, now);
check('logs by age: 30 days stay, older logs go, other files stay',
  fs.readdirSync(dir).sort().join() === 'app-2026-10-04.log,app-2026-11-02.log,app-old.log,notes.txt');

write('app-2026-11-01.log', 30 * 1024 * 1024);
write('app-2026-10-31.log', 30 * 1024 * 1024);
pruneLogs(dir, now);
check('logs by size: an older log goes over the limit',
  !fs.existsSync(path.join(dir, 'app-2026-10-31.log')) && !fs.existsSync(path.join(dir, 'app-2026-10-04.log')) &&
  fs.existsSync(path.join(dir, 'app-2026-11-01.log')));

const onlyDir = fs.mkdtempSync(path.join(os.tmpdir(), 'saira-logs-'));
fs.writeFileSync(path.join(onlyDir, 'app-2020-01-01.log'), Buffer.alloc(60 * 1024 * 1024));
pruneLogs(onlyDir, now);
check('the newest log stays', fs.existsSync(path.join(onlyDir, 'app-2020-01-01.log')));
fs.rmSync(dir, { recursive: true, force: true });
fs.rmSync(onlyDir, { recursive: true, force: true });

const flush = () => new Promise((resolve) => setTimeout(resolve, 100));
const writerDir = fs.mkdtempSync(path.join(os.tmpdir(), 'saira-logs-'));
let clock = Date.parse('2026-11-02T23:59:00Z');
const writer = createLogWriter(writerDir, { maxBytes: 10, now: () => clock });
writer.write('0123456789');
await flush();
writer.write('next part');
await flush();
clock = Date.parse('2026-11-03T00:01:00Z');
writer.write('next day');
await flush();
check('log writer: a full log gets a next part, a new day gets a new log',
  fs.readdirSync(writerDir).sort().join() === 'app-2026-11-02.log,app-2026-11-02.log.001,app-2026-11-03.log');
const restart = createLogWriter(writerDir, { maxBytes: 100, now: () => clock });
restart.write('after restart');
await flush();
check('log writer: a restart on the same day continues the log',
  fs.readFileSync(path.join(writerDir, 'app-2026-11-03.log'), 'utf8') === 'next dayafter restart');

// Retention removes the first parts of the day, so a restart must not use their numbers again.
const PART_BYTES = 10 * 1024 * 1024;
const gapDir = fs.mkdtempSync(path.join(os.tmpdir(), 'saira-logs-'));
const gapPart = (suffix) => path.join(gapDir, `app-2026-11-03.log${suffix}`);
for (const suffix of ['', '.001', '.002', '.003', '.004', '.005', '.006']) {
  fs.writeFileSync(gapPart(suffix), Buffer.alloc(PART_BYTES));
}
pruneLogs(gapDir, clock);
const afterGap = createLogWriter(gapDir, { now: () => clock });
afterGap.write('new session');
await flush();
afterGap.write('x'.repeat(PART_BYTES));
await flush();
afterGap.write('next part');
await flush();
check('log writer: a restart after retention keeps the new log and removes the old part',
  fs.existsSync(gapPart('.007')) && fs.readFileSync(gapPart('.007'), 'utf8').startsWith('new session') &&
  !fs.existsSync(gapPart('.002')) && !fs.existsSync(gapPart('')));
fs.rmSync(gapDir, { recursive: true, force: true });

const part = path.join(writerDir, 'app-2026-10-30.log.001');
fs.writeFileSync(part, 'x');
pruneLogs(writerDir, Date.parse('2027-01-01T00:00:00Z'));
check('logs by age: an old part goes', !fs.existsSync(part));

// The folder cannot exist, because a file has its name.
const blocked = path.join(writerDir, 'blocked');
fs.writeFileSync(blocked, '');
const consoleError = console.error;
const reported = [];
console.error = (...args) => reported.push(args.join(' '));
createLogWriter(path.join(blocked, 'logs')).write('line');
await flush();
const failing = createLogWriter(writerDir, { now: () => clock });
const stream = fs.createWriteStream;
fs.createWriteStream = () => {
  const fake = stream(path.join(writerDir, 'fake.tmp'));
  setImmediate(() => fake.emit('error', Object.assign(new Error('disk full'), { code: 'ENOSPC' })));
  return fake;
};
failing.write('line');
await flush();
failing.write('after the error');
fs.createWriteStream = stream;
console.error = consoleError;
check('log writer: file errors stop the file log and do not throw', reported.length === 2,
  reported.join(' | '));
fs.rmSync(writerDir, { recursive: true, force: true });

// Only the last component is the archive, not a user folder named app.asar-tests.
const installed = 'C:\\Users\\Pessoa\\app.asar-tests\\Saira\\resources\\app.asar';
check('asar path: only the archive component changes',
  unpackedRoot(installed, path.win32) === 'C:\\Users\\Pessoa\\app.asar-tests\\Saira\\resources\\app.asar.unpacked',
  unpackedRoot(installed, path.win32));
check('asar path: a development folder stays', unpackedRoot('/home/dev/app.asar-tests/shell') === '/home/dev/app.asar-tests/shell');

console.log(failed ? `${failed} check(s) failed` : 'All checks passed');
process.exit(failed ? 1 : 0);
