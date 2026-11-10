'use strict';
let start;
const selection = document.getElementById('selection');
window.capture.image().then(value => { document.getElementById('screen').src = value.image; document.getElementById('hint').textContent = value.language === 'zh-CN' ? '拖动框选二维码 · Esc 取消' : 'Drag to select a QR code · Esc to cancel'; });
document.addEventListener('keydown', e => { if (e.key === 'Escape') window.capture.finish(null); });
document.addEventListener('pointerdown', e => { if (e.button !== 0) return; start = { x: e.clientX, y: e.clientY }; selection.style.display = 'block'; draw(e); });
function rectangle(e) { return { x: Math.min(start.x, e.clientX), y: Math.min(start.y, e.clientY), width: Math.abs(start.x - e.clientX), height: Math.abs(start.y - e.clientY) }; }
function draw(e) { if (!start) return; const r = rectangle(e); Object.assign(selection.style, { left: r.x + 'px', top: r.y + 'px', width: r.width + 'px', height: r.height + 'px' }); }
document.addEventListener('pointermove', draw);
document.addEventListener('pointerup', e => { if (!start) return; const r = rectangle(e); start = null; window.capture.finish(r.width >= 8 && r.height >= 8 ? r : null); });
