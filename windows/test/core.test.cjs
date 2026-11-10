'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const core = require('../src/core.cjs');
const fixtures = path.join(__dirname, '../../Tests/QuickAuthCoreTests/Fixtures');
const secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';
const account = (props = {}) => core.parseRecord({ issuer: 'Public fixture', account: 'test@example.com', secret, ...props });
test('RFC 4226 HOTP vectors', () => {
  const codes = ['755224', '287082', '359152', '969429', '338314', '254676', '287922', '162583', '399871', '520489'];
  codes.forEach((expected, counter) => assert.equal(core.code(account({ type: 'hotp', counter })), expected));
});
test('RFC 6238 all SHA1, SHA256 and SHA512 vectors', () => {
  const seconds = [59, 1111111109, 1111111111, 1234567890, 2000000000, 20000000000];
  const vectors = { SHA1: ['94287082', '07081804', '14050471', '89005924', '69279037', '65353130'], SHA256: ['46119246', '68084774', '67062674', '91819424', '90698825', '77737706'], SHA512: ['90693936', '25091201', '99943326', '93441116', '38618901', '47863826'] };
  for (const [algorithm, expected] of Object.entries(vectors)) {
    const length = { SHA1: 20, SHA256: 32, SHA512: 64 }[algorithm];
    const a = account({ algorithm, digits: 8, secret: core.base32Encode(Buffer.from('1234567890'.repeat(7).slice(0, length))) });
    seconds.forEach((second, index) => assert.equal(core.code(a, second), expected[index]));
  }
});
test('Base32 strict decoding and RFC 4648 vectors', () => {
  for (const [plain, encoded] of [['f', 'MY======'], ['fo', 'MZXQ===='], ['foo', 'MZXW6==='], ['foob', 'MZXW6YQ='], ['fooba', 'MZXW6YTB'], ['foobar', 'MZXW6YTBOI======']]) {
    assert.equal(core.base32Decode(encoded).toString(), plain); assert.equal(core.base32Encode(Buffer.from(plain)), encoded.replace(/=/g, ''));
  }
  for (const invalid of ['', 'A', 'MZ', 'MY=', 'MY======x', '000000', 'MY======' + '=']) assert.throws(() => core.base32Decode(invalid));
});
test('time period boundaries, Steam and hexadecimal input', () => {
  const a = account(); assert.equal(core.code(a, 29.99), core.code(a, 0)); assert.notEqual(core.code(a, 30), core.code(a, 29));
  assert.match(core.code(account({ type: 'steam' }), 59), /^[23456789BCDFGHJKMNPQRTVWXY]{5}$/);
  assert.equal(core.manualAccount({ issuer: 'Hex', kind: 'totp', secret: '3132333435363738393031323334353637383930', hexadecimal: true }).secret, secret);
});
test('otpauth links and invalid parameters', () => {
  const uri = `otpauth://totp/Example:test%40example.com?secret=${secret}&issuer=Example&digits=8`;
  assert.equal(core.parseURI(uri).account, 'test@example.com');
  for (const value of [uri + '&digits=6', uri.replace('digits=8', 'digits=abc'), uri.replace('totp', 'hotp'), 'https://example.com', 'otpauth-migration://offline?data=abc']) assert.throws(() => core.parseURI(value));
  for (const props of [{ digits: true }, { digits: 5 }, { period: 0 }, { counter: -1 }, { counter: 1.1 }, { algorithm: 'GOST' }, { type: true }, { type: 1.5 }, { algorithm: false }, { secret: 'ABCD1' }]) assert.throws(() => account(props));
});
test('deduplication never rewinds an existing HOTP counter', () => {
  const newer = account({ type: 'hotp', counter: 98 }); const older = account({ type: 'hotp', counter: 2 });
  const result = core.merge([newer], [older]); assert.equal(result.added, 0); assert.equal(result.duplicates, 1); assert.equal(result.accounts[0].counter, '98');
});
for (const fixture of ['plain', 'encrypted-v1', 'encrypted-v2', 'encrypted-v3']) {
  test(`Chrome Authenticator ${fixture} fixture`, async () => {
    const data = fs.readFileSync(path.join(fixtures, fixture + '.json'));
    const result = await core.parseBackup(data, 'quick-auth-test-密码');
    assert.equal(result.accounts.length, 1); assert.equal(result.accounts[0].issuer, 'Fixture 测试'); assert.equal(core.code(result.accounts[0], 59), '94287082'); assert.deepEqual(result.issues, []);
    if (fixture !== 'plain') { await assert.rejects(core.parseBackup(data), { code: 'passwordRequired' }); await assert.rejects(core.parseBackup(data, 'wrong-password'), { code: 'decryptFailed' }); }
  });
}
test('Argon2 verifier resource limits and missing keys are rejected', async () => {
  const data = JSON.parse(fs.readFileSync(path.join(fixtures, 'encrypted-v3.json')));
  data['fixture-key'].hash = data['fixture-key'].hash.replace('m=19456', 'm=999999999');
  await assert.rejects(core.parseBackup(JSON.stringify(data), 'quick-auth-test-密码'), { code: 'decryptFailed' });
  delete data['fixture-key']; await assert.rejects(core.parseBackup(JSON.stringify(data), 'quick-auth-test-密码'), { code: 'decryptFailed' });
});
test('plaintext and encrypted roundtrip retain metadata and full UInt64 counters', async () => {
  const accounts = [account({ pinned: true, period: 60, digits: 8, algorithm: 'SHA256' }), account({ type: 'hotp', counter: '18446744073709551615' })];
  for (const data of [core.plaintextBackup(accounts), await core.encryptedBackup(accounts, 'public-test-密码')]) {
    const imported = await core.parseBackup(data, 'public-test-密码');
    assert.equal(imported.accounts[0].favorite, true); assert.equal(imported.accounts[0].period, 60); assert.equal(imported.accounts[0].algorithm, 'SHA256'); assert.equal(imported.accounts[1].counter, '18446744073709551615');
    assert.deepEqual(imported.accounts.map(core.fingerprint), accounts.map(core.fingerprint));
  }
  const swiftNumber = core.plaintextBackup(accounts).toString().replace('"18446744073709551615"', '18446744073709551615');
  assert.equal((await core.parseBackup(swiftNumber)).accounts[1].counter, '18446744073709551615');
});
test('AES-GCM randomizes salt/nonce and detects wrong password and tampering', async () => {
  const a = await core.encryptedBackup([account()], 'public-test-密码'), b = await core.encryptedBackup([account()], 'public-test-密码');
  assert.notEqual(a.toString(), b.toString()); assert.equal(a.includes(Buffer.from(secret)), false); assert.equal(a.includes(Buffer.from('Public fixture')), false);
  await assert.rejects(core.parseBackup(a, 'wrong-password'), { code: 'decryptFailed' });
  const obj = JSON.parse(a); const ciphertext = Buffer.from(obj.data, 'base64'); ciphertext[20] ^= 1; obj.data = ciphertext.toString('base64');
  await assert.rejects(core.parseBackup(JSON.stringify(obj), 'public-test-密码'), { code: 'decryptFailed' });
  obj.iterations = 999999999; await assert.rejects(core.parseBackup(JSON.stringify(obj), 'public-test-密码'), { code: 'invalidBackup' });
  await assert.rejects(core.encryptedBackup([account()], 'short'), { code: 'passwordLength' });
});
test('invalid records require explicit partial import; empty, malformed and oversized files fail', async () => {
  const list = Array.from({ length: 12 }, (_, i) => ({ issuer: String(i), secret }));
  list.push({ secret: 'INVALID!' });
  const result = await core.parseBackup('\uFEFF' + JSON.stringify(list));
  assert.deepEqual(result.accounts.map(a => a.issuer), Array.from({ length: 12 }, (_, i) => String(i))); assert.equal(result.issues.length, 1);
  for (const invalid of ['', '{}', '[', Buffer.alloc(core.MAX_BYTES + 1), Buffer.from([0xff])]) await assert.rejects(core.parseBackup(invalid));
});
