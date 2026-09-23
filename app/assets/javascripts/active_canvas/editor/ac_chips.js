/**
 * ActiveCanvas Editor - Liquid chips
 *
 * The canvas always holds the page SOURCE. On load every `{{ expr }}` found in
 * a text node is wrapped in <span data-ac-var> so it can be styled and locked;
 * before save, preview, validation and the code view the wrapper is removed
 * again. Attributes, <script> and <style> are never touched, so the round
 * trip is lossless by construction. Loops and conditions are attributes
 * (data-ac-for / data-ac-if) that GrapesJS preserves on its own.
 */
(function() {
  'use strict';

  const VAR_RE = /\{\{[\s\S]*?\}\}/g;
  const SKIP_PARENTS = ['SCRIPT', 'STYLE', 'TEXTAREA'];

  function parse(html) {
    return new DOMParser().parseFromString(`<!doctype html><body>${html}</body>`, 'text/html');
  }

  // Wrap each {{ expr }} in a text node with a chip span.
  function decorate(html) {
    const doc = parse(html);
    const walker = doc.createTreeWalker(doc.body, NodeFilter.SHOW_TEXT);
    const nodes = [];
    while (walker.nextNode()) nodes.push(walker.currentNode);

    nodes.forEach(node => {
      const parent = node.parentNode;
      if (!parent || SKIP_PARENTS.includes(parent.nodeName)) return;
      if (parent.nodeType === 1 && parent.hasAttribute('data-ac-var')) return;
      const text = node.nodeValue;
      if (!/\{\{[\s\S]*?\}\}/.test(text)) return;

      const frag = doc.createDocumentFragment();
      let last = 0;
      let match;
      VAR_RE.lastIndex = 0;
      while ((match = VAR_RE.exec(text))) {
        if (match.index > last) frag.appendChild(doc.createTextNode(text.slice(last, match.index)));
        const span = doc.createElement('span');
        span.setAttribute('data-ac-var', '');
        span.textContent = match[0];
        frag.appendChild(span);
        last = match.index + match[0].length;
      }
      if (last < text.length) frag.appendChild(doc.createTextNode(text.slice(last)));
      parent.replaceChild(frag, node);
    });

    return doc.body.innerHTML;
  }

  // Replace each chip span with its text. The inverse of decorate().
  function undecorate(html) {
    if (!html || html.indexOf('data-ac-var') === -1) return html;
    const doc = parse(html);
    doc.querySelectorAll('span[data-ac-var]').forEach(el => {
      el.replaceWith(doc.createTextNode(el.textContent));
    });
    return doc.body.innerHTML;
  }

  const CANVAS_CSS = `
    span[data-ac-var] {
      display: inline; background: #eef2ff; color: #3730a3; border: 1px solid #c7d2fe;
      border-radius: 4px; padding: 0 4px; font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
      font-size: 0.9em; white-space: nowrap; cursor: default;
    }
    [data-ac-for] { outline: 1px dashed #6366f1; outline-offset: 2px; }
    [data-ac-for]::before {
      content: "\\21BB " attr(data-ac-for); display: inline-block; font: 11px/1.4 ui-monospace, SFMono-Regular, Menlo, monospace;
      background: #6366f1; color: #fff; padding: 0 5px; border-radius: 3px; margin-right: 4px; vertical-align: top;
    }
    [data-ac-if] { outline: 1px dotted #f59e0b; outline-offset: 2px; }
    [data-ac-if]::after {
      content: "if " attr(data-ac-if); display: inline-block; font: 11px/1.4 ui-monospace, SFMono-Regular, Menlo, monospace;
      background: #f59e0b; color: #1f2937; padding: 0 5px; border-radius: 3px; margin-left: 4px; vertical-align: top;
    }
  `;

  // GrapesJS plugin: registers the chip component type and styles the canvas.
  function plugin(editor) {
    editor.DomComponents.addType('ac-chip', {
      isComponent: el => el.nodeType === 1 && el.tagName === 'SPAN' && el.hasAttribute('data-ac-var'),
      model: {
        defaults: {
          name: 'Variable',
          tagName: 'span',
          editable: false,
          droppable: false,
          copyable: true,
          removable: true,
          layerable: false,
          traits: [],
          attributes: { 'data-ac-var': '' }
        },
        init() {
          // The view marks the element contenteditable=false so the RTE skips
          // it; that must never leak into the model (and so into the source).
          this.removeAttributes('contenteditable');
        }
      },
      view: {
        events: { dblclick: 'editExpression' },
        onRender() {
          this.el.setAttribute('contenteditable', 'false');
        },
        editExpression(e) {
          e.preventDefault();
          e.stopPropagation();
          const current = this.el.textContent.trim();
          const next = window.prompt('Liquid expression', current);
          if (next === null) return;
          const expr = next.trim();
          if (!expr) return;
          this.model.components(expr.startsWith('{{') ? expr : `{{ ${expr} }}`);
        }
      }
    });

    editor.on('load', () => {
      const doc = editor.Canvas.getDocument();
      if (!doc || doc.getElementById('ac-chips-css')) return;
      const style = doc.createElement('style');
      style.id = 'ac-chips-css';
      style.textContent = CANVAS_CSS;
      doc.head.appendChild(style);
    });
  }

  window.ActiveCanvasChips = { decorate, undecorate, plugin };
})();
