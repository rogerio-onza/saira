// Saíra desktop shell. It replaces the main.js that shinyelectron generates and
// keeps its native R backend (backends/native-r.js).
const { app, BrowserWindow, Menu, clipboard, dialog, ipcMain, nativeTheme, screen, shell } = require('electron');
const path = require('path');
const fs = require('fs');
const backend = require('./backends/native-r.js');
const strings = require('./i18n.js');

const SLUG = 'saira-desktop-preview';
// A fixed port keeps one origin, so the theme in localStorage survives a restart.
const PREFERRED_PORT = 38838;
// navigator.clipboard (copy buttons) and fullscreen are the only permissions the app uses.
const ALLOWED_PERMISSIONS = new Set(['clipboard-sanitized-write', 'fullscreen']);
const ICON = path.join(__dirname, 'assets', 'icon.ico');

const info = readJson(path.join(__dirname, 'desktop-info.json')) || {};
const unpacked = __dirname.replace('app.asar', 'app.asar.unpacked');
const appPath = path.join(unpacked, 'src', 'app');
const bundledLibrary = path.join(unpacked, 'runtime', 'R', 'library');
const desktopHome = path.join(process.env.LOCALAPPDATA || app.getPath('userData'), SLUG);
const logDir = path.join(app.getPath('userData'), 'logs');
const stateFile = path.join(app.getPath('userData'), 'window-state.json');

let logStream = null;
let mainWindow = null;
let actualPort = null;
let serverRunning = false;
let quitting = false;
let closePending = false;
// A completed download from the Export tab in this R session.
let exported = false;
let lastReport = '';
let lang = 'pt-BR';
let themeMode = 'system';
let themeDark = nativeTheme.shouldUseDarkColors;

function readJson(file) {
  try { return JSON.parse(fs.readFileSync(file, 'utf8')); } catch { return null; }
}

function log(level, ...args) {
  const line = `[${new Date().toISOString()}] [${level.toUpperCase()}] ${args.join(' ')}`;
  if (logStream) logStream.write(line + '\n');
  if (level === 'error') console.error(line); else console.log(line);
}

function initLogging() {
  try {
    fs.mkdirSync(logDir, { recursive: true });
    const file = path.join(logDir, `app-${new Date().toISOString().slice(0, 10)}.log`);
    logStream = fs.createWriteStream(file, { flags: 'a' });
  } catch { /* logging is best-effort */ }
}

process.on('uncaughtException', (err) => {
  if (err && err.code === 'EPIPE') return;
  log('error', 'uncaughtException:', (err && err.stack) || err);
  process.exit(1);
});

function t() {
  return strings[lang] || strings['pt-BR'];
}

function previewVersion() {
  return info.preview_version || app.getVersion();
}

// R reads only the bundle: no user library, no ~/.Rprofile or ~/.Renviron of an
// R installed on the same machine. R_LIBS_USER also reaches the PSOCK workers
// that R starts with --vanilla (Rostrum, Flora/Fauna BR updates).
function prepareRuntimeEnvironment() {
  const empty = path.join(app.getPath('userData'), 'empty-r-startup');
  fs.mkdirSync(path.dirname(empty), { recursive: true });
  fs.writeFileSync(empty, '');
  for (const name of ['R_HOME', 'R_LIBS', 'R_LIBS_SITE']) delete process.env[name];
  Object.assign(process.env, {
    R_LIBS_USER: bundledLibrary,
    R_PROFILE_USER: empty,
    R_ENVIRON_USER: empty,
    SAIRA_DESKTOP_HOME: desktopHome,
    R_USER_DATA_DIR: path.join(desktopHome, 'data'),
    R_USER_CACHE_DIR: path.join(desktopHome, 'cache'),
    R_USER_CONFIG_DIR: path.join(desktopHome, 'config')
  });
  // The rostrum.sqlite file follows SAIRA_DATA_DIR, the BR snapshots follow R_USER_DATA_DIR.
  process.env.SAIRA_DATA_DIR = path.join(desktopHome, 'data', 'R', 'saira');
}

function isAppUrl(url) {
  try {
    const u = new URL(url);
    return u.protocol === 'http:' && u.hostname === '127.0.0.1' && Number(u.port) === actualPort;
  } catch {
    return false;
  }
}

