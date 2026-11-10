'use strict';
const fs = require('node:fs/promises');
const path = require('node:path');
const crypto = require('node:crypto');
const { validateAccount, AuthError } = require('./core.cjs');
async function atomicWrite(destination, bytes) {
  const temporary = path.join(path.dirname(destination), `.quick-auth-${crypto.randomUUID()}.tmp`);
  let handle;
  try {
    handle = await fs.open(temporary, 'wx', 0o600);
    await handle.writeFile(bytes); await handle.sync(); await handle.close(); handle = null;
    await fs.rename(temporary, destination);
  } finally { await handle?.close().catch(() => {}); await fs.rm(temporary, { force: true }).catch(() => {}); }
}
class Vault {
  constructor(directory, safeStorage) { this.directory = directory; this.file = path.join(directory, 'accounts.vault'); this.crypto = safeStorage; }
  async ready() { if (!await this.crypto.isAsyncEncryptionAvailable()) throw new AuthError('vaultUnavailable'); }
  async load() {
    await this.ready();
    let encrypted;
    try { encrypted = await fs.readFile(this.file); } catch (error) { if (error.code === 'ENOENT') return []; throw new AuthError('vaultUnavailable'); }
    try {
      if (encrypted.length > 12 * 1024 * 1024) throw new Error();
      const { result } = await this.crypto.decryptStringAsync(encrypted);
      const envelope = JSON.parse(result);
      if (envelope.version !== 1 || !Array.isArray(envelope.accounts) || envelope.accounts.length > 5000) throw new Error();
      const accounts = envelope.accounts.map(validateAccount);
      if (new Set(accounts.map(a => a.id)).size !== accounts.length) throw new Error();
      return accounts;
    } catch { throw new AuthError('vaultUnavailable'); }
  }
  async save(accounts) {
    await this.ready();
    if (accounts.length > 5000) throw new AuthError('tooMany');
    const validated = accounts.map(validateAccount);
    if (new Set(validated.map(a => a.id)).size !== validated.length) throw new AuthError('invalidRecord');
    const encrypted = await this.crypto.encryptStringAsync(JSON.stringify({ version: 1, accounts: validated }));
    await fs.mkdir(this.directory, { recursive: true, mode: 0o700 });
    await atomicWrite(this.file, encrypted);
  }
}
module.exports = { Vault, atomicWrite };
