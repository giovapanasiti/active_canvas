/**
 * ActiveCanvas Editor - Code Panel (Monaco Editor)
 */

(function() {
  'use strict';

  window.ActiveCanvasEditor = window.ActiveCanvasEditor || {};

  /**
   * Setup the code panel with Monaco editors
   * @param {Object} editor - GrapeJS editor instance
   * @param {Object} config - Editor configuration
   */
  function setupCodePanel(editor, config) {
    const { showToast } = window.ActiveCanvasEditor;

    const codePanel = document.getElementById('code-panel');
    const btnCode = document.getElementById('btn-code');
    const statusEl = document.getElementById('code-status');
    const codePanelMode = document.getElementById('code-panel-mode');
    const componentNameEl = document.getElementById('component-name');

    if (!codePanel || !btnCode) return;

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
        // Define custom themes for Monaco
        defineMonacoThemes();

        // Get Monaco theme based on editor theme
        function getMonacoTheme() {
          const editorTheme = document.documentElement.getAttribute('data-theme') || 'dark';
          const themeMap = {
            'dark': 'ac-dark',
            'midnight': 'ac-midnight',
            'ocean': 'ac-ocean',
            'charcoal': 'ac-charcoal',
            'light': 'ac-light'
          };
          return themeMap[editorTheme] || 'ac-dark';
        }

        // Expose theme setter for external use
        window.ActiveCanvasEditor.setMonacoTheme = function(theme) {
          const themeMap = {
            'dark': 'ac-dark',
            'midnight': 'ac-midnight',
            'ocean': 'ac-ocean',
            'charcoal': 'ac-charcoal',
            'light': 'ac-light'
          };
          const monacoTheme = themeMap[theme] || 'ac-dark';
          monaco.editor.setTheme(monacoTheme);
        };

        // Common editor options
        const editorOptions = {
          theme: getMonacoTheme(),
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

    function defineMonacoThemes() {
      monaco.editor.defineTheme('ac-dark', {
        base: 'vs-dark',
        inherit: true,
        rules: [],
        colors: {
          'editor.background': '#1e293b',
          'editor.foreground': '#f8fafc',
          'editorLineNumber.foreground': '#64748b',
          'editorCursor.foreground': '#f8fafc',
          'editor.selectionBackground': '#334155',
          'editor.lineHighlightBackground': '#334155'
        }
      });

      monaco.editor.defineTheme('ac-midnight', {
        base: 'vs-dark',
        inherit: true,
        rules: [],
        colors: {
          'editor.background': '#1a1730',
          'editor.foreground': '#f5f3ff',
          'editorLineNumber.foreground': '#7c75a8',
          'editorCursor.foreground': '#8b5cf6',
          'editor.selectionBackground': '#2d2750',
          'editor.lineHighlightBackground': '#2d2750'
        }
      });

      monaco.editor.defineTheme('ac-ocean', {
        base: 'vs-dark',
        inherit: true,
        rules: [],
        colors: {
          'editor.background': '#0f2930',
          'editor.foreground': '#ecfeff',
          'editorLineNumber.foreground': '#5eaab8',
          'editorCursor.foreground': '#06b6d4',
          'editor.selectionBackground': '#1a3d47',
          'editor.lineHighlightBackground': '#1a3d47'
        }
      });

      monaco.editor.defineTheme('ac-charcoal', {
        base: 'vs-dark',
        inherit: true,
        rules: [],
        colors: {
          'editor.background': '#262626',
          'editor.foreground': '#fafafa',
          'editorLineNumber.foreground': '#737373',
          'editorCursor.foreground': '#f97316',
          'editor.selectionBackground': '#363636',
          'editor.lineHighlightBackground': '#363636'
        }
      });

      monaco.editor.defineTheme('ac-light', {
        base: 'vs',
        inherit: true,
        rules: [],
        colors: {
          'editor.background': '#ffffff',
          'editor.foreground': '#1e293b',
          'editorLineNumber.foreground': '#94a3b8',
          'editorCursor.foreground': '#6366f1',
          'editor.selectionBackground': '#e0e7ff',
          'editor.lineHighlightBackground': '#f8fafc'
        }
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
        if (statusEl) {
          statusEl.textContent = 'Synced';
          statusEl.className = 'code-status synced';
        }
      } catch (e) {
        if (statusEl) {
          statusEl.textContent = 'Error';
          statusEl.className = 'code-status modified';
        }
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

      if (codePanelMode) codePanelMode.style.display = 'flex';
      if (componentNameEl) componentNameEl.textContent = getComponentName(component);

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
      if (codePanelMode) codePanelMode.style.display = 'none';

      document.querySelectorAll('.code-panel-tab').forEach(t => {
        t.style.display = '';
      });

      if (wasInComponentMode && monacoInitialized) {
        syncGrapeJSToMonaco();
      }
    }

    function scheduleCodeUpdate() {
      if (statusEl) {
        statusEl.textContent = 'Modified...';
        statusEl.className = 'code-status modified';
      }

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
      if (statusEl) {
        statusEl.textContent = 'Modified...';
        statusEl.className = 'code-status modified';
      }

      if (codeDebounceTimer) {
        clearTimeout(codeDebounceTimer);
      }
      codeDebounceTimer = setTimeout(() => {
        injectJsIntoCanvas();
        if (statusEl) {
          statusEl.textContent = 'Synced';
          statusEl.className = 'code-status synced';
        }
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

    const closeBtn = document.getElementById('code-close');
    if (closeBtn) {
      closeBtn.addEventListener('click', () => {
        exitComponentMode();
        codePanel.classList.remove('open');
        btnCode.classList.remove('active');
        editor.refresh();
      });
    }

    const fullPageBtn = document.getElementById('code-full-page');
    if (fullPageBtn) {
      fullPageBtn.addEventListener('click', () => {
        exitComponentMode();
      });
    }

    document.querySelectorAll('.code-panel-tab').forEach(tab => {
      tab.addEventListener('click', function() {
        currentCodeTab = this.dataset.type;
        document.querySelectorAll('.code-panel-tab').forEach(t => t.classList.remove('active'));
        this.classList.add('active');

        const htmlContainer = document.getElementById('monaco-html-container');
        const cssContainer = document.getElementById('monaco-css-container');
        const jsContainer = document.getElementById('monaco-js-container');

        if (htmlContainer) htmlContainer.style.display = 'none';
        if (cssContainer) cssContainer.style.display = 'none';
        if (jsContainer) jsContainer.style.display = 'none';

        if (currentCodeTab === 'html' && htmlContainer) {
          htmlContainer.style.display = 'block';
          if (htmlMonacoEditor) {
            htmlMonacoEditor.layout();
            htmlMonacoEditor.focus();
          }
        } else if (currentCodeTab === 'css' && cssContainer) {
          cssContainer.style.display = 'block';
          if (cssMonacoEditor) {
            cssMonacoEditor.layout();
            cssMonacoEditor.focus();
          }
        } else if (currentCodeTab === 'js' && jsContainer) {
          jsContainer.style.display = 'block';
          if (jsMonacoEditor) {
            jsMonacoEditor.layout();
            jsMonacoEditor.focus();
          }
        }
      });
    });

    const applyBtn = document.getElementById('code-apply');
    if (applyBtn) {
      applyBtn.addEventListener('click', async () => {
        if (codeDebounceTimer) {
          clearTimeout(codeDebounceTimer);
        }
        await formatAllCode();
        updatePreviewFromCode();
        showToast('Formatted and applied', 'success');
      });
    }

    const formatBtn = document.getElementById('code-format');
    if (formatBtn) {
      formatBtn.addEventListener('click', async () => {
        await formatAllCode();
      });
    }

    // Resize functionality
    setupResizeHandle();

    function setupResizeHandle() {
      const resizeHandle = document.getElementById('code-panel-resize');
      if (!resizeHandle) return;

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
    }

    // Expose getters for save function
    window.ActiveCanvasEditor.getJs = function() {
      return jsMonacoEditor ? jsMonacoEditor.getValue() : (config.contentJs || '');
    };
  }

  // Expose function
  window.ActiveCanvasEditor.setupCodePanel = setupCodePanel;

})();
