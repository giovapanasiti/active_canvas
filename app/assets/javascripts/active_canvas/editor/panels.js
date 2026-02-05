/**
 * ActiveCanvas Editor - Panel Controls, Device Switching, Save
 */

(function() {
  'use strict';

  window.ActiveCanvasEditor = window.ActiveCanvasEditor || {};

  /**
   * Setup panel controls (toggle left/right/AI panels, tabs)
   * @param {Object} editor - GrapeJS editor instance
   */
  function setupPanelControls(editor) {
    const panelLeft = document.getElementById('panel-left');
    const panelRight = document.getElementById('panel-right');
    const panelAi = document.getElementById('panel-ai');
    const btnToggleLeft = document.getElementById('btn-toggle-left');
    const btnToggleRight = document.getElementById('btn-toggle-right');
    const btnToggleAi = document.getElementById('btn-toggle-ai');
    const btnCloseAi = document.getElementById('btn-close-ai');

    function refreshEditor() {
      setTimeout(() => {
        editor.refresh();
      }, 250);
    }

    // Toggle left panel (blocks/assets/layers)
    if (btnToggleLeft && panelLeft) {
      btnToggleLeft.addEventListener('click', function() {
        const isOpening = panelLeft.classList.contains('collapsed');

        if (isOpening && panelAi) {
          // Close AI panel when opening left panel
          panelAi.classList.add('collapsed');
          if (btnToggleAi) btnToggleAi.classList.remove('active');
        }

        panelLeft.classList.toggle('collapsed');
        this.classList.toggle('active', !panelLeft.classList.contains('collapsed'));
        refreshEditor();
      });
    }

    // Toggle AI panel
    if (btnToggleAi && panelAi) {
      btnToggleAi.addEventListener('click', function() {
        const isOpening = panelAi.classList.contains('collapsed');

        if (isOpening && panelLeft) {
          // Close left panel when opening AI panel
          panelLeft.classList.add('collapsed');
          if (btnToggleLeft) btnToggleLeft.classList.remove('active');
        }

        panelAi.classList.toggle('collapsed');
        this.classList.toggle('active', !panelAi.classList.contains('collapsed'));
        refreshEditor();
      });
    }

    // Close AI panel button
    if (btnCloseAi && panelAi) {
      btnCloseAi.addEventListener('click', function() {
        panelAi.classList.add('collapsed');
        if (btnToggleAi) btnToggleAi.classList.remove('active');
        refreshEditor();
      });
    }

    // Toggle right panel
    if (btnToggleRight && panelRight) {
      btnToggleRight.addEventListener('click', function() {
        panelRight.classList.toggle('collapsed');
        this.classList.toggle('active', !panelRight.classList.contains('collapsed'));
        refreshEditor();
      });
    }

    // Panel tab switching
    document.querySelectorAll('.panel-tab').forEach(tab => {
      tab.addEventListener('click', function() {
        const panel = this.dataset.panel;
        const parent = this.closest('.editor-panel-left, .editor-panel-right');

        // Update active tab
        parent.querySelectorAll('.panel-tab').forEach(t => t.classList.remove('active'));
        this.classList.add('active');

        // Show/hide content
        if (parent.classList.contains('editor-panel-left')) {
          const blocksContainer = document.getElementById('blocks-container');
          const assetsContainer = document.getElementById('assets-container');
          const layersContainer = document.getElementById('layers-container');

          if (blocksContainer) blocksContainer.style.display = panel === 'blocks' ? 'block' : 'none';
          if (assetsContainer) assetsContainer.style.display = panel === 'assets' ? 'block' : 'none';
          if (layersContainer) layersContainer.style.display = panel === 'layers' ? 'block' : 'none';
        } else {
          const stylesContainer = document.getElementById('styles-container');
          const traitsContainer = document.getElementById('traits-container');

          if (stylesContainer) stylesContainer.style.display = panel === 'styles' ? 'block' : 'none';
          if (traitsContainer) traitsContainer.style.display = panel === 'settings' ? 'block' : 'none';
        }
      });
    });
  }

  /**
   * Setup device switching for responsive preview
   * @param {Object} editor - GrapeJS editor instance
   */
  function setupDeviceSwitching(editor) {
    document.querySelectorAll('.device-btn').forEach(btn => {
      btn.addEventListener('click', function() {
        const device = this.dataset.device;
        document.querySelectorAll('.device-btn').forEach(b => b.classList.remove('active'));
        this.classList.add('active');

        const deviceMap = {
          'desktop': 'Desktop',
          'tablet': 'Tablet',
          'mobile': 'Mobile'
        };

        // Set the device in GrapeJS
        editor.setDevice(deviceMap[device]);

        // Refresh the canvas to ensure proper rendering
        setTimeout(() => {
          editor.refresh();
        }, 100);
      });
    });

    // Set initial device to Desktop on load
    editor.on('load', () => {
      editor.setDevice('Desktop');
    });
  }

  /**
   * Setup undo/redo buttons
   * @param {Object} editor - GrapeJS editor instance
   */
  function setupUndoRedo(editor) {
    const undoBtn = document.getElementById('btn-undo');
    const redoBtn = document.getElementById('btn-redo');

    if (undoBtn) {
      undoBtn.addEventListener('click', () => {
        editor.UndoManager.undo();
      });
    }

    if (redoBtn) {
      redoBtn.addEventListener('click', () => {
        editor.UndoManager.redo();
      });
    }
  }

  /**
   * Setup save functionality
   * @param {Object} editor - GrapeJS editor instance
   * @param {Object} config - Editor configuration
   * @param {string} csrfToken - CSRF token for requests
   */
  function setupSave(editor, config, csrfToken) {
    const { showToast, showLoading } = window.ActiveCanvasEditor;

    const saveBtn = document.getElementById('btn-save');
    if (saveBtn) {
      saveBtn.addEventListener('click', () => saveContent(false));
    }

    // Keyboard shortcuts
    document.addEventListener('keydown', function(e) {
      if ((e.ctrlKey || e.metaKey) && e.key === 's') {
        e.preventDefault();
        saveContent(false);
      }
    });

    // Auto-save every 60 seconds
    setInterval(() => {
      saveContent(true);
    }, 60000);

    function saveContent(isAutoSave) {
      const saveBtn = document.getElementById('btn-save');
      if (saveBtn) saveBtn.disabled = true;

      const html = editor.getHtml();
      const css = editor.getCss();
      const js = window.ActiveCanvasEditor.getJs ? window.ActiveCanvasEditor.getJs() : '';
      const components = JSON.stringify(editor.getComponents());

      // Use entityType from config (defaults to 'page' for backwards compatibility)
      const entityType = config.entityType || 'page';
      const payload = {};
      payload[entityType] = {
        content: html,
        content_css: css,
        content_js: js,
        content_components: components
      };

      fetch(config.saveUrl, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfToken,
          'Accept': 'application/json'
        },
        body: JSON.stringify(payload)
      })
      .then(response => response.json())
      .then(result => {
        if (result.success) {
          // Build save message with Tailwind compilation info
          let message = isAutoSave ? 'Auto-saved' : 'Page saved successfully';

          if (result.tailwind && result.tailwind.compiled) {
            if (result.tailwind.success) {
              const sizeKb = (result.tailwind.css_size / 1024).toFixed(1);
              message += ` · Tailwind compiled (${sizeKb}KB in ${result.tailwind.elapsed_ms}ms)`;
            } else {
              showToast('Page saved, but Tailwind compilation failed: ' + result.tailwind.error, 'warning');
              return;
            }
          }

          showToast(message, 'success');
        } else {
          showToast(result.errors ? result.errors.join(', ') : 'Save failed', 'error');
        }
      })
      .catch(error => {
        showToast('Save failed', 'error');
        console.error('Save error:', error);
      })
      .finally(() => {
        if (saveBtn) saveBtn.disabled = false;
      });
    }
  }

  /**
   * Setup add section button
   * @param {Object} editor - GrapeJS editor instance
   */
  function setupAddSection(editor) {
    const btnAddSection = document.getElementById('btn-add-section');

    if (!btnAddSection) return;

    btnAddSection.addEventListener('click', function() {
      // Add a new empty section at the end of the page
      const wrapper = editor.getWrapper();

      const section = wrapper.append({
        tagName: 'section',
        classes: ['ac-section'],
        style: {
          'min-height': '100px',
          'padding': '2rem'
        },
        content: ''
      })[0];

      // Select the new section
      editor.select(section);

      // Scroll to the new section in the canvas
      const frame = editor.Canvas.getFrameEl();
      if (frame && frame.contentWindow) {
        const el = section.getEl();
        if (el) {
          el.scrollIntoView({ behavior: 'smooth', block: 'center' });
        }
      }
    });
  }

  /**
   * Setup canvas injection for global CSS/JS
   * @param {Object} editor - GrapeJS editor instance
   * @param {Object} config - Editor configuration
   */
  function setupCanvasInjection(editor, config) {
    editor.on('load', () => {
      setTimeout(() => {
        const frame = editor.Canvas.getFrameEl();
        if (!frame || !frame.contentDocument) return;

        // Inject Tailwind config before the CDN script (if using Tailwind)
        if (config.cssFramework === 'tailwind' && config.tailwindConfig) {
          const tailwindConfigScript = frame.contentDocument.createElement('script');
          tailwindConfigScript.id = 'active-canvas-tailwind-config';
          tailwindConfigScript.textContent = 'tailwind.config = ' + JSON.stringify(config.tailwindConfig) + ';';
          // Insert at the beginning of head so it's available before Tailwind CDN loads
          frame.contentDocument.head.insertBefore(tailwindConfigScript, frame.contentDocument.head.firstChild);
        }

        // Inject editor-specific CSS (for empty sections, etc.)
        const editorStyle = frame.contentDocument.createElement('style');
        editorStyle.id = 'active-canvas-editor-css';
        editorStyle.textContent = `
          /* Empty section placeholder styling */
          section:empty,
          .ac-section:empty,
          [data-gjs-type="section"]:empty {
            min-height: 100px !important;
            background-color: #fef2f2 !important;
            border: 2px dashed #fca5a5 !important;
            display: flex !important;
            align-items: center !important;
            justify-content: center !important;
            position: relative;
          }
          section:empty::after,
          .ac-section:empty::after,
          [data-gjs-type="section"]:empty::after {
            content: "Empty section - drag content here";
            color: #f87171;
            font-size: 14px;
            font-weight: 500;
          }
        `;
        frame.contentDocument.head.appendChild(editorStyle);

        // Inject global CSS
        if (config.globalCss && config.globalCss.trim()) {
          const globalStyle = frame.contentDocument.createElement('style');
          globalStyle.id = 'active-canvas-global-css';
          globalStyle.textContent = config.globalCss;
          frame.contentDocument.head.appendChild(globalStyle);
        }

        // Inject global JS
        if (config.globalJs && config.globalJs.trim()) {
          const globalScript = frame.contentDocument.createElement('script');
          globalScript.id = 'active-canvas-global-js';
          globalScript.textContent = config.globalJs;
          frame.contentDocument.body.appendChild(globalScript);
        }

        // Inject page-specific JS
        if (config.contentJs && config.contentJs.trim()) {
          const script = frame.contentDocument.createElement('script');
          script.id = 'active-canvas-custom-js';
          script.textContent = config.contentJs;
          frame.contentDocument.body.appendChild(script);
        }
      }, 500);
    });
  }

  /**
   * Setup RTE toolbar visibility management
   * Hides the toolbar when not actively editing text
   * @param {Object} editor - GrapeJS editor instance
   */
  function setupRteToolbar(editor) {
    let rteActive = false;

    // Function to hide RTE toolbar
    const hideRteToolbar = () => {
      rteActive = false;
      const rteToolbar = document.querySelector('.gjs-rte-toolbar');
      if (rteToolbar) {
        rteToolbar.classList.add('ac-rte-hidden');
      }
    };

    // Function to show RTE toolbar
    const showRteToolbar = () => {
      const rteToolbar = document.querySelector('.gjs-rte-toolbar');
      if (rteToolbar) {
        rteToolbar.classList.remove('ac-rte-hidden');
      }
    };

    // Check if component is a text element
    const isTextComponent = (component) => {
      if (!component) return false;
      const type = component.get('type');
      const tagName = (component.get('tagName') || '').toLowerCase();

      // Text component types
      const textTypes = ['text', 'textnode', 'label'];
      if (textTypes.includes(type)) return true;

      // Text-like HTML tags
      const textTags = ['p', 'span', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'a', 'label', 'li', 'td', 'th', 'blockquote', 'cite', 'em', 'strong', 'b', 'i', 'u'];
      if (textTags.includes(tagName)) return true;

      return false;
    };

    // Track RTE state
    editor.on('rte:enable', () => {
      rteActive = true;
      showRteToolbar();
    });

    editor.on('rte:disable', () => {
      hideRteToolbar();
    });

    // Hide when selecting a non-text component
    editor.on('component:selected', (component) => {
      if (!isTextComponent(component)) {
        hideRteToolbar();
        // Also disable RTE if it was active
        if (rteActive) {
          editor.RichTextEditor.disable();
        }
      }
    });

    // Hide when deselecting
    editor.on('component:deselected', () => {
      hideRteToolbar();
    });

    // Initial hide after editor loads
    editor.on('load', () => {
      setTimeout(hideRteToolbar, 100);

      // Set up a MutationObserver to catch the toolbar being created
      const observer = new MutationObserver((mutations) => {
        mutations.forEach((mutation) => {
          mutation.addedNodes.forEach((node) => {
            if (node.classList && node.classList.contains('gjs-rte-toolbar')) {
              if (!rteActive) {
                node.classList.add('ac-rte-hidden');
              }
            }
          });
        });
      });

      observer.observe(document.body, { childList: true, subtree: true });
    });
  }

  // Expose functions
  window.ActiveCanvasEditor.setupPanelControls = setupPanelControls;
  window.ActiveCanvasEditor.setupDeviceSwitching = setupDeviceSwitching;
  window.ActiveCanvasEditor.setupUndoRedo = setupUndoRedo;
  window.ActiveCanvasEditor.setupSave = setupSave;
  window.ActiveCanvasEditor.setupAddSection = setupAddSection;
  window.ActiveCanvasEditor.setupCanvasInjection = setupCanvasInjection;
  window.ActiveCanvasEditor.setupRteToolbar = setupRteToolbar;

})();
