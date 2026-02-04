/**
 * ActiveCanvas Editor - Custom Asset Manager Modal
 */

(function() {
  'use strict';

  window.ActiveCanvasEditor = window.ActiveCanvasEditor || {};

  /**
   * Setup the custom asset manager modal
   * @param {Object} editor - GrapeJS editor instance
   * @param {Object} config - Editor configuration
   * @param {string} csrfToken - CSRF token for requests
   */
  function setupCustomAssetManager(editor, config, csrfToken) {
    const { showToast } = window.ActiveCanvasEditor;
    let currentPage = 1;
    let totalPages = 1;
    let currentTarget = null;

    // Override the default asset manager open behavior
    editor.on('run:open-assets', () => {
      const am = editor.AssetManager;
      currentTarget = am.getConfig().target;
      openCustomAssetModal();
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
      setupModalHandlers(modal);
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

  /**
   * Load assets into the editor and sidebar panel
   * @param {Object} editor - GrapeJS editor instance
   * @param {string} mediaUrl - URL to fetch media from
   */
  function loadAssets(editor, mediaUrl) {
    const { showToast } = window.ActiveCanvasEditor;

    fetch(mediaUrl, {
      headers: { 'Accept': 'application/json' }
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

  /**
   * Render the assets panel in the sidebar
   */
  function renderAssetsPanel(assets, editor) {
    const { showToast } = window.ActiveCanvasEditor;
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

  /**
   * Insert an image into the canvas
   */
  function insertImageToCanvas(editor, src) {
    const { showToast } = window.ActiveCanvasEditor;
    const selected = editor.getSelected();
    const wrapper = editor.getWrapper();

    const imageComponent = {
      type: 'image',
      attributes: { src: src, alt: 'Image' },
      style: { 'max-width': '100%' }
    };

    if (selected) {
      const parent = selected.parent();
      if (parent) {
        const index = parent.components().indexOf(selected);
        parent.components().add(imageComponent, { at: index + 1 });
      } else {
        wrapper.append(imageComponent);
      }
    } else {
      wrapper.append(imageComponent);
    }

    showToast('Image inserted', 'success');
  }

  /**
   * Setup the assets panel controls (upload, refresh)
   */
  function setupAssetsPanel(editor, config, csrfToken) {
    const { showToast } = window.ActiveCanvasEditor;
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

  // Expose functions
  window.ActiveCanvasEditor.setupCustomAssetManager = setupCustomAssetManager;
  window.ActiveCanvasEditor.loadAssets = loadAssets;
  window.ActiveCanvasEditor.setupAssetsPanel = setupAssetsPanel;

})();
