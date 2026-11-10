'use strict';
const { parentPort, workerData } = require('node:worker_threads');
const core = require('./core.cjs');
(async () => {
  try {
    const result = workerData.kind === 'parse' ? await core.parseBackup(workerData.text, workerData.password) : workerData.encrypted ? await core.encryptedBackup(workerData.accounts, workerData.password) : core.plaintextBackup(workerData.accounts);
    parentPort.postMessage({ ok: true, value: result });
  } catch (e) { parentPort.postMessage({ ok: false, error: e.code || 'actionFailed' }); }
})();
