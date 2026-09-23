/**
 * ActiveCanvas Editor - Loop and condition traits
 *
 * Every selectable component gets three traits in the Settings tab:
 *   Repeat for each  -> data-ac-for="<item> in <binding>"
 *   Item name        -> the <item> part
 *   Show only if     -> data-ac-if="<condition>"
 * The traits are (re)built on selection so the binding list is current.
 * Liquid loop modifiers after the binding (limit:, offset:, reversed) are
 * kept as they are when the item or the binding changes.
 */
(function() {
  'use strict';

  window.ActiveCanvasEditor = window.ActiveCanvasEditor || {};

  const SKIP_TYPES = ['wrapper', 'textnode', 'comment', 'ac-chip'];
  const PROPS = ['ac-repeat', 'ac-item', 'ac-tail'];

  function setupDirectiveTraits(editor, config) {
    if (!config.templateEnabled) return;

    editor.on('component:selected', component => {
      if (!component || SKIP_TYPES.includes(component.get('type'))) return;
      ensureTraits(component);
    });
  }

  function parseFor(value) {
    const match = /^\s*(\S+)\s+in\s+(\S+)(.*)$/.exec(value || '');
    return match
      ? { item: match[1], binding: match[2], tail: match[3].trim() }
      : { item: '', binding: '', tail: '' };
  }

  function ensureTraits(component) {
    const bindings = window.ActiveCanvasBindings;
    const current = parseFor(component.getAttributes()['data-ac-for']);

    ['ac-repeat', 'ac-item', 'data-ac-if'].forEach(name => component.removeTrait(name));
    component.set({ 'ac-repeat': current.binding, 'ac-item': current.item, 'ac-tail': current.tail }, { silent: true });

    const names = bindings.listNames();
    const options = [{ id: '', name: '— none —' }].concat(names.map(name => ({ id: name, name })));
    if (current.binding && !names.includes(current.binding)) {
      const note = bindings.read()[current.binding] ? 'not a list' : 'missing';
      options.push({ id: current.binding, name: `${current.binding} (${note})` });
    }

    component.addTrait([
      { type: 'select', name: 'ac-repeat', label: 'Repeat for each', changeProp: true, options },
      { type: 'text', name: 'ac-item', label: 'Item name', changeProp: true, placeholder: 'item' },
      { type: 'text', name: 'data-ac-if', label: 'Show only if', placeholder: `${current.item || 'item'}.featured` }
    ], { at: 0 });

    if (!component.__acDirectivesWired) {
      component.__acDirectivesWired = true;
      component.set('_undoexc', (component.get('_undoexc') || []).concat(PROPS), { silent: true });
      component.on('change:ac-repeat change:ac-item', () => applyFor(component));
      component.on('change:attributes:data-ac-for', () => syncFromAttribute(component));
      component.on('change:attributes:data-ac-if', () => {
        const value = (component.getAttributes()['data-ac-if'] || '').trim();
        if (!value) component.removeAttributes('data-ac-if');
      });
    }
  }

  function applyFor(component) {
    const binding = component.get('ac-repeat');
    if (!binding) {
      if ('data-ac-for' in component.getAttributes()) component.removeAttributes('data-ac-for');
      return;
    }
    let item = (component.get('ac-item') || '').trim();
    if (!item) {
      item = window.ActiveCanvasBindings.itemName(binding);
      component.set('ac-item', item); // not silent: the trait input must show it
      return; // the change:ac-item handler calls applyFor again with the item set
    }
    const tail = component.get('ac-tail') || '';
    const next = `${item} in ${binding}${tail ? ' ' + tail : ''}`;
    if (component.getAttributes()['data-ac-for'] !== next) component.addAttributes({ 'data-ac-for': next });
  }

  // Keeps the trait values in step with the attribute when it changes behind
  // the traits' back (undo, code panel, another handler). Non-silent so the
  // inputs re-render; applyFor is a no-op when nothing differs.
  function syncFromAttribute(component) {
    const parsed = parseFor(component.getAttributes()['data-ac-for']);
    if (component.get('ac-repeat') === parsed.binding && component.get('ac-item') === parsed.item && component.get('ac-tail') === parsed.tail) return;
    component.set({ 'ac-repeat': parsed.binding, 'ac-item': parsed.item, 'ac-tail': parsed.tail });
  }

  window.ActiveCanvasEditor.setupDirectiveTraits = setupDirectiveTraits;
})();
