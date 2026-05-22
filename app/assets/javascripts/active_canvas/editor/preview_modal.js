(function() {
  'use strict';

  function init() {
    const btn = document.getElementById('btn-preview');
    const modal = document.getElementById('preview-modal');
    if (!btn || !modal) return;

    const iframe = document.getElementById('preview-modal-iframe');
    const loading = document.getElementById('preview-modal-loading');
    const errorBox = document.getElementById('preview-modal-error');
    const errorMsg = document.getElementById('preview-modal-error-message');
    const closeBtn = document.getElementById('btn-close-preview');
    const previewUrl = btn.dataset.previewUrl;

    btn.addEventListener('click', open);
    closeBtn.addEventListener('click', close);
    modal.addEventListener('click', e => { if (e.target === modal) close(); });
    document.addEventListener('keydown', e => {
      if (!isOpen()) return;
      if (e.key === 'Escape') close();
    });
    document.addEventListener('keydown', e => {
      if ((e.ctrlKey || e.metaKey) && e.shiftKey && e.key.toLowerCase() === 'p') {
        e.preventDefault();
        open();
      }
    });

    function isOpen() { return !modal.hasAttribute('hidden'); }

    function open() {
      const editor = window.ActiveCanvasEditor && window.ActiveCanvasEditor.instance;
      if (!editor) {
        showError('Editor not ready yet — try again in a second.');
        modal.removeAttribute('hidden');
        document.body.style.overflow = 'hidden';
        return;
      }

      modal.removeAttribute('hidden');
      document.body.style.overflow = 'hidden';
      showLoading();

      const bindingsJson = readBindings();
      const content = stripChips(editor.getHtml());

      const csrf = document.querySelector('meta[name="csrf-token"]');
      fetch(previewUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'X-CSRF-Token': csrf ? csrf.content : '',
          'Accept': 'application/json'
        },
        body: new URLSearchParams({
          content: content,
          content_css: editor.getCss(),
          content_js: (window.ActiveCanvasEditor && window.ActiveCanvasEditor.getJs) ? window.ActiveCanvasEditor.getJs() : '',
          bindings: bindingsJson
        }).toString()
      })
        .then(r => r.json().then(body => ({ ok: r.ok, body })))
        .then(({ ok, body }) => {
          if (ok && body.html) {
            iframe.srcdoc = body.html;
            iframe.onload = hideLoading;
            // Fallback in case onload doesn't fire (some browsers + srcdoc).
            setTimeout(hideLoading, 1500);
          } else {
            const msg = (body && body.error && body.error.message) || 'Render failed';
            showError(msg);
          }
        })
        .catch(err => showError(err.message || 'Network error'));
    }

    function close() {
      modal.setAttribute('hidden', '');
      document.body.style.overflow = '';
      iframe.srcdoc = '';
      hideError();
    }

    function showLoading() {
      loading.removeAttribute('hidden');
      hideError();
    }

    function hideLoading() {
      loading.setAttribute('hidden', '');
    }

    function showError(message) {
      hideLoading();
      errorMsg.textContent = message;
      errorBox.removeAttribute('hidden');
    }

    function hideError() {
      errorBox.setAttribute('hidden', '');
    }

    // The canvas may contain chip wrappers from the live preview overlay
    // (see grape_chips_plugin.js). For an accurate render we restore the
    // original Liquid source from each chip's data-ac-source attribute.
    function stripChips(html) {
      const tmp = document.createElement('div');
      tmp.innerHTML = html;
      tmp.querySelectorAll('[data-ac-var], [data-ac-block]').forEach(el => {
        const src = el.getAttribute('data-ac-source') || '';
        el.outerHTML = src;
      });
      return tmp.innerHTML;
    }

    function readBindings() {
      const container = document.getElementById('data-panel-container');
      if (!container) return '{}';
      const pageId = container.dataset.pageId;
      return localStorage.getItem('ac:bindings:' + pageId) || '{}';
    }
  }

  document.addEventListener('DOMContentLoaded', init);
})();
