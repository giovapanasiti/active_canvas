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

    // Setup code panel
    setupCodePanel(editor, config);

    // Setup save functionality
    setupSave(editor, config, csrfToken);

    // Setup add section button
    setupAddSection(editor);

    // Setup assets panel
    setupAssetsPanel(editor, config, csrfToken);

    // Setup custom asset manager modal
    setupCustomAssetManager(editor, config, csrfToken);

    // Expose editor instance for debugging
    window.ActiveCanvasEditor.instance = editor;
  }

  // ==================== Custom Asset Manager Modal ====================

  function setupCustomAssetManager(editor, config, csrfToken) {
    let currentPage = 1;
    let totalPages = 1;
    let currentTarget = null;

    // Override the default asset manager open behavior
    editor.on('run:open-assets', () => {
      // Get the target (what's requesting the image)
      const am = editor.AssetManager;
      currentTarget = am.getConfig().target;

      // Show our custom modal instead
      openCustomAssetModal();

      // Prevent default modal
      return false;
    });

    // Also listen for asset manager open command
    const originalOpen = editor.AssetManager.open;
    editor.AssetManager.open = function(options) {
      currentTarget = options?.target;
      openCustomAssetModal();
    };

    function openCustomAssetModal() {
      // Remove existing modal if any
      const existing = document.querySelector('.ac-asset-modal');
      if (existing) existing.remove();

      // Create modal
      const modal = document.createElement('div');
      modal.className = 'ac-asset-modal';
      modal.innerHTML = `
        <div class="ac-asset-modal-overlay"></div>
        <div class="ac-asset-modal-dialog">
          <div class="ac-asset-modal-header">
            <h3>Select Image</h3>
            <button class="ac-asset-modal-close" title="Close">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <line x1="18" y1="6" x2="6" y2="18"></line>
                <line x1="6" y1="6" x2="18" y2="18"></line>
              </svg>
            </button>
          </div>
          <div class="ac-asset-modal-tabs">
            <button class="ac-asset-tab active" data-tab="library">Media Library</button>
            <button class="ac-asset-tab" data-tab="upload">Upload New</button>
          </div>
          <div class="ac-asset-modal-body">
            <div class="ac-asset-tab-content active" data-tab="library">
              <div class="ac-asset-grid" id="ac-asset-grid">
                <div class="ac-asset-loading">Loading media...</div>
              </div>
              <div class="ac-asset-pagination" id="ac-asset-pagination"></div>
            </div>
            <div class="ac-asset-tab-content" data-tab="upload">
              <div class="ac-asset-upload-zone" id="ac-upload-zone">
                <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                  <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
                  <polyline points="17 8 12 3 7 8"/>
                  <line x1="12" y1="3" x2="12" y2="15"/>
                </svg>
                <p>Drag & drop images here or click to browse</p>
                <p class="ac-upload-hint">Supports: JPEG, PNG, GIF, WebP, SVG</p>
                <input type="file" id="ac-upload-input" accept="image/*" multiple style="display:none">
              </div>
              <div class="ac-upload-progress" id="ac-upload-progress" style="display:none">
                <div class="ac-upload-progress-bar"></div>
                <span class="ac-upload-progress-text">Uploading...</span>
              </div>
            </div>
          </div>
        </div>
      `;

      document.body.appendChild(modal);

      // Setup event handlers
      setupModalHandlers(modal);

      // Load first page of media
      loadMediaPage(1);
    }

    function setupModalHandlers(modal) {
      // Close button
      modal.querySelector('.ac-asset-modal-close').addEventListener('click', () => {
        modal.remove();
      });

      // Overlay click to close
      modal.querySelector('.ac-asset-modal-overlay').addEventListener('click', () => {
        modal.remove();
      });

      // Tab switching
      modal.querySelectorAll('.ac-asset-tab').forEach(tab => {
        tab.addEventListener('click', () => {
          modal.querySelectorAll('.ac-asset-tab').forEach(t => t.classList.remove('active'));
          modal.querySelectorAll('.ac-asset-tab-content').forEach(c => c.classList.remove('active'));
          tab.classList.add('active');
          modal.querySelector(`.ac-asset-tab-content[data-tab="${tab.dataset.tab}"]`).classList.add('active');
        });
      });

      // Upload zone
      const uploadZone = modal.querySelector('#ac-upload-zone');
      const uploadInput = modal.querySelector('#ac-upload-input');

      uploadZone.addEventListener('click', () => uploadInput.click());

      uploadZone.addEventListener('dragover', (e) => {
        e.preventDefault();
        uploadZone.classList.add('dragover');
      });

      uploadZone.addEventListener('dragleave', () => {
        uploadZone.classList.remove('dragover');
      });

      uploadZone.addEventListener('drop', (e) => {
        e.preventDefault();
        uploadZone.classList.remove('dragover');
        handleFileUpload(e.dataTransfer.files, modal);
      });

      uploadInput.addEventListener('change', (e) => {
        handleFileUpload(e.target.files, modal);
      });
    }

    async function loadMediaPage(page) {
      currentPage = page;
      const grid = document.getElementById('ac-asset-grid');
      const pagination = document.getElementById('ac-asset-pagination');

      if (!grid) return;

      grid.innerHTML = '<div class="ac-asset-loading">Loading media...</div>';

      try {
        const response = await fetch(`${config.mediaUrl}?page=${page}&per_page=20`, {
          headers: { 'Accept': 'application/json' }
        });
        const result = await response.json();

        if (result.data && result.data.length > 0) {
          totalPages = result.meta?.total_pages || 1;
          renderMediaGrid(result.data, grid);
          renderPagination(pagination, result.meta);
        } else {
          grid.innerHTML = '<div class="ac-asset-empty">No media found. Upload some images to get started.</div>';
          pagination.innerHTML = '';
        }
      } catch (error) {
        console.error('Failed to load media:', error);
        grid.innerHTML = '<div class="ac-asset-empty">Failed to load media.</div>';
      }
    }

    function renderMediaGrid(media, container) {
      container.innerHTML = media.map(item => `
        <div class="ac-asset-item" data-src="${item.src}" data-name="${item.name || ''}">
          <div class="ac-asset-thumb">
            <img src="${item.src}" alt="${item.name || 'Image'}" loading="lazy">
          </div>
          <div class="ac-asset-name">${item.name || 'Untitled'}</div>
        </div>
      `).join('');

      // Add click handlers
      container.querySelectorAll('.ac-asset-item').forEach(item => {
        item.addEventListener('click', () => {
          selectAsset(item.dataset.src, item.dataset.name);
        });
      });
    }

    function renderPagination(container, meta) {
      if (!meta || meta.total_pages <= 1) {
        container.innerHTML = '';
        return;
      }

      let html = '<div class="ac-pagination-info">';
      html += `Page ${meta.current_page} of ${meta.total_pages} (${meta.total_count} items)`;
      html += '</div><div class="ac-pagination-buttons">';

      if (meta.current_page > 1) {
        html += `<button class="ac-pagination-btn" data-page="${meta.current_page - 1}">Previous</button>`;
      }

      // Page numbers
      const startPage = Math.max(1, meta.current_page - 2);
      const endPage = Math.min(meta.total_pages, meta.current_page + 2);

      for (let i = startPage; i <= endPage; i++) {
        html += `<button class="ac-pagination-btn ${i === meta.current_page ? 'active' : ''}" data-page="${i}">${i}</button>`;
      }

      if (meta.current_page < meta.total_pages) {
        html += `<button class="ac-pagination-btn" data-page="${meta.current_page + 1}">Next</button>`;
      }

      html += '</div>';
      container.innerHTML = html;

      // Add click handlers
      container.querySelectorAll('.ac-pagination-btn').forEach(btn => {
        btn.addEventListener('click', () => {
          loadMediaPage(parseInt(btn.dataset.page));
        });
      });
    }

    function selectAsset(src, name) {
      // Add to GrapeJS asset manager
      editor.AssetManager.add({ src, name, type: 'image' });

      // If there's a target component, set the image
      if (currentTarget) {
        currentTarget.set('src', src);
      }

      // Close modal
      const modal = document.querySelector('.ac-asset-modal');
      if (modal) modal.remove();

      showToast('Image selected', 'success');
    }

    async function handleFileUpload(files, modal) {
      const progressContainer = modal.querySelector('#ac-upload-progress');
      const progressBar = modal.querySelector('.ac-upload-progress-bar');
      const progressText = modal.querySelector('.ac-upload-progress-text');

      progressContainer.style.display = 'block';

      for (let i = 0; i < files.length; i++) {
        const file = files[i];
        progressText.textContent = `Uploading ${file.name}... (${i + 1}/${files.length})`;
        progressBar.style.width = `${((i + 1) / files.length) * 100}%`;

        const formData = new FormData();
        formData.append('media[file]', file);
        formData.append('media[filename]', file.name);

        try {
          const response = await fetch(config.uploadUrl, {
            method: 'POST',
            headers: { 'X-CSRF-Token': csrfToken },
            body: formData
          });

          const result = await response.json();

          if (response.ok && result.src) {
            editor.AssetManager.add(result);
            showToast(`Uploaded ${file.name}`, 'success');
          } else if (result.errors) {
            showToast(`Failed: ${result.errors.join(', ')}`, 'error');
          }
        } catch (error) {
          showToast(`Error uploading ${file.name}`, 'error');
        }
      }

      progressContainer.style.display = 'none';
      progressBar.style.width = '0';

      // Reload media library and switch to it
      loadMediaPage(1);
      modal.querySelector('.ac-asset-tab[data-tab="library"]').click();
    }
  }

  // ==================== Add Section ====================

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

  // ==================== Component Code Editing ====================

  function setupComponentCodeEditing(editor) {
    // Define default toolbar for all components
    const defaultToolbar = [
      {
        id: 'edit-code',
        attributes: { class: 'fa fa-code', title: 'Edit Code' },
        command: 'edit-component-code'
      },
      {
        id: 'component-menu',
        label: '⋮',
        attributes: { class: 'toolbar-menu-btn', title: 'More Actions' },
        command: 'ac-show-menu'
      }
    ];

    // Add toolbar buttons on component selection
    editor.on('component:selected', (component) => {
      if (!component) return;

      let toolbar = component.get('toolbar') || [];

      // Ensure toolbar is an array and make a copy
      if (!Array.isArray(toolbar)) {
        toolbar = [];
      } else {
        toolbar = [...toolbar];
      }

      // Check if our buttons already exist
      const hasCodeBtn = toolbar.some(item => item.id === 'edit-code' || item.command === 'edit-component-code');
      const hasMenuBtn = toolbar.some(item => item.id === 'component-menu' || item.command === 'ac-show-menu');

      if (!hasCodeBtn) {
        toolbar.unshift(defaultToolbar[0]);
      }

      if (!hasMenuBtn) {
        toolbar.push(defaultToolbar[1]);
      }

      component.set('toolbar', toolbar);
    });

    // Add command for editing component code
    editor.Commands.add('edit-component-code', {
      run(editor) {
        const selected = editor.getSelected();
        if (!selected) return;

        window.ActiveCanvasEditor.openComponentCodeEditor(selected);
      }
    });

    // Helper to cleanup menu
    const cleanupComponentMenu = () => {
      const existingMenu = document.querySelector('.component-context-menu');
      if (existingMenu) {
        existingMenu.remove();
      }
    };

    // Close menu when selection changes
    editor.on('component:selected', cleanupComponentMenu);
    editor.on('component:deselected', cleanupComponentMenu);

    // Function to show the component menu
    const showComponentMenu = () => {
      const selected = editor.getSelected();
      if (!selected) return;

      // Always cleanup first
      cleanupComponentMenu();

      // Get position - use the toolbar
      let btnRect = null;
      const toolbarEl = document.querySelector('.gjs-toolbar');

      if (toolbarEl) {
        const allItems = toolbarEl.querySelectorAll('.gjs-toolbar-item');
        const menuBtn = allItems[allItems.length - 1];
        btnRect = menuBtn ? menuBtn.getBoundingClientRect() : toolbarEl.getBoundingClientRect();
      }

      // Final fallback: center of screen
      if (!btnRect) {
        btnRect = {
          top: 100,
          bottom: 120,
          left: window.innerWidth / 2 - 80,
          right: window.innerWidth / 2 + 80
        };
      }

      // Create dropdown menu
      const menu = document.createElement('div');
      menu.className = 'component-context-menu';
      menu.innerHTML = `
        <div class="context-menu-item" data-action="duplicate">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect>
            <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path>
          </svg>
          <span>Duplicate</span>
        </div>
        <div class="context-menu-item" data-action="add-div-above">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect>
            <line x1="12" y1="8" x2="12" y2="16"></line>
            <line x1="8" y1="12" x2="16" y2="12"></line>
          </svg>
          <span>Add Div Above</span>
        </div>
        <div class="context-menu-item" data-action="add-div-below">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect>
            <line x1="12" y1="8" x2="12" y2="16"></line>
            <line x1="8" y1="12" x2="16" y2="12"></line>
          </svg>
          <span>Add Div Below</span>
        </div>
        <div class="context-menu-divider"></div>
        <div class="context-menu-item" data-action="move-up">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <polyline points="18 15 12 9 6 15"></polyline>
          </svg>
          <span>Move Up</span>
        </div>
        <div class="context-menu-item" data-action="move-down">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <polyline points="6 9 12 15 18 9"></polyline>
          </svg>
          <span>Move Down</span>
        </div>
        <div class="context-menu-divider"></div>
        <div class="context-menu-item context-menu-item-danger" data-action="delete">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <polyline points="3 6 5 6 21 6"></polyline>
            <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path>
          </svg>
          <span>Delete</span>
        </div>
      `;

      // Position the menu
      menu.style.position = 'fixed';
      menu.style.zIndex = '10000';

      document.body.appendChild(menu);

      // Get menu dimensions after adding to DOM
      const menuRect = menu.getBoundingClientRect();

      // Position below the button, aligned to the right edge
      let top = btnRect.bottom + 5;
      let left = btnRect.right - menuRect.width;

      // Keep menu on screen
      if (left < 10) left = 10;
      if (top + menuRect.height > window.innerHeight - 10) {
        top = btnRect.top - menuRect.height - 5;
      }

      menu.style.top = top + 'px';
      menu.style.left = left + 'px';

      // Handle menu item clicks
      menu.querySelectorAll('.context-menu-item').forEach(item => {
        item.addEventListener('click', (e) => {
          e.preventDefault();
          e.stopPropagation();
          const action = item.dataset.action;
          cleanupComponentMenu();
          handleComponentAction(editor, selected, action);
        });
      });

      // Close menu on click outside (with delay)
      setTimeout(() => {
        const closeHandler = (e) => {
          if (menu.contains(e.target)) return;
          if (e.target.closest('.toolbar-menu-btn') || e.target.textContent === '⋮') return;
          cleanupComponentMenu();
          document.removeEventListener('mousedown', closeHandler);
        };
        document.addEventListener('mousedown', closeHandler);
      }, 50);
    };

    // Add command that just calls our function
    editor.Commands.add('ac-show-menu', {
      run() {
        showComponentMenu();
      }
    });
  }

  // Handle component context menu actions
  function handleComponentAction(editor, component, action) {
    if (!component) return;

    const parent = component.parent();

    switch (action) {
      case 'duplicate':
        const cloned = component.clone();
        if (parent) {
          const index = parent.components().indexOf(component);
          parent.components().add(cloned, { at: index + 1 });
          editor.select(cloned);
          showToast('Component duplicated', 'success');
        }
        break;

      case 'add-div-above':
        if (parent) {
          const index = parent.components().indexOf(component);
          const newDiv = parent.components().add({
            tagName: 'div',
            style: { padding: '1rem', 'min-height': '50px' },
            content: ''
          }, { at: index });
          editor.select(newDiv);
          showToast('Div added above', 'success');
        }
        break;

      case 'add-div-below':
        if (parent) {
          const index = parent.components().indexOf(component);
          const newDiv = parent.components().add({
            tagName: 'div',
            style: { padding: '1rem', 'min-height': '50px' },
            content: ''
          }, { at: index + 1 });
          editor.select(newDiv);
          showToast('Div added below', 'success');
        }
        break;

      case 'move-up':
        if (parent) {
          const index = parent.components().indexOf(component);
          if (index > 0) {
            parent.components().remove(component);
            parent.components().add(component, { at: index - 1 });
            editor.select(component);
            showToast('Moved up', 'success');
          }
        }
        break;

      case 'move-down':
        if (parent) {
          const components = parent.components();
          const index = components.indexOf(component);
          if (index < components.length - 1) {
            components.remove(component);
            components.add(component, { at: index + 1 });
            editor.select(component);
            showToast('Moved down', 'success');
          }
        }
        break;

      case 'delete':
        component.remove();
        showToast('Component deleted', 'success');
        break;
    }
  }

  // ==================== Canvas Injection ====================

  function setupCanvasInjection(editor, config) {
    editor.on('load', () => {
      setTimeout(() => {
        const frame = editor.Canvas.getFrameEl();
        if (!frame || !frame.contentDocument) return;

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

  // ==================== Panel Controls ====================

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
    btnToggleLeft.addEventListener('click', function() {
      const isOpening = panelLeft.classList.contains('collapsed');

      if (isOpening) {
        // Close AI panel when opening left panel
        panelAi.classList.add('collapsed');
        btnToggleAi.classList.remove('active');
      }

      panelLeft.classList.toggle('collapsed');
      this.classList.toggle('active', !panelLeft.classList.contains('collapsed'));
      refreshEditor();
    });

    // Toggle AI panel
    btnToggleAi.addEventListener('click', function() {
      const isOpening = panelAi.classList.contains('collapsed');

      if (isOpening) {
        // Close left panel when opening AI panel
        panelLeft.classList.add('collapsed');
        btnToggleLeft.classList.remove('active');
      }

      panelAi.classList.toggle('collapsed');
      this.classList.toggle('active', !panelAi.classList.contains('collapsed'));
      refreshEditor();
    });

    // Close AI panel button
    if (btnCloseAi) {
      btnCloseAi.addEventListener('click', function() {
        panelAi.classList.add('collapsed');
        btnToggleAi.classList.remove('active');
        refreshEditor();
      });
    }

    // Toggle right panel
    btnToggleRight.addEventListener('click', function() {
      panelRight.classList.toggle('collapsed');
      this.classList.toggle('active', !panelRight.classList.contains('collapsed'));
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
          document.getElementById('assets-container').style.display = panel === 'assets' ? 'block' : 'none';
          document.getElementById('layers-container').style.display = panel === 'layers' ? 'block' : 'none';
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

  // ==================== Undo/Redo ====================

  function setupUndoRedo(editor) {
    document.getElementById('btn-undo').addEventListener('click', () => {
      editor.UndoManager.undo();
    });

    document.getElementById('btn-redo').addEventListener('click', () => {
      editor.UndoManager.redo();
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
        // Define custom themes for Monaco
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
        renderAssetsPanel(result.data, editor);
      }
    })
    .catch(error => {
      console.error('Failed to load assets:', error);
      const grid = document.getElementById('assets-grid');
      if (grid) {
        grid.innerHTML = '<div class="assets-empty">Failed to load assets</div>';
      }
    });
  }

  function renderAssetsPanel(assets, editor) {
    const grid = document.getElementById('assets-grid');
    if (!grid) return;

    if (!assets || assets.length === 0) {
      grid.innerHTML = `
        <div class="assets-empty">
          <svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
            <rect x="3" y="3" width="18" height="18" rx="2" ry="2"/>
            <circle cx="8.5" cy="8.5" r="1.5"/>
            <polyline points="21 15 16 10 5 21"/>
          </svg>
          <p>No assets yet</p>
          <span>Upload images to use them here</span>
        </div>
      `;
      return;
    }

    grid.innerHTML = assets.map(asset => `
      <div class="asset-item" draggable="true" data-src="${asset.src}" data-name="${asset.name || 'Image'}" title="${asset.name || 'Image'}">
        <img src="${asset.src}" alt="${asset.name || 'Image'}" loading="lazy">
        <div class="asset-item-overlay">
          <button class="asset-insert-btn" data-src="${asset.src}" title="Insert image">
            <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <line x1="12" y1="5" x2="12" y2="19"/>
              <line x1="5" y1="12" x2="19" y2="12"/>
            </svg>
          </button>
        </div>
      </div>
    `).join('');

    // Add drag and insert functionality
    grid.querySelectorAll('.asset-item').forEach(item => {
      // Drag to canvas
      item.addEventListener('dragstart', (e) => {
        const src = item.dataset.src;
        e.dataTransfer.setData('text/html', `<img src="${src}" alt="Image" style="max-width: 100%;">`);
        e.dataTransfer.effectAllowed = 'copy';
      });

      // Click to insert
      const insertBtn = item.querySelector('.asset-insert-btn');
      if (insertBtn) {
        insertBtn.addEventListener('click', (e) => {
          e.stopPropagation();
          const src = insertBtn.dataset.src;
          insertImageToCanvas(editor, src);
        });
      }

      // Double-click to insert
      item.addEventListener('dblclick', () => {
        const src = item.dataset.src;
        insertImageToCanvas(editor, src);
      });
    });
  }

  function insertImageToCanvas(editor, src) {
    const selected = editor.getSelected();
    const wrapper = editor.getWrapper();

    const imageComponent = {
      type: 'image',
      attributes: { src: src, alt: 'Image' },
      style: { 'max-width': '100%' }
    };

    if (selected) {
      // Insert after selected component
      const parent = selected.parent();
      if (parent) {
        const index = parent.components().indexOf(selected);
        parent.components().add(imageComponent, { at: index + 1 });
      } else {
        wrapper.append(imageComponent);
      }
    } else {
      // Append to wrapper
      wrapper.append(imageComponent);
    }

    showToast('Image inserted', 'success');
  }

  function setupAssetsPanel(editor, config, csrfToken) {
    const uploadBtn = document.getElementById('btn-upload-asset');
    const refreshBtn = document.getElementById('btn-refresh-assets');
    const uploadInput = document.getElementById('asset-upload-input');

    if (!uploadBtn || !refreshBtn || !uploadInput) return;

    // Upload button click
    uploadBtn.addEventListener('click', () => {
      uploadInput.click();
    });

    // Refresh button click
    refreshBtn.addEventListener('click', () => {
      const grid = document.getElementById('assets-grid');
      if (grid) {
        grid.innerHTML = '<div class="assets-loading">Loading assets...</div>';
      }
      loadAssets(editor, config.mediaUrl);
    });

    // Handle file selection
    uploadInput.addEventListener('change', async (e) => {
      const files = e.target.files;
      if (!files || files.length === 0) return;

      uploadBtn.disabled = true;
      uploadBtn.innerHTML = `
        <svg class="spin" xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <line x1="12" y1="2" x2="12" y2="6"/>
          <line x1="12" y1="18" x2="12" y2="22"/>
          <line x1="4.93" y1="4.93" x2="7.76" y2="7.76"/>
          <line x1="16.24" y1="16.24" x2="19.07" y2="19.07"/>
          <line x1="2" y1="12" x2="6" y2="12"/>
          <line x1="18" y1="12" x2="22" y2="12"/>
          <line x1="4.93" y1="19.07" x2="7.76" y2="16.24"/>
          <line x1="16.24" y1="7.76" x2="19.07" y2="4.93"/>
        </svg>
        Uploading...
      `;

      for (const file of files) {
        const formData = new FormData();
        formData.append('media[file]', file);
        formData.append('media[filename]', file.name);

        try {
          const response = await fetch(config.uploadUrl, {
            method: 'POST',
            headers: {
              'X-CSRF-Token': csrfToken
            },
            body: formData
          });

          const result = await response.json();

          if (response.ok && result.src) {
            editor.AssetManager.add(result);
            showToast(`Uploaded ${file.name}`, 'success');
          } else if (result.errors) {
            showToast(`Failed: ${result.errors.join(', ')}`, 'error');
          }
        } catch (error) {
          showToast(`Error uploading ${file.name}`, 'error');
          console.error('Upload error:', error);
        }
      }

      // Reset and refresh
      uploadInput.value = '';
      uploadBtn.disabled = false;
      uploadBtn.innerHTML = `
        <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
          <polyline points="17 8 12 3 7 8"/>
          <line x1="12" y1="3" x2="12" y2="15"/>
        </svg>
        Upload
      `;

      // Refresh assets panel
      loadAssets(editor, config.mediaUrl);
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
