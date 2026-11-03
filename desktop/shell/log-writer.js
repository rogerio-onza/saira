// Writes the daily log of the desktop shell, in parts of limited size. The log is
// best-effort: a file error stops the file log, and the app continues.
const fs = require('fs');
const path = require('path');
const { pruneLogs } = require('./log-retention.js');

const MAX_FILE_BYTES = 10 * 1024 * 1024;

function logFileName(day, part) {
  return `app-${day}.log${part ? `.${String(part).padStart(3, '0')}` : ''}`;
}

function createLogWriter(dir, { maxBytes = MAX_FILE_BYTES, now = Date.now } = {}) {
  let stream = null;
  let stopped = false;
  let day = '';
  let part = 0;
  let bytes = 0;

  function stop(err) {
    stopped = true;
    stream = null;
    console.error('File logging stopped:', (err && (err.code || err.message)) || err);
  }

  function sizeOf(file) {
    return fs.existsSync(file) ? fs.statSync(file).size : 0;
  }

  function lastPart(forDay) {
    const first = logFileName(forDay, 0);
    const parts = fs.readdirSync(dir).filter((name) => name.startsWith(`${first}.`))
      .map((name) => Number(name.slice(first.length + 1)));
    return Math.max(0, ...parts.filter(Number.isInteger));
  }

  // A restart on the same day continues the newest part. Retention removes the
  // first parts, and the age order fails if a new log uses their numbers again.
  function open(nextDay, nextPart) {
    if (stream) stream.end();
    fs.mkdirSync(dir, { recursive: true });
    day = nextDay;
    part = nextPart ?? lastPart(nextDay);
    while (sizeOf(path.join(dir, logFileName(day, part))) >= maxBytes) part += 1;
    const file = path.join(dir, logFileName(day, part));
    bytes = sizeOf(file);
    const opened = fs.createWriteStream(file, { flags: 'a' });
    // A stream reports its errors as events, after the try/catch of write() ended.
    opened.on('error', (err) => { if (stream === opened) stop(err); });
    stream = opened;
    pruneLogs(dir, now());
  }

  function write(line) {
    if (stopped) return;
    try {
      const today = new Date(now()).toISOString().slice(0, 10);
      if (today !== day) open(today);
      else if (bytes >= maxBytes) open(day, part + 1);
      bytes += Buffer.byteLength(line);
      stream.write(line);
    } catch (err) {
      stop(err);
    }
  }

  return { write };
}

module.exports = { createLogWriter };
