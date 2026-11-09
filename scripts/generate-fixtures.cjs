// Synthetic fixtures only. Run with the directory containing crypto-js/package
// and argon-browser/package (crypto-js 4.2.0 / argon2-browser 1.18.0).
const fs = require('fs');
const path = require('path');
global.fetch = undefined; // Use the WASM loader's filesystem path in Node.
const root = process.argv[2];
const CryptoJS = require(path.join(root, 'crypto-js/package'));
const argon2 = require(path.join(root, 'argon-browser/package'));
const output = path.join(__dirname, '../Tests/QuickAuthCoreTests/Fixtures');
const password = 'quick-auth-test-密码';
const secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';
const entry = { dataType: 'OTPStorage', type: 'totp', issuer: 'Fixture 测试', account: 'test@example.com', secret, digits: 8, index: 0, encrypted: false };
function aes(text, pass) {
  return CryptoJS.AES.encrypt(text, pass, { salt: CryptoJS.enc.Hex.parse('0102030405060708') }).toString();
}
function write(name, data) { fs.writeFileSync(path.join(output, name + '.json'), JSON.stringify(data, null, 2) + '\n'); }
async function hash(pass, salt) { return argon2.hash({ pass, salt, time: 2, mem: 19456, parallelism: 1, hashLen: 32, type: argon2.ArgonType.Argon2id }); }
(async () => {
  write('plain', { fixture: entry });
  write('encrypted-v1', { fixture: { ...entry, encrypted: true, secret: aes(secret, password) } });
  const oldKey = CryptoJS.enc.Hex.parse('00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff');
  write('encrypted-v2', { key: { enc: aes(oldKey, password), hash: 'synthetic-verifier' }, fixture: { ...entry, encrypted: true, secret: aes(secret, oldKey.toString()) } });
  const salt = 'synthetic-key-salt';
  const derived = (await hash(password, salt)).encoded.split('$')[5];
  const verifier = (await hash(derived, 'synthetic-verifier-salt')).encoded;
  write('encrypted-v3', {
    'fixture-key': { dataType: 'Key', id: 'fixture-key', salt, hash: verifier },
    fixture: { dataType: 'EncOTPStorage', keyId: 'fixture-key', index: 0, data: aes(JSON.stringify(entry), derived) }
  });
  console.log('Generated 4 synthetic backup fixtures using the extension’s JS libraries.');
})();
