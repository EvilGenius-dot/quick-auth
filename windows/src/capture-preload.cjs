'use strict';
const { contextBridge, ipcRenderer } = require('electron');
contextBridge.exposeInMainWorld('capture', {
  image: () => ipcRenderer.invoke('capture-image'),
  finish: rect => ipcRenderer.send('capture-finish', rect)
});
