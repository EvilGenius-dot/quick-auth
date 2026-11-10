'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const { Vault, atomicWrite } = require('../src/storage.cjs');
const { parseRecord } = require('../src/core.cjs');
test('failed encryption never overwrites the existing vault', async () => {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'quick-auth-storage-'));
  try {
    const original = Buffer.from('existing encrypted data'); await fs.writeFile(path.join(dir, 'accounts.vault'), original);
    const vault = new Vault(dir, { isAsyncEncryptionAvailable: async () => true, encryptStringAsync: async () => { throw new Error('encryption failed'); } });
    await assert.rejects(vault.save([parseRecord({ secret: 'JBSWY3DPEHPK3PXP' })]));
    assert.deepEqual(await fs.readFile(vault.file), original);
    assert.deepEqual(await fs.readdir(dir), ['accounts.vault']);
  } finally { await fs.rm(dir, { recursive: true, force: true }); }
});
test('atomic replacement and malformed vault protection', async () => {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'quick-auth-storage-'));
  try {
    const file = path.join(dir, 'backup.json'); await atomicWrite(file, Buffer.from('first')); await atomicWrite(file, Buffer.from('second')); assert.equal(await fs.readFile(file, 'utf8'), 'second');
    if (process.platform !== 'win32') assert.equal((await fs.stat(file)).mode & 0o777, 0o600);
    const vault = new Vault(dir, { isAsyncEncryptionAvailable: async () => true, decryptStringAsync: async () => ({ result: '{"version":999,"accounts":[]}' }) });
    await fs.writeFile(vault.file, 'encrypted'); await assert.rejects(vault.load(), { code: 'vaultUnavailable' });
  } finally { await fs.rm(dir, { recursive: true, force: true }); }
});
