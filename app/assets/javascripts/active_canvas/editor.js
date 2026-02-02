/**
 * ActiveCanvas Visual Editor
 *
 * This file contains the main editor logic for the GrapeJS-based page builder.
 * Configuration is passed via window.ActiveCanvasEditor.config
 */

(function() {
  'use strict';

  // Wait for DOM and config to be ready
  document.addEventListener('DOMContentLoaded', function() {
    if (!window.ActiveCanvasEditor || !window.ActiveCanvasEditor.config) {
      console.error('ActiveCanvasEditor config not found');
      return;
    }

    const config = window.ActiveCanvasEditor.config;
    initEditor(config);
  });

  function initEditor(config) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]').getAttribute('content');

    // Parse components JSON if available, otherwise use HTML content
    let componentsToLoad = config.content || '';
    if (config.contentComponents) {
      try {
        componentsToLoad = JSON.parse(config.contentComponents);
      } catch (e) {
        console.warn('Could not parse components JSON, falling back to HTML content');
        componentsToLoad = config.content || '';
      }
    }

    // Determine canvas configuration based on framework
    let canvasStyles = [];
    let canvasScripts = [];

    if (config.cssFrameworkUrl) {
      if (config.cssFrameworkType === 'script') {
        canvasScripts.push(config.cssFrameworkUrl);
      } else if (config.cssFrameworkType === 'stylesheet') {
        canvasStyles.push(config.cssFrameworkUrl);
      }
    }

    // Initialize GrapeJS
    const editor = grapesjs.init({
      container: '#gjs',
      height: '100%',
      width: 'auto',
      fromElement: false,

      // Load existing content
      components: componentsToLoad,
      style: config.contentCss || '',

      // Storage - we'll handle saving manually
      storageManager: false,

      // Device Manager
      deviceManager: {
        devices: [
          { name: 'Desktop', width: '' },
          { name: 'Tablet', width: '768px', widthMedia: '992px' },
          { name: 'Mobile', width: '320px', widthMedia: '480px' }
        ]
      },

      // Panels - we'll use custom panels
      panels: { defaults: [] },

      // Block Manager
      blockManager: {
        appendTo: '#blocks-container'
      },

      // Layer Manager
      layerManager: {
        appendTo: '#layers-container'
      },

      // Style Manager
      styleManager: {
        appendTo: '#styles-container',
        sectors: [
          {
            name: 'Dimension',
            open: true,
            buildProps: ['width', 'min-width', 'max-width', 'height', 'min-height', 'max-height', 'padding', 'margin']
          },
          {
            name: 'Typography',
            open: false,
            buildProps: ['font-family', 'font-size', 'font-weight', 'letter-spacing', 'color', 'line-height', 'text-align', 'text-decoration', 'text-shadow']
          },
          {
            name: 'Decorations',
            open: false,
            buildProps: ['background-color', 'border-radius', 'border', 'box-shadow']
          },
          {
            name: 'Extra',
            open: false,
            buildProps: ['opacity', 'transition', 'transform']
          }
        ]
      },

      // Trait Manager
      traitManager: {
        appendTo: '#traits-container'
      },

      // Selector Manager
      selectorManager: {
        appendTo: '#styles-container',
        componentFirst: true
      },

      // Asset Manager
      assetManager: {
        uploadName: 'media[file]',
        uploadFile: function(e) {
          const files = e.dataTransfer ? e.dataTransfer.files : e.target.files;
          const formData = new FormData();

          for (let i = 0; i < files.length; i++) {
            formData.append('media[file]', files[i]);
            formData.append('media[filename]', files[i].name);
          }

          fetch(config.uploadUrl, {
            method: 'POST',
            headers: {
              'X-CSRF-Token': csrfToken
            },
            body: formData
          })
          .then(response => response.json())
          .then(result => {
            if (result.src) {
              editor.AssetManager.add(result);
              showToast('Image uploaded successfully', 'success');
            } else if (result.errors) {
              showToast(result.errors.join(', '), 'error');
            }
          })
          .catch(error => {
            showToast('Upload failed', 'error');
            console.error('Upload error:', error);
          });
        },
        assets: []
      },

      // Canvas - use scripts for Tailwind, styles for others
      canvas: {
        styles: canvasStyles,
        scripts: canvasScripts
      },

      // Plugins
      plugins: [
        'gjs-blocks-basic',
        'grapesjs-plugin-forms',
        'grapesjs-preset-webpage',
        'grapesjs-style-bg',
        'grapesjs-tabs',
        'grapesjs-custom-code',
        'grapesjs-touch',
        'grapesjs-parser-postcss',
        'grapesjs-tooltip',
        'grapesjs-typed'
      ],

      pluginsOpts: {
        'gjs-blocks-basic': {
          flexGrid: true,
          stylePrefix: 'gjs-'
        },
        'grapesjs-plugin-forms': {},
        'grapesjs-preset-webpage': {
          modalImportTitle: 'Import Template',
          modalImportLabel: '<div style="margin-bottom: 10px; font-size: 13px;">Paste your HTML/CSS here</div>',
          modalImportContent: function(editor) {
            return editor.getHtml() + '<style>' + editor.getCss() + '</style>';
          }
        },
        'grapesjs-tabs': {
          tabsBlock: { category: 'Extra' }
        },
        'grapesjs-typed': {
          block: {
            category: 'Extra',
            content: {
              type: 'typed',
              'type-speed': 40,
              strings: ['Text row one', 'Text row two', 'Text row three']
            }
          }
        }
      }
    });

    // Add custom blocks
    addCustomBlocks(editor);

    // Load existing assets
    loadAssets(editor, config.mediaUrl);

    // Setup component code editing
    setupComponentCodeEditing(editor);

    // Inject global and page-specific CSS/JS into canvas
    setupCanvasInjection(editor, config);

    // Setup panel controls
    setupPanelControls(editor);

    // Setup device switching
    setupDeviceSwitching(editor);

    // Setup undo/redo
    setupUndoRedo(editor);

    // Setup preview
    setupPreview(editor);

    // Setup code panel
    setupCodePanel(editor, config);

    // Setup save functionality
    setupSave(editor, config, csrfToken);

    // Expose editor instance for debugging
    window.ActiveCanvasEditor.instance = editor;
  }

  // ==================== Component Code Editing ====================

  function setupComponentCodeEditing(editor) {
    // Add code button to component toolbar
    editor.on('component:selected', (component) => {
      if (!component) return;

      let toolbar = component.get('toolbar') || [];

      // Ensure toolbar is an array
      if (!Array.isArray(toolbar)) {
        toolbar = [];
      }

      // Check if code button already exists
      const hasCodeBtn = toolbar.some(item => item.command === 'edit-component-code');

      if (!hasCodeBtn) {
        toolbar.unshift({
          attributes: { class: 'fa-solid fa-code', title: 'Edit Code' },
          command: 'edit-component-code'
        });
        component.set('toolbar', toolbar);
      }
    });

    // Add command for editing component code
    editor.Commands.add('edit-component-code', {
      run(editor) {
        const selected = editor.getSelected();
        if (!selected) return;

        window.ActiveCanvasEditor.openComponentCodeEditor(selected);
      }
    });
  }

  // ==================== Canvas Injection ====================

  function setupCanvasInjection(editor, config) {
    editor.on('load', () => {
      setTimeout(() => {
        const frame = editor.Canvas.getFrameEl();
        if (!frame || !frame.contentDocument) return;

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

  // ==================== Panel Controls ====================

  function setupPanelControls(editor) {
    const panelLeft = document.getElementById('panel-left');
    const panelRight = document.getElementById('panel-right');
    const btnToggleLeft = document.getElementById('btn-toggle-left');
    const btnToggleRight = document.getElementById('btn-toggle-right');

    function refreshEditor() {
      setTimeout(() => {
        editor.refresh();
      }, 250);
    }

    btnToggleLeft.addEventListener('click', function() {
      panelLeft.classList.toggle('collapsed');
      this.classList.toggle('active', panelLeft.classList.contains('collapsed'));
      refreshEditor();
    });

    btnToggleRight.addEventListener('click', function() {
      panelRight.classList.toggle('collapsed');
      this.classList.toggle('active', panelRight.classList.contains('collapsed'));
      refreshEditor();
    });

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
          document.getElementById('blocks-container').style.display = panel === 'blocks' ? 'block' : 'none';
          document.getElementById('layers-container').style.display = panel === 'layers' ? 'block' : 'none';
          document.getElementById('ai-container').style.display = panel === 'ai' ? 'block' : 'none';
        } else {
          document.getElementById('styles-container').style.display = panel === 'styles' ? 'block' : 'none';
          document.getElementById('traits-container').style.display = panel === 'settings' ? 'block' : 'none';
        }
      });
    });
  }

  // ==================== Device Switching ====================

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
        editor.setDevice(deviceMap[device]);
      });
    });
  }

  // ==================== Undo/Redo ====================

  function setupUndoRedo(editor) {
    document.getElementById('btn-undo').addEventListener('click', () => {
      editor.UndoManager.undo();
    });

    document.getElementById('btn-redo').addEventListener('click', () => {
      editor.UndoManager.redo();
    });
  }

  // ==================== Preview ====================

  function setupPreview(editor) {
    document.getElementById('btn-preview').addEventListener('click', () => {
      editor.runCommand('preview');
    });
  }

  // ==================== Code Panel ====================

  function setupCodePanel(editor, config) {
    const codePanel = document.getElementById('code-panel');
    const btnCode = document.getElementById('btn-code');
    const statusEl = document.getElementById('code-status');
    const codePanelMode = document.getElementById('code-panel-mode');
    const componentNameEl = document.getElementById('component-name');

    let currentCodeTab = 'html';
    let codeDebounceTimer = null;
    let htmlMonacoEditor = null;
    let cssMonacoEditor = null;
    let jsMonacoEditor = null;
    let monacoInitialized = false;

    // Component editing mode
    let editingComponent = null;
    let isComponentMode = false;

    // Initialize Monaco editors
    function initMonacoEditors() {
      if (monacoInitialized) return;

      require(['vs/editor/editor.main'], function() {
        // Define custom dark theme
        monaco.editor.defineTheme('activeCanvasDark', {
          base: 'vs-dark',
          inherit: true,
          rules: [],
          colors: {
            'editor.background': '#1e1e1e',
            'editor.foreground': '#d4d4d4',
            'editorLineNumber.foreground': '#858585',
            'editorCursor.foreground': '#aeafad',
            'editor.selectionBackground': '#264f78',
            'editor.lineHighlightBackground': '#2d2d2d'
          }
        });

        // Common editor options
        const editorOptions = {
          theme: 'activeCanvasDark',
          fontSize: 13,
          lineNumbers: 'on',
          minimap: { enabled: false },
          scrollBeyondLastLine: false,
          automaticLayout: true,
          tabSize: 2,
          wordWrap: 'on',
          folding: true,
          lineDecorationsWidth: 10,
          lineNumbersMinChars: 3,
          renderLineHighlight: 'line',
          scrollbar: {
            verticalScrollbarSize: 10,
            horizontalScrollbarSize: 10
          }
        };

        // Create HTML editor
        htmlMonacoEditor = monaco.editor.create(document.getElementById('monaco-html-container'), {
          value: editor.getHtml(),
          language: 'html',
          ...editorOptions
        });

        // Create CSS editor
        cssMonacoEditor = monaco.editor.create(document.getElementById('monaco-css-container'), {
          value: editor.getCss(),
          language: 'css',
          ...editorOptions
        });

        // Create JS editor
        jsMonacoEditor = monaco.editor.create(document.getElementById('monaco-js-container'), {
          value: config.contentJs || '',
          language: 'javascript',
          ...editorOptions
        });

        // Live update on content change
        htmlMonacoEditor.onDidChangeModelContent(scheduleCodeUpdate);
        cssMonacoEditor.onDidChangeModelContent(scheduleCodeUpdate);
        jsMonacoEditor.onDidChangeModelContent(scheduleJsUpdate);

        // Add keyboard shortcuts to Monaco
        addMonacoCommands(htmlMonacoEditor);
        addMonacoCommands(cssMonacoEditor);
        addMonacoCommands(jsMonacoEditor);

        monacoInitialized = true;

        // Auto-format on first open
        setTimeout(formatAllCode, 100);
      });
    }

    // Sync GrapeJS content to Monaco editors
    function syncGrapeJSToMonaco() {
      if (!monacoInitialized) return;

      if (isComponentMode && editingComponent) {
        htmlMonacoEditor.setValue(editingComponent.toHTML());
      } else {
        htmlMonacoEditor.setValue(editor.getHtml());
      }
      cssMonacoEditor.setValue(editor.getCss());
      setTimeout(formatAllCode, 50);
    }

    // Update GrapeJS preview from Monaco
    function updatePreviewFromCode() {
      if (!monacoInitialized) return;

      try {
        if (isComponentMode && editingComponent) {
          const newHtml = htmlMonacoEditor.getValue();
          updateComponentFromHtml(editingComponent, newHtml);
        } else {
          const newHtml = htmlMonacoEditor.getValue();
          const newCss = cssMonacoEditor.getValue();
          editor.setComponents(newHtml);
          editor.setStyle(newCss);
        }
        statusEl.textContent = 'Synced';
        statusEl.className = 'code-status synced';
      } catch (e) {
        statusEl.textContent = 'Error';
        statusEl.className = 'code-status modified';
        console.error('Code parse error:', e);
      }
    }

    // Update a component from HTML string
    function updateComponentFromHtml(component, html) {
      if (!component) return;

      try {
        const newComponents = component.replaceWith(html);

        if (newComponents && newComponents.length > 0) {
          editingComponent = newComponents[0];
          editor.select(editingComponent);
        }
      } catch (e) {
        console.error('Error replacing component:', e);
        try {
          component.components(html);
        } catch (e2) {
          console.error('Error updating component content:', e2);
        }
      }
    }

    // Open code panel in component editing mode
    function openComponentCodeEditor(component) {
      editingComponent = component;
      isComponentMode = true;

      codePanelMode.style.display = 'flex';
      componentNameEl.textContent = getComponentName(component);

      // Hide CSS/JS tabs in component mode
      document.querySelectorAll('.code-panel-tab').forEach(t => {
        if (t.dataset.type === 'html') {
          t.style.display = '';
          t.classList.add('active');
        } else {
          t.style.display = 'none';
          t.classList.remove('active');
        }
      });
      currentCodeTab = 'html';

      codePanel.classList.add('open');
      btnCode.classList.add('active');

      if (!monacoInitialized) {
        initMonacoEditors();
        setTimeout(() => {
          htmlMonacoEditor.setValue(component.toHTML());
          setTimeout(() => htmlMonacoEditor.getAction('editor.action.formatDocument').run(), 50);

          document.getElementById('monaco-html-container').style.display = 'block';
          document.getElementById('monaco-css-container').style.display = 'none';
          document.getElementById('monaco-js-container').style.display = 'none';

          htmlMonacoEditor.layout();
          htmlMonacoEditor.focus();
        }, 200);
      } else {
        htmlMonacoEditor.setValue(component.toHTML());
        setTimeout(() => htmlMonacoEditor.getAction('editor.action.formatDocument').run(), 50);

        document.getElementById('monaco-html-container').style.display = 'block';
        document.getElementById('monaco-css-container').style.display = 'none';
        document.getElementById('monaco-js-container').style.display = 'none';

        htmlMonacoEditor.layout();
        htmlMonacoEditor.focus();
      }

      setTimeout(() => editor.refresh(), 50);
    }

    // Expose for external use
    window.ActiveCanvasEditor.openComponentCodeEditor = openComponentCodeEditor;

    // Get a friendly name for a component
    function getComponentName(component) {
      const type = component.get('type');
      const tagName = component.get('tagName') || 'div';
      const classes = component.getClasses().slice(0, 2).join('.');
      const id = component.getId();

      if (id) return `#${id}`;
      if (classes) return `${tagName}.${classes}`;
      if (type && type !== 'default') return type;
      return tagName;
    }

    // Exit component mode
    function exitComponentMode() {
      const wasInComponentMode = isComponentMode;
      isComponentMode = false;
      editingComponent = null;
      codePanelMode.style.display = 'none';

      document.querySelectorAll('.code-panel-tab').forEach(t => {
        t.style.display = '';
      });

      if (wasInComponentMode && monacoInitialized) {
        syncGrapeJSToMonaco();
      }
    }

    function scheduleCodeUpdate() {
      statusEl.textContent = 'Modified...';
      statusEl.className = 'code-status modified';

      if (codeDebounceTimer) {
        clearTimeout(codeDebounceTimer);
      }
      codeDebounceTimer = setTimeout(updatePreviewFromCode, 200);
    }

    async function formatAllCode() {
      if (!monacoInitialized) return;
      await htmlMonacoEditor.getAction('editor.action.formatDocument').run();
      await cssMonacoEditor.getAction('editor.action.formatDocument').run();
      await jsMonacoEditor.getAction('editor.action.formatDocument').run();
    }

    function scheduleJsUpdate() {
      statusEl.textContent = 'Modified...';
      statusEl.className = 'code-status modified';

      if (codeDebounceTimer) {
        clearTimeout(codeDebounceTimer);
      }
      codeDebounceTimer = setTimeout(() => {
        injectJsIntoCanvas();
        statusEl.textContent = 'Synced';
        statusEl.className = 'code-status synced';
      }, 200);
    }

    function injectJsIntoCanvas() {
      if (!monacoInitialized) return;

      const jsCode = jsMonacoEditor.getValue();
      const frame = editor.Canvas.getFrameEl();
      if (!frame || !frame.contentDocument) return;

      const existingScript = frame.contentDocument.getElementById('active-canvas-custom-js');
      if (existingScript) {
        existingScript.remove();
      }

      if (jsCode.trim()) {
        const script = frame.contentDocument.createElement('script');
        script.id = 'active-canvas-custom-js';
        script.textContent = jsCode;
        frame.contentDocument.body.appendChild(script);
      }
    }

    function addMonacoCommands(monacoEditor) {
      monacoEditor.addCommand(monaco.KeyMod.CtrlCmd | monaco.KeyCode.KeyS, async () => {
        if (codeDebounceTimer) {
          clearTimeout(codeDebounceTimer);
        }
        await formatAllCode();
        updatePreviewFromCode();
        showToast('Formatted and applied', 'success');
      });

      monacoEditor.addCommand(monaco.KeyMod.CtrlCmd | monaco.KeyMod.Shift | monaco.KeyCode.KeyF, () => {
        monacoEditor.getAction('editor.action.formatDocument').run();
      });
    }

    function toggleCodePanel() {
      const isOpen = codePanel.classList.toggle('open');
      btnCode.classList.toggle('active', isOpen);

      if (isOpen) {
        exitComponentMode();

        if (!monacoInitialized) {
          initMonacoEditors();
        } else {
          syncGrapeJSToMonaco();
        }
        setTimeout(() => {
          if (htmlMonacoEditor) htmlMonacoEditor.layout();
          if (cssMonacoEditor) cssMonacoEditor.layout();
          if (jsMonacoEditor) jsMonacoEditor.layout();
          editor.refresh();
        }, 50);
      } else {
        exitComponentMode();
        editor.refresh();
      }
    }

    // Event listeners
    btnCode.addEventListener('click', toggleCodePanel);

    // Keyboard shortcut: Ctrl+E / Cmd+E to toggle code editor
    document.addEventListener('keydown', function(e) {
      if ((e.ctrlKey || e.metaKey) && e.key === 'e') {
        e.preventDefault();
        toggleCodePanel();
      }
    });

    document.getElementById('code-close').addEventListener('click', () => {
      exitComponentMode();
      codePanel.classList.remove('open');
      btnCode.classList.remove('active');
      editor.refresh();
    });

    document.getElementById('code-full-page').addEventListener('click', () => {
      exitComponentMode();
    });

    document.querySelectorAll('.code-panel-tab').forEach(tab => {
      tab.addEventListener('click', function() {
        currentCodeTab = this.dataset.type;
        document.querySelectorAll('.code-panel-tab').forEach(t => t.classList.remove('active'));
        this.classList.add('active');

        const htmlContainer = document.getElementById('monaco-html-container');
        const cssContainer = document.getElementById('monaco-css-container');
        const jsContainer = document.getElementById('monaco-js-container');

        htmlContainer.style.display = 'none';
        cssContainer.style.display = 'none';
        jsContainer.style.display = 'none';

        if (currentCodeTab === 'html') {
          htmlContainer.style.display = 'block';
          if (htmlMonacoEditor) {
            htmlMonacoEditor.layout();
            htmlMonacoEditor.focus();
          }
        } else if (currentCodeTab === 'css') {
          cssContainer.style.display = 'block';
          if (cssMonacoEditor) {
            cssMonacoEditor.layout();
            cssMonacoEditor.focus();
          }
        } else if (currentCodeTab === 'js') {
          jsContainer.style.display = 'block';
          if (jsMonacoEditor) {
            jsMonacoEditor.layout();
            jsMonacoEditor.focus();
          }
        }
      });
    });

    document.getElementById('code-apply').addEventListener('click', async () => {
      if (codeDebounceTimer) {
        clearTimeout(codeDebounceTimer);
      }
      await formatAllCode();
      updatePreviewFromCode();
      showToast('Formatted and applied', 'success');
    });

    document.getElementById('code-format').addEventListener('click', async () => {
      await formatAllCode();
    });

    // Resize functionality
    const resizeHandle = document.getElementById('code-panel-resize');
    let isResizing = false;
    let startY = 0;
    let startHeight = 0;

    resizeHandle.addEventListener('mousedown', (e) => {
      isResizing = true;
      startY = e.clientY;
      startHeight = codePanel.offsetHeight;
      document.body.style.cursor = 'ns-resize';
      document.body.style.userSelect = 'none';
    });

    document.addEventListener('mousemove', (e) => {
      if (!isResizing) return;
      const deltaY = startY - e.clientY;
      const newHeight = Math.min(Math.max(startHeight + deltaY, 150), window.innerHeight * 0.7);
      codePanel.style.height = newHeight + 'px';
      if (htmlMonacoEditor) htmlMonacoEditor.layout();
      if (cssMonacoEditor) cssMonacoEditor.layout();
      if (jsMonacoEditor) jsMonacoEditor.layout();
      editor.refresh();
    });

    document.addEventListener('mouseup', () => {
      if (isResizing) {
        isResizing = false;
        document.body.style.cursor = '';
        document.body.style.userSelect = '';
      }
    });

    // Expose getters for save function
    window.ActiveCanvasEditor.getJs = function() {
      return jsMonacoEditor ? jsMonacoEditor.getValue() : (config.contentJs || '');
    };
  }

  // ==================== Save Functionality ====================

  function setupSave(editor, config, csrfToken) {
    document.getElementById('btn-save').addEventListener('click', () => saveContent(false));

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
      saveBtn.disabled = true;

      if (!isAutoSave) {
        showLoading(true);
      }

      const html = editor.getHtml();
      const css = editor.getCss();
      const js = window.ActiveCanvasEditor.getJs ? window.ActiveCanvasEditor.getJs() : '';
      const components = JSON.stringify(editor.getComponents());

      fetch(config.saveUrl, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfToken,
          'Accept': 'application/json'
        },
        body: JSON.stringify({
          page: {
            content: html,
            content_css: css,
            content_js: js,
            content_components: components
          }
        })
      })
      .then(response => response.json())
      .then(result => {
        if (result.success) {
          showToast(isAutoSave ? 'Auto-saved' : 'Page saved successfully', 'success');
        } else {
          showToast(result.errors ? result.errors.join(', ') : 'Save failed', 'error');
        }
      })
      .catch(error => {
        showToast('Save failed', 'error');
        console.error('Save error:', error);
      })
      .finally(() => {
        saveBtn.disabled = false;
        showLoading(false);
      });
    }
  }

  // ==================== Load Assets ====================

  function loadAssets(editor, mediaUrl) {
    fetch(mediaUrl, {
      headers: {
        'Accept': 'application/json'
      }
    })
    .then(response => response.json())
    .then(result => {
      if (result.data) {
        editor.AssetManager.add(result.data);
      }
    })
    .catch(error => {
      console.error('Failed to load assets:', error);
    });
  }

  // ==================== Custom Blocks ====================

  function addCustomBlocks(editor) {
    const bm = editor.BlockManager;

    // --- Layout Blocks ---
    bm.add('section', {
      label: 'Section',
      category: 'Layout',
      content: '<section class="py-16 px-4"><div class="max-w-6xl mx-auto"></div></section>',
      attributes: { class: 'gjs-fonts gjs-f-b1' }
    });

    bm.add('container', {
      label: 'Container',
      category: 'Layout',
      content: '<div class="max-w-6xl mx-auto px-4"></div>',
      attributes: { class: 'gjs-fonts gjs-f-b1' }
    });

    bm.add('div', {
      label: 'Div Block',
      category: 'Layout',
      content: '<div></div>',
      attributes: { class: 'gjs-fonts gjs-f-b1' }
    });

    // --- Hero Sections ---
    bm.add('hero-simple', {
      label: 'Hero Simple',
      category: 'Sections',
      content: `
        <section class="py-20 px-4 bg-gray-900 text-white text-center">
          <div class="max-w-4xl mx-auto">
            <h1 class="text-5xl font-bold mb-6">Welcome to Your Site</h1>
            <p class="text-xl text-gray-300 mb-8">A beautiful subtitle that describes what you do and why visitors should care.</p>
            <a href="#" class="inline-block bg-blue-600 text-white px-8 py-3 rounded-lg font-semibold hover:bg-blue-700">Get Started</a>
          </div>
        </section>
      `
    });

    bm.add('hero-split', {
      label: 'Hero Split',
      category: 'Sections',
      content: `
        <section class="py-16 px-4">
          <div class="max-w-6xl mx-auto grid md:grid-cols-2 gap-12 items-center">
            <div>
              <h1 class="text-4xl font-bold mb-4">Build Something Amazing</h1>
              <p class="text-lg text-gray-600 mb-6">Create beautiful, responsive websites without writing code. Drag, drop, and customize.</p>
              <a href="#" class="inline-block bg-blue-600 text-white px-6 py-3 rounded-lg font-semibold">Learn More</a>
            </div>
            <div class="bg-gray-200 rounded-lg aspect-video flex items-center justify-center">
              <span class="text-gray-500">Image Placeholder</span>
            </div>
          </div>
        </section>
      `
    });

    // --- Feature Sections ---
    bm.add('features-grid', {
      label: 'Features Grid',
      category: 'Sections',
      content: `
        <section class="py-16 px-4 bg-gray-50">
          <div class="max-w-6xl mx-auto">
            <h2 class="text-3xl font-bold text-center mb-12">Features</h2>
            <div class="grid md:grid-cols-3 gap-8">
              <div class="text-center p-6">
                <div class="w-12 h-12 bg-blue-600 rounded-lg mx-auto mb-4"></div>
                <h3 class="text-xl font-semibold mb-2">Feature One</h3>
                <p class="text-gray-600">Description of this amazing feature and why it matters to your users.</p>
              </div>
              <div class="text-center p-6">
                <div class="w-12 h-12 bg-blue-600 rounded-lg mx-auto mb-4"></div>
                <h3 class="text-xl font-semibold mb-2">Feature Two</h3>
                <p class="text-gray-600">Description of this amazing feature and why it matters to your users.</p>
              </div>
              <div class="text-center p-6">
                <div class="w-12 h-12 bg-blue-600 rounded-lg mx-auto mb-4"></div>
                <h3 class="text-xl font-semibold mb-2">Feature Three</h3>
                <p class="text-gray-600">Description of this amazing feature and why it matters to your users.</p>
              </div>
            </div>
          </div>
        </section>
      `
    });

    // --- Cards ---
    bm.add('card', {
      label: 'Card',
      category: 'Components',
      content: `
        <div class="bg-white rounded-lg shadow-md overflow-hidden max-w-sm">
          <div class="bg-gray-200 h-48 flex items-center justify-center">
            <span class="text-gray-500">Image</span>
          </div>
          <div class="p-6">
            <h3 class="text-xl font-semibold mb-2">Card Title</h3>
            <p class="text-gray-600 mb-4">Some description text for this card component.</p>
            <a href="#" class="text-blue-600 font-semibold">Learn more &rarr;</a>
          </div>
        </div>
      `
    });

    bm.add('cards-row', {
      label: 'Cards Row',
      category: 'Sections',
      content: `
        <section class="py-16 px-4">
          <div class="max-w-6xl mx-auto grid md:grid-cols-3 gap-8">
            <div class="bg-white rounded-lg shadow-md overflow-hidden">
              <div class="bg-gray-200 h-48 flex items-center justify-center">
                <span class="text-gray-500">Image</span>
              </div>
              <div class="p-6">
                <h3 class="text-xl font-semibold mb-2">Card One</h3>
                <p class="text-gray-600">Description text for this card.</p>
              </div>
            </div>
            <div class="bg-white rounded-lg shadow-md overflow-hidden">
              <div class="bg-gray-200 h-48 flex items-center justify-center">
                <span class="text-gray-500">Image</span>
              </div>
              <div class="p-6">
                <h3 class="text-xl font-semibold mb-2">Card Two</h3>
                <p class="text-gray-600">Description text for this card.</p>
              </div>
            </div>
            <div class="bg-white rounded-lg shadow-md overflow-hidden">
              <div class="bg-gray-200 h-48 flex items-center justify-center">
                <span class="text-gray-500">Image</span>
              </div>
              <div class="p-6">
                <h3 class="text-xl font-semibold mb-2">Card Three</h3>
                <p class="text-gray-600">Description text for this card.</p>
              </div>
            </div>
          </div>
        </section>
      `
    });

    // --- CTA Sections ---
    bm.add('cta-simple', {
      label: 'CTA Section',
      category: 'Sections',
      content: `
        <section class="py-16 px-4 bg-blue-600 text-white text-center">
          <div class="max-w-3xl mx-auto">
            <h2 class="text-3xl font-bold mb-4">Ready to Get Started?</h2>
            <p class="text-blue-100 mb-8">Join thousands of satisfied customers using our product.</p>
            <a href="#" class="inline-block bg-white text-blue-600 px-8 py-3 rounded-lg font-semibold hover:bg-gray-100">Start Free Trial</a>
          </div>
        </section>
      `
    });

    // --- Testimonials ---
    bm.add('testimonial', {
      label: 'Testimonial',
      category: 'Components',
      content: `
        <div class="bg-white p-8 rounded-lg shadow-md max-w-md">
          <p class="text-gray-600 mb-6 italic">"This product has completely transformed how we work. Highly recommended!"</p>
          <div class="flex items-center">
            <div class="w-12 h-12 bg-gray-300 rounded-full mr-4"></div>
            <div>
              <div class="font-semibold">John Doe</div>
              <div class="text-gray-500 text-sm">CEO, Company</div>
            </div>
          </div>
        </div>
      `
    });

    // --- Footer ---
    bm.add('footer-simple', {
      label: 'Footer',
      category: 'Sections',
      content: `
        <footer class="py-8 px-4 bg-gray-900 text-white">
          <div class="max-w-6xl mx-auto flex flex-col md:flex-row justify-between items-center">
            <div class="text-xl font-bold mb-4 md:mb-0">YourBrand</div>
            <nav class="flex gap-6 mb-4 md:mb-0">
              <a href="#" class="text-gray-400 hover:text-white">Home</a>
              <a href="#" class="text-gray-400 hover:text-white">About</a>
              <a href="#" class="text-gray-400 hover:text-white">Services</a>
              <a href="#" class="text-gray-400 hover:text-white">Contact</a>
            </nav>
            <div class="text-gray-400 text-sm">&copy; 2024 YourBrand. All rights reserved.</div>
          </div>
        </footer>
      `
    });

    // --- Navigation ---
    bm.add('navbar', {
      label: 'Navbar',
      category: 'Navigation',
      content: `
        <nav class="py-4 px-4 bg-white shadow-sm">
          <div class="max-w-6xl mx-auto flex justify-between items-center">
            <a href="#" class="text-xl font-bold">YourBrand</a>
            <div class="flex gap-6">
              <a href="#" class="text-gray-600 hover:text-gray-900">Home</a>
              <a href="#" class="text-gray-600 hover:text-gray-900">About</a>
              <a href="#" class="text-gray-600 hover:text-gray-900">Services</a>
              <a href="#" class="text-gray-600 hover:text-gray-900">Contact</a>
            </div>
            <a href="#" class="bg-blue-600 text-white px-4 py-2 rounded-lg font-semibold">Sign Up</a>
          </div>
        </nav>
      `
    });

    // --- Pricing ---
    bm.add('pricing-card', {
      label: 'Pricing Card',
      category: 'Components',
      content: `
        <div class="bg-white rounded-lg shadow-md p-8 text-center max-w-sm">
          <h3 class="text-xl font-semibold mb-2">Pro Plan</h3>
          <div class="text-4xl font-bold mb-4">$29<span class="text-lg text-gray-500">/mo</span></div>
          <ul class="text-gray-600 mb-6 space-y-2">
            <li>Unlimited Projects</li>
            <li>Priority Support</li>
            <li>Advanced Analytics</li>
            <li>Custom Domain</li>
          </ul>
          <a href="#" class="block bg-blue-600 text-white py-3 rounded-lg font-semibold">Get Started</a>
        </div>
      `
    });

    // --- Contact Form ---
    bm.add('contact-form', {
      label: 'Contact Form',
      category: 'Forms',
      content: `
        <form class="max-w-lg mx-auto p-8 bg-white rounded-lg shadow-md">
          <h3 class="text-2xl font-bold mb-6">Contact Us</h3>
          <div class="mb-4">
            <label class="block text-gray-700 text-sm font-semibold mb-2">Name</label>
            <input type="text" class="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500" placeholder="Your name">
          </div>
          <div class="mb-4">
            <label class="block text-gray-700 text-sm font-semibold mb-2">Email</label>
            <input type="email" class="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500" placeholder="your@email.com">
          </div>
          <div class="mb-4">
            <label class="block text-gray-700 text-sm font-semibold mb-2">Message</label>
            <textarea class="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 h-32" placeholder="Your message"></textarea>
          </div>
          <button type="submit" class="w-full bg-blue-600 text-white py-3 rounded-lg font-semibold hover:bg-blue-700">Send Message</button>
        </form>
      `
    });

    // --- Newsletter ---
    bm.add('newsletter', {
      label: 'Newsletter',
      category: 'Forms',
      content: `
        <section class="py-12 px-4 bg-gray-100">
          <div class="max-w-xl mx-auto text-center">
            <h3 class="text-2xl font-bold mb-4">Subscribe to Our Newsletter</h3>
            <p class="text-gray-600 mb-6">Get the latest updates delivered to your inbox.</p>
            <form class="flex gap-2">
              <input type="email" class="flex-1 px-4 py-3 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500" placeholder="your@email.com">
              <button type="submit" class="bg-blue-600 text-white px-6 py-3 rounded-lg font-semibold hover:bg-blue-700">Subscribe</button>
            </form>
          </div>
        </section>
      `
    });

    // --- FAQ ---
    bm.add('faq', {
      label: 'FAQ Section',
      category: 'Sections',
      content: `
        <section class="py-16 px-4">
          <div class="max-w-3xl mx-auto">
            <h2 class="text-3xl font-bold text-center mb-12">Frequently Asked Questions</h2>
            <div class="space-y-4">
              <details class="bg-white rounded-lg shadow-md">
                <summary class="px-6 py-4 font-semibold cursor-pointer">What is your return policy?</summary>
                <p class="px-6 pb-4 text-gray-600">We offer a 30-day money-back guarantee on all purchases. Simply contact our support team for a full refund.</p>
              </details>
              <details class="bg-white rounded-lg shadow-md">
                <summary class="px-6 py-4 font-semibold cursor-pointer">How do I get started?</summary>
                <p class="px-6 pb-4 text-gray-600">Sign up for a free account and follow our quick start guide to begin using our platform in minutes.</p>
              </details>
              <details class="bg-white rounded-lg shadow-md">
                <summary class="px-6 py-4 font-semibold cursor-pointer">Do you offer customer support?</summary>
                <p class="px-6 pb-4 text-gray-600">Yes! We have 24/7 customer support available via chat, email, and phone for all paid plans.</p>
              </details>
            </div>
          </div>
        </section>
      `
    });
  }

  // ==================== Utility Functions ====================

  function showToast(message, type) {
    const toast = document.getElementById('editor-toast');
    toast.textContent = message;
    toast.className = 'editor-toast show ' + type;

    setTimeout(() => {
      toast.classList.remove('show');
    }, 3000);
  }

  function showLoading(show) {
    const loading = document.getElementById('editor-loading');
    if (show) {
      loading.classList.remove('hidden');
    } else {
      loading.classList.add('hidden');
    }
  }

  // Expose utility functions
  window.ActiveCanvasEditor = window.ActiveCanvasEditor || {};
  window.ActiveCanvasEditor.showToast = showToast;
  window.ActiveCanvasEditor.showLoading = showLoading;

})();
