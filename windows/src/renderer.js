'use strict';
const $ = id => document.getElementById(id);
let model, view = 'home', source = 'file', onlyFavorites = false, hasFile = false, pendingPreview = null, processing = false, cardSignature = '', operation = 0;
async function call(method, args) { const response = await window.quickAuth.call(method, args); if (!response.ok) { const error = new Error(response.error); error.code = response.error; throw error; } return response.value; }
function notice(message, error = false) { $('notice').textContent = message; $('notice').hidden = !message; $('notice').classList.toggle('error', error); }
async function action(fn) {
  if (processing) return;
  const token = ++operation; processing = true; document.body.dataset.busy = 'true'; $('working').hidden = false; updateButtons(); notice('');
  try { await fn(token); } catch (e) { if (token === operation && e.code !== 'cancelled') notice(t(e.code || 'actionFailed'), true); }
  finally { if (token === operation) { processing = false; document.body.dataset.busy = 'false'; $('working').hidden = true; updateButtons(); } }
}
function resetPreview() { pendingPreview = null; $('preview').hidden = true; $('allowPartial').checked = false; updateButtons(); }
function clearForms() { resetPreview(); hasFile = false; $('filename').textContent = t('chooseHint'); $('backupText').value = ''; $('importPassword').value = ''; $('exportPassword').value = ''; $('confirmation').value = ''; $('acceptPlaintext').checked = false; $('passwordField').hidden = true; $('manualForm').reset(); updateManual(); }
async function go(next) {
  operation++; processing = false; document.body.dataset.busy = 'false'; $('working').hidden = true;
  await call('cancelPreview'); clearForms(); notice(''); view = next; document.body.dataset.view = view;
  for (const page of ['home', 'add', 'export']) $(page).hidden = page !== view;
  $('homeFooter').hidden = view !== 'home'; $('formFooter').hidden = view === 'home';
  $('settings').open = false; $('exportFormat').value = 'encrypted'; updateExport();
  $('exportCount').textContent = t('exportCount', { n: model?.accounts.length || 0 });
  await call('view', { value: next }); updateButtons();
  if (next === 'home') $('search').focus();
}
function updateButtons() {
  $('previewButton').hidden = view !== 'add' || !!pendingPreview || source === 'qr';
  $('importButton').hidden = view !== 'add' || !pendingPreview;
  $('saveExport').hidden = view !== 'export';
  $('previewButton').disabled = processing || (source === 'file' && !hasFile) || (source === 'text' && !$('backupText').value.trim());
  $('importButton').disabled = processing || !pendingPreview?.accounts.length || (pendingPreview.issues.length > 0 && !$('allowPartial').checked);
  const encrypted = $('exportFormat').value === 'encrypted';
  $('saveExport').disabled = processing || !model?.accounts.length || (encrypted ? [...$('exportPassword').value].length < 8 || $('exportPassword').value !== $('confirmation').value : !$('acceptPlaintext').checked);
}
function updateManual() { const kind = $('manualForm').elements.kind.value; $('periodField').hidden = kind === 'hotp'; $('counterField').hidden = kind !== 'hotp'; $('digitsField').hidden = kind === 'steam'; }
function updateExport() { const encrypted = $('exportFormat').value === 'encrypted'; $('encryptedFields').hidden = !encrypted; $('plaintextFields').hidden = encrypted; updateButtons(); }
function displayPreview(value) {
  if (!value) return;
  pendingPreview = value; $('preview').hidden = false; $('previewAccounts').replaceChildren(); $('previewIssues').replaceChildren();
  $('previewCount').textContent = t('previewCount', value);
  for (const a of value.accounts) { const row = document.createElement('div'); row.className = 'preview-row'; const title = document.createElement('strong'); title.textContent = a.issuer || a.account || t('unnamed'); const subtitle = document.createElement('span'); subtitle.textContent = ` · ${a.account} · ${a.kind.toUpperCase()}`; row.append(title, subtitle); $('previewAccounts').append(row); }
  for (const issue of value.issues) { const row = document.createElement('div'); row.className = 'issue'; row.textContent = t('recordIssue', { n: issue.position, reason: t(issue.reason) }); $('previewIssues').append(row); }
  $('partialLabel').hidden = !value.issues.length; $('passwordField').hidden = true; $('importPassword').value = ''; updateButtons();
}
function visibleAccounts() {
  const terms = $('search').value.trim().toLocaleLowerCase().split(/\s+/);
  return (model?.accounts || []).filter(a => (!onlyFavorites || a.favorite) && terms.every(term => `${a.issuer} ${a.account}`.toLocaleLowerCase().includes(term))).sort((a, b) => Number(b.favorite) - Number(a.favorite) || (a.issuer || a.account).localeCompare(b.issuer || b.account));
}
function renderAccounts() {
  const available = !model.locked && !model.loadFailed;
  $('available').hidden = !available; $('unavailable').hidden = available;
  $('unavailableTitle').textContent = t(model.locked ? 'locked' : 'loadFailed'); $('unavailableHint').textContent = t(model.locked ? 'lockedHint' : 'loadFailedHint'); $('retry').hidden = model.locked;
  $('addButton').disabled = !available; $('exportButton').disabled = !available || !model.accounts.length;
  const accounts = visibleAccounts();
  $('count').textContent = t('items', { n: accounts.length }); $('empty').hidden = !!model.accounts.length; $('noMatch').hidden = !model.accounts.length || !!accounts.length;
  const signature = model.language + accounts.map(a => [a.id, a.issuer, a.account, a.favorite, a.kind].join('|')).join('\n');
  if (signature !== cardSignature) {
    cardSignature = signature; $('accounts').replaceChildren();
    for (const a of accounts) {
      const card = document.createElement('article'); card.className = 'card'; card.dataset.id = a.id;
      // The template is static. Imported labels always use textContent.
      card.innerHTML = '<div class="avatar"></div><div class="identity"><strong></strong><small></small></div><button class="star"></button><div class="code-line"><button class="code"></button><span class="countdown"></span></div><div class="card-controls"><button class="copy"></button><button class="next"></button><button class="remove"></button></div>';
      const title = a.issuer || a.account || t('unnamed'); card.querySelector('.avatar').textContent = [...title][0].toLocaleUpperCase(); card.querySelector('strong').textContent = title; card.querySelector('small').textContent = a.account || a.kind.toUpperCase();
      const star = card.querySelector('.star'); star.textContent = a.favorite ? '★' : '☆'; star.classList.toggle('saved', a.favorite); star.title = t(a.favorite ? 'unfavorite' : 'favorite'); star.setAttribute('aria-label', star.title); star.dataset.action = 'favorite';
      for (const name of ['copy', 'next', 'remove']) { const button = card.querySelector('.' + name); button.textContent = t(name); button.dataset.action = name === 'next' ? 'advance' : name; }
      card.querySelector('.next').hidden = a.kind !== 'hotp'; card.querySelector('.code').dataset.action = 'copy'; card.querySelector('.code').setAttribute('aria-label', `${t('copy')} · ${title}`);
      $('accounts').append(card);
    }
  }
  for (const a of accounts) {
    const card = Array.from($('accounts').children).find(node => node.dataset.id === a.id); if (!card) continue;
    card.querySelector('.code').textContent = a.code.length === 6 ? `${a.code.slice(0, 3)} ${a.code.slice(3)}` : a.code;
    card.querySelector('.countdown').textContent = a.kind === 'hotp' ? `#${a.counter}` : t('refresh', { n: a.remaining });
  }
}
function update(state) {
  const changed = !model || model.language !== state.language; model = state;
  if (changed) { localize(state.language); cardSignature = ''; if (pendingPreview) displayPreview(pendingPreview); if (!hasFile) $('filename').textContent = t('chooseHint'); }
  $('privacy').textContent = t(state.demo ? 'demo' : 'onDevice'); $('version').textContent = 'v' + state.version; $('language').value = state.preference; $('login').checked = state.launchAtLogin; $('login').disabled = state.demo; $('lock').disabled = state.demo;
  if ((state.locked || state.loadFailed) && view !== 'home') go('home').catch(() => {});
  renderAccounts(); updateButtons();
}
$('hide').onclick = () => go('home').then(() => call('hide')).catch(() => {});
for (const id of ['addButton', 'firstAdd']) $(id).onclick = () => go('add').catch(() => notice(t('actionFailed'), true));
$('exportButton').onclick = () => go('export').catch(() => notice(t('actionFailed'), true));
$('cancel').onclick = () => go('home').catch(() => {});
$('search').addEventListener('input', renderAccounts);
$('search').addEventListener('keydown', event => { if (event.key === 'Enter' && visibleAccounts()[0]) action(async () => { await call('copy', { id: visibleAccounts()[0].id }); notice(t('copied')); }); });
$('all').onclick = () => { onlyFavorites = false; $('all').classList.add('selected'); $('favorites').classList.remove('selected'); renderAccounts(); };
$('favorites').onclick = () => { onlyFavorites = true; $('favorites').classList.add('selected'); $('all').classList.remove('selected'); renderAccounts(); };
$('accounts').onclick = event => { const button = event.target.closest('button[data-action]'), card = button?.closest('.card'); if (card) action(async () => { await call(button.dataset.action, { id: card.dataset.id }); if (button.dataset.action === 'copy') notice(t('copied')); }); };
$('language').onchange = () => action(async () => update(await call('language', { value: $('language').value })));
$('login').onchange = () => action(() => call('login', { enabled: $('login').checked }));
$('lock').onclick = () => action(() => call('lock'));
$('retry').onclick = () => action(() => call('retry'));
document.querySelectorAll('[data-source]').forEach(button => button.onclick = async () => {
  if (processing) return; source = button.dataset.source; await call('cancelPreview'); resetPreview(); hasFile = false; $('filename').textContent = t('chooseHint'); $('passwordField').hidden = true; $('importPassword').value = ''; notice('');
  for (const name of ['file', 'text', 'manual', 'qr']) $(name + 'Source').hidden = source !== name;
  document.querySelectorAll('[data-source]').forEach(b => { b.classList.toggle('selected', b === button); b.setAttribute('aria-selected', String(b === button)); }); updateButtons();
});
$('chooseFile').onclick = () => action(async token => { const result = await call('chooseBackup'); if (token !== operation || !result) return; resetPreview(); hasFile = true; $('filename').textContent = result.name; $('passwordField').hidden = true; $('importPassword').value = ''; });
$('backupText').oninput = resetPreview; $('manualForm').oninput = resetPreview; $('manualForm').onchange = () => { resetPreview(); updateManual(); }; $('manualForm').onsubmit = event => event.preventDefault();
$('previewButton').onclick = () => action(async token => {
  try {
    let value;
    if (source === 'manual') { const fields = Object.fromEntries(new FormData($('manualForm'))); value = await call('manual', { ...fields, hexadecimal: fields.encoding === 'hex' }); }
    else value = await call('preview', { file: source === 'file', text: $('backupText').value, password: $('importPassword').value });
    if (token === operation) displayPreview(value);
  } catch (e) { if (e.code === 'passwordRequired') { $('passwordField').hidden = false; $('importPassword').focus(); } throw e; }
});
$('allowPartial').onchange = updateButtons;
$('importButton').onclick = () => action(async token => { const result = await call('import', { allowPartial: $('allowPartial').checked }); if (token !== operation) return; await go('home'); notice(t('imported', result)); });
for (const id of ['qrScreen', 'qrFile', 'qrPaste']) $(id).onclick = () => action(async token => { resetPreview(); const result = await call(id); if (token === operation) displayPreview(result); });
$('exportFormat').onchange = updateExport;
for (const id of ['exportPassword', 'confirmation', 'acceptPlaintext']) $(id).oninput = updateButtons;
$('saveExport').onclick = () => action(async token => { const result = await call('export', { encrypted: $('exportFormat').value === 'encrypted', password: $('exportPassword').value, confirmation: $('confirmation').value, acceptedPlaintext: $('acceptPlaintext').checked }); if (token === operation && result) { await go('home'); notice(t('exported', { n: result.count })); } });
document.addEventListener('keydown', event => { if (event.key === 'Escape') { if (view !== 'home') go('home').catch(() => {}); else if ($('search').value) { $('search').value = ''; renderAccounts(); } else call('hide').catch(() => {}); } });
window.quickAuth.subscribe(update); call('state').then(update).catch(() => notice(t('actionFailed'), true));
