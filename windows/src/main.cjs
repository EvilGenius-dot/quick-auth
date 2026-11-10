'use strict';
const { app, BrowserWindow, Tray, Menu, ipcMain, dialog, clipboard, safeStorage, screen, desktopCapturer, nativeImage, powerMonitor, session } = require('electron');
const fs = require('node:fs/promises');
const path = require('node:path');
const os = require('node:os');
const { pathToFileURL } = require('node:url');
const { Worker } = require('node:worker_threads');
const { execFile } = require('node:child_process');
const { PNG } = require('pngjs');
const jsQR = require('jsqr');
const core = require('./core.cjs');
const { Vault, atomicWrite } = require('./storage.cjs');
const demo = process.argv.includes('--demo');
const smoke = process.argv.includes('--smoke-test');
app.setName('Quick Auth');
const directory = demo || smoke ? path.join(os.tmpdir(), `quick-auth-${smoke ? 'smoke' : 'demo'}-${process.pid}`) : path.join(app.getPath('appData'), 'Quick Auth');
app.setPath('userData', directory);
let window, tray, vault, captureWindow, captureImage, captureResolve;
let accounts = [], preview = null, backupText = null, locked = false, loadFailed = false, busy = false, generation = 0, activeView = 'home', config = { language: 'system' };
let copiedText = null, copyTimer, worker;
const indexURL = pathToFileURL(path.join(__dirname, 'index.html')).href;
const captureURL = pathToFileURL(path.join(__dirname, 'capture.html')).href;
function language() { return config.language === 'system' ? app.getLocale().toLowerCase().startsWith('zh') ? 'zh-CN' : 'en' : config.language; }
function words(en, zh) { return language() === 'zh-CN' ? zh : en; }
function publicAccount(a) { return { id: a.id, issuer: a.issuer, account: a.account, kind: a.kind, favorite: a.favorite, code: core.code(a), remaining: a.period - Math.floor(Date.now() / 1000) % a.period, period: a.period, counter: a.kind === 'hotp' ? a.counter : undefined }; }
function state() { return { language: language(), preference: config.language, version: app.getVersion(), demo, locked, loadFailed, accounts: accounts.map(publicAccount), launchAtLogin: !demo && !smoke && app.getLoginItemSettings().openAtLogin }; }
function broadcast() { if (window && !window.isDestroyed()) window.webContents.send('state', state()); }
function assertOpen() { if (locked || loadFailed) throw new core.AuthError('vaultUnavailable'); }
function checkToken(token) { if (generation !== token || locked) throw new core.AuthError('cancelled'); }
function clearClipboard() { if (copiedText !== null && clipboard.readText() === copiedText) clipboard.clear(); copiedText = null; clearTimeout(copyTimer); }
function clearPreview() { preview = null; backupText = null; }
function cancelCapture() {
  captureImage = null;
  if (captureWindow && !captureWindow.isDestroyed()) captureWindow.destroy();
  captureWindow = null;
  const resolve = captureResolve; captureResolve = null; resolve?.(null);
}
function lock() { generation++; locked = true; accounts = []; clearPreview(); clearClipboard(); worker?.terminate(); worker = null; cancelCapture(); activeView = 'home'; broadcast(); }
async function reload() {
  const token = generation;
  try { const loaded = await vault.load(); if (token !== generation) return; accounts = loaded; loadFailed = false; locked = false; }
  catch { if (token !== generation) return; accounts = []; loadFailed = true; locked = false; }
  broadcast();
}
async function commit(next, token) { checkToken(token); if (!demo) await vault.save(next); checkToken(token); accounts = next; broadcast(); }
function task(data) {
  return new Promise((resolve, reject) => {
    const w = new Worker(path.join(__dirname, 'worker.cjs'), { workerData: data }); worker = w;
    const timeout = setTimeout(() => { w.terminate(); reject(new core.AuthError('actionFailed')); }, 60000);
    w.once('message', r => r.ok ? resolve(r.value) : reject(new core.AuthError(r.error)));
    w.once('error', () => reject(new core.AuthError('actionFailed')));
    w.once('exit', code => { clearTimeout(timeout); if (worker === w) worker = null; if (code !== 0) reject(new core.AuthError('cancelled')); });
  });
}
function previewResult(value) {
  preview = value;
  const combined = core.merge(accounts, value.accounts);
  return { accounts: value.accounts.map(a => ({ issuer: a.issuer, account: a.account, kind: a.kind })), issues: value.issues, added: combined.added, duplicates: combined.duplicates };
}
async function scanImage(image) {
  if (image.isEmpty()) throw new core.AuthError('invalidImage');
  const size = image.getSize();
  if (size.width * size.height > 32_000_000) throw new core.AuthError('imageTooLarge');
  if (Math.max(size.width, size.height) > 4096) image = image.resize(size.width >= size.height ? { width: 4096 } : { height: 4096 });
  const png = PNG.sync.read(image.toPNG());
  const qr = jsQR(new Uint8ClampedArray(png.data), png.width, png.height);
  if (!qr) throw new core.AuthError('noQR');
  return previewResult({ accounts: [core.parseURI(qr.data)], issues: [] });
}
function secureWindow(win, url) {
  win.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));
  win.webContents.on('will-navigate', (event, target) => { if (target !== url) event.preventDefault(); });
  win.webContents.on('will-attach-webview', event => event.preventDefault());
}
async function captureQR(token) {
  const display = screen.getDisplayNearestPoint(screen.getCursorScreenPoint());
  window.hide();
  await new Promise(resolve => setTimeout(resolve, 250)); checkToken(token);
  try {
    const sources = await desktopCapturer.getSources({ types: ['screen'], thumbnailSize: { width: Math.round(display.size.width * display.scaleFactor), height: Math.round(display.size.height * display.scaleFactor) } });
    checkToken(token);
    const source = sources.find(s => s.display_id === String(display.id));
    if (!source || source.thumbnail.isEmpty()) throw new core.AuthError('captureFailed');
    captureImage = source.thumbnail;
    const promise = new Promise(resolve => { captureResolve = resolve; });
    captureWindow = new BrowserWindow({ ...display.bounds, frame: false, alwaysOnTop: true, skipTaskbar: true, resizable: false, movable: false, fullscreenable: false, webPreferences: { preload: path.join(__dirname, 'capture-preload.cjs'), contextIsolation: true, sandbox: true, nodeIntegration: false } });
    secureWindow(captureWindow, captureURL);
    captureWindow.on('closed', () => { captureImage = null; captureWindow = null; const resolve = captureResolve; captureResolve = null; resolve?.(null); });
    await captureWindow.loadURL(captureURL); captureWindow.focus();
    const image = await promise; checkToken(token);
    return image ? await scanImage(image) : null;
  } finally { cancelCapture(); if (!locked) showWindow(); }
}
function showWindow() {
  if (!window || window.isDestroyed()) return;
  const point = screen.getCursorScreenPoint(), display = screen.getDisplayNearestPoint(point).workArea;
  const bounds = tray?.getBounds();
  const width = 440, height = Math.min(680, display.height - 20);
  const x = Math.max(display.x + 10, Math.min((bounds?.x || point.x) - width / 2, display.x + display.width - width - 10));
  const y = Math.max(display.y + 10, display.y + display.height - height - 10);
  window.setBounds({ x: Math.round(x), y: Math.round(y), width, height });
  window.show(); window.focus(); broadcast();
}
function trayMenu() {
  tray.setToolTip('Quick Auth');
  tray.setContextMenu(Menu.buildFromTemplate([
    { label: words('Open Quick Auth', '打开 Quick Auth'), click: showWindow },
    { type: 'separator' },
    { label: words('Language', '语言'), submenu: [
      { label: words('System default', '跟随系统'), type: 'radio', checked: config.language === 'system', click: () => setLanguage('system') },
      { label: 'English', type: 'radio', checked: config.language === 'en', click: () => setLanguage('en') },
      { label: '简体中文', type: 'radio', checked: config.language === 'zh-CN', click: () => setLanguage('zh-CN') }
    ] },
    { label: words('Quit', '退出'), click: () => app.quit() }
  ]));
}
async function setLanguage(value) {
  if (!['system', 'en', 'zh-CN'].includes(value)) throw new core.AuthError('invalidParameter');
  const next = { language: value };
  await fs.mkdir(directory, { recursive: true });
  await atomicWrite(path.join(directory, 'preferences.json'), Buffer.from(JSON.stringify(next)));
  config = next; trayMenu(); broadcast(); return state();
}
async function handle(method, args = {}) {
  if (method === 'state') return state();
  if (method === 'hide') { window.hide(); return; }
  if (method === 'language') return setLanguage(args.value);
  if (method === 'view') { activeView = ['home', 'add', 'export'].includes(args.value) ? args.value : 'home'; return; }
  if (method === 'cancelPreview') { generation++; worker?.terminate(); clearPreview(); return; }
  if (method === 'retry') { if (locked) throw new core.AuthError('locked'); await reload(); return; }
  if (busy) throw new core.AuthError('busy');
  busy = true; const token = generation;
  try {
    assertOpen();
    if (method === 'copy') {
      const a = accounts.find(a => a.id === args.id); if (!a) throw new core.AuthError('invalidRecord');
      clearClipboard(); copiedText = core.code(a); clipboard.writeText(copiedText);
      copyTimer = setTimeout(clearClipboard, 30000); return;
    }
    if (['favorite', 'remove', 'advance'].includes(method)) {
      const a = accounts.find(a => a.id === args.id); if (!a) throw new core.AuthError('invalidRecord');
      if (method !== 'favorite') {
        const result = await dialog.showMessageBox(window, { type: 'question', message: method === 'remove' ? words('Remove this account?', '移除这个账户？') : words('Generate the next HOTP code?', '生成下一个 HOTP 验证码？'), detail: method === 'remove' ? words('Keep another authenticator or a backup before removing an account.', '移除前请确认仍保留其他验证器或备份。') : words('The counter will increase by 1. Continue only after using the current code.', '计数器会增加 1。仅在当前验证码已使用后继续。'), buttons: [words('Cancel', '取消'), words('Continue', '继续')], defaultId: 0, cancelId: 0 });
        checkToken(token); if (result.response !== 1) return;
      }
      if (method === 'advance' && (a.kind !== 'hotp' || BigInt(a.counter) >= core.MAX_COUNTER)) throw new core.AuthError('invalidCounter');
      const next = method === 'remove' ? accounts.filter(x => x.id !== a.id) : accounts.map(x => x.id === a.id ? { ...x, ...(method === 'favorite' ? { favorite: !x.favorite } : { counter: (BigInt(x.counter) + 1n).toString() }) } : x);
      await commit(next, token); if (method !== 'favorite') clearClipboard(); return;
    }
    if (method === 'chooseBackup') {
      const result = await dialog.showOpenDialog(window, { properties: ['openFile'], filters: [{ name: 'Authenticator', extensions: ['json', 'txt', 'quickauth'] }] });
      checkToken(token); if (result.canceled) return null;
      const file = result.filePaths[0]; if ((await fs.stat(file)).size > core.MAX_BYTES) throw new core.AuthError('tooLarge');
      try { backupText = new TextDecoder('utf-8', { fatal: true }).decode(await fs.readFile(file)); }
      catch { throw new core.AuthError('invalidBackup'); }
      preview = null; checkToken(token);
      return { name: path.basename(file) };
    }
    if (method === 'preview') {
      preview = null;
      const text = args.file ? backupText : args.text;
      if (typeof text !== 'string' || Buffer.byteLength(text) > core.MAX_BYTES) throw new core.AuthError('tooLarge');
      const result = await task({ kind: 'parse', text, password: args.password || undefined }); checkToken(token);
      return previewResult(result);
    }
    if (method === 'manual') { preview = null; return previewResult({ accounts: [core.manualAccount(args)], issues: [] }); }
    if (method === 'import') {
      if (!preview || !preview.accounts.length || (preview.issues.length && args.allowPartial !== true)) throw new core.AuthError('invalidRecord');
      const result = core.merge(accounts, preview.accounts); await commit(result.accounts, token); clearPreview(); return { added: result.added, duplicates: result.duplicates };
    }
    if (method === 'export') {
      if (args.encrypted !== true && args.acceptedPlaintext !== true) throw new core.AuthError('plaintextWarning');
      if (args.encrypted === true && args.password !== args.confirmation) throw new core.AuthError('passwordMismatch');
      const output = await task({ kind: 'export', accounts, encrypted: args.encrypted === true, password: args.password }); checkToken(token);
      const suffix = args.encrypted ? 'encrypted' : 'plaintext';
      const result = await dialog.showSaveDialog(window, { defaultPath: path.join(app.getPath('downloads'), `quick-auth-backup-${new Date().toISOString().slice(0, 10)}-${suffix}.json`), filters: [{ name: 'JSON', extensions: ['json'] }] });
      checkToken(token); if (result.canceled || !result.filePath) return null;
      await atomicWrite(result.filePath, Buffer.from(output)); return { count: accounts.length };
    }
    if (method === 'qrFile') {
      const result = await dialog.showOpenDialog(window, { properties: ['openFile'], filters: [{ name: 'QR', extensions: ['png', 'jpg', 'jpeg', 'bmp', 'webp'] }] });
      checkToken(token); if (result.canceled) return null;
      if ((await fs.stat(result.filePaths[0])).size > 20 * 1024 * 1024) throw new core.AuthError('imageTooLarge');
      const image = nativeImage.createFromBuffer(await fs.readFile(result.filePaths[0])); checkToken(token); return scanImage(image);
    }
    if (method === 'qrPaste') return scanImage(clipboard.readImage());
    if (method === 'qrScreen') return captureQR(token);
    if (method === 'login') { if (!demo && !smoke && process.platform === 'win32') app.setLoginItemSettings({ openAtLogin: args.enabled === true }); broadcast(); return; }
    if (method === 'lock') {
      if (!demo && process.platform === 'win32') await new Promise((resolve, reject) => execFile(path.join(process.env.SystemRoot || 'C:\\Windows', 'System32', 'rundll32.exe'), ['user32.dll,LockWorkStation'], error => error ? reject(new core.AuthError('actionFailed')) : resolve()));
      if (!demo) lock(); return;
    }
    throw new core.AuthError('actionFailed');
  } finally { busy = false; }
}
ipcMain.handle('quickauth', async (event, method, args) => {
  if (event.sender !== window?.webContents || event.senderFrame !== window.webContents.mainFrame || event.senderFrame.url !== indexURL) return { ok: false, error: 'actionFailed' };
  try { return { ok: true, value: await handle(method, args) }; } catch (e) { return { ok: false, error: e instanceof core.AuthError ? e.code : 'actionFailed' }; }
});
ipcMain.handle('capture-image', event => {
  if (!captureWindow || event.sender !== captureWindow.webContents || event.senderFrame !== captureWindow.webContents.mainFrame || event.senderFrame.url !== captureURL || !captureImage) return null;
  return { image: captureImage.toDataURL(), language: language() };
});
ipcMain.on('capture-finish', (event, rect) => {
  if (!captureWindow || event.sender !== captureWindow.webContents || event.senderFrame !== captureWindow.webContents.mainFrame || event.senderFrame.url !== captureURL) return;
  let cropped = null;
  if (rect && captureImage && ['x', 'y', 'width', 'height'].every(k => Number.isFinite(rect[k]))) {
    const bounds = captureWindow.getContentBounds(), size = captureImage.getSize();
    if (rect.x >= 0 && rect.y >= 0 && rect.width >= 8 && rect.height >= 8 && rect.x + rect.width <= bounds.width + 1 && rect.y + rect.height <= bounds.height + 1) {
      const x = Math.round(rect.x * size.width / bounds.width), y = Math.round(rect.y * size.height / bounds.height);
      cropped = captureImage.crop({ x, y, width: Math.min(size.width - x, Math.round(rect.width * size.width / bounds.width)), height: Math.min(size.height - y, Math.round(rect.height * size.height / bounds.height)) });
    }
  }
  const resolve = captureResolve; captureResolve = null; resolve?.(cropped); cancelCapture();
});
if (!app.requestSingleInstanceLock()) app.quit();
else {
  app.on('second-instance', showWindow);
  app.on('window-all-closed', () => {});
  app.on('before-quit', () => { clearClipboard(); clearPreview(); accounts = []; worker?.terminate(); cancelCapture(); });
  app.whenReady().then(async () => {
    if (process.platform !== 'win32' && !demo && !smoke) { dialog.showErrorBox('Quick Auth', 'Use the native macOS app. This client is built for Windows.'); app.quit(); return; }
    session.defaultSession.setPermissionRequestHandler((_wc, _permission, callback) => callback(false));
    session.defaultSession.setPermissionCheckHandler(() => false);
    session.defaultSession.webRequest.onBeforeRequest((details, callback) => callback({ cancel: /^https?:|^wss?:/i.test(details.url) }));
    try { const read = JSON.parse(await fs.readFile(path.join(directory, 'preferences.json'), 'utf8')); if (['system', 'en', 'zh-CN'].includes(read.language)) config.language = read.language; } catch {}
    vault = new Vault(directory, safeStorage);
    if (demo || smoke) accounts = ['GitHub', 'Google', 'Cloudflare', 'Microsoft'].map((issuer, i) => core.parseRecord({ issuer, account: 'hello@example.com', secret: core.base32Encode(Buffer.from(`demo-only-secret-${i}`)), pinned: i === 0 }));
    else await reload();
    window = new BrowserWindow({ width: 440, height: 680, show: false, frame: false, resizable: false, skipTaskbar: true, backgroundColor: '#f6f8f7', title: 'Quick Auth', icon: path.join(__dirname, '../assets/icon.png'), webPreferences: { preload: path.join(__dirname, 'preload.cjs'), contextIsolation: true, sandbox: true, nodeIntegration: false, spellcheck: false } });
    secureWindow(window, indexURL);
    window.on('blur', () => { if (!smoke && activeView === 'home' && !busy) window.hide(); });
    window.on('close', event => { if (!app.isQuitting && !smoke) { event.preventDefault(); window.hide(); } });
    app.on('before-quit', () => { app.isQuitting = true; });
    tray = new Tray(path.join(__dirname, '../assets/icon.png')); trayMenu();
    tray.on('click', () => window.isVisible() ? window.hide() : showWindow());
    await window.loadURL(indexURL);
    if (demo || smoke || accounts.length === 0 || loadFailed) showWindow();
    powerMonitor.on('lock-screen', lock);
    // Hiding on suspend avoids leaving codes visible. Windows emits lock-screen
    // when authentication is required; unlock-screen then reloads the vault.
    powerMonitor.on('suspend', () => { window.hide(); clearClipboard(); clearPreview(); });
    powerMonitor.on('unlock-screen', () => { generation++; reload(); });
    powerMonitor.on('resume', () => { if (!locked) reload(); });
    setInterval(() => { if (window?.isVisible() && activeView === 'home' && !locked) broadcast(); }, 1000).unref();
    if (smoke) {
      try { await require('./smoke.cjs')({ app, window, vault, accounts, directory, lock, reload, state, scanImage }); app.exit(0); }
      catch (error) { console.error('Smoke test failed:', error.message); app.exit(1); }
    }
  }).catch(() => { dialog.showErrorBox('Quick Auth', 'Quick Auth could not start. Existing account data has not been overwritten.'); app.exit(1); });
}
