(function() {
  const container = document.getElementById('data-panel-container');
  if (!container) return;
  const pageId = container.dataset.pageId;
  const previewUrl = container.dataset.renderPreviewUrl;

  const csrf = () => document.querySelector('meta[name="csrf-token"]').content;

  // Hook into GrapesJS once it's available on window.ActiveCanvasEditor.instance.
  function waitForEditor(cb) {
    const editor = window.ActiveCanvasEditor && window.ActiveCanvasEditor.instance;
    if (editor && editor.DomComponents) return cb(editor);
    setTimeout(() => waitForEditor(cb), 100);
  }

  // The editor saves via a plain fetch with storageManager disabled, so chips
  // must be restored to their Liquid source in that save path (panels.js) —
  // GrapesJS storage events never fire.
  window.ActiveCanvasChips = { restoreSourceTags };

  waitForEditor((editor) => {
    // Register chip components (variables) as atomic, non-editable.
    editor.DomComponents.addType('ac-chip', {
      isComponent: (el) => el.tagName === 'SPAN' && el.hasAttribute && el.hasAttribute('data-ac-var'),
      model: { defaults: { editable: false, droppable: false, copyable: true, removable: true, attributes: {} } }
    });

    // Register block markers as atomic, non-editable.
    editor.DomComponents.addType('ac-block', {
      isComponent: (el) => el.tagName === 'SPAN' && el.hasAttribute && el.hasAttribute('data-ac-block'),
      model: { defaults: { editable: false, droppable: false, copyable: true, removable: true } }
    });

    // Only dynamic pages get their canvas swapped for the rendered preview;
    // static pages keep the components GrapesJS loaded.
    if (container.dataset.templateEnabled !== 'true') return;

    // 1) Initial load: fetch rendered preview and load into canvas.
    refreshPreview(editor);

    // 2) Refresh on binding change.
    document.addEventListener('ac:bindings-changed', () => refreshPreview(editor));
  });

  function refreshPreview(editor) {
    if (!pageId || !previewUrl) return;
    const bindings = JSON.parse(localStorage.getItem(`ac:bindings:${pageId}`) || '{}');
    const content = editor.getHtml();
    // Replace chip nodes back to their Liquid source before sending so we
    // render the underlying template, not the already-rendered preview.
    const sourceContent = restoreSourceTags(content);

    fetch(previewUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'X-CSRF-Token': csrf() },
      body: new URLSearchParams({ content: sourceContent, bindings: JSON.stringify(bindings) }).toString(),
    }).then(r => r.json()).then(body => {
      if (body.error) {
        showError(body.error);
      } else {
        editor.setComponents(body.html);
        clearError();
      }
    });
  }

  // Replace each <span data-ac-var=...> / <span data-ac-block=...> with the
  // original Liquid source stored in its data-ac-source attribute.
  function restoreSourceTags(html) {
    const tmp = document.createElement('div');
    tmp.innerHTML = html;
    tmp.querySelectorAll('[data-ac-var], [data-ac-block]').forEach(el => {
      const source = el.getAttribute('data-ac-source') || '';
      el.outerHTML = source;
    });
    return tmp.innerHTML;
  }

  function showError(err) {
    let banner = document.getElementById('ac-error-banner');
    if (!banner) {
      banner = document.createElement('div');
      banner.id = 'ac-error-banner';
      banner.style.cssText = 'background:#dc2626;color:#fff;padding:8px;font:13px monospace;';
      document.querySelector('.editor-canvas, body').prepend(banner);
    }
    banner.textContent = `Template error: ${err.message}${err.line ? ` (line ${err.line})` : ''}`;
  }

  function clearError() {
    const banner = document.getElementById('ac-error-banner');
    if (banner) banner.remove();
  }
})();
