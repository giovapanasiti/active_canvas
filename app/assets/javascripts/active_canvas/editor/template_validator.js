/**
 * ActiveCanvas Editor - Template validator
 *
 * Posts the current source and bindings to validate_template after the
 * canvas or the bindings change (debounced) and shows the first error in a
 * banner above the canvas, with line and column. Never touches the canvas.
 */
(function() {
  'use strict';

  window.ActiveCanvasEditor = window.ActiveCanvasEditor || {};

  function setupTemplateValidator(editor, config) {
    const container = document.getElementById('data-panel-container');
    if (!container || !config.templateEnabled) return;

    const url = container.dataset.validateUrl;
    const csrf = window.ActiveCanvasEditor.getCsrfToken();
    let seq = 0;
    let timer = null;
    let lastPayload = null;

    function currentPayload() {
      const html = editor.getHtml();
      const content = window.ActiveCanvasChips ? window.ActiveCanvasChips.undecorate(html) : html;
      return JSON.stringify({ content, bindings: window.ActiveCanvasBindings.readJson() });
    }

    function validate(force) {
      const payload = currentPayload();
      if (!force && payload === lastPayload) return;
      lastPayload = payload;
      const id = ++seq;

      fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': csrf, 'Accept': 'application/json' },
        body: payload
      })
        .then(r => r.json().then(body => ({ ok: r.ok, body })))
        .then(({ ok, body }) => {
          if (id !== seq) return; // a newer check is in flight
          if (ok && body.ok) clearError();
          else showError(body.error || { message: 'Template check failed' });
        })
        .catch(() => {
          if (id === seq) showError({ message: 'Could not reach the server to check the template' });
        });
    }

    function schedule() {
      clearTimeout(timer);
      timer = setTimeout(() => validate(false), 800);
    }

    editor.on('load', () => validate(true));
    editor.on('component:update component:add component:remove', schedule);
    document.addEventListener('ac:bindings-changed', () => validate(true));

    function showError(err) {
      let banner = document.getElementById('ac-error-banner');
      if (!banner) {
        banner = document.createElement('div');
        banner.id = 'ac-error-banner';
        banner.className = 'ac-error-banner';
        (document.querySelector('.editor-canvas') || document.body).prepend(banner);
      }
      const where = err.line ? ` (line ${err.line}${err.column ? `, column ${err.column}` : ''})` : '';
      const message = String(err.message || '').replace(/^Liquid (?:syntax )?error \(line \d+\): /, '');
      banner.innerHTML = '';
      const text = document.createElement('span');
      text.textContent = `Template error: ${message}${where}`;
      const close = document.createElement('button');
      close.type = 'button';
      close.className = 'ac-error-banner-close';
      close.title = 'Dismiss';
      close.textContent = '×';
      close.addEventListener('click', clearError);
      banner.append(text, close);
    }

    function clearError() {
      const banner = document.getElementById('ac-error-banner');
      if (banner) banner.remove();
    }
  }

  window.ActiveCanvasEditor.setupTemplateValidator = setupTemplateValidator;
})();
