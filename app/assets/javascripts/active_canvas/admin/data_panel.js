(function() {
  const container = document.getElementById('data-panel-container');
  if (!container) return;

  let registry = []; // [{ name, params: { limit: { type, default, ... } } }]
  let bindings = {}; // { localName: { source, params } | { source: '_literal', value } }
  const NAME_RE = /^[a-z][a-z0-9_]*$/;

  const csrf = () => document.querySelector('meta[name="csrf-token"]').content;
  const post = (url, body) => fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': csrf(), 'Accept': 'application/json' },
    body: JSON.stringify(body),
  }).then(r => r.json().then(b => ({ ok: r.ok, body: b })));
  const get = (url) => fetch(url, { headers: { Accept: 'application/json' } }).then(r => r.json());

  function init() {
    loadBindings();
    renderBindings();
    renderImplicit();
    const addBtn = document.getElementById('ac-add-binding-btn');
    const emptyAddBtn = document.getElementById('ac-empty-add-btn');
    addBtn.disabled = true;
    emptyAddBtn.disabled = true;
    loadRegistry()
      .then(() => {
        addBtn.disabled = false;
        emptyAddBtn.disabled = false;
        renderBindings(); // labels and snippets need the registry
      })
      .catch(err => {
        console.error('ActiveCanvas: data sources unavailable', err);
        showPanelMessage('Data sources could not be loaded. Reload the page to try again.');
      });
    addBtn.addEventListener('click', showForm);
    emptyAddBtn.addEventListener('click', showForm);
    const toggle = document.getElementById('ac-template-toggle');
    if (toggle) toggle.addEventListener('change', onTemplateToggle);
  }

  function showPanelMessage(text) {
    const el = document.getElementById('ac-panel-message');
    if (!el) return;
    el.textContent = text;
    el.hidden = !text;
  }

  // Saving with template_enabled flips how the editor loads the page, so a
  // successful save is followed by a reload.
  function onTemplateToggle(e) {
    const toggle = e.target;
    const save = window.ActiveCanvasEditor && window.ActiveCanvasEditor.saveContent;
    if (!save) { toggle.checked = !toggle.checked; return; }
    toggle.disabled = true;
    save(false, { template_enabled: toggle.checked }).then(ok => {
      if (ok) { window.location.reload(); return; }
      toggle.checked = !toggle.checked;
      toggle.disabled = false;
    });
  }

  function loadBindings() {
    bindings = window.ActiveCanvasBindings.read();
  }

  function persistBindings() {
    window.ActiveCanvasBindings.write(bindings);
  }

  function loadRegistry() {
    const url = container.dataset.dataSourcesUrl;
    return get(url).then(json => {
      registry = json;
      window.ActiveCanvasBindings.setRegistry(json);
    });
  }

  function renderBindings() {
    const list = document.getElementById('ac-bindings-list');
    const names = Object.keys(bindings);
    list.dataset.empty = names.length === 0 ? 'true' : 'false';
    list.innerHTML = names.map(name => bindingRowHTML(name, bindings[name])).join('');
    wireRowEvents(list);
  }

  function bindingRowHTML(name, spec) {
    const B = window.ActiveCanvasBindings;
    const src = B.source(spec.source);
    const item = B.itemName(name);
    const firstField = src && src.fields && src.fields[0] ? src.fields[0].id : 'title';
    const sourceLabel = spec.source === '_literal' ? 'Literal' : ((src && src.label) || spec.source);
    const snippet = `{{ ${name} }}`;
    const loopSnippet = `<div data-ac-for="${item} in ${name}">{{ ${item}.${firstField} }}</div>`;
    return `
      <li class="data-panel-row">
        <div class="data-panel-row-header">
          <strong class="data-panel-row-name">${escape(name)}</strong>
          <span class="data-panel-row-source">${escape(sourceLabel)}</span>
          <button type="button" class="data-panel-row-action" data-edit="${escape(name)}" title="Edit binding">
            <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M12 20h9"/>
              <path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4Z"/>
            </svg>
          </button>
          <button type="button" class="data-panel-row-action data-panel-row-remove" data-remove="${escape(name)}" title="Remove binding">
            <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <line x1="18" y1="6" x2="6" y2="18"/>
              <line x1="6" y1="6" x2="18" y2="18"/>
            </svg>
          </button>
        </div>
        ${valueLineHTML(name, spec)}
        <div class="data-panel-row-chips">
          <button type="button" class="data-panel-chip" data-snippet="${escape(snippet)}" title="Copy ${escape(snippet)}">{{ }}</button>
          ${B.isList(name) ? `<button type="button" class="data-panel-chip" data-snippet="${escape(loopSnippet)}" title="Copy loop">for&hellip;</button>` : ''}
        </div>
        <details class="data-panel-sample" data-sample-for="${escape(name)}">
          <summary>Sample data</summary>
          <pre class="data-panel-sample-body">Loading…</pre>
        </details>
      </li>
    `;
  }

  // A literal shows its value in a text box you can type in. Any other
  // binding shows its parameters; the pencil opens the form to change them.
  function valueLineHTML(name, spec) {
    if (spec.source === '_literal') {
      if (typeof spec.value !== 'string') {
        return `<code class="data-panel-row-params" title="Edit with the pencil">${escape(JSON.stringify(spec.value))}</code>`;
      }
      return `<input type="text" class="data-panel-row-literal" data-literal="${escape(name)}" value="${escape(spec.value)}" placeholder="Value" title="The value of {{ ${escape(name)} }}">`;
    }
    const params = Object.entries(spec.params || {}).filter(([, v]) => v != null && v !== '');
    return `<span class="data-panel-row-params">${params.length ? params.map(([k, v]) => `${escape(k)}: ${escape(v)}`).join(' · ') : 'default parameters'}</span>`;
  }

  // Read-only "Template data" section for a collection's template pages
  // (Part 4 "Editor"): the implicit `item`/`items`/`collection`/`pagination`
  // names, with a chip per field, so an author can insert `{{ item.x }}` /
  // `{{ entry.x }}` (inside a loop over `items`) / `{{ pagination.x }}`
  // without adding a binding for them. The schema (field ids only, no live
  // values) comes from the editor config; chip_values resolves the actual
  // values once the chip is in the canvas.
  function renderImplicit() {
    const list = document.getElementById('ac-implicit-list');
    if (!list) return;
    const config = window.ActiveCanvasEditor && window.ActiveCanvasEditor.config;
    const implicit = (config && config.implicitBindings) || {};
    list.innerHTML = Object.keys(implicit).map(name => implicitRowHTML(name, implicit[name])).join('');
    wireImplicitChips(list);
  }

  function implicitRowHTML(name, spec) {
    const varName = spec.item_name || name;
    const fields = spec.fields || [];
    const fieldChips = fields.map(field => {
      const snippet = `{{ ${varName}.${field.id} }}`;
      return `<button type="button" class="data-panel-chip" data-snippet="${escape(snippet)}" title="Copy ${escape(snippet)}">${escape(field.id)}</button>`;
    }).join('');
    const loopChip = spec.item_name ? loopChipHTML(name, varName, fields) : '';
    return `
      <li class="data-panel-row data-panel-row-implicit">
        <div class="data-panel-row-header">
          <strong class="data-panel-row-name">${escape(name)}</strong>
          <span class="data-panel-row-source">from the collection</span>
        </div>
        <div class="data-panel-row-chips">${fieldChips}${loopChip}</div>
      </li>
    `;
  }

  function loopChipHTML(name, varName, fields) {
    const firstField = fields[0] ? fields[0].id : 'id';
    const snippet = `<div data-ac-for="${varName} in ${name}">{{ ${varName}.${firstField} }}</div>`;
    return `<button type="button" class="data-panel-chip" data-snippet="${escape(snippet)}" title="Copy loop">for&hellip;</button>`;
  }

  function wireImplicitChips(list) {
    list.querySelectorAll('.data-panel-chip').forEach(chip => {
      chip.addEventListener('click', () => copySnippet(chip));
    });
  }

  function wireRowEvents(list) {
    list.querySelectorAll('[data-literal]').forEach(input => {
      input.addEventListener('change', () => {
        bindings[input.dataset.literal].value = input.value;
        persistBindings();
      });
      input.addEventListener('keydown', e => { if (e.key === 'Enter') { e.preventDefault(); input.blur(); } });
    });
    list.querySelectorAll('[data-edit]').forEach(btn => {
      btn.addEventListener('click', () => showForm(btn.dataset.edit));
    });
    list.querySelectorAll('[data-remove]').forEach(btn => {
      btn.addEventListener('click', () => {
        delete bindings[btn.dataset.remove];
        persistBindings();
        renderBindings();
      });
    });
    list.querySelectorAll('.data-panel-chip').forEach(chip => {
      chip.addEventListener('click', () => copySnippet(chip));
    });
    list.querySelectorAll('.data-panel-sample').forEach(details => {
      details.addEventListener('toggle', () => {
        if (details.open && !details.dataset.loaded) loadSample(details);
      });
    });
  }

  function loadSample(details) {
    const body = details.querySelector('.data-panel-sample-body');
    const url = container.dataset.sampleDataUrl;
    body.textContent = 'Loading…';
    post(url, { binding: details.dataset.sampleFor, bindings: window.ActiveCanvasBindings.readJson() })
      .then(({ ok, body: json }) => {
        details.dataset.loaded = 'true';
        body.textContent = ok ? JSON.stringify(json.rows, null, 2) : `Could not load: ${json.error || 'unknown error'}`;
      })
      .catch(() => { body.textContent = 'Could not reach the server.'; });
  }

  function copySnippet(chip) {
    const text = chip.dataset.snippet;
    const write = navigator.clipboard?.writeText(text);
    if (write && typeof write.then === 'function') {
      write.then(() => flashCopied(chip, 'Copied!')).catch(() => flashCopied(chip, 'Press Ctrl+C'));
    } else {
      flashCopied(chip, 'Copy unavailable');
    }
  }

  function flashCopied(el, message) {
    const original = el.textContent;
    el.textContent = message || 'Copied!';
    el.classList.add('is-copied');
    setTimeout(() => {
      el.textContent = original;
      el.classList.remove('is-copied');
    }, 1000);
  }

  // With a name, the form opens prefilled to edit that binding in place.
  function showForm(existing) {
    showPanelMessage('');
    const list = document.getElementById('ac-bindings-list');
    if (list.querySelector('#ac-binding-form')) return;
    const tpl = document.getElementById('ac-binding-form-template');
    const form = tpl.content.firstElementChild.cloneNode(true);
    const li = document.createElement('li');
    li.className = 'data-panel-add-card-wrapper';
    li.appendChild(form);
    list.dataset.empty = 'false';
    list.prepend(li);
    renderSources(form);
    form.addEventListener('submit', onSave);
    form.querySelector('#ac-binding-cancel').addEventListener('click', hideForm);
    form.querySelector('[data-cancel]').addEventListener('click', hideForm);
    form.querySelector('select[name="source"]').addEventListener('change', () => renderParamInputs(form));
    form.querySelector('input[name="name"]').addEventListener('input', () => showNameError(form, ''));
    if (typeof existing === 'string' && bindings[existing]) {
      prefill(form, existing, bindings[existing]);
    } else {
      form.querySelector('input[name="name"]').focus();
    }
  }

  function prefill(form, name, spec) {
    form.dataset.editing = name;
    form.querySelector('.data-panel-add-card-title').textContent = `Edit ${name}`;
    form.querySelector('button[type="submit"]').textContent = 'Save changes';
    const nameInput = form.querySelector('input[name="name"]');
    nameInput.value = name;
    nameInput.readOnly = true;
    const sel = form.querySelector('select[name="source"]');
    if (![...sel.options].some(o => o.value === spec.source)) return;
    sel.value = spec.source;
    renderParamInputs(form);
    const params = spec.source === '_literal' ? { value: spec.value } : (spec.params || {});
    Object.entries(params).forEach(([pname, value]) => {
      const el = form.querySelector(`[name="param_${pname}"]`);
      if (!el || value == null) return;
      if (el.type === 'checkbox') el.checked = !!value;
      else el.value = typeof value === 'string' ? value : JSON.stringify(value);
      if (pname === 'filter_field') el.dispatchEvent(new Event('change'));
    });
    const filterValue = form.querySelector('[name="param_filter_value"]');
    if (filterValue && params.filter_value != null) filterValue.value = params.filter_value;
    const first = form.querySelector('#ac-binding-params input, #ac-binding-params select');
    if (first) first.focus();
  }

  function hideForm() {
    renderBindings();
  }

  function showNameError(form, text) {
    const el = form.querySelector('#ac-binding-name-error');
    if (!el) return;
    el.textContent = text;
    el.hidden = !text;
  }

  function renderSources(form) {
    const sel = form.querySelector('select[name="source"]');
    const groups = [
      ['Values', registry.filter(s => s.kind === 'literal')],
      ['Data sources', registry.filter(s => s.kind === 'source')],
      ['Collections', registry.filter(s => s.kind === 'collection')]
    ];
    sel.innerHTML = groups
      .filter(([, list]) => list.length > 0)
      .map(([label, list]) =>
        `<optgroup label="${escape(label)}">` +
        list.map(s => `<option value="${escape(s.name)}">${escape(s.label || s.name)}</option>`).join('') +
        '</optgroup>')
      .join('');
    renderParamInputs(form);
  }

  function renderParamInputs(form) {
    const sel = form.querySelector('select[name="source"]');
    const source = registry.find(s => s.name === sel.value);
    const target = form.querySelector('#ac-binding-params');
    if (!source) { target.innerHTML = ''; return; }
    target.innerHTML = Object.entries(source.params || {})
      .map(([pname, spec]) => paramInputHTML(pname, spec || {}))
      .join('');
    if (source.kind === 'collection') wireFilterValue(form, source);
  }

  // One input per param spec: allowed -> select (with labels), integer ->
  // number with min/max from range, boolean -> checkbox, else text.
  function paramInputHTML(pname, spec, allowedOverride) {
    const label = `<span class="data-panel-field-label">${escape(pname)}</span>`;
    const allowed = allowedOverride || spec.allowed;
    if (allowed) {
      const labels = spec.labels || {};
      const blank = spec.default == null ? '<option value="">— none —</option>' : '';
      const opts = allowed.map(v =>
        `<option value="${escape(v)}" ${String(spec.default) === String(v) ? 'selected' : ''}>${escape(labels[v] || v)}</option>`
      ).join('');
      return `<label class="data-panel-field">${label}<select name="param_${escape(pname)}">${blank}${opts}</select></label>`;
    }
    if (spec.type === 'integer') {
      const range = Array.isArray(spec.range) ? `min="${escape(spec.range[0])}" max="${escape(spec.range[1])}"` : '';
      return `<label class="data-panel-field">${label}<input type="number" name="param_${escape(pname)}" ${range} value="${escape(spec.default ?? '')}"></label>`;
    }
    if (spec.type === 'boolean') {
      return `<label class="data-panel-field data-panel-field-inline"><input type="checkbox" name="param_${escape(pname)}" ${spec.default ? 'checked' : ''}>${label}</label>`;
    }
    return `<label class="data-panel-field">${label}<input type="text" name="param_${escape(pname)}" value="${escape(spec.default ?? '')}"></label>`;
  }

  // When the chosen filter field is a select field, offer its options.
  function wireFilterValue(form, source) {
    const fieldSel = form.querySelector('[name="param_filter_field"]');
    if (!fieldSel) return;
    fieldSel.addEventListener('change', () => {
      const field = (source.fields || []).find(f => f.id === fieldSel.value);
      const current = form.querySelector('[name="param_filter_value"]');
      if (!current) return;
      const options = field && field.type === 'select' ? field.options : null;
      current.closest('label').outerHTML = paramInputHTML('filter_value', source.params.filter_value || {}, options);
    });
  }

  function onSave(e) {
    e.preventDefault();
    const form = e.target;
    const name = form.name.value.trim();
    if (!NAME_RE.test(name)) {
      showNameError(form, 'Use lowercase letters, digits and underscores, starting with a letter.');
      form.querySelector('input[name="name"]').focus();
      return;
    }
    if (bindings[name] && form.dataset.editing !== name && !window.confirm(`A binding named "${name}" already exists. Replace it?`)) return;
    const sourceName = form.source.value;
    const source = registry.find(s => s.name === sourceName);
    if (!source) { showPanelMessage('Pick a source.'); return; }
    const params = {};
    Object.keys(source.params || {}).forEach(pname => {
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
    return String(s).replace(/[<>&"']/g, c => ({ '<':'&lt;','>':'&gt;','&':'&amp;','"':'&quot;',"'":'&#39;' }[c]));
  }

  document.addEventListener('DOMContentLoaded', init);
})();
