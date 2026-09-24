/**
 * ActiveCanvas Editor - Live data
 *
 * With the "Live data" switch on, every chip in the canvas shows the value
 * it renders, a loop shows all its items (the first one is the editable
 * element, the others are dimmed ghost copies), and an element whose
 * condition is false is dimmed with a "hidden" badge. This is a view layer
 * only: the chip's source stays in its data-ac-source attribute and ghosts
 * never enter the model, so saving, validating and the code panel keep
 * working on the source. Values come from chip_values, refreshed after
 * edits and binding changes.
 */
(function() {
  'use strict';

  window.ActiveCanvasEditor = window.ActiveCanvasEditor || {};

  const state = { enabled: false, values: {}, loops: [], conds: [], doc: null };

  function applyChip(el) {
    const source = window.ActiveCanvasChips.sourceOf(el);
    if (el.closest('[data-ac-ghost]')) return; // ghost copies arrive rendered
    if (!state.enabled) {
      if (el.textContent !== source) el.textContent = source;
      el.removeAttribute('title');
      el.classList.remove('ac-chip-empty');
      return;
    }
    const id = el.getAttribute('data-ac-id');
    const has = !!id && Object.prototype.hasOwnProperty.call(state.values, id);
    const value = has ? state.values[id] : null;
    const shown = has ? (value === '' ? '\u2014' : value) : source;
    if (el.textContent !== shown) el.textContent = shown;
    el.title = has ? source : `${source} (no value yet)`;
    el.classList.toggle('ac-chip-empty', has && value === '');
  }

  function cssString(text) {
    return `"${String(text).replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"`;
  }

  // Loop and condition elements in the order the server numbered them:
  // document order, ghosts excluded.
  function directiveElements(doc, attr) {
    return [...doc.querySelectorAll(`[${attr}]`)].filter(el => !el.closest('[data-ac-ghost]'));
  }

  function removeGhosts(doc) {
    doc.querySelectorAll('[data-ac-ghost]').forEach(el => el.remove());
  }

  // The other items of a loop, inserted after the real element as dimmed,
  // unselectable copies. They are never components, and the chips module
  // strips them from anything that reaches the source.
  function insertGhosts(doc) {
    directiveElements(doc, 'data-ac-for').forEach((el, i) => {
      const loop = state.loops[i];
      if (!loop || !loop.copies) return;
      let anchor = el;
      loop.copies.forEach(html => {
        anchor.insertAdjacentHTML('afterend', html);
        const ghost = anchor.nextElementSibling;
        if (!ghost) return;
        ghost.setAttribute('data-ac-ghost', '');
        ghost.setAttribute('contenteditable', 'false');
        anchor = ghost;
      });
    });
  }

  // Counts and hidden conditions are shown through generated CSS keyed by
  // the expression, so no attribute or class is added to the element itself
  // (those would end up in the saved source).
  function applyBadges(doc) {
    let style = doc.getElementById('ac-live-badges');
    if (!state.enabled) { if (style) style.remove(); return; }
    if (!style) {
      style = doc.createElement('style');
      style.id = 'ac-live-badges';
      doc.head.appendChild(style);
    }
    const rules = [];
    state.loops.forEach(loop => {
      const shown = 1 + (loop.copies ? loop.copies.length : 0);
      const more = loop.count > shown ? `, ${shown} shown` : '';
      const label = `\u21BB ${loop.expr} \u00B7 ${loop.count} item${loop.count === 1 ? '' : 's'}${more}`;
      rules.push(`[data-ac-for=${cssString(loop.expr)}]::before { content: ${cssString(label)}; }`);
    });
    state.conds.forEach(cond => {
      const label = cond.shown ? `if ${cond.expr}` : `if ${cond.expr} \u00B7 hidden`;
      rules.push(`[data-ac-if=${cssString(cond.expr)}]::after { content: ${cssString(label)}; }`);
      if (!cond.shown) rules.push(`[data-ac-if=${cssString(cond.expr)}] { opacity: 0.35; }`);
    });
    style.textContent = rules.join('\n');
  }

  function render() {
    const doc = state.doc;
    const btn = document.getElementById('btn-live-data');
    if (btn) {
      btn.classList.toggle('active', state.enabled);
      btn.setAttribute('aria-pressed', String(state.enabled));
    }
    if (!doc) return;
    removeGhosts(doc);
    doc.body.classList.toggle('ac-live-data', state.enabled);
    doc.querySelectorAll('span[data-ac-var]').forEach(applyChip);
    if (state.enabled) insertGhosts(doc);
    applyBadges(doc);
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
          state.loops = Array.isArray(body.loops) ? body.loops : [];
          state.conds = Array.isArray(body.conds) ? body.conds : [];
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

  window.ActiveCanvasLiveData = { applyChip, enabled: () => state.enabled, removeGhosts };
  window.ActiveCanvasEditor.setupLiveData = setupLiveData;
})();
