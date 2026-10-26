// IPC bridge. lifecycle.html needs window.lifecycle. On the Shiny page the
// shell reads <html lang> and the theme.
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('lifecycle', {
  onStatus: (callback) => {
    ipcRenderer.on('lifecycle-status', (_event, data) => callback(data));
  },
  retry: () => ipcRenderer.send('lifecycle-action', { type: 'retry' }),
  quit: () => ipcRenderer.send('lifecycle-action', { type: 'quit' }),
  copy: () => ipcRenderer.send('lifecycle-action', { type: 'copy' })
});

function storedTheme() {
  try { return localStorage.getItem('saira-theme') || 'system'; } catch { return 'system'; }
}

function connectApp() {
  if (location.protocol !== 'http:') return;
  const root = document.documentElement;
  const sendLang = () => ipcRenderer.send('saira:lang', root.lang);
  const sendTheme = () => ipcRenderer.send('saira:theme', {
    dark: root.getAttribute('data-bs-theme') === 'dark', mode: storedTheme()
  });
  sendLang();
  sendTheme();
  new MutationObserver((records) => {
    if (records.some((r) => r.attributeName === 'lang')) sendLang();
    if (records.some((r) => r.attributeName === 'data-bs-theme')) sendTheme();
  }).observe(root, { attributes: true, attributeFilter: ['lang', 'data-bs-theme'] });
  // A switch to "system" can keep the same colors, so the click also reports the mode.
  document.addEventListener('click', (e) => {
    if (e.target.closest && e.target.closest('.theme-switch')) setTimeout(sendTheme, 0);
  });
}

if (document.readyState === 'loading') window.addEventListener('DOMContentLoaded', connectApp);
else connectApp();
