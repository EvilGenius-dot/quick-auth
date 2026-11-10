'use strict';
const fs = require('node:fs/promises');
const path = require('node:path');
const assert = require('node:assert/strict');
const core = require('../src/core.cjs');
const root = process.env.QUICKAUTH_INTEROP_DIR;
if (!root) throw new Error('QUICKAUTH_INTEROP_DIR is required');
(async () => {
  if (process.argv[2] === 'create') {
    const accounts = [core.parseRecord({ issuer: 'Cross-platform 测试', account: 'public@example.com', secret: 'JBSWY3DPEHPK3PXP', pinned: true }), core.parseRecord({ issuer: 'HOTP', secret: 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ', type: 'hotp', counter: '18446744073709551615' })];
    await fs.writeFile(path.join(root, 'windows.json'), await core.encryptedBackup(accounts, 'public-interop-密码'));
  } else {
    const result = await core.parseBackup(await fs.readFile(path.join(root, 'macos.json')), 'public-interop-密码');
    assert.equal(result.accounts.length, 2); assert.equal(result.accounts[0].issuer, 'Cross-platform 测试'); assert.equal(result.accounts[0].favorite, true); assert.equal(result.accounts[1].counter, '18446744073709551615');
    console.log('Windows → macOS → Windows encrypted backup interoperability passed.');
  }
})().catch(e => { console.error(e.message); process.exitCode = 1; });
