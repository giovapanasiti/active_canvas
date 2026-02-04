/**
 * AI Panel Module for ActiveCanvas Editor
 * Handles AI-powered text generation, image generation, and screenshot-to-code
 */
(function() {
  'use strict';

  // State
  let aiStatus = null;
  let availableModels = { text: [], image: [], vision: [] };
  let currentMode = 'page';
  let currentTab = 'text';
  let isGenerating = false;
  let abortController = null;

  // DOM Elements (cached after init)
  let elements = {};

  /**
   * Initialize the AI panel
   */
  function init() {
    if (!window.ActiveCanvasEditor?.config?.aiEndpoints) {
      console.log('AI Panel: No AI endpoints configured');
      return;
    }

    cacheElements();
    setupEventListeners();
    checkAiStatus();
    setupTextareaAutoResize();
  }

  /**
   * Cache DOM elements for performance
   */
  function cacheElements() {
    elements = {
      panel: document.getElementById('panel-ai'),
      // Tabs
      tabs: document.querySelectorAll('.ai-tab'),
      tabPanels: document.querySelectorAll('.ai-tab-panel'),
      // Text generation
      textPrompt: document.getElementById('ai-text-prompt'),
      textModelSelect: document.getElementById('ai-text-model'),
      textGenerateBtn: document.getElementById('btn-ai-text-generate'),
      textOutput: document.getElementById('ai-text-output'),
      textOutputWrapper: document.getElementById('ai-text-output-wrapper'),
      textInsertBtn: document.getElementById('btn-ai-text-insert'),
      textConversation: document.getElementById('ai-text-conversation'),
      regenerateBtn: document.getElementById('btn-ai-regenerate'),
      copyBtn: document.getElementById('btn-ai-copy'),
      // Image generation
      imagePrompt: document.getElementById('ai-image-prompt'),
      imageModelSelect: document.getElementById('ai-image-model'),
      imageGenerateBtn: document.getElementById('btn-ai-image-generate'),
      imageOutput: document.getElementById('ai-image-output'),
      imageOutputWrapper: document.getElementById('ai-image-output-wrapper'),
      imageInsertBtn: document.getElementById('btn-ai-image-insert'),
      imageEmpty: document.getElementById('ai-image-empty'),
      // Screenshot
      screenshotInput: document.getElementById('ai-screenshot-input'),
      screenshotPreview: document.getElementById('ai-screenshot-preview'),
      screenshotPrompt: document.getElementById('ai-screenshot-prompt'),
      screenshotModelSelect: document.getElementById('ai-screenshot-model'),
      screenshotConvertBtn: document.getElementById('btn-ai-screenshot-convert'),
      screenshotOutput: document.getElementById('ai-screenshot-output'),
      screenshotOutputWrapper: document.getElementById('ai-screenshot-output-wrapper'),
      screenshotInsertBtn: document.getElementById('btn-ai-screenshot-insert'),
      uploadZone: document.getElementById('ai-screenshot-drop'),
      uploadPlaceholder: document.getElementById('ai-upload-placeholder'),
      // Mode selector
      modeButtons: document.querySelectorAll('.ai-mode-toggle .ai-mode-btn'),
      modeSlider: document.querySelector('.ai-mode-slider'),
      elementInfo: document.getElementById('ai-element-info'),
      selectedElement: document.getElementById('ai-selected-element'),
      // Status
      statusBadge: document.getElementById('ai-status-badge'),
      notConfigured: document.getElementById('ai-not-configured'),
      panelTabs: document.getElementById('ai-panel-tabs')
    };
  }

  /**
   * Setup auto-resize for textareas
   */
  function setupTextareaAutoResize() {
    const textareas = [elements.textPrompt, elements.imagePrompt, elements.screenshotPrompt];

    textareas.forEach(textarea => {
      if (!textarea) return;

      textarea.addEventListener('input', function() {
        this.style.height = 'auto';
        this.style.height = Math.min(this.scrollHeight, 120) + 'px';
      });
    });
  }

  /**
   * Check AI configuration status
   */
  async function checkAiStatus() {
    const endpoints = window.ActiveCanvasEditor.config.aiEndpoints;
    if (!endpoints?.status) return;

    try {
      const response = await fetch(endpoints.status);
      aiStatus = await response.json();

      updateStatusUI();
      if (aiStatus.configured) {
        loadAvailableModels();
      }
    } catch (error) {
      console.error('AI Panel: Failed to check status', error);
      showNotConfiguredState('Unable to connect to AI service');
    }
  }

  /**
   * Load available models based on configured providers
   */
  async function loadAvailableModels() {
    const endpoints = window.ActiveCanvasEditor.config.aiEndpoints;
    if (!endpoints?.models) return;

    try {
      const response = await fetch(endpoints.models);
      const data = await response.json();

      availableModels = {
        text: data.text || [],
        image: data.image || [],
        vision: data.vision || []
      };

      populateModelSelects(data.default_text, data.default_image, data.default_vision);
    } catch (error) {
      console.error('AI Panel: Failed to load models', error);
    }
  }

  /**
   * Populate model select dropdowns
   */
  function populateModelSelects(defaultText, defaultImage, defaultVision) {
    if (elements.textModelSelect && availableModels.text.length) {
      elements.textModelSelect.innerHTML = availableModels.text
        .map(m => `<option value="${m.id}" ${m.id === defaultText ? 'selected' : ''}>${m.name}</option>`)
        .join('');
    }

    if (elements.imageModelSelect && availableModels.image.length) {
      elements.imageModelSelect.innerHTML = availableModels.image
        .map(m => `<option value="${m.id}" ${m.id === defaultImage ? 'selected' : ''}>${m.name}</option>`)
        .join('');
    }

    if (elements.screenshotModelSelect && availableModels.vision.length) {
      elements.screenshotModelSelect.innerHTML = availableModels.vision
        .map(m => `<option value="${m.id}" ${m.id === defaultVision ? 'selected' : ''}>${m.name}</option>`)
        .join('');
    }
  }

  /**
   * Update UI based on status
   */
  function updateStatusUI() {
    if (!aiStatus) return;

    // Show/hide not configured state
    if (elements.notConfigured) {
      elements.notConfigured.style.display = aiStatus.configured ? 'none' : 'flex';
    }

    if (elements.panelTabs) {
      elements.panelTabs.style.display = aiStatus.configured ? 'flex' : 'none';
    }

    // Hide all tab panels if not configured
    elements.tabPanels.forEach(panel => {
      panel.style.display = aiStatus.configured && panel.dataset.tab === currentTab ? 'flex' : 'none';
      panel.classList.toggle('active', aiStatus.configured && panel.dataset.tab === currentTab);
    });

    // Update status badge
    // if (elements.statusBadge) {
    //   if (aiStatus.configured) {
    //     const providers = aiStatus.providers || [];
    //     elements.statusBadge.textContent = providers.join(' + ');
    //     elements.statusBadge.className = 'ai-status-indicator configured';
    //   } else {
    //     elements.statusBadge.textContent = 'Not configured';
    //     elements.statusBadge.className = 'ai-status-indicator';
    //   }
    // }

    updateTabStates();
  }

  /**
   * Update tab enabled states based on feature toggles
   */
  function updateTabStates() {
    if (!aiStatus) return;

    elements.tabs.forEach(tab => {
      const feature = tab.dataset.tab;
      let enabled = false;

      switch (feature) {
        case 'text':
          enabled = aiStatus.text_enabled;
          break;
        case 'image':
          enabled = aiStatus.image_enabled;
          break;
        case 'screenshot':
          enabled = aiStatus.screenshot_enabled;
          break;
      }

      tab.classList.toggle('disabled', !enabled);
      tab.disabled = !enabled;
      if (!enabled) {
        tab.title = 'This feature is disabled in settings';
      }
    });
  }

  /**
   * Show not configured state
   */
  function showNotConfiguredState(message) {
    if (elements.notConfigured) {
      elements.notConfigured.style.display = 'flex';
      const msgEl = elements.notConfigured.querySelector('p');
      if (msgEl && message) msgEl.textContent = message;
    }
    if (elements.panelTabs) {
      elements.panelTabs.style.display = 'none';
    }
  }

  /**
   * Setup event listeners
   */
  function setupEventListeners() {
    // Tab switching
    elements.tabs.forEach(tab => {
      tab.addEventListener('click', () => {
        if (!tab.disabled) {
          switchTab(tab.dataset.tab);
        }
      });
    });

    // Mode switching
    elements.modeButtons.forEach(btn => {
      btn.addEventListener('click', () => switchMode(btn.dataset.mode));
    });

    // Text generation
    if (elements.textPrompt) {
      elements.textPrompt.addEventListener('input', updateTextButtonState);
      elements.textPrompt.addEventListener('keydown', handleTextPromptKeydown);
    }
    if (elements.textGenerateBtn) {
      elements.textGenerateBtn.addEventListener('click', generateText);
    }
    if (elements.textInsertBtn) {
      elements.textInsertBtn.addEventListener('click', insertTextContent);
    }
    if (elements.regenerateBtn) {
      elements.regenerateBtn.addEventListener('click', generateText);
    }
    if (elements.copyBtn) {
      elements.copyBtn.addEventListener('click', copyToClipboard);
    }

    // Image generation
    if (elements.imagePrompt) {
      elements.imagePrompt.addEventListener('input', updateImageButtonState);
      elements.imagePrompt.addEventListener('keydown', handleImagePromptKeydown);
    }
    if (elements.imageGenerateBtn) {
      elements.imageGenerateBtn.addEventListener('click', generateImage);
    }
    if (elements.imageInsertBtn) {
      elements.imageInsertBtn.addEventListener('click', insertImageContent);
    }

    // Screenshot
    if (elements.screenshotInput) {
      elements.screenshotInput.addEventListener('change', handleScreenshotUpload);
    }
    if (elements.uploadZone) {
      elements.uploadZone.addEventListener('dragover', handleDragOver);
      elements.uploadZone.addEventListener('dragleave', handleDragLeave);
      elements.uploadZone.addEventListener('drop', handleDrop);
    }
    if (elements.screenshotConvertBtn) {
      elements.screenshotConvertBtn.addEventListener('click', convertScreenshot);
    }
    if (elements.screenshotInsertBtn) {
      elements.screenshotInsertBtn.addEventListener('click', insertScreenshotContent);
    }

    // Listen for editor selection changes
    listenForSelectionChanges();
  }

  /**
   * Handle keydown in text prompt
   */
  function handleTextPromptKeydown(e) {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      if (!elements.textGenerateBtn.disabled && !isGenerating) {
        generateText();
      }
    }
  }

  /**
   * Handle keydown in image prompt
   */
  function handleImagePromptKeydown(e) {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      if (!elements.imageGenerateBtn.disabled && !isGenerating) {
        generateImage();
      }
    }
  }

  /**
   * Handle drag over
   */
  function handleDragOver(e) {
    e.preventDefault();
    elements.uploadZone.classList.add('dragover');
  }

  /**
   * Handle drag leave
   */
  function handleDragLeave(e) {
    e.preventDefault();
    elements.uploadZone.classList.remove('dragover');
  }

  /**
   * Handle drop
   */
  function handleDrop(e) {
    e.preventDefault();
    elements.uploadZone.classList.remove('dragover');

    const file = e.dataTransfer.files[0];
    if (file && file.type.startsWith('image/')) {
      processScreenshotFile(file);
    }
  }

  /**
   * Switch between AI tabs
   */
  function switchTab(tabName) {
    if (!aiStatus?.configured) return;

    const featureEnabled = {
      text: aiStatus.text_enabled,
      image: aiStatus.image_enabled,
      screenshot: aiStatus.screenshot_enabled
    };

    if (!featureEnabled[tabName]) {
      showToast('This feature is disabled in settings', 'warning');
      return;
    }

    currentTab = tabName;

    elements.tabs.forEach(tab => {
      tab.classList.toggle('active', tab.dataset.tab === tabName);
    });

    elements.tabPanels.forEach(panel => {
      const isActive = panel.dataset.tab === tabName;
      panel.classList.toggle('active', isActive);
      panel.style.display = isActive ? 'flex' : 'none';
    });
  }

  /**
   * Switch between page/element mode
   */
  function switchMode(mode) {
    currentMode = mode;

    elements.modeButtons.forEach(btn => {
      btn.classList.toggle('active', btn.dataset.mode === mode);
    });

    // Update slider position
    if (elements.modeSlider) {
      elements.modeSlider.style.transform = mode === 'element' ? 'translateX(100%)' : 'translateX(0)';
    }

    if (elements.elementInfo) {
      elements.elementInfo.style.display = mode === 'element' ? 'flex' : 'none';
    }

    if (mode === 'element') {
      updateSelectedElementDisplay();
    }
  }

  /**
   * Update selected element display
   */
  function updateSelectedElementDisplay() {
    if (!window.ActiveCanvasEditor?.instance) return;

    const selected = window.ActiveCanvasEditor.instance.getSelected();

    if (selected && elements.selectedElement) {
      const tagName = selected.get('tagName') || 'div';
      const classes = selected.getClasses().slice(0, 2).join('.');
      const id = selected.getId();

      let name = tagName.toLowerCase();
      if (id) name = `#${id}`;
      else if (classes) name = `${tagName.toLowerCase()}.${classes}`;

      elements.selectedElement.textContent = name;
    } else if (elements.selectedElement) {
      elements.selectedElement.textContent = 'No element selected';
    }
  }

  /**
   * Listen for GrapeJS selection changes
   */
  function listenForSelectionChanges() {
    const checkEditor = setInterval(() => {
      if (window.ActiveCanvasEditor?.instance) {
        clearInterval(checkEditor);
        window.ActiveCanvasEditor.instance.on('component:selected', updateSelectedElementDisplay);
        window.ActiveCanvasEditor.instance.on('component:deselected', updateSelectedElementDisplay);
      }
    }, 100);
  }

  /**
   * Update text generate button state
   */
  function updateTextButtonState() {
    if (elements.textGenerateBtn) {
      elements.textGenerateBtn.disabled = !elements.textPrompt?.value.trim() || isGenerating;
    }
  }

  /**
   * Update image generate button state
   */
  function updateImageButtonState() {
    if (elements.imageGenerateBtn) {
      elements.imageGenerateBtn.disabled = !elements.imagePrompt?.value.trim() || isGenerating;
    }
  }

  /**
   * Generate text content using SSE streaming
   */
  async function generateText() {
    if (isGenerating || !elements.textPrompt?.value.trim()) return;

    const endpoints = window.ActiveCanvasEditor.config.aiEndpoints;
    if (!endpoints?.chat) return;

    const prompt = elements.textPrompt.value.trim();
    const model = elements.textModelSelect?.value;

    // Get current element HTML if in element mode
    let currentHtml = '';
    if (currentMode === 'element' && window.ActiveCanvasEditor?.instance) {
      const selected = window.ActiveCanvasEditor.instance.getSelected();
      if (selected) {
        currentHtml = selected.toHTML();
      }
    }

    setGenerating(true);

    // Hide conversation empty state, show output wrapper
    if (elements.textConversation) {
      elements.textConversation.style.display = 'none';
    }
    if (elements.textOutputWrapper) {
      elements.textOutputWrapper.style.display = 'block';
    }

    clearOutput(elements.textOutput);
    showLoadingInOutput(elements.textOutput);

    try {
      abortController = new AbortController();

      const response = await fetch(endpoints.chat, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': getCSRFToken()
        },
        body: JSON.stringify({
          prompt,
          model,
          mode: currentMode,
          current_html: currentHtml
        }),
        signal: abortController.signal
      });

      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.error || 'Generation failed');
      }

      await processSSEStream(response.body, elements.textOutput);

    } catch (error) {
      if (error.name !== 'AbortError') {
        console.error('AI Text Generation Error:', error);
        showOutputError(elements.textOutput, error.message);
      }
    } finally {
      setGenerating(false);
      abortController = null;
    }
  }

  /**
   * Process SSE stream and update output
   */
  async function processSSEStream(body, outputElement) {
    const reader = body.getReader();
    const decoder = new TextDecoder();
    let buffer = '';
    let fullContent = '';

    // Clear loading state
    outputElement.innerHTML = '';

    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split('\n');
        buffer = lines.pop() || '';

        for (const line of lines) {
          if (line.startsWith('data: ')) {
            try {
              const data = JSON.parse(line.slice(6));

              if (data.content) {
                fullContent += data.content;
                outputElement.textContent = fullContent;
                outputElement.scrollTop = outputElement.scrollHeight;
              }

              if (data.error) {
                showOutputError(outputElement, data.error);
                return;
              }
            } catch (e) {
              // Ignore JSON parse errors for incomplete data
            }
          }
        }
      }
    } catch (error) {
      throw error;
    }
  }

  /**
   * Generate image
   */
  async function generateImage() {
    if (isGenerating || !elements.imagePrompt?.value.trim()) return;

    const endpoints = window.ActiveCanvasEditor.config.aiEndpoints;
    if (!endpoints?.image) return;

    const prompt = elements.imagePrompt.value.trim();
    const model = elements.imageModelSelect?.value;

    setGenerating(true);

    // Hide empty state, show output wrapper
    if (elements.imageEmpty) {
      elements.imageEmpty.style.display = 'none';
    }
    if (elements.imageOutputWrapper) {
      elements.imageOutputWrapper.style.display = 'block';
    }

    if (elements.imageOutput) {
      elements.imageOutput.innerHTML = '<div class="ai-loading-indicator"><div class="ai-loading-dots"><span></span><span></span><span></span></div><span>Generating image...</span></div>';
    }

    try {
      const response = await fetch(endpoints.image, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': getCSRFToken()
        },
        body: JSON.stringify({ prompt, model })
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Image generation failed');
      }

      // Display generated image
      elements.imageOutput.innerHTML = `<img src="${data.url}" alt="AI Generated: ${escapeHtml(prompt)}" />`;
      elements.imageOutput.dataset.imageUrl = data.url;

    } catch (error) {
      console.error('AI Image Generation Error:', error);
      elements.imageOutput.innerHTML = `<div class="ai-error">${escapeHtml(error.message)}</div>`;
    } finally {
      setGenerating(false);
    }
  }

  /**
   * Handle screenshot file upload
   */
  function handleScreenshotUpload(event) {
    const file = event.target.files?.[0];
    if (file) {
      processScreenshotFile(file);
    }
  }

  /**
   * Process screenshot file
   */
  function processScreenshotFile(file) {
    if (!file.type.startsWith('image/')) {
      showToast('Please upload an image file', 'error');
      return;
    }

    const reader = new FileReader();
    reader.onload = (e) => {
      const dataUrl = e.target.result;

      if (elements.screenshotPreview) {
        elements.screenshotPreview.innerHTML = `<img src="${dataUrl}" alt="Screenshot preview" />`;
        elements.screenshotPreview.dataset.imageData = dataUrl;
      }

      if (elements.uploadZone) {
        elements.uploadZone.classList.add('has-preview');
      }

      if (elements.screenshotConvertBtn) {
        elements.screenshotConvertBtn.disabled = false;
      }
    };
    reader.readAsDataURL(file);
  }

  /**
   * Convert screenshot to code
   */
  async function convertScreenshot() {
    if (isGenerating) return;

    const imageData = elements.screenshotPreview?.dataset.imageData;
    if (!imageData) {
      showToast('Please upload a screenshot first', 'error');
      return;
    }

    const endpoints = window.ActiveCanvasEditor.config.aiEndpoints;
    if (!endpoints?.screenshot) return;

    const additionalPrompt = elements.screenshotPrompt?.value.trim();
    const model = elements.screenshotModelSelect?.value;

    setGenerating(true);

    if (elements.screenshotOutputWrapper) {
      elements.screenshotOutputWrapper.style.display = 'block';
    }

    if (elements.screenshotOutput) {
      elements.screenshotOutput.innerHTML = '<div class="ai-loading-indicator"><div class="ai-loading-dots"><span></span><span></span><span></span></div><span>Converting screenshot...</span></div>';
    }

    try {
      const response = await fetch(endpoints.screenshot, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': getCSRFToken()
        },
        body: JSON.stringify({
          screenshot: imageData,
          model: model,
          additional_prompt: additionalPrompt
        })
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Conversion failed');
      }

      elements.screenshotOutput.textContent = data.html;

    } catch (error) {
      console.error('AI Screenshot Conversion Error:', error);
      elements.screenshotOutput.innerHTML = `<div class="ai-error">${escapeHtml(error.message)}</div>`;
    } finally {
      setGenerating(false);
    }
  }

  /**
   * Insert text content into editor
   */
  function insertTextContent() {
    const html = elements.textOutput?.textContent;
    if (html) {
      insertHtmlToEditor(html);
    }
  }

  /**
   * Insert image content into editor
   */
  function insertImageContent() {
    const imageUrl = elements.imageOutput?.dataset.imageUrl;
    if (imageUrl) {
      const html = `<img src="${imageUrl}" alt="AI Generated Image" style="max-width: 100%; height: auto;" />`;
      insertHtmlToEditor(html);
    }
  }

  /**
   * Insert screenshot content into editor
   */
  function insertScreenshotContent() {
    const html = elements.screenshotOutput?.textContent;
    if (html) {
      insertHtmlToEditor(html);
    }
  }

  /**
   * Copy output to clipboard
   */
  async function copyToClipboard() {
    const content = elements.textOutput?.textContent;
    if (!content) return;

    try {
      await navigator.clipboard.writeText(content);
      showToast('Copied to clipboard', 'success');
    } catch (err) {
      showToast('Failed to copy', 'error');
    }
  }

  /**
   * Insert HTML into GrapeJS editor
   */
  function insertHtmlToEditor(html) {
    const editor = window.ActiveCanvasEditor?.instance;
    if (!editor) {
      showToast('Editor not ready', 'error');
      return;
    }

    try {
      if (currentMode === 'element') {
        const selected = editor.getSelected();
        if (selected) {
          selected.components(html);
          showToast('Content updated', 'success');
        } else {
          const wrapper = editor.getWrapper();
          wrapper.append(html);
          showToast('Content added to page', 'success');
        }
      } else {
        const wrapper = editor.getWrapper();
        wrapper.append(html);
        showToast('Content added to page', 'success');
      }
    } catch (error) {
      console.error('Insert error:', error);
      showToast('Failed to insert content', 'error');
    }
  }

  /**
   * Utility functions
   */
  function setGenerating(state) {
    isGenerating = state;
    updateTextButtonState();
    updateImageButtonState();

    // Update send buttons
    [elements.textGenerateBtn, elements.imageGenerateBtn, elements.screenshotConvertBtn].forEach(btn => {
      if (btn) {
        btn.disabled = state || !getPromptValue(btn);
        btn.classList.toggle('loading', state);
      }
    });
  }

  function getPromptValue(btn) {
    if (btn === elements.textGenerateBtn) return elements.textPrompt?.value.trim();
    if (btn === elements.imageGenerateBtn) return elements.imagePrompt?.value.trim();
    if (btn === elements.screenshotConvertBtn) return elements.screenshotPreview?.dataset.imageData;
    return true;
  }

  function clearOutput(element) {
    if (element) {
      element.innerHTML = '';
    }
  }

  function showLoadingInOutput(element) {
    if (element) {
      element.innerHTML = '<div class="ai-loading-indicator"><div class="ai-loading-dots"><span></span><span></span><span></span></div><span>Generating...</span></div>';
    }
  }

  function showOutputError(element, message) {
    if (element) {
      element.innerHTML = `<div class="ai-error">${escapeHtml(message)}</div>`;
    }
  }

  function getCSRFToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || '';
  }

  function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }

  function showToast(message, type) {
    if (window.ActiveCanvasEditor?.showToast) {
      window.ActiveCanvasEditor.showToast(message, type);
    }
  }

  // Export for global access
  window.ActiveCanvasAiPanel = {
    init,
    checkAiStatus,
    loadAvailableModels
  };

  // Initialize when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
