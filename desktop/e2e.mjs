// End-to-end check of the packaged Saíra desktop app (win-unpacked or linux-unpacked, no install).
// It drives the renderer over CDP (--remote-debugging-port) and reads the main
// process over the Node inspector (--inspect). No npm packages are necessary.
import { spawn, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import { createRequire } from 'node:module';
import path from 'node:path';

// Usage: node e2e.mjs <unpacked executable> <csv> [work folder]
// The CSV must pass the export gate (see LOCAL-TEST.md). The work folder holds
// LOCALAPPDATA, the downloads, the shell log and results.json.
// DOM.setFileInputFiles with a relative path makes Chromium kill the renderer
// (bad IPC message, reason 2), so both paths are absolute.
const [EXE, CSV] = process.argv.slice(2, 4).map((p) => p && path.resolve(p));
const WORK = process.argv[4] || path.join(path.dirname(CSV || '.'), `e2e-${new Date().toISOString().replace(/\D/g, '').slice(0, 14)}`);
const DOWNLOADS = path.join(WORK, 'downloads');
const LOCALAPPDATA = path.join(WORK, 'localappdata');
const RENDERER_PORT = 9333;
const MAIN_PORT = 9339;
const APP_ORIGIN = 'http://127.0.0.1:38838';
// The checks compare with the strings that the shell shows.
const STRINGS = createRequire(import.meta.url)('./shell/i18n.js');
const PT = STRINGS['pt-BR'];
const EN = STRINGS.en;

const results = [];
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const t0 = Date.now();
const elapsed = () => ((Date.now() - t0) / 1000).toFixed(1);

function record(name, ok, detail = '') {
  results.push({ name, ok, detail });
  console.log(`${ok ? 'PASS' : 'FAIL'} [${elapsed()} s] ${name}${detail ? ': ' + detail : ''}`);
}

async function waitFor(fn, { timeout = 30000, interval = 250, what = 'condition' } = {}) {
  const end = Date.now() + timeout;
  let last;
  while (Date.now() < end) {
    try {
      last = await fn();
      if (last) return last;
    } catch (err) {
      last = err;
    }
    await sleep(interval);
  }
  throw new Error(`Timeout (${timeout} ms) waiting for ${what}. Last: ${last && last.message ? last.message : JSON.stringify(last)}`);
}

class CDP {
  constructor(url) {
    this.url = url;
    this.nextId = 0;
    this.pending = new Map();
    this.closed = false;
  }
  open() {
    return new Promise((resolve, reject) => {
      this.ws = new WebSocket(this.url);
      this.ws.onopen = () => resolve(this);
      this.ws.onerror = (e) => reject(new Error(`WebSocket error ${this.url}: ${e.message || e.type}`));
      this.ws.onclose = () => {
        this.closed = true;
        for (const { reject: rej } of this.pending.values()) rej(new Error('CDP closed'));
        this.pending.clear();
      };
      this.ws.onmessage = (msg) => {
        const data = JSON.parse(msg.data);
        if (data.id && this.pending.has(data.id)) {
          const { resolve: res, reject: rej } = this.pending.get(data.id);
          this.pending.delete(data.id);
          if (data.error) rej(new Error(data.error.message)); else res(data.result);
        }
      };
    });
  }
  send(method, params = {}) {
    if (this.closed) return Promise.reject(new Error('CDP closed'));
    const id = ++this.nextId;
    this.ws.send(JSON.stringify({ id, method, params }));
    return new Promise((resolve, reject) => this.pending.set(id, { resolve, reject }));
  }
  async eval(expression) {
    const r = await this.send('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
    if (r.exceptionDetails) {
      throw new Error((r.exceptionDetails.exception && r.exceptionDetails.exception.description) || r.exceptionDetails.text);
    }
    return r.result.value;
  }
}

async function targets(port) {
  const res = await fetch(`http://127.0.0.1:${port}/json/list`);
  return res.json();
}

let page = null;
let child = null;
async function renderer() {
  if (page && !page.closed) return page;
  const list = await targets(RENDERER_PORT);
  const target = list.find((t) => t.type === 'page' && t.url.startsWith(APP_ORIGIN)) ||
    list.find((t) => t.type === 'page');
  if (!target) throw new Error('No page target');
  page = await new CDP(target.webSocketDebuggerUrl).open();
  return page;
}
const js = async (expr) => (await renderer()).eval(expr);

const idle = `(function () {
  return !!(window.Shiny && Shiny.shinyapp && Shiny.shinyapp.isConnected()) &&
    !document.documentElement.classList.contains('shiny-busy');
})()`;

// The names module polls every 1.2 s while a BR catalog update runs, so a quiet window must be shorter.
async function waitIdle(timeout = 60000, quietMs = 800) {
  let quietSince = null;
  await waitFor(async () => {
    if (await js(idle)) {
      quietSince = quietSince || Date.now();
      return Date.now() - quietSince >= quietMs;
    }
    quietSince = null;
    return false;
  }, { timeout, what: 'Shiny idle' }).catch(async (err) => {
    const why = await js(`(function () {
      return {
        connected: !!(window.Shiny && Shiny.shinyapp && Shiny.shinyapp.isConnected()),
        busy: document.documentElement.classList.contains('shiny-busy'),
        recalculating: Array.from(document.querySelectorAll('.recalculating')).map(function (e) { return e.id; }),
        tab: (document.querySelector('.navbar .nav-link.active') || {}).textContent
      };
    })()`).catch((e) => String(e));
    throw new Error(`${err.message} State: ${JSON.stringify(why)}`);
  });
}

async function clickSel(selector) {
  const ok = await js(`(function () {
    var el = document.querySelector(${JSON.stringify(selector)});
    if (!el) return false;
    el.scrollIntoView({ block: 'center' });
    el.click();
    return true;
  })()`);
  if (!ok) throw new Error(`No element ${selector}`);
}

// The packaged exe ignores --inspect (Electron fuse). The test runs a copy of
// the unpacked folder with that one fuse on, so the shipped exe keeps it off.
async function inspectableCopy(exe) {
  const unpacked = path.dirname(exe);
  const project = path.resolve(unpacked, '..', '..');
  const copy = path.join(WORK, path.basename(unpacked));
  fs.cpSync(unpacked, copy, { recursive: true });
  const fuses = createRequire(path.join(project, 'package.json'))('@electron/fuses');
  const wire = await fuses.getCurrentFuseWire(exe);
  // 49 is '1', FuseState.ENABLE. The package index does not export FuseState.
  const state = (name) => (wire[fuses.FuseV1Options[name]] === 49 ? 'on' : 'off');
  const names = ['RunAsNode', 'EnableNodeOptionsEnvironmentVariable', 'EnableNodeCliInspectArguments',
    'EnableEmbeddedAsarIntegrityValidation', 'OnlyLoadAppFromAsar'];
  const shipped = names.map((name) => `${name} ${state(name)}`);
  record('shipped exe fuses', shipped.join(' ') === ['off', 'off', 'off', 'on', 'on'].map((s, i) => `${names[i]} ${s}`).join(' '),
    shipped.join(', '));
  const target = path.join(copy, path.basename(exe));
  await fuses.flipFuses(target, {
    version: fuses.FuseVersion.V1,
    [fuses.FuseV1Options.EnableNodeCliInspectArguments]: true
  });
  return target;
}

// The R processes that run from one unpacked folder, workers too.
function rProcesses(folder) {
  if (process.platform === 'win32') {
    const script = `Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.Name -match '^(R|Rscript|Rterm|cmd)\\.exe$' -and $_.CommandLine.Contains('${folder}') } | ForEach-Object { $_.ProcessId }`;
    return spawnSync('powershell', ['-NoProfile', '-Command', script], { encoding: 'utf8' }).stdout.split(/\s+/).filter(Boolean);
  }
  return spawnSync('pgrep', ['-f', `${folder}.*portable-r`], { encoding: 'utf8' }).stdout.split(/\s+/).filter(Boolean);
}

// A hard kill gives the shell no time to stop R, so R has to see that the shell left.
async function hardKillCheck(exe, env) {
  const folder = path.dirname(exe);
  const launched = spawn(exe, [`--remote-debugging-port=${RENDERER_PORT}`], { env, stdio: 'ignore' });
  await waitFor(async () => (await targets(RENDERER_PORT)).some((t) => t.type === 'page' && t.url.startsWith(APP_ORIGIN)),
    { timeout: 240000, interval: 200, what: 'app URL after a restart' });
  const before = rProcesses(folder);
  if (process.platform === 'win32') spawnSync('taskkill', ['/PID', String(launched.pid), '/F']);
  else launched.kill('SIGKILL');
  const killedAt = Date.now();
  const gone = await waitFor(() => rProcesses(folder).length === 0, { timeout: 30000, interval: 500, what: 'R stops' }).catch(() => false);
  const portFree = await fetch(APP_ORIGIN).then(() => false, () => true);
  record('hard kill of the shell stops R', before.length > 0 && !!gone && portFree,
    `${before.length} R process(es), ${((Date.now() - killedAt) / 1000).toFixed(1)} s`);
  for (const pid of rProcesses(folder)) {
    if (process.platform === 'win32') spawnSync('taskkill', ['/PID', pid, '/T', '/F']);
    else spawnSync('kill', ['-KILL', pid]);
  }
}

async function main() {
  if (!EXE || !fs.existsSync(EXE)) throw new Error(`Missing exe: ${EXE}`);
  if (!CSV || !fs.existsSync(CSV)) throw new Error(`Missing CSV: ${CSV}`);
  for (const dir of [DOWNLOADS, LOCALAPPDATA]) fs.mkdirSync(dir, { recursive: true });
  const exe = await inspectableCopy(EXE);

  const launchedAt = Date.now();
  // On Linux the shell keeps the data in XDG_DATA_HOME and Electron keeps its state in XDG_CONFIG_HOME.
  const env = { ...process.env, LOCALAPPDATA, XDG_DATA_HOME: LOCALAPPDATA, XDG_CONFIG_HOME: path.join(WORK, 'config'),
    SAIRA_DESKTOP_DOWNLOAD_DIR: DOWNLOADS };
  child = spawn(exe, [`--remote-debugging-port=${RENDERER_PORT}`, `--inspect=${MAIN_PORT}`], {
    env,
    stdio: ['ignore', 'pipe', 'pipe']
  });
  const shellLog = fs.createWriteStream(path.join(WORK, 'shell-stdout.log'));
  child.stdout.pipe(shellLog);
  child.stderr.pipe(shellLog);
  let shellOut = '';
  child.stdout.on('data', (chunk) => { shellOut += chunk; });
  let exitedAt = null;
  child.on('exit', (code) => { exitedAt = Date.now(); console.log(`[${elapsed()} s] app exit code ${code}`); });

  // Main process inspector: stub the native dialog and the external browser.
  const mainTarget = await waitFor(async () => (await targets(MAIN_PORT))[0], { timeout: 20000, what: 'main inspector' });
  const main = await new CDP(mainTarget.webSocketDebuggerUrl).open();
  await main.send('Runtime.enable');
  const stubbed = await main.eval(`(function () {
    const e = process.mainModule.require('electron');
    globalThis.__e2e = { external: [], dialogs: [], closeAnswer: 0 };
    e.shell.openExternal = (url) => { globalThis.__e2e.external.push(url); return Promise.resolve(); };
    // closeAnswer is a button label, so the checks do not depend on the button order.
    e.dialog.showMessageBoxSync = (win, opts) => {
      const o = opts || win;
      const a = globalThis.__e2e.closeAnswer;
      globalThis.__e2e.dialogs.push(o);
      return typeof a === 'string' ? (o.buttons || []).indexOf(a) : a;
    };
    return e.shell.openExternal.toString().includes('__e2e') && e.dialog.showMessageBoxSync.toString().includes('__e2e');
  })()`);
  record('main process stubs installed', stubbed);

  // 1. Startup time: the Shiny UI connected in the app window.
  await waitFor(async () => {
    const list = await targets(RENDERER_PORT);
    return list.some((t) => t.type === 'page' && t.url.startsWith(APP_ORIGIN));
  }, { timeout: 240000, interval: 200, what: 'app URL' });
  page = null;
  await waitFor(() => js(`!!document.querySelector("a[data-value='mapping']") && ${idle}`),
    { timeout: 120000, interval: 200, what: 'Shiny connected' });
  const startup = (Date.now() - launchedAt) / 1000;
  record('startup to connected Shiny UI', true, `${startup.toFixed(1)} s`);

  const windows = () => main.eval(`process.mainModule.require('electron').BrowserWindow.getAllWindows().length`);
  const dialogs = () => main.eval('globalThis.__e2e.dialogs');
  const external = () => main.eval('globalThis.__e2e.external');
  const setLang = async (code) => {
    await js(`(function () { $('#lang_switch').val('${code}').trigger('change'); return true; })()`);
    await waitFor(() => js(`document.documentElement.lang.startsWith('${code}')`), { timeout: 15000, what: `app in ${code}` });
    await waitIdle();
  };

  // 2. The window has no menu bar. The hidden menu keeps the edit, zoom and quit keys.
  const menu = await main.eval(`(function () {
    const e = process.mainModule.require('electron');
    const m = e.Menu.getApplicationMenu();
    return { bar: e.BrowserWindow.getAllWindows()[0].isMenuBarVisible(),
      roles: m ? m.items.flatMap((i) => (i.submenu ? i.submenu.items : [i]).map((x) => String(x.role).toLowerCase())) : [] };
  })()`);
  record('menu bar hidden, keys kept', menu.bar === false && ['copy', 'paste', 'zoomin', 'quit'].every((r) => menu.roles.includes(r)),
    `bar ${menu.bar}, roles ${menu.roles.join(' ')}`);
  const bridge = await js('typeof window.lifecycle');
  record('app page has no lifecycle bridge', bridge === 'undefined', `typeof window.lifecycle: ${bridge}`);
  const csp = await js(`fetch(location.href).then((r) => r.headers.get('content-security-policy'))`);
  record('app page has the CSP', /object-src 'none'/.test(csp || ''), csp || 'no header');
  const backendUnpacked = await main.eval(`process.mainModule.require('fs').existsSync(
    process.mainModule.require('path').join(process.resourcesPath, 'app.asar.unpacked', 'backends'))`);
  record('backend code only in app.asar', backendUnpacked === false);

  // 3. Upload the demo CSV.
  const doc = await (await renderer()).send('DOM.getDocument', { depth: 1 });
  const { nodeId } = await (await renderer()).send('DOM.querySelector', { nodeId: doc.root.nodeId, selector: '#upload-file' });
  await (await renderer()).send('DOM.setFileInputFiles', { nodeId, files: [CSV] });
  const uploadStart = Date.now();
  await waitFor(() => js(`(function () {
    var el = document.getElementById('mapping-map_scientificName');
    return !!el && !!el.value;
  })()`), { timeout: 120000, what: 'auto-map after upload' }).catch(() => null);
  await waitIdle(120000);
  const mapped = await js(`(function () { var el = document.getElementById('mapping-map_scientificName'); return el ? el.value : null; })()`);
  record('upload + auto-map', mapped === 'especie', `scientificName <- ${mapped}, ${((Date.now() - uploadStart) / 1000).toFixed(1)} s`);

  // 4. Names: Flora BR and Fauna BR first, then GBIF.
  await clickSel(`a[data-value='validate_names']`);
  await waitFor(() => js(`!!document.getElementById('validate_names-validate')`), { what: 'names tab' });
  const namesStart = Date.now();
  await clickSel('#validate_names-validate');
  const countExpr = `(function () {
    var el = document.querySelector('#validate_names-stream_filter_all .vn-pill-count');
    return el ? el.textContent.trim() : '';
  })()`;
  // The run button spins until the run ends, also while the run waits for a
  // Flora BR or Fauna BR download. The count stays at 0 during that wait.
  const spinning = `!!document.querySelector('#validate_names-validate .ph-spin')`;
  await waitFor(() => js(spinning), { timeout: 15000, what: 'names run start' }).catch(() => false);
  // An error notification closes after 5 s, so the test counts it during the run.
  let namesErrors = 0;
  const ended = await waitFor(async () => {
    namesErrors = Math.max(namesErrors, await js(`document.querySelectorAll('.shiny-notification-error').length`));
    return !(await js(spinning)) && (await js(idle));
  }, { timeout: 600000, interval: 1000, what: 'names run' }).catch(() => false);
  const names = await js(countExpr);
  const namesSecs = ((Date.now() - namesStart) / 1000).toFixed(1);
  const namesWarn = await js(`Array.from(document.querySelectorAll('.shiny-notification-warning')).map((n) => n.textContent.trim()).join(' | ')`);
  record('names run', ended && namesErrors === 0 && Number(names) > 0,
    `${names} names, about ${namesSecs} s${namesErrors ? `, ${namesErrors} errors` : ''}${namesWarn ? ', warning: ' + namesWarn : ''}`);

  // 5. External links leave the app window.
  const before = (await external()).length;
  await js(`window.open('https://rogerio-onza.github.io/saira/', '_blank'); true`);
  await sleep(800);
  const linkInfo = await js(`(function () {
    var a = Array.from(document.querySelectorAll('a[href^="https://"]')).find(function (x) { return x.offsetParent !== null; });
    if (!a) return null;
    var href = a.href;
    a.click();
    return href;
  })()`);
  await sleep(1200);
  const opened = (await external()).slice(before);
  const stillApp = (await js('location.origin')) === APP_ORIGIN;
  record('external links open in the browser', opened.length >= 1 && (await windows()) === 1 && stillApp,
    `${JSON.stringify(opened)}${linkInfo ? '' : ' (no visible https link in the page)'}`);

  // 6. Close before Export, with the app in English: the warning follows the app
  // language, names the records and goes to Export.
  await setLang('en');
  const records = await js(`(function () { var el = document.querySelector('#upload-stats .stat-value'); return el ? el.textContent.trim() : ''; })()`);
  await main.eval(`globalThis.__e2e.closeAnswer = ${JSON.stringify(EN.close.goExport)}; true`);
  await main.eval(`process.mainModule.require('electron').BrowserWindow.getAllWindows()[0].close(); true`);
  const unsaved = await waitFor(async () => (await dialogs())[0], { timeout: 5000, what: 'close warning' }).catch(() => ({}));
  const onExport = await waitFor(() => js(`(function () {
    var a = document.querySelector("a[data-value='export']");
    return !!a && a.classList.contains('active');
  })()`), { timeout: 10000, what: 'Export tab' }).catch(() => false);
  record('close before Export warns in English and goes to Export',
    unsaved.message === EN.close.unsaved && !!records && unsaved.detail.includes(records) && onExport && (await windows()) === 1,
    `${unsaved.message} | ${unsaved.detail} | ${JSON.stringify(unsaved.buttons)} | Export tab ${onExport}`);
  await setLang('pt');

  // 7. Export: the zip lands in the download folder.
  await js(`(function () {
    var boxes = Array.from(document.querySelectorAll("input[name='mapping-custom_license']"));
    var box = boxes.find(function (b) { return /CC.?BY.?4/i.test(b.value) && !/NC|SA|ND/i.test(b.value); }) || boxes[0];
    if (box && !box.checked) box.click();
    return boxes.map(function (b) { return b.value; });
  })()`);
  await waitIdle();
  await clickSel(`a[data-value='export']`);
  await waitIdle(90000);
  const enabled = await waitFor(() => js(`(function () {
    var b = document.getElementById('export-download_trigger');
    return !!b && !b.disabled && !b.classList.contains('is-inert');
  })()`), { timeout: 60000, what: 'export button enabled' }).catch(() => false);
  if (!enabled) {
    const why = await js(`(function () { var s = document.getElementById('export-summary'); return s ? s.innerText.slice(0, 600) : ''; })()`);
    record('export download', false, `button blocked: ${why}`);
  } else {
    const exportStart = Date.now();
    await clickSel('#export-download_trigger');
    // The trigger opens a confirmation modal. A validation modal has no Yes button.
    const confirm = await waitFor(() => js(`(function () {
      var b = document.getElementById('export-confirm_download_yes');
      return !!b && b.offsetParent !== null;
    })()`), { timeout: 30000, what: 'download confirmation' }).catch(() => false);
    if (!confirm) {
      const modal = await js(`(function () { var m = document.querySelector('.modal.show'); return m ? m.innerText.slice(0, 600) : 'no modal'; })()`);
      throw new Error(`No download confirmation: ${modal}`);
    }
    await clickSel('#export-confirm_download_yes');
    // The zip is on disk a few ms before the shell gets the download done event.
    const zip = await waitFor(() => {
      if (!/Download completed:/.test(shellOut)) return false;
      const files = fs.readdirSync(DOWNLOADS).filter((f) => f.endsWith('.zip'));
      if (!files.length) return false;
      const f = path.join(DOWNLOADS, files[0]);
      return fs.statSync(f).size > 0 ? f : false;
    }, { timeout: 180000, interval: 500, what: 'zip in the download folder' }).catch(() => null);
    record('export download', !!zip, zip ? `${path.basename(zip)}, ${fs.statSync(zip).size} bytes, ${((Date.now() - exportStart) / 1000).toFixed(1)} s` : 'no zip');
    // R marks the bundle current in the flush after the download, about 0.1 s
    // after the shell event. A close in that gap warns, as before the export.
    const bundleStart = Date.now();
    const current = await waitFor(() => js(`document.documentElement.dataset.sairaBundle === 'current'`),
      { timeout: 10000, interval: 50, what: 'bundle current' }).catch(() => false);
    record('bundle marked current after the download', !!current, `${Date.now() - bundleStart} ms after the zip`);
  }

  // 8. Close after Export: a plain question. Cancel keeps the window, Close stops R and the app.
  await main.eval(`globalThis.__e2e.closeAnswer = ${JSON.stringify(PT.close.cancel)}; true`);
  await main.eval(`process.mainModule.require('electron').BrowserWindow.getAllWindows()[0].close(); true`);
  const asked = await waitFor(async () => (await dialogs())[1], { timeout: 5000, what: 'close question' }).catch(() => ({}));
  await sleep(500);
  record('close after Export asks first, Cancel keeps the window', (await windows()) === 1 && asked.message === PT.close.message,
    `${asked.message} | ${JSON.stringify(asked.buttons)} | default ${asked.defaultId}`);

  // 9. A change after Export: the warning comes back.
  const license = await js(`(function () {
    var box = Array.from(document.querySelectorAll("input[name='mapping-custom_license']")).find(function (b) { return !b.checked; });
    if (box) box.click();
    return box ? box.value : '';
  })()`);
  await waitIdle();
  await main.eval(`process.mainModule.require('electron').BrowserWindow.getAllWindows()[0].close(); true`);
  const changed = await waitFor(async () => (await dialogs())[2], { timeout: 5000, what: 'close after a change' }).catch(() => ({}));
  await sleep(500);
  record('close after a change warns again', !!license && changed.message === PT.close.unsaved && (await windows()) === 1,
    `${license} | ${changed.message}`);

  // An open inspector session holds the process ("Waiting for the debugger to disconnect").
  // Close the window from a timer, then disconnect before the app exits.
  await main.eval(`globalThis.__e2e.closeAnswer = ${JSON.stringify(PT.close.discard)};
    setTimeout(() => process.mainModule.require('electron').BrowserWindow.getAllWindows()[0].close(), 300); true`);
  main.ws.close();
  const closeStart = Date.now();
  await waitFor(() => exitedAt, { timeout: 20000, what: 'app exit' }).catch(() => null);
  record('Close ends the app', !!exitedAt, exitedAt ? `${((exitedAt - closeStart) / 1000).toFixed(1)} s` : 'still running');

  const portFree = await fetch(APP_ORIGIN).then(() => false, () => true);
  record('R server port closed', portFree);

  if (exitedAt) await hardKillCheck(exe, env);

  fs.writeFileSync(path.join(WORK, 'results.json'), JSON.stringify({ startup, results }, null, 2));
  const failed = results.filter((r) => !r.ok).length;
  console.log(`\n${results.length - failed}/${results.length} checks passed.`);
  if (!exitedAt) child.kill();
  process.exit(failed ? 1 : 0);
}

main().catch((err) => {
  console.error('E2E error:', err && err.stack || err);
  if (child && child.exitCode === null) {
    if (process.platform === 'win32') spawnSync('taskkill', ['/PID', String(child.pid), '/T', '/F']);
    else { spawnSync('pkill', ['-KILL', '-P', String(child.pid)]); child.kill('SIGKILL'); }
  }
  fs.writeFileSync(path.join(WORK, 'results.json'), JSON.stringify({ error: String(err), results }, null, 2));
  process.exit(2);
});
