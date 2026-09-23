/**
 * ActiveCanvas Editor - Loop and condition traits
 *
 * Every selectable component gets three traits in the Settings tab:
 *   Repeat for each  -> data-ac-for="<item> in <binding>"
 *   Item name        -> the <item> part
 *   Show only if     -> data-ac-if="<condition>"
 * The traits are (re)built on selection so the binding list is current.
 */
(function() {
  'use strict';

  window.ActiveCanvasEditor = window.ActiveCanvasEditor || {};

  const SKIP_TYPES = ['wrapper', 'textnode', 'comment', 'ac-chip'];

  function setupDirectiveTraits(editor, config) {
    if (!config.templateEnabled) return;

    editor.on('component:selected', component => {
      if (!component || SKIP_TYPES.includes(component.get('type'))) return;
      ensureTraits(component);
    });
  }

  function parseFor(value) {
    const match = /^\s*(\S+)\s+in\s+(\S+)/.exec(value || '');
    return match ? { item: match[1], binding: match[2] } : { item: '', binding: '' };
  }

  function ensureTraits(component) {
    const B = window.ActiveCanvasBindings;
    const current = parseFor(component.getAttributes()['data-ac-for']);

    ['ac-repeat', 'ac-item', 'data-ac-if'].forEach(name => component.removeTrait(name));
    component.set({ 'ac-repeat': current.binding, 'ac-item': current.item }, { silent: true });

    const names = B.listNames();
    const options = [{ id: '', name: '— none —' }].concat(names.map(name => ({ id: name, name })));
    if (current.binding && !names.includes(current.binding)) {
      options.push({ id: current.binding, name: `${current.binding} (missing)` });
    }

    component.addTrait([
      { type: 'select', name: 'ac-repeat', label: 'Repeat for each', changeProp: true, options },
      { type: 'text', name: 'ac-item', label: 'Item name', changeProp: true, placeholder: 'item' },
      { type: 'text', name: 'data-ac-if', label: 'Show only if', placeholder: 'item.featured' }
    ], { at: 0 });

    if (!component.__acDirectivesWired) {
      component.__acDirectivesWired = true;
      component.on('change:ac-repeat change:ac-item', () => applyFor(component));
      component.on('change:attributes:data-ac-if', () => {
        const value = (component.getAttributes()['data-ac-if'] || '').trim();
        if (!value) component.removeAttributes('data-ac-if');
      });
    }
  }

  function applyFor(component) {
    const binding = component.get('ac-repeat');
    if (!binding) {
      component.removeAttributes('data-ac-for');
      component.set('ac-item', '', { silent: true });
      return;
    }
    let item = (component.get('ac-item') || '').trim();
    if (!item) {
      item = window.ActiveCanvasBindings.itemName(binding);
      component.set('ac-item', item); // not silent: the trait input must show it
      return; // the change:ac-item handler calls applyFor again with the item set
    }
    component.addAttributes({ 'data-ac-for': `${item} in ${binding}` });
  }

  window.ActiveCanvasEditor.setupDirectiveTraits = setupDirectiveTraits;
})();
