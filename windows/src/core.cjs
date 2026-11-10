'use strict';
const crypto = require('node:crypto');
const { promisify } = require('node:util');
const { argon2id, argon2Verify } = require('hash-wasm');
const pbkdf2 = promisify(crypto.pbkdf2);
const MAX_BYTES = 5 * 1024 * 1024;
const MAX_COUNTER = (1n << 64n) - 1n;
const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
class AuthError extends Error {
  constructor(code) { super(code); this.code = code; }
}
function fail(code) { throw new AuthError(code); }
function base32Decode(input) {
  if (typeof input !== 'string' || input.length > 8192) fail('invalidSecret');
  const text = input.toUpperCase().replace(/[\s-]/gu, '');
  const match = /^([A-Z2-7]+)(=*)$/.exec(text);
  if (!match) fail('invalidSecret');
  const required = { 0: 0, 2: 6, 4: 4, 5: 3, 7: 1 }[match[1].length % 8];
  if (required === undefined || (match[2].length && match[2].length !== required)) fail('invalidSecret');
  let buffer = 0, bits = 0; const bytes = [];
  for (const char of match[1]) {
    buffer = (buffer << 5) | alphabet.indexOf(char); bits += 5;
    if (bits >= 8) { bits -= 8; bytes.push((buffer >>> bits) & 255); }
    buffer &= (1 << bits) - 1;
  }
  if (buffer || !bytes.length || bytes.length > 1024) fail('invalidSecret');
  return Buffer.from(bytes);
}
function base32Encode(bytes) {
  let result = '', buffer = 0, bits = 0;
  for (const byte of bytes) {
    buffer = (buffer << 8) | byte; bits += 8;
    while (bits >= 5) { bits -= 5; result += alphabet[(buffer >>> bits) & 31]; }
    buffer &= (1 << bits) - 1;
  }
  if (bits) result += alphabet[(buffer << (5 - bits)) & 31];
  return result;
}
function integer(value, fallback, min, max) {
  if (value === undefined) return fallback;
  if ((typeof value !== 'string' && typeof value !== 'number') || !/^\d+$/.test(String(value))) fail('invalidParameter');
  const number = Number(value);
  if (!Number.isSafeInteger(number) || number < min || number > max) fail('invalidParameter');
  return number;
}
function counterValue(value = '0') {
  if (!['string', 'number'].includes(typeof value) || !/^\d+$/.test(String(value))) fail('invalidCounter');
  if (typeof value === 'number' && !Number.isSafeInteger(value)) fail('invalidCounter');
  const counter = BigInt(value);
  if (counter > MAX_COUNTER) fail('invalidCounter');
  return counter.toString();
}
function parseRecord(record) {
  if (!record || typeof record !== 'object' || Array.isArray(record)) fail('invalidRecord');
  const types = { 1: 'totp', 2: 'hotp', 3: 'battle', 4: 'steam', 5: 'hex', 6: 'hhex' };
  let type = record.type === undefined ? 'totp' : typeof record.type === 'string' ? record.type.toLowerCase() : types[record.type];
  let secret = record.secret;
  if (typeof secret !== 'string') fail('invalidSecret');
  for (const [prefix, kind] of [['stm-', 'steam'], ['blz-', 'battle'], ['bliz-', 'battle']]) {
    if (secret.startsWith(prefix)) { secret = secret.slice(prefix.length); type = kind; break; }
  }
  if (!Object.values(types).includes(type)) fail('invalidType');
  let bytes;
  if (['hex', 'hhex'].includes(type)) {
    secret = secret.replace(/\s/gu, '');
    if (!/^(?:[0-9a-f]{2})+$/i.test(secret) || secret.length > 2048) fail('invalidSecret');
    bytes = Buffer.from(secret, 'hex');
  } else bytes = base32Decode(secret);
  let algorithm = record.algorithm === undefined ? 'SHA1' : typeof record.algorithm === 'string' ? record.algorithm.toUpperCase().replace(/-/g, '') : { 1: 'SHA1', 2: 'SHA256', 3: 'SHA512' }[record.algorithm];
  if (!['SHA1', 'SHA256', 'SHA512'].includes(algorithm)) fail('invalidAlgorithm');
  const issuer = typeof record.issuer === 'string' ? record.issuer : '';
  const account = typeof record.account === 'string' ? record.account : '';
  if ([...issuer].length > 512 || [...account].length > 512) fail('nameTooLong');
  const parsedDigits = integer(record.digits, 6, 6, 10);
  return { id: crypto.randomUUID(), issuer, account, secret: base32Encode(bytes),
    kind: ['hotp', 'hhex'].includes(type) ? 'hotp' : type === 'steam' ? 'steam' : 'totp',
    algorithm, digits: type === 'battle' ? 8 : type === 'steam' ? 6 : parsedDigits,
    period: integer(record.period, 30, 1, 86400), counter: counterValue(record.counter), favorite: record.pinned === true };
}
function validateAccount(account) {
  const parsed = parseRecord({ ...account, type: account.kind, pinned: account.favorite });
  if (typeof account.id !== 'string' || !/^[\da-f-]{36}$/i.test(account.id) || !['totp', 'hotp', 'steam'].includes(account.kind)) fail('invalidRecord');
  return { ...parsed, id: account.id };
}
function manualAccount(input) {
  if (!input || typeof input !== 'object') fail('invalidRecord');
  if (!String(input.issuer ?? '').trim() && !String(input.account ?? '').trim()) fail('nameRequired');
  let type = input.kind;
  if (!['totp', 'hotp', 'steam'].includes(type)) fail('invalidType');
  let secret = input.secret;
  if (input.hexadecimal) {
    secret = String(secret).replace(/\s/g, '');
    if (!/^(?:[0-9a-f]{2})+$/i.test(secret) || secret.length > 2048) fail('invalidSecret');
    secret = base32Encode(Buffer.from(secret, 'hex'));
  }
  return parseRecord({ ...input, type, secret, counter: type === 'hotp' ? input.counter : '0', period: type === 'hotp' ? 30 : input.period });
}
function parseURI(text) {
  let url; try { url = new URL(text); } catch { fail('invalidURI'); }
  if (url.protocol !== 'otpauth:' || !['totp', 'hotp', 'steam'].includes(url.hostname) || url.username || url.password || url.port || url.hash) fail('invalidURI');
  const values = Object.create(null);
  for (const [key, value] of url.searchParams) {
    const name = key.toLowerCase();
    if (Object.hasOwn(values, name) || !value) fail('invalidURI');
    values[name] = value;
  }
  if (values.encoder && values.encoder.toLowerCase() !== 'steam') fail('invalidType');
  if (url.hostname === 'hotp' && values.counter === undefined) fail('invalidCounter');
  let label; try { label = decodeURIComponent(url.pathname.replace(/^\//, '')); } catch { fail('invalidURI'); }
  const colon = label.indexOf(':');
  return parseRecord({ ...values, type: url.hostname === 'hotp' ? 'hotp' : (url.hostname === 'steam' || values.encoder?.toLowerCase() === 'steam') ? 'steam' : 'totp', issuer: values.issuer ?? (colon >= 0 ? label.slice(0, colon) : ''), account: colon >= 0 ? label.slice(colon + 1) : label });
}
function code(account, seconds = Date.now() / 1000) {
  const count = account.kind === 'hotp' ? BigInt(account.counter) : BigInt(Math.max(0, Math.floor(seconds / account.period)));
  const message = Buffer.alloc(8); message.writeBigUInt64BE(count);
  const digest = crypto.createHmac(account.algorithm.toLowerCase(), base32Decode(account.secret)).update(message).digest();
  let number = digest.readUInt32BE(digest[digest.length - 1] & 15) & 0x7fffffff;
  if (account.kind === 'steam') {
    const chars = '23456789BCDFGHJKMNPQRTVWXY'; let value = '';
    for (let i = 0; i < 5; i++) { value += chars[number % chars.length]; number = Math.floor(number / chars.length); }
    return value;
  }
  return (number % (10 ** account.digits)).toString().padStart(account.digits, '0');
}
function fingerprint(a) {
  return crypto.createHash('sha256').update([base32Decode(a.secret).toString('base64'), a.kind, a.algorithm, a.digits, a.period].join('|')).digest('hex');
}
function merge(existing, incoming) {
  const accounts = [...existing], known = new Set(existing.map(fingerprint)); let duplicates = 0;
  for (const a of incoming) { const key = fingerprint(a); if (known.has(key)) duplicates++; else { known.add(key); accounts.push(a); } }
  if (accounts.length > 5000) fail('tooMany');
  return { accounts, added: accounts.length - existing.length, duplicates };
}
// Preserve UInt64 counters written as JSON numbers by the Swift exporter.
// Only integer tokens outside quoted strings are rewritten; JSON.parse still
// validates the complete grammar and no object properties are executed.
function parseJSON(text) {
  const normalized = text.replace(/"(?:\\.|[^"\\])*"|-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?/g, token => {
    if (/^-?\d+$/.test(token) && !Number.isSafeInteger(Number(token))) return JSON.stringify(token);
    return token;
  });
  try { return JSON.parse(normalized); } catch { fail('invalidJSON'); }
}
function decode64(text) {
  if (typeof text !== 'string' || !/^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(text)) fail('decryptFailed');
  return Buffer.from(text, 'base64');
}
function legacyDecrypt(encoded, password) {
  try {
    const payload = decode64(encoded);
    if (payload.length < 32 || payload.subarray(0, 8).toString() !== 'Salted__' || (payload.length - 16) % 16) fail('decryptFailed');
    const salt = payload.subarray(8, 16), pass = Buffer.from(password, 'utf8');
    let material = Buffer.alloc(0), previous = Buffer.alloc(0);
    while (material.length < 48) { previous = crypto.createHash('md5').update(Buffer.concat([previous, pass, salt])).digest(); material = Buffer.concat([material, previous]); }
    const cipher = crypto.createDecipheriv('aes-256-cbc', material.subarray(0, 32), material.subarray(32, 48));
    return Buffer.concat([cipher.update(payload.subarray(16)), cipher.final()]);
  } catch { fail('decryptFailed'); }
}
async function unlockKey(key, password) {
  if (typeof key.salt !== 'string' || Buffer.byteLength(key.salt) < 8 || Buffer.byteLength(key.salt) > 1024 || typeof key.hash !== 'string' || key.hash.length > 512) fail('decryptFailed');
  const match = /^\$argon2id\$v=19\$m=(\d+),t=(\d+),p=(\d+)\$([A-Za-z0-9+/]+)\$([A-Za-z0-9+/]+)$/.exec(key.hash);
  if (!match || +match[1] < 8 || +match[1] > 65536 || +match[2] < 1 || +match[2] > 10 || +match[3] < 1 || +match[3] > 4) fail('decryptFailed');
  try {
    const bytes = await argon2id({ password, salt: key.salt, iterations: 2, memorySize: 19456, parallelism: 1, hashLength: 32, outputType: 'binary' });
    const phrase = Buffer.from(bytes).toString('base64').replace(/=+$/, '');
    if (!await argon2Verify({ password: phrase, hash: key.hash })) fail('decryptFailed');
    return phrase;
  } catch { fail('decryptFailed'); }
}
async function decryptEnvelope(envelope, password) {
  if (envelope.version !== 1 || envelope.kdf !== 'PBKDF2-SHA256' || envelope.cipher !== 'AES-256-GCM' || !Number.isInteger(envelope.iterations) || envelope.iterations < 100000 || envelope.iterations > 2000000) fail('invalidBackup');
  const salt = decode64(envelope.salt), combined = decode64(envelope.data);
  if (salt.length !== 16 || combined.length < 28) fail('invalidBackup');
  if (!password) fail('passwordRequired');
  if (typeof password !== 'string' || Buffer.byteLength(password) > 4096) fail('decryptFailed');
  try {
    const key = await pbkdf2(password, salt, envelope.iterations, 32, 'sha256');
    const cipher = crypto.createDecipheriv('aes-256-gcm', key, combined.subarray(0, 12));
    cipher.setAAD(Buffer.from('QuickAuth backup v1'));
    cipher.setAuthTag(combined.subarray(-16));
    const plaintext = Buffer.concat([cipher.update(combined.subarray(12, -16)), cipher.final()]);
    key.fill(0); return parseJSON(new TextDecoder('utf-8', { fatal: true }).decode(plaintext));
  } catch { fail('decryptFailed'); }
}
async function parseBackup(input, password) {
  if (!Buffer.isBuffer(input) && typeof input !== 'string') fail('invalidBackup');
  if (Buffer.byteLength(input) > MAX_BYTES) fail('tooLarge');
  if (password !== undefined && (typeof password !== 'string' || Buffer.byteLength(password) > 4096)) fail('decryptFailed');
  let text; try { text = new TextDecoder('utf-8', { fatal: true }).decode(Buffer.from(input)).replace(/^\uFEFF/, '').trim(); } catch { fail('invalidBackup'); }
  if (!text) fail('emptyBackup');
  if (!/^[{[]/.test(text)) {
    const lines = text.split(/\r?\n/); if (lines.length > 10000) fail('tooMany');
    const accounts = [], issues = [];
    lines.forEach((line, i) => { if (!line.trim() || line.trim().startsWith('#')) return; try { accounts.push(parseURI(line.trim())); } catch (e) { issues.push({ position: i + 1, reason: e.code || 'invalidURI' }); } });
    if (accounts.length > 5000) fail('tooMany');
    if (!accounts.length && !issues.length) fail('emptyBackup');
    return { accounts, issues };
  }
  let root = parseJSON(text);
  if (root?.format === 'quickauth') root = await decryptEnvelope(root, password);
  if (!root || typeof root !== 'object') fail('emptyBackup');
  let records = Array.isArray(root) ? root.map((v, i) => [String(i), v]) : root.secret !== undefined ? [['0', root]] : Object.entries(root).filter(([key]) => !['key', 'enc', 'hash', 'UserSettings', 'LocalStorage'].includes(key));
  records = records.filter(([, r]) => r?.dataType !== 'Key');
  if (records.length > 5000) fail('tooMany');
  const order = ([key, r]) => Number.isSafeInteger(r?.index) ? r.index : /^\d+$/.test(key) ? Number(key) : Number.MAX_SAFE_INTEGER;
  records.sort((a, b) => order(a) - order(b) || a[0].localeCompare(b[0]));
  const encrypted = records.some(([, r]) => r?.encrypted === true || r?.dataType === 'EncOTPStorage');
  if (encrypted && !password) fail('passwordRequired');
  let phrase = password || '';
  const wrapped = root.key?.enc ?? root.enc;
  if (encrypted && wrapped !== undefined) phrase = legacyDecrypt(wrapped, phrase).toString('hex');
  const unlocked = new Map(), accounts = [], issues = [];
  for (let i = 0; i < records.length; i++) {
    let record = records[i][1];
    if (record?.dataType === 'EncOTPStorage') {
      const key = Object.hasOwn(root, record.keyId) ? root[record.keyId] : null;
      if (!key || key.dataType !== 'Key' || key.id !== record.keyId || typeof record.data !== 'string') fail('decryptFailed');
      if (!unlocked.has(record.keyId)) unlocked.set(record.keyId, await unlockKey(key, password));
      try { record = parseJSON(new TextDecoder('utf-8', { fatal: true }).decode(legacyDecrypt(record.data, unlocked.get(record.keyId)))); if (typeof record.secret !== 'string') fail('decryptFailed'); } catch { fail('decryptFailed'); }
    } else if (record?.encrypted === true) {
      try { record = { ...record, secret: new TextDecoder('utf-8', { fatal: true }).decode(legacyDecrypt(record.secret, phrase)) }; } catch { fail('decryptFailed'); }
    }
    try { accounts.push(parseRecord(record)); } catch (error) { issues.push({ position: i + 1, reason: error.code || 'invalidRecord' }); }
  }
  if (!accounts.length && !issues.length) fail('emptyBackup');
  return { accounts, issues };
}
function plaintextBackup(accounts) {
  if (!accounts.length) fail('emptyBackup'); if (accounts.length > 5000) fail('tooMany');
  const records = Object.create(null);
  accounts.forEach((a, index) => {
    a = validateAccount(a);
    records[a.id] = { dataType: 'OTPStorage', hash: a.id, index, type: a.kind, issuer: a.issuer, account: a.account, secret: a.secret, algorithm: a.algorithm, digits: a.digits, period: a.period, counter: BigInt(a.counter) <= BigInt(Number.MAX_SAFE_INTEGER) ? Number(a.counter) : a.counter, pinned: a.favorite, encrypted: false };
  });
  const bytes = Buffer.from(JSON.stringify(records, null, 2)); if (bytes.length > MAX_BYTES) fail('tooLarge');
  return bytes;
}
async function encryptedBackup(accounts, password) {
  if (typeof password !== 'string' || [...password].length < 8 || Buffer.byteLength(password) > 4096) fail('passwordLength');
  const plain = plaintextBackup(accounts), salt = crypto.randomBytes(16), nonce = crypto.randomBytes(12);
  const key = await pbkdf2(password, salt, 600000, 32, 'sha256');
  const cipher = crypto.createCipheriv('aes-256-gcm', key, nonce);
  cipher.setAAD(Buffer.from('QuickAuth backup v1'));
  const ciphertext = Buffer.concat([cipher.update(plain), cipher.final()]);
  const combined = Buffer.concat([nonce, ciphertext, cipher.getAuthTag()]); key.fill(0);
  const bytes = Buffer.from(JSON.stringify({ format: 'quickauth', version: 1, kdf: 'PBKDF2-SHA256', iterations: 600000, salt: salt.toString('base64'), cipher: 'AES-256-GCM', data: combined.toString('base64') }, null, 2));
  if (bytes.length > MAX_BYTES) fail('tooLarge'); return bytes;
}
module.exports = { AuthError, MAX_BYTES, MAX_COUNTER, base32Encode, base32Decode, parseRecord, validateAccount, manualAccount, parseURI, code, fingerprint, merge, parseJSON, parseBackup, plaintextBackup, encryptedBackup };
