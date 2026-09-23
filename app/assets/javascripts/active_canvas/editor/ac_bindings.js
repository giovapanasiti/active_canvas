/**
 * ActiveCanvas Editor - Bindings store
 *
 * The one place that knows where the page's bindings live while editing
 * (localStorage, seeded from the server on every load) and which data
 * sources exist. Every other module reads and writes through here.
 *
 * Events on document:
 *   ac:bindings-changed  { bindings }   after write()
 *   ac:registry-loaded   { registry }   after setRegistry()
 */
(function() {
  'use strict';

  const container = document.getElementById('data-panel-container');
  const pageId = container ? container.dataset.pageId : null;
  const key = pageId ? `ac:bindings:${pageId}` : null;
  let registry = [];

  function read() {
    if (!key) return {};
    try {
      return JSON.parse(localStorage.getItem(key) || '{}') || {};
    } catch (e) {
      return {};
    }
  }

  function save(bindings) {
    if (!key) return;
    try { localStorage.setItem(key, JSON.stringify(bindings)); } catch (e) { /* storage unavailable */ }
  }

  function write(bindings) {
    save(bindings);
    document.dispatchEvent(new CustomEvent('ac:bindings-changed', { detail: { bindings } }));
  }

  function readJson() {
    return JSON.stringify(read());
  }

  function setRegistry(list) {
    registry = Array.isArray(list) ? list : [];
    document.dispatchEvent(new CustomEvent('ac:registry-loaded', { detail: { registry } }));
  }

  function source(name) {
    return registry.find(s => s.name === name) || null;
  }

  // True when the binding resolves to something a loop can iterate.
  function isList(name) {
    const spec = read()[name];
    if (!spec) return false;
    if (spec.source === '_literal') return Array.isArray(spec.value);
    const src = source(spec.source);
    return !!src && (src.kind === 'collection' || src.list === true);
  }

  function listNames() {
    return Object.keys(read()).filter(isList);
  }

  function itemName(name) {
    const spec = read()[name];
    const src = spec ? source(spec.source) : null;
    return (src && src.item_name) || 'item';
  }

  // The server's copy wins on load: the page may have been saved elsewhere.
  const seed = document.getElementById('ac-server-bindings');
  if (seed) {
    try { save(JSON.parse(seed.textContent || '{}')); } catch (e) { save({}); }
  }

  window.ActiveCanvasBindings = {
    pageId, read, save, write, readJson, setRegistry, source, isList, listNames, itemName,
    registry: () => registry
  };
})();