function openExternal(url) {
  if (/^(https?|mailto):/i.test(url)) shell.openExternal(url);
  else log('warn', 'Blocked URL:', url);
}

// The menu bar stays hidden. The menu keeps the edit, zoom and full screen shortcuts.
function buildMenu() {
  const items = ['undo', 'redo', 'cut', 'copy', 'paste', 'selectAll', 'zoomIn', 'zoomOut',
    'resetZoom', 'togglefullscreen', 'quit'].map((role) => ({ role }));
  if (process.env.SAIRA_DESKTOP_DEVTOOLS === '1') items.push({ role: 'toggleDevTools' });
  Menu.setApplicationMenu(Menu.buildFromTemplate([{ label: 'Saíra', submenu: items }]));
}

function background() {
  return themeDark ? '#0f1116' : '#f5f6f8';
}

function shellPreferences() {
  return {
    contextIsolation: true, nodeIntegration: false, sandbox: true, spellcheck: false,
    preload: path.join(__dirname, 'preload.js')
  };
}

// The shell pages read their view, theme and text from the query string.
function pageOptions(fields) {
  return { query: { page: JSON.stringify({ lang, theme: themeDark ? 'dark' : 'light', ...fields }) } };
}

function lifecycleOptions(view, fields) {
  const text = t().lifecycle;
  return pageOptions({ view, text, version: `${text.preview} ${previewVersion().split('-')[0]}`, ...fields });
}

// Small shell windows: no menu, no navigation away from the page.
function smallWindow(options) {
  const win = new BrowserWindow({
    useContentSize: true, resizable: false, minimizable: false, maximizable: false,
    fullscreenable: false, icon: ICON, show: false, backgroundColor: background(),
    webPreferences: shellPreferences(), ...options
  });
  win.setMenu(null);
  win.webContents.on('will-navigate', (event) => event.preventDefault());
  win.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));
  win.once('ready-to-show', () => win.show());
  return win;
}

function setLanguage(tag) {
  const next = /^pt/i.test(tag) ? 'pt-BR' : /^es/i.test(tag) ? 'es' : /^en/i.test(tag) ? 'en' : null;
  if (next) lang = next;
}

function showLifecycle(view, fields) {
  if (!mainWindow || mainWindow.isDestroyed()) return;
  mainWindow.loadFile('lifecycle.html', lifecycleOptions(view, fields));
}

// Board Crash-B: the last lines that R wrote, then the versions.
function crashReport(data) {
  const stderr = ((data.detail && data.detail.stderr) || '').trim();
  return [
    ...(stderr ? stderr.split(/\r?\n/).slice(-40) : []),
    '',
    `Saíra desktop ${previewVersion()} · saira ${info.saira_version || '?'} (${(info.source_commit || '').slice(0, 7)})`,
    `R ${info.r_version || '?'} · Electron ${process.versions.electron} · ${process.platform} ${process.arch}`,
    data.message || ''
  ].join('\n');
}

function startServer() {
  serverRunning = false;
  exported = false;
  backend.start({
    appPath,
    port: PREFERRED_PORT,
    config: { runtime_strategy: 'bundled', app_type: 'r-shiny', app_slug: SLUG, startup_timeout: 180000 }
  }).then(({ port }) => {
    actualPort = port;
    log('info', 'Server ready on port', port);
    mainWindow.loadURL(`http://127.0.0.1:${port}/`);
  }).catch((err) => {
    if (err && err.code === 'START_SUPERSEDED') return;
    log('error', 'Backend start failed:', err && err.message);
  });
}

function restoreBounds(saved) {
  const bounds = { width: 1280, height: 850 };
  if (!saved || !saved.bounds) return { bounds, maximized: false };
  const { x, y, width, height } = saved.bounds;
  // Keep the saved position only when it is on a display that is still connected.
  const visible = screen.getAllDisplays().some(({ workArea: w }) =>
    x < w.x + w.width && x + width > w.x && y < w.y + w.height && y + height > w.y);
  return { bounds: visible ? saved.bounds : { width, height }, maximized: Boolean(saved.isMaximized) };
}

