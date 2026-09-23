/**
 * ActiveCanvas Editor - Live data
 *
 * With the "Live data" switch on, every chip in the canvas shows the value
 * it renders (the first item's value inside a loop) and each loop badge
 * shows how many items it renders. This is a view layer only: the chip's
 * source stays in its data-ac-source attribute, so saving, validating and
 * the code panel keep working on the source. Values come from chip_values,
 * refreshed after edits and binding changes.
 */
(function() {
  'use strict';

  window.ActiveCanvasEditor = window.ActiveCanvasEditor || {};

  const state = { enabled: false, values: {}, loops: {}, doc: null };

  function applyChip(el) {
    const source = window.ActiveCanvasChips.sourceOf(el);
    if (!state.enabled) {
      if (el.textContent !== source) el.textContent = source;
      el.removeAttribute('title');
      el.classList.remove('ac-chip-empty');
      return;
    }
    const id = el.getAttribute('data-ac-id');
    const has = !!id && Object.prototype.hasOwnProperty.call(state.values, id);
    const value = has ? state.values[id] : null;
    const shown = has ? (value === '' ? '—' : value) : source;
    if (el.textContent !== shown) el.textContent = shown;
    el.title = has ? source : `${source} (no value yet)`;
    el.classList.toggle('ac-chip-empty', has && value === '');
  }

  function cssString(text) {
    return `"${String(text).replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"`;
  }

  // Loop counts are shown through generated CSS so no attribute is added to
  // the loop element itself (attributes would end up in the saved source).
  function applyLoopCounts(doc) {
    let style = doc.getElementById('ac-loop-counts');
    if (!state.enabled) { if (style) style.remove(); return; }
    if (!style) {
      style = doc.createElement('style');
      style.id = 'ac-loop-counts';
      doc.head.appendChild(style);
    }
    style.textContent = Object.entries(state.loops).map(([expr, count]) =>
      `[data-ac-for=${cssString(expr)}]::before { content: ${cssString(`↻ ${expr} · ${count} item${count === 1 ? '' : 's'}`)}; }`
    ).join('\n');
  }

  function render() {
    const doc = state.doc;
    const btn = document.getElementById('btn-live-data');
    if (btn) {
      btn.classList.toggle('active', state.enabled);
      btn.setAttribute('aria-pressed', String(state.enabled));
    }
    if (!doc) return;
    doc.body.classList.toggle('ac-live-data', state.enabled);
    doc.querySelectorAll('span[data-ac-var]').forEach(applyChip);
    applyLoopCounts(doc);
  }

  function setupLiveData(editor, config) {
    const container = document.getElementById('data-panel-container');
    const btn = document.getElementById('btn-live-data');
    if (!container || !btn) return;
    if (!config.templateEnabled) { btn.hidden = true; return; }

    const url = container.dataset.chipValuesUrl;
    const key = `ac:livedata:${config.pageId}`;
    const csrf = window.ActiveCanvasEditor.getCsrfToken();
    let seq = 0;
    let timer = null;
    let lastFingerprint = null;

    try { state.enabled = localStorage.getItem(key) !== 'off'; } catch (e) { state.enabled = true; }

    function fingerprint(html) {
      return (html.match(/data-ac-source="[^"]*"|data-ac-(?:for|if)="[^"]*"/g) || []).join('\n') + '\n' + window.ActiveCanvasBindings.readJson();
    }

    function refresh(force) {
      if (!state.enabled) return;
      const html = editor.getHtml();
      const fp = fingerprint(html);
      if (!force && fp === lastFingerprint) return;
      lastFingerprint = fp;
      const id = ++seq;

      fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': csrf, 'Accept': 'application/json' },
        body: JSON.stringify({ content: html, bindings: window.ActiveCanvasBindings.readJson() })
      })
        .then(r => r.json())
        .then(body => {
          if (id !== seq) return;
          state.values = body.values || {};
          state.loops = body.loops || {};
          render();
        })
        .catch(() => { /* the validator banner reports server trouble */ });
    }

    function schedule() {
      clearTimeout(timer);
      timer = setTimeout(() => refresh(false), 1500);
    }

    btn.addEventListener('click', () => {
      state.enabled = !state.enabled;
      try { localStorage.setItem(key, state.enabled ? 'on' : 'off'); } catch (e) { /* storage unavailable */ }
      render();
      refresh(true);
    });

    editor.on('load', () => {
      state.doc = editor.Canvas.getDocument();
      render();
      refresh(true);
    });
    editor.on('component:update component:add component:remove', schedule);
    document.addEventListener('ac:bindings-changed', () => refresh(true));
  }

  window.ActiveCanvasLiveData = { applyChip, enabled: () => state.enabled };
  window.ActiveCanvasEditor.setupLiveData = setupLiveData;
})();
