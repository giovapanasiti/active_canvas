/**
 * ActiveCanvas Editor - Preview modal
 *
 * Renders the editor's unsaved state through the public view (preview_iframe)
 * into a sandboxed iframe. Requests are sequenced so a stale response never
 * replaces a newer one, and closing aborts the in-flight request.
 */
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

    let seq = 0;
    let controller = null;
    let loadingTimer = null;

    btn.addEventListener('click', open);
    closeBtn.addEventListener('click', close);
    modal.addEventListener('click', e => { if (e.target === modal) close(); });
    document.addEventListener('keydown', e => {
      if (isOpen() && e.key === 'Escape') { close(); return; }
      if ((e.ctrlKey || e.metaKey) && e.shiftKey && e.key.toLowerCase() === 'p') {
        if (document.activeElement && document.activeElement.closest('.monaco-editor')) return;
        e.preventDefault();
        if (!isOpen()) open();
      }
    });

    function isOpen() { return !modal.hasAttribute('hidden'); }

    function open() {
      const editor = window.ActiveCanvasEditor && window.ActiveCanvasEditor.instance;
      modal.removeAttribute('hidden');
      document.body.style.overflow = 'hidden';

      if (!editor) {
        showError('Editor not ready yet — try again in a second.');
        return;
      }

      showLoading();
      const id = ++seq;
      if (controller) controller.abort();
      controller = new AbortController();

      const html = editor.getHtml();
      const content = window.ActiveCanvasChips ? window.ActiveCanvasChips.undecorate(html) : html;
      const csrf = document.querySelector('meta[name="csrf-token"]');

      fetch(previewUrl, {
        method: 'POST',
        signal: controller.signal,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'X-CSRF-Token': csrf ? csrf.content : '',
          'Accept': 'application/json'
        },
        body: new URLSearchParams({
          content: content,
          content_css: editor.getCss(),
          content_js: (window.ActiveCanvasEditor && window.ActiveCanvasEditor.getJs) ? window.ActiveCanvasEditor.getJs() : '',
          bindings: window.ActiveCanvasBindings ? window.ActiveCanvasBindings.readJson() : '{}'
        }).toString()
      })
        .then(r => r.json().then(body => ({ ok: r.ok, body })))
        .then(({ ok, body }) => {
          if (id !== seq || !isOpen()) return;
          if (ok && body.html) {
            iframe.onload = hideLoading;
            iframe.srcdoc = body.html;
            clearTimeout(loadingTimer);
            loadingTimer = setTimeout(hideLoading, 1500); // some browsers skip onload for srcdoc
          } else {
            showError((body && body.error && body.error.message) || 'Render failed');
          }
        })
        .catch(err => {
          if (err.name === 'AbortError' || id !== seq) return;
          showError(err.message || 'Network error');
        });
    }

    function close() {
      seq++; // any response still in flight is now stale
      if (controller) { controller.abort(); controller = null; }
      clearTimeout(loadingTimer);
      modal.setAttribute('hidden', '');
      document.body.style.overflow = '';
      iframe.onload = null;
      iframe.srcdoc = '';
      hideError();
      hideLoading();
    }

    function showLoading() { loading.removeAttribute('hidden'); hideError(); }
    function hideLoading() { loading.setAttribute('hidden', ''); }
    function showError(message) { hideLoading(); errorMsg.textContent = message; errorBox.removeAttribute('hidden'); }
    function hideError() { errorBox.setAttribute('hidden', ''); }
  }

  document.addEventListener('DOMContentLoaded', init);
})();
