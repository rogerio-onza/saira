// Stops the R process and its workers. shinyelectron signals only the R process
// on Linux and blocks the main process on Windows. The promise settles when the
// tree is gone, because app.exit() in main.js drops a timer that is still pending.
const { execFile } = require('child_process');

const POLL_MS = 50;
const FORCE_AFTER_MS = 500;
const GIVE_UP_AFTER_MS = 5000;

// A second request for one process gets the promise of the first request.
const requested = new WeakMap();

function running(proc) {
  return proc.exitCode === null && proc.signalCode === null;
}

function groupAlive(pgid) {
  try {
    process.kill(-pgid, 0);
    return true;
  } catch (err) {
    return err.code === 'EPERM';
  }
}

function signalTree(proc, signal) {
  try {
    process.kill(-proc.pid, signal);
  } catch {
    // The process has no group of its own. Skip it once it has exited: its PID
    // may already belong to another process.
    if (running(proc)) proc.kill(signal);
  }
}

// A worker can stay after the R process exits, so the group decides, not the
// R process. A group with a member keeps its ID, so the ID stays safe to signal.
function stopGroup(proc) {
  signalTree(proc, 'SIGTERM');
  const started = Date.now();
  return new Promise((resolve) => {
    let forced = false;
    const timer = setInterval(() => {
      const elapsed = Date.now() - started;
      if ((!running(proc) && !groupAlive(proc.pid)) || elapsed >= GIVE_UP_AFTER_MS) {
        clearInterval(timer);
        resolve();
      } else if (!forced && elapsed >= FORCE_AFTER_MS) {
        forced = true;
        signalTree(proc, 'SIGKILL');
      }
    }, POLL_MS);
  });
}

function stopWindowsTree(proc) {
  return new Promise((resolve) => {
    execFile('taskkill', ['/pid', String(proc.pid), '/f', '/t'],
      { windowsHide: true, timeout: GIVE_UP_AFTER_MS }, (err) => {
        if (err) console.error('Error killing process:', err.message);
        resolve();
      });
  });
}

function killProcessTree(proc) {
  if (!proc || !proc.pid) return Promise.resolve();
  if (!requested.has(proc)) {
    requested.set(proc, process.platform === 'win32' ? stopWindowsTree(proc) : stopGroup(proc));
  }
  return requested.get(proc);
}

module.exports = { killProcessTree };