// The theme lets the next start page use the colors of the app.
function saveState() {
  if (!mainWindow || mainWindow.isDestroyed()) return;
  const state = { bounds: mainWindow.getNormalBounds(), isMaximized: mainWindow.isMaximized(), theme: themeMode };
  try { fs.writeFileSync(stateFile, JSON.stringify(state)); } catch { /* best-effort */ }
}

function guardNavigation(contents) {
  // Shiny download links carry target="_blank": download them, open other links in the browser.
  contents.setWindowOpenHandler(({ url }) => {
    if (isAppUrl(url)) contents.downloadURL(url);
    else openExternal(url);
    return { action: 'deny' };
  });
  contents.on('will-navigate', (event, url) => {
    if (isAppUrl(url)) return;
    event.preventDefault();
    openExternal(url);
  });
}

function configureSession(ses) {
  ses.setPermissionRequestHandler((_wc, permission, callback, details) => {
    callback(ALLOWED_PERMISSIONS.has(permission) && isAppUrl(details.requestingUrl));
  });
  ses.setPermissionCheckHandler((_wc, permission, origin) =>
    ALLOWED_PERMISSIONS.has(permission) && isAppUrl(origin));
  ses.on('will-download', (_event, item) => {
    const name = item.getFilename();
    // Browser tests set a folder, so no native dialog blocks them.
    const folder = process.env.SAIRA_DESKTOP_DOWNLOAD_DIR;
    if (folder) {
      item.setSavePath(path.join(folder, name));
    } else {
      const ext = path.extname(name).slice(1);
      item.setSaveDialogOptions({
        title: t().download.title,
        defaultPath: path.join(app.getPath('downloads'), name),
        filters: ext ? [{ name: t().download.type.replace('{ext}', ext.toUpperCase()), extensions: [ext] }] : []
      });
    }
    // Shiny serves the files of the Export tab at /download/export-<output id>.
    const fromExport = /\/download\/export-/.test(item.getURL());
    item.once('done', (_e, state) => {
      if (state === 'completed' && fromExport) exported = true;
      log('info', `Download ${state}:`, item.getSavePath() || name);
    });
  });
}

// null: the session has no data. '': data, but the Home tab shows no count.
async function sessionRecords() {
  const probe = `(function () {
    if (!document.querySelector("[id^='mapping-map_']")) return null;
    var count = document.querySelector('#upload-stats .stat-value');
    return count ? count.textContent.trim() : '';
  })()`;
  const timeout = new Promise((resolve) => setTimeout(() => resolve(''), 1500));
  try {
    return await Promise.race([mainWindow.webContents.executeJavaScript(probe), timeout]);
  } catch {
    return '';
  }
}

// Board Close-B: data that was not exported gets a warning with a way to Export.
async function closeChoice() {
  const records = await sessionRecords();
  if (records === null) return 'close';
  const c = t().close;
  if (exported) {
    const answer = dialog.showMessageBoxSync(mainWindow, {
      type: 'question', title: c.title, message: c.message, detail: c.detail,
      buttons: [c.confirm, c.cancel], defaultId: 1, cancelId: 1, noLink: true
    });
    return answer === 0 ? 'close' : 'cancel';
  }
  const answer = dialog.showMessageBoxSync(mainWindow, {
    type: 'warning', title: c.title, message: c.unsaved,
    detail: records ? c.unsavedDetail.replace('{n}', records) : c.unsavedDetailNoCount,
    buttons: [c.goExport, c.discard, c.cancel], defaultId: 0, cancelId: 2, noLink: true
  });
  return ['export', 'close', 'cancel'][answer] || 'cancel';
}

async function requestClose() {
  if (closePending) return;
  closePending = true;
  try {
    const choice = await closeChoice();
    log('info', 'Close:', choice);
    if (choice === 'close') {
      shutdown();
    } else if (choice === 'export') {
      await mainWindow.webContents.executeJavaScript(
        `(function () { var tab = document.querySelector("a[data-value='export']"); if (tab) tab.click(); })()`);
    }
  } catch (err) {
    log('error', 'Close failed:', err && err.message);
  } finally {
    closePending = false;
  }
}

