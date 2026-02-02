/**
 * ActiveCanvas Editor - Component Toolbar and Context Menu
 */

(function() {
  'use strict';

  window.ActiveCanvasEditor = window.ActiveCanvasEditor || {};

  /**
   * Setup component code editing and toolbar
   * @param {Object} editor - GrapeJS editor instance
   */
  function setupComponentToolbar(editor) {
    const { showToast } = window.ActiveCanvasEditor;

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
        <div class="context-menu-item" data-action="open-styles">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M12 19l7-7 3 3-7 7-3-3z"></path>
            <path d="M18 13l-1.5-7.5L2 2l3.5 14.5L13 18l5-5z"></path>
            <path d="M2 2l7.586 7.586"></path>
            <circle cx="11" cy="11" r="2"></circle>
          </svg>
          <span>Edit Styles</span>
        </div>
        <div class="context-menu-divider"></div>
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

  /**
   * Handle component context menu actions
   */
  function handleComponentAction(editor, component, action) {
    const { showToast } = window.ActiveCanvasEditor;

    if (!component) return;

    const parent = component.parent();

    switch (action) {
      case 'open-styles':
        // Ensure the component is selected
        editor.select(component);

        // Open the right panel if collapsed
        const panelRight = document.getElementById('panel-right');
        const btnToggleRight = document.getElementById('btn-toggle-right');
        if (panelRight && panelRight.classList.contains('collapsed')) {
          panelRight.classList.remove('collapsed');
          if (btnToggleRight) btnToggleRight.classList.add('active');
        }

        // Switch to the Styles tab
        const stylesTab = document.querySelector('.editor-panel-right .panel-tab[data-panel="styles"]');
        if (stylesTab) {
          stylesTab.click();
        }

        // Scroll the style manager into view if needed
        const stylesContainer = document.getElementById('styles-container');
        if (stylesContainer) {
          stylesContainer.style.display = 'block';
          // Hide traits container
          const traitsContainer = document.getElementById('traits-container');
          if (traitsContainer) traitsContainer.style.display = 'none';
        }

        // Refresh the editor to update the style manager
        setTimeout(() => editor.refresh(), 100);

        showToast('Style panel opened', 'success');
        break;

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

  // Expose function
  window.ActiveCanvasEditor.setupComponentToolbar = setupComponentToolbar;

})();
