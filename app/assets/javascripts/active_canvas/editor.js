/**
 * ActiveCanvas Visual Editor
 *
 * Main entry point that orchestrates all editor modules.
 * Configuration is passed via window.ActiveCanvasEditor.config
 *
 * Module dependencies (loaded in order):
 * - editor/utils.js       - Utility functions
 * - editor/blocks.js      - Custom block definitions
 * - editor/asset_manager.js - Asset manager modal
 * - editor/code_panel.js  - Monaco code editor
 * - editor/component_toolbar.js - Component toolbar/menu
 * - editor/panels.js      - Panel controls, save, devices
 * - editor.js             - This file (main orchestrator)
 */

(function() {
  'use strict';

  // Initialize namespace
  window.ActiveCanvasEditor = window.ActiveCanvasEditor || {};

  // Wait for DOM and config to be ready
  document.addEventListener('DOMContentLoaded', function() {
    if (!window.ActiveCanvasEditor || !window.ActiveCanvasEditor.config) {
      console.error('ActiveCanvasEditor config not found');
      return;
    }

    const config = window.ActiveCanvasEditor.config;
    initEditor(config);
  });

  /**
   * Initialize the GrapeJS editor and all modules
   * @param {Object} config - Editor configuration from Rails
   */
  function initEditor(config) {
    const csrfToken = window.ActiveCanvasEditor.getCsrfToken();

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
    const canvasConfig = buildCanvasConfig(config);

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

      // Asset Manager (basic config, custom modal handles most functionality)
      assetManager: {
        uploadName: 'media[file]',
        uploadFile: createUploadHandler(config, csrfToken),
        assets: []
      },

      // Canvas
      canvas: canvasConfig,

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

    // Setup all modules
    setupModules(editor, config, csrfToken);

    // Expose editor instance for debugging
    window.ActiveCanvasEditor.instance = editor;
  }

  /**
   * Build canvas configuration based on CSS framework
   */
  function buildCanvasConfig(config) {
    const canvasStyles = [];
    const canvasScripts = [];

    if (config.cssFrameworkUrl) {
      if (config.cssFrameworkType === 'script') {
        canvasScripts.push(config.cssFrameworkUrl);
      } else if (config.cssFrameworkType === 'stylesheet') {
        canvasStyles.push(config.cssFrameworkUrl);
      }
    }

    return {
      styles: canvasStyles,
      scripts: canvasScripts
    };
  }

  /**
   * Create the upload handler for the asset manager
   */
  function createUploadHandler(config, csrfToken) {
    const { showToast } = window.ActiveCanvasEditor;

    return function(e) {
      const files = e.dataTransfer ? e.dataTransfer.files : e.target.files;
      const formData = new FormData();
      const editor = window.ActiveCanvasEditor.instance;

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
    };
  }

  /**
   * Setup all editor modules
   */
  function setupModules(editor, config, csrfToken) {
    const AC = window.ActiveCanvasEditor;

    // Add custom blocks (framework-specific based on config.cssFramework)
    AC.addCustomBlocks(editor, config);

    // Load existing assets
    AC.loadAssets(editor, config.mediaUrl);

    // Setup component toolbar and context menu
    AC.setupComponentToolbar(editor);

    // Inject global and page-specific CSS/JS into canvas
    AC.setupCanvasInjection(editor, config);

    // Setup panel controls
    AC.setupPanelControls(editor);

    // Setup device switching
    AC.setupDeviceSwitching(editor);

    // Setup undo/redo
    AC.setupUndoRedo(editor);

    // Setup code panel
    AC.setupCodePanel(editor, config);

    // Setup save functionality
    AC.setupSave(editor, config, csrfToken);

    // Setup add section button
    AC.setupAddSection(editor);

    // Setup RTE toolbar visibility
    AC.setupRteToolbar(editor);

    // Setup assets panel
    AC.setupAssetsPanel(editor, config, csrfToken);

    // Setup custom asset manager modal
    AC.setupCustomAssetManager(editor, config, csrfToken);
  }

})();