// Board Closing-C: a small window while R stops, instead of the large app window.
function showClosingWindow() {
  if (!mainWindow || mainWindow.isDestroyed() || !mainWindow.isVisible()) return;
  const width = 360;
  const height = 150;
  const b = mainWindow.getBounds();
  const win = smallWindow({
    width, height, title: 'Saíra', closable: false,
    x: Math.round(b.x + (b.width - width) / 2), y: Math.round(b.y + (b.height - height) / 2)
  });
  win.once('show', () => { if (mainWindow && !mainWindow.isDestroyed()) mainWindow.hide(); });
  win.loadFile('lifecycle.html', lifecycleOptions('closing'));
}

async function shutdown() {
  if (quitting) return;
  quitting = true;
  saveState();
  showClosingWindow();
  // taskkill /T ends R and the workers it started. Do not wait more than 10 s.
  await Promise.race([backend.stop(), new Promise((resolve) => setTimeout(resolve, 10000))]);
  app.exit(0);
}

function createWindow() {
  const saved = readJson(stateFile);
  if (saved && (saved.theme === 'light' || saved.theme === 'dark')) {
    themeMode = saved.theme;
    themeDark = saved.theme === 'dark';
  }
  const { bounds, maximized } = restoreBounds(saved);
  mainWindow = new BrowserWindow({
    ...bounds,
    minWidth: 1024,
    minHeight: 680,
    title: 'Saíra',
    icon: ICON,
    show: false,
    backgroundColor: background(),
    webPreferences: { ...shellPreferences(), partition: `persist:${SLUG}` }
  });
  mainWindow.setMenuBarVisibility(false);
  if (maximized) mainWindow.maximize();

  const contents = mainWindow.webContents;
  guardNavigation(contents);
  configureSession(contents.session);
  contents.on('console-message', (e) => {
    if (e.level === 'error' || e.level === 'warning') log('warn', `[renderer] ${e.message}`);
  });
  contents.on('render-process-gone', (_e, details) => log('error', `[renderer] gone: ${details.reason}`));

  mainWindow.once('ready-to-show', () => mainWindow.show());
  mainWindow.on('close', (event) => {
    if (quitting) return;
    event.preventDefault();
    if (serverRunning) requestClose();
    else shutdown();
  });
  mainWindow.on('closed', () => { mainWindow = null; });

  backend.on('status', (data) => {
    log('info', `[lifecycle] ${data.phase}: ${data.message || ''}`);
    if (data.phase === 'server_ready') serverRunning = true;
    if (data.phase === 'error' || data.phase === 'server_crashed') lastReport = crashReport(data);
    if (data.phase === 'server_crashed' && serverRunning && !quitting) {
      serverRunning = false;
      showLifecycle('error', { kind: 'crash', report: lastReport });
      return;
    }
    if (mainWindow && !mainWindow.isDestroyed()) contents.send('lifecycle-status', { ...data, report: lastReport });
  });
  backend.on('error', (err) => log('error', 'Backend error:', err && err.message));

  showLifecycle('start');
  startServer();
}

function fromMainWindow(event) {
  return Boolean(mainWindow) && event.sender === mainWindow.webContents;
}

ipcMain.on('lifecycle-action', (event, action) => {
  if (!fromMainWindow(event)) return;
  const type = action && action.type;
  if (type === 'retry') {
    showLifecycle('start');
    startServer();
  } else if (type === 'quit') {
    shutdown();
  } else if (type === 'copy') {
    clipboard.writeText(lastReport);
  }
});

ipcMain.on('saira:lang', (event, tag) => {
  if (fromMainWindow(event)) setLanguage(String(tag || ''));
});

ipcMain.on('saira:theme', (event, data) => {
  if (!fromMainWindow(event) || !data) return;
  themeDark = Boolean(data.dark);
  themeMode = data.mode === 'light' || data.mode === 'dark' ? data.mode : 'system';
});

if (!app.requestSingleInstanceLock()) {
  app.quit();
} else {
  app.on('second-instance', () => {
    if (!mainWindow) return;
    if (mainWindow.isMinimized()) mainWindow.restore();
    mainWindow.focus();
  });
  app.whenReady().then(() => {
    initLogging();
    log('info', `Saíra desktop ${previewVersion()}, saira ${info.saira_version}, ${process.platform} ${process.arch}`);
    prepareRuntimeEnvironment();
    buildMenu();
    createWindow();
  });
  app.on('window-all-closed', () => app.quit());
}
