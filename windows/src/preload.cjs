'use strict';
const { contextBridge, ipcRenderer } = require('electron');
const methods = ['state', 'language', 'hide', 'view', 'copy', 'favorite', 'remove', 'advance', 'chooseBackup', 'preview', 'manual', 'cancelPreview', 'import', 'export', 'qrFile', 'qrPaste', 'qrScreen', 'login', 'lock', 'retry'];
contextBridge.exposeInMainWorld('quickAuth', {
  call: (method, args) => {
    if (!methods.includes(method)) return Promise.resolve({ ok: false, error: 'actionFailed' });
    return ipcRenderer.invoke('quickauth', method, args);
  },
  subscribe: callback => {
    const listener = (_event, state) => callback(state);
    ipcRenderer.on('state', listener);
    return () => ipcRenderer.removeListener('state', listener);
  }
});
