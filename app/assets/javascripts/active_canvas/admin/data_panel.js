(function() {
  const container = document.getElementById('data-panel-container');
  if (!container) return;
  const pageId      = container.dataset.pageId;
  const bindingsKey = `ac:bindings:${pageId}`;

  let registry = []; // [{ name, params: { limit: { type, default, ... } } }]
  let bindings = {}; // { localName: { source, params } | { source: '_literal', value } }

  const csrf = () => document.querySelector('meta[name="csrf-token"]').content;
  const post = (url, body) => fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': csrf(), 'Accept': 'application/json' },
    body: JSON.stringify(body),
  }).then(r => r.json().then(b => ({ ok: r.ok, body: b })));
  const get = (url) => fetch(url, { headers: { Accept: 'application/json' } }).then(r => r.json());

  function init() {
    loadBindings();
    loadRegistry().then(renderBindings);
    document.getElementById('ac-add-binding-btn').addEventListener('click', showForm);
    document.getElementById('ac-empty-add-btn').addEventListener('click', showForm);
  }

  function loadBindings() {
    bindings = JSON.parse(localStorage.getItem(bindingsKey) || '{}');
    const pre = document.getElementById('ac-server-bindings');
    if (pre) {
      bindings = JSON.parse(pre.textContent);
      localStorage.setItem(bindingsKey, JSON.stringify(bindings));
    }
  }

  function persistBindings() {
    localStorage.setItem(bindingsKey, JSON.stringify(bindings));
    document.dispatchEvent(new CustomEvent('ac:bindings-changed', { detail: { bindings } }));
  }

  function loadRegistry() {
    const url = container.dataset.dataSourcesUrl;
    return get(url).then(json => { registry = json; });
  }

  function renderBindings() {
    const list = document.getElementById('ac-bindings-list');
    const names = Object.keys(bindings);
    list.dataset.empty = names.length === 0 ? 'true' : 'false';
    list.innerHTML = names.map(name => bindingRowHTML(name, bindings[name])).join('');
    wireRowEvents(list);
  }

  function bindingRowHTML(name, spec) {
    const snippet = `{{ ${name} }}`;
    const loopSnippet = `{% for item in ${name} %}{{ item.title }}{% endfor %}`;
    return `
      <li class="data-panel-row">
        <div class="data-panel-row-header">
          <strong class="data-panel-row-name">${escape(name)}</strong>
          <span class="data-panel-row-source">${escape(spec.source)}</span>
          <button type="button" class="data-panel-row-remove" data-remove="${escape(name)}" title="Remove binding">
            <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <line x1="18" y1="6" x2="6" y2="18"/>
              <line x1="6" y1="6" x2="18" y2="18"/>
            </svg>
          </button>
        </div>
        <div class="data-panel-row-chips">
          <button type="button" class="data-panel-chip" data-snippet="${escape(snippet)}" title="Copy ${escape(snippet)}">{{ }}</button>
          <button type="button" class="data-panel-chip" data-snippet="${escape(loopSnippet)}" title="Copy loop">for&hellip;</button>
        </div>
      </li>
    `;
  }

  function wireRowEvents(list) {
    list.querySelectorAll('[data-remove]').forEach(btn => {
      btn.addEventListener('click', () => {
        delete bindings[btn.dataset.remove];
        persistBindings();
        renderBindings();
      });
    });
    list.querySelectorAll('.data-panel-chip').forEach(chip => {
      chip.addEventListener('click', () => {
        navigator.clipboard.writeText(chip.dataset.snippet).then(() => flashCopied(chip));
      });
    });
  }

  function flashCopied(el) {
    const original = el.textContent;
    el.textContent = 'Copied!';
    el.classList.add('is-copied');
    setTimeout(() => {
      el.textContent = original;
      el.classList.remove('is-copied');
    }, 1000);
  }

  function showForm() {
    const list = document.getElementById('ac-bindings-list');
    if (list.querySelector('#ac-binding-form')) return;
    const tpl = document.getElementById('ac-binding-form-template');
    const form = tpl.content.firstElementChild.cloneNode(true);
    list.prepend(form);
    list.dataset.empty = 'false';
    renderSources(form);
    form.addEventListener('submit', onSave);
    form.querySelector('#ac-binding-cancel').addEventListener('click', hideForm);
    form.querySelector('[data-cancel]').addEventListener('click', hideForm);
    form.querySelector('select[name="source"]').addEventListener('change', () => renderParamInputs(form));
    form.querySelector('input[name="name"]').focus();
  }

  function hideForm() {
    const form = document.querySelector('#ac-bindings-list #ac-binding-form');
    if (form) form.remove();
    renderBindings();
  }

  function renderSources(form) {
    const sel = form.querySelector('select[name="source"]');
    sel.innerHTML = registry.map(s => `<option value="${escape(s.name)}">${escape(s.name)}</option>`).join('');
    renderParamInputs(form);
  }

  function renderParamInputs(form) {
    const sel = form.querySelector('select[name="source"]');
    const source = registry.find(s => s.name === sel.value);
    const target = form.querySelector('#ac-binding-params');
    if (!source) { target.innerHTML = ''; return; }
    target.innerHTML = Object.entries(source.params).map(([pname, spec]) => {
      if (spec.allowed) {
        const opts = spec.allowed.map(v => `<option value="${escape(v)}">${escape(v)}</option>`).join('');
        return `<label class="data-panel-field"><span class="data-panel-field-label">${escape(pname)}</span><select name="param_${escape(pname)}">${opts}</select></label>`;
      }
      if (spec.type === 'integer') return `<label class="data-panel-field"><span class="data-panel-field-label">${escape(pname)}</span><input type="number" name="param_${escape(pname)}" value="${escape(String(spec.default ?? ''))}"></label>`;
      if (spec.type === 'boolean') return `<label class="data-panel-field data-panel-field-inline"><input type="checkbox" name="param_${escape(pname)}" ${spec.default ? 'checked' : ''}><span class="data-panel-field-label">${escape(pname)}</span></label>`;
      return `<label class="data-panel-field"><span class="data-panel-field-label">${escape(pname)}</span><input type="text" name="param_${escape(pname)}" value="${escape(String(spec.default ?? ''))}"></label>`;
    }).join('');
  }

  function onSave(e) {
    e.preventDefault();
    const form = e.target;
    const name = form.name.value.trim();
    const sourceName = form.source.value;
    const source = registry.find(s => s.name === sourceName);
    const params = {};
    Object.keys(source.params).forEach(pname => {
      const el = form.querySelector(`[name="param_${pname}"]`);
      if (!el) return;
      if (el.type === 'checkbox') params[pname] = el.checked;
      else if (el.type === 'number') params[pname] = el.value === '' ? null : Number(el.value);
      else params[pname] = el.value === '' ? null : el.value;
    });
    if (sourceName === '_literal') {
      bindings[name] = { source: '_literal', value: params.value };
    } else {
      bindings[name] = { source: sourceName, params: params };
    }
    persistBindings();
    hideForm();
  }

  function escape(s) {
    return String(s).replace(/[<>&"]/g, c => ({ '<':'&lt;','>':'&gt;','&':'&amp;','"':'&quot;' }[c]));
  }

  document.addEventListener('DOMContentLoaded', init);
})();
