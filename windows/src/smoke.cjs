'use strict';
// Runs only with --smoke-test in a fresh temporary profile and public demo data.
// The Windows CI job exercises actual DPAPI and the packaged UI.
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
module.exports = async ({ window, vault, accounts, directory, lock, reload, state, scanImage }) => {
  const evaluate = code => window.webContents.executeJavaScript(code);
  async function screenshot(file) {
    await evaluate('new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))');
    await fs.writeFile(file, (await window.webContents.capturePage()).toPNG());
  }
  async function until(expression) {
    for (let i = 0; i < 100; i++) { if (await evaluate(expression)) return; await new Promise(resolve => setTimeout(resolve, 50)); }
    throw new Error('UI timeout: ' + expression);
  }
  if (process.platform === 'win32') {
    await vault.save(accounts); const loaded = await vault.load(); assert.equal(loaded.length, 4);
    const encrypted = await fs.readFile(vault.file); assert(!encrypted.includes(Buffer.from(accounts[0].secret))); assert(!encrypted.includes(Buffer.from('hello@example.com')));
  }
  await until('document.querySelectorAll(".card").length === 4');
  assert.equal(await evaluate('typeof require'), 'undefined'); assert.equal(await evaluate('typeof process'), 'undefined');
  assert.equal((await evaluate('window.quickAuth.call("not-a-method")')).ok, false);
  assert.equal((await evaluate('window.quickAuth.call("state")')).value.accounts.some(a => 'secret' in a), false);
  await evaluate('window.quickAuth.call("language", {value:"en"})');
  await until('document.documentElement.lang === "en"');
  await evaluate('document.getElementById("search").value="github"; document.getElementById("search").dispatchEvent(new Event("input"))');
  assert.equal(await evaluate('document.querySelectorAll(".card").length'), 1);
  await evaluate('document.getElementById("search").value=""; document.getElementById("search").dispatchEvent(new Event("input"))');
  const out = process.env.QUICKAUTH_SCREENSHOTS || directory; await fs.mkdir(out, { recursive: true });
  await screenshot(path.join(out, 'windows-en.png'));
  await evaluate('document.getElementById("addButton").click()'); await until('document.body.dataset.view === "add"');
  await evaluate('document.querySelector("[data-source=manual]").click()'); await until('!document.getElementById("manualSource").hidden');
  await evaluate('const f=document.getElementById("manualForm"); f.elements.issuer.value="Smoke Test"; f.elements.account.value="public@example.com"; f.elements.secret.value="JBSWY3DPEHPK3PXP"; f.dispatchEvent(new Event("input")); document.getElementById("previewButton").click()');
  await until('!document.getElementById("preview").hidden');
  await evaluate('document.getElementById("importButton").click()'); await until('document.body.dataset.view === "home" && document.querySelectorAll(".card").length === 5');
  await evaluate('window.quickAuth.call("language", {value:"zh-CN"})'); await until('document.documentElement.lang === "zh-CN"');
  await evaluate('document.getElementById("exportButton").click()'); await until('document.body.dataset.view === "export"');
  assert.equal(await evaluate('document.querySelector("#export h2").textContent'), '导出备份');
  assert.equal(await evaluate('document.getElementById("saveExport").disabled'), true);
  await screenshot(path.join(out, 'windows-export-zh.png'));
  await evaluate('document.getElementById("cancel").click()'); await until('document.body.dataset.view === "home"');
  if (process.platform === 'win32') {
    lock(); assert.equal(state().accounts.length, 0); assert.equal(state().locked, true);
    await reload(); assert.equal(state().accounts.length, 5); assert.equal(state().locked, false);
    const originalLoad = vault.load.bind(vault);
    lock(); vault.load = async () => { throw new Error('temporary DPAPI failure'); };
    await reload(); assert.equal(state().loadFailed, true); assert.equal(state().locked, false);
    vault.load = originalLoad; await reload(); assert.equal(state().accounts.length, 5); assert.equal(state().loadFailed, false);
  }
  // QR test data contains an RFC test secret, never a personal account.
  const qrPath = process.env.QUICKAUTH_QR_FIXTURE;
  if (qrPath) {
    const { nativeImage } = require('electron'); const result = await scanImage(nativeImage.createFromPath(qrPath));
    assert.equal(result.accounts[0].issuer, 'QR Public Fixture'); assert.equal(result.accounts[0].account, 'public@example.com');
  }
  console.log('Smoke passed: isolated renderer, bilingual UI, search, manual import, export form, QR fixture' + (process.platform === 'win32' ? ', DPAPI save/load and session lock.' : ' (Windows DPAPI checks run in Windows CI).'));
};
