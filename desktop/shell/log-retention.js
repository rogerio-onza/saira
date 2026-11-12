// Removes old daily logs of the desktop shell. The name gives the age, because
// a copy or a backup restore changes the file time.
const fs = require('fs');
const path = require('path');

// A full daily log continues in app-<date>.log.001, so the sort keeps the age order.
const LOG_NAME = /^app-(\d{4}-\d{2}-\d{2})\.log(\.\d{3})?$/;
const MAX_AGE_DAYS = 30;
const MAX_TOTAL_BYTES = 50 * 1024 * 1024;
const DAY_MS = 24 * 60 * 60 * 1000;

function pruneLogs(dir, now = Date.now()) {
  const newestFirst = fs.readdirSync(dir).filter((name) => LOG_NAME.test(name)).sort().reverse();
  let total = 0;
  newestFirst.forEach((name, index) => {
    const file = path.join(dir, name);
    total += fs.statSync(file).size;
    const age = now - Date.parse(LOG_NAME.exec(name)[1]);
    // The newest log stays, as it can be the log of this session.
    if (index > 0 && (age > MAX_AGE_DAYS * DAY_MS || total > MAX_TOTAL_BYTES)) fs.rmSync(file, { force: true });
  });
}

module.exports = { pruneLogs };
