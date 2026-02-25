/**
 * AI Panel Module for ActiveCanvas Editor
 * Handles AI-powered text generation, image generation, and screenshot-to-code
 */
(function() {
  'use strict';

  const STORAGE_PREFIX = 'active_canvas_ai_model_';

  // Direct mode endpoint map
  const DIRECT_ENDPOINTS = {
    openai:     { chat: 'https://api.openai.com/v1/chat/completions',
                  image: 'https://api.openai.com/v1/images/generations' },
    openrouter: { chat: 'https://openrouter.ai/api/v1/chat/completions' },
    anthropic:  { chat: 'https://api.anthropic.com/v1/messages' }
  };

  // State
  let aiStatus = null;
  let availableModels = { text: [], image: [], vision: [] };
  let selectedModels = { text: null, image: null, screenshot: null };
  let currentMode = 'page';
  let currentTab = 'text';
  let isGenerating = false;
  let abortController = null;

  // DOM Elements (cached after init)
  let elements = {};

  // Model pickers state
  let pickers = {};

  // ==================== Direct Mode Helpers ====================

  function isDirectMode() {
    return window.ActiveCanvasEditor?.config?.aiConnectionMode === 'direct';
  }

  function getModelProvider(modelId) {
    const allModels = [...(availableModels.text || []), ...(availableModels.image || []), ...(availableModels.vision || [])];
    const model = allModels.find(m => m.id === modelId);
    return model?.provider || null;
  }

  function getApiKey(provider) {
    return window.ActiveCanvasEditor?.config?.aiApiKeys?.[provider] || null;
  }

  function buildSystemPrompt(context) {
    const framework = window.ActiveCanvasEditor?.config?.cssFramework || 'custom';
    let frameworkGuidelines = '';

    if (framework === 'tailwind') {
      frameworkGuidelines = `CSS Framework: Tailwind CSS v4

You MUST use Tailwind CSS utility classes exclusively for all styling. Do NOT use inline styles or custom CSS.

Tailwind v4 rules:
- Use slash syntax for opacity: bg-blue-500/50, text-black/75 (NOT bg-opacity-50 or text-opacity-75)
- Use modern color syntax: bg-red-500/20 instead of bg-red-500 bg-opacity-20
- Use arbitrary values with square brackets when needed: w-[72rem], text-[#1a2b3c]
- Use the new shadow and ring syntax: shadow-sm, ring-1 ring-gray-200
- Prefer gap-* over space-x-*/space-y-* for flex and grid layouts
- Use size-* for equal width and height: size-8 instead of w-8 h-8
- Use grid with grid-cols-subgrid where appropriate
- All legacy utilities removed in v4 are forbidden (bg-opacity-*, text-opacity-*, divide-opacity-*, etc.)`;
    } else if (framework === 'bootstrap5') {
      frameworkGuidelines = `CSS Framework: Bootstrap 5

Use Bootstrap 5 classes exclusively for all styling. Do NOT use inline styles or custom CSS.

Bootstrap 5 rules:
- Use the grid system: container, row, col-*, col-md-*, col-lg-*
- Use Bootstrap utility classes: d-flex, justify-content-center, align-items-center, p-3, m-2, etc.
- Use Bootstrap components: card, btn, navbar, alert, badge, etc.
- Use responsive breakpoints: sm, md, lg, xl, xxl
- Use spacing utilities: p-*, m-*, gap-*
- Use text utilities: text-center, fw-bold, fs-*, text-muted
- Use background utilities: bg-primary, bg-light, bg-dark, etc.`;
    } else {
      frameworkGuidelines = `CSS Framework: None (vanilla CSS)

Use inline styles for all styling since no CSS framework is loaded.

Vanilla CSS rules:
- Apply all styles via the style attribute directly on HTML elements
- Use modern CSS: flexbox, grid, clamp(), min(), max()
- Ensure responsive behavior with relative units (%, rem, vw) and media queries via <style> blocks when necessary
- Use CSS custom properties (variables) in a <style> block for consistent theming`;
    }

    return `You are an expert web designer creating content for a visual page builder.
Generate clean, semantic HTML.

${frameworkGuidelines}

General guidelines:
- Use proper semantic HTML5 elements (section, article, header, nav, etc.)
- Include responsive design patterns
- Return ONLY the HTML code, no explanations or markdown code blocks
- Do not include <html>, <head>, or <body> tags - just the content
- Use placeholder images from https://placehold.co/ when images are needed

${context || ''}`;
  }

  function buildScreenshotPrompt(additionalPrompt) {
    const framework = window.ActiveCanvasEditor?.config?.cssFramework || 'custom';
    let frameworkGuidelines = '';

    if (framework === 'tailwind') {
      frameworkGuidelines = 'CSS Framework: Tailwind CSS v4\n\nYou MUST use Tailwind CSS utility classes exclusively for all styling. Do NOT use inline styles or custom CSS.';
    } else if (framework === 'bootstrap5') {
      frameworkGuidelines = 'CSS Framework: Bootstrap 5\n\nUse Bootstrap 5 classes exclusively for all styling. Do NOT use inline styles or custom CSS.';
    } else {
      frameworkGuidelines = 'CSS Framework: None (vanilla CSS)\n\nUse inline styles for all styling since no CSS framework is loaded.';
    }

    let base = `Convert this screenshot into clean HTML.

${frameworkGuidelines}

Requirements:
- Create semantic, accessible HTML5 structure
- Make it fully responsive
- Use placeholder images from https://placehold.co/ for any images
- Match the layout, colors, and typography as closely as possible
- Return ONLY the HTML code, no explanations or markdown code blocks
- Do not include <html>, <head>, or <body> tags - just the content`;

    if (additionalPrompt) {
      base += `\n\nAdditional instructions: ${additionalPrompt}`;
    }

    return base;
  }

  // ==================== Direct Mode SSE Parsers ====================

  async function processOpenAIStream(body, outputElement) {
    const reader = body.getReader();
    const decoder = new TextDecoder();
    let buffer = '';
    let fullContent = '';

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
            const payload = line.slice(6).trim();
            if (payload === '[DONE]') return;

            try {
              const data = JSON.parse(payload);
              const content = data.choices?.[0]?.delta?.content;
              if (content) {
                fullContent += content;
                outputElement.textContent = fullContent;
                outputElement.scrollTop = outputElement.scrollHeight;
              }
            } catch (e) {
              // Ignore incomplete JSON
            }
          }
        }
      }
    } catch (error) {
      throw error;
    }
  }

  async function processAnthropicStream(body, outputElement) {
    const reader = body.getReader();
    const decoder = new TextDecoder();
    let buffer = '';
    let fullContent = '';

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

              if (data.type === 'content_block_delta' && data.delta?.type === 'text_delta') {
                fullContent += data.delta.text;
                outputElement.textContent = fullContent;
                outputElement.scrollTop = outputElement.scrollHeight;
              }

              if (data.type === 'message_stop') return;

              if (data.type === 'error') {
                showOutputError(outputElement, data.error?.message || 'Anthropic stream error');
                return;
              }
            } catch (e) {
              // Ignore incomplete JSON
            }
          }
        }
      }
    } catch (error) {
      throw error;
    }
  }

  // ==================== Direct Mode API Calls ====================

  async function generateTextDirect(prompt, model, currentHtml) {
    const provider = getModelProvider(model);
    if (!provider) {
      throw new Error(`Unknown provider for model ${model}. Check your model configuration.`);
    }

    const apiKey = getApiKey(provider);
    if (!apiKey) {
      throw new Error(`No API key configured for ${provider}. Add it in Settings > AI.`);
    }

    const endpoint = DIRECT_ENDPOINTS[provider]?.chat;
    if (!endpoint) {
      throw new Error(`Direct mode not supported for provider: ${provider}`);
    }

    let context = '';
    if (currentMode === 'element' && currentHtml) {
      context = `The user is editing an existing element. Current HTML:\n${currentHtml}`;
    }
    const systemPrompt = buildSystemPrompt(context);

    abortController = new AbortController();

    let response;

    if (provider === 'anthropic') {
      response = await fetch(endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'anthropic-dangerous-direct-browser-access': 'true'
        },
        body: JSON.stringify({
          model,
          max_tokens: 4096,
          stream: true,
          system: systemPrompt,
          messages: [{ role: 'user', content: prompt }]
        }),
        signal: abortController.signal
      });
    } else {
      // OpenAI / OpenRouter
      const headers = {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`
      };

      response = await fetch(endpoint, {
        method: 'POST',
        headers,
        body: JSON.stringify({
          model,
          stream: true,
          messages: [
            { role: 'system', content: systemPrompt },
            { role: 'user', content: prompt }
          ]
        }),
        signal: abortController.signal
      });
    }

    if (!response.ok) {
      if (response.status === 401) {
        throw new Error(`API key may be incorrect for ${provider}.`);
      }
      let errMsg = `Request failed (${response.status})`;
      try {
        const errData = await response.json();
        errMsg = errData.error?.message || errData.error || errMsg;
      } catch (e) {}
      throw new Error(errMsg);
    }

    if (provider === 'anthropic') {
      await processAnthropicStream(response.body, elements.textOutput);
    } else {
      await processOpenAIStream(response.body, elements.textOutput);
    }
  }

  async function generateImageDirect(prompt, model) {
    const provider = getModelProvider(model);

    // Only OpenAI supports image generation in direct mode
    if (provider !== 'openai') {
      throw new Error(`Direct image generation only supported for OpenAI models. Switch to server mode for ${provider}.`);
    }

    const apiKey = getApiKey('openai');
    if (!apiKey) {
      throw new Error('No API key configured for openai. Add it in Settings > AI.');
    }

    abortController = new AbortController();

    const response = await fetch(DIRECT_ENDPOINTS.openai.image, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`
      },
      body: JSON.stringify({
        model,
        prompt,
        n: 1,
        size: '1024x1024'
      }),
      signal: abortController.signal
    });

    if (!response.ok) {
      if (response.status === 401) {
        throw new Error('API key may be incorrect for openai.');
      }
      let errMsg = `Image generation failed (${response.status})`;
      try {
        const errData = await response.json();
        errMsg = errData.error?.message || errMsg;
      } catch (e) {}
      throw new Error(errMsg);
    }

    const data = await response.json();
    return data.data?.[0]?.url || data.data?.[0]?.b64_json;
  }

  async function convertScreenshotDirect(imageDataUrl, model, additionalPrompt) {
    const provider = getModelProvider(model);
    if (!provider) {
      throw new Error(`Unknown provider for model ${model}.`);
    }

    const apiKey = getApiKey(provider);
    if (!apiKey) {
      throw new Error(`No API key configured for ${provider}. Add it in Settings > AI.`);
    }

    const endpoint = DIRECT_ENDPOINTS[provider]?.chat;
    if (!endpoint) {
      throw new Error(`Direct mode not supported for provider: ${provider}`);
    }

    const screenshotPrompt = buildScreenshotPrompt(additionalPrompt);
    abortController = new AbortController();

    let response;

    if (provider === 'anthropic') {
      // Extract base64 data and media type from data URL
      const match = imageDataUrl.match(/^data:(image\/\w+);base64,(.+)$/);
      const mediaType = match ? match[1] : 'image/png';
      const rawBase64 = match ? match[2] : imageDataUrl.replace(/^data:image\/\w+;base64,/, '');

      response = await fetch(endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'anthropic-dangerous-direct-browser-access': 'true'
        },
        body: JSON.stringify({
          model,
          max_tokens: 4096,
          stream: true,
          messages: [{
            role: 'user',
            content: [
              { type: 'image', source: { type: 'base64', media_type: mediaType, data: rawBase64 } },
              { type: 'text', text: screenshotPrompt }
            ]
          }]
        }),
        signal: abortController.signal
      });
    } else {
      // OpenAI / OpenRouter vision format
      response = await fetch(endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${apiKey}`
        },
        body: JSON.stringify({
          model,
          stream: true,
          messages: [{
            role: 'user',
            content: [
              { type: 'text', text: screenshotPrompt },
              { type: 'image_url', image_url: { url: imageDataUrl } }
            ]
          }]
        }),
        signal: abortController.signal
      });
    }

    if (!response.ok) {
      if (response.status === 401) {
        throw new Error(`API key may be incorrect for ${provider}.`);
      }
      let errMsg = `Screenshot conversion failed (${response.status})`;
      try {
        const errData = await response.json();
        errMsg = errData.error?.message || errData.error || errMsg;
      } catch (e) {}
      throw new Error(errMsg);
    }

    if (provider === 'anthropic') {
      await processAnthropicStream(response.body, elements.screenshotOutput);
    } else {
      await processOpenAIStream(response.body, elements.screenshotOutput);
    }
  }

  // ==================== Initialization ====================

  /**
   * Initialize the AI panel
   */
  function init() {
    if (!window.ActiveCanvasEditor?.config?.aiEndpoints) {
      console.log('AI Panel: No AI endpoints configured');
      return;
    }

    cacheElements();
    initModelPickers();
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
      textGenerateBtn: document.getElementById('btn-ai-text-generate'),
      textOutput: document.getElementById('ai-text-output'),
      textOutputWrapper: document.getElementById('ai-text-output-wrapper'),
      textInsertBtn: document.getElementById('btn-ai-text-insert'),
      textConversation: document.getElementById('ai-text-conversation'),
      regenerateBtn: document.getElementById('btn-ai-regenerate'),
      copyBtn: document.getElementById('btn-ai-copy'),
      // Image generation
      imagePrompt: document.getElementById('ai-image-prompt'),
      imageGenerateBtn: document.getElementById('btn-ai-image-generate'),
      imageOutput: document.getElementById('ai-image-output'),
      imageOutputWrapper: document.getElementById('ai-image-output-wrapper'),
      imageInsertBtn: document.getElementById('btn-ai-image-insert'),
      imageEmpty: document.getElementById('ai-image-empty'),
      // Screenshot
      screenshotInput: document.getElementById('ai-screenshot-input'),
      screenshotPreview: document.getElementById('ai-screenshot-preview'),
      screenshotPrompt: document.getElementById('ai-screenshot-prompt'),
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
   * Initialize model picker components
   */
  function initModelPickers() {
    ['text', 'image', 'screenshot'].forEach(tab => {
      const el = document.getElementById(`ai-${tab}-model-picker`);
      if (!el) return;

      const picker = {
        root: el,
        btn: el.querySelector('.ai-model-picker-btn'),
        label: el.querySelector('.ai-model-picker-label'),
        dropdown: el.querySelector('.ai-model-picker-dropdown'),
        search: el.querySelector('.ai-model-picker-search'),
        list: el.querySelector('.ai-model-picker-list'),
        open: false,
        tab: tab
      };

      picker.btn.addEventListener('click', (e) => {
        e.stopPropagation();
        togglePicker(tab);
      });

      picker.search.addEventListener('input', () => filterModels(tab));
      picker.search.addEventListener('keydown', (e) => handlePickerKeydown(e, tab));

      pickers[tab] = picker;
    });

    // Close all pickers on outside click
    document.addEventListener('click', closeAllPickers);
  }

  /**
   * Toggle a model picker open/closed
   */
  function togglePicker(tab) {
    const picker = pickers[tab];
    if (!picker) return;

    if (picker.open) {
      closePicker(tab);
    } else {
      closeAllPickers();
      openPicker(tab);
    }
  }

  function openPicker(tab) {
    const picker = pickers[tab];
    if (!picker) return;

    picker.open = true;
    picker.root.classList.add('open');
    picker.search.value = '';
    filterModels(tab);
    picker.search.focus();
  }

  function closePicker(tab) {
    const picker = pickers[tab];
    if (!picker) return;

    picker.open = false;
    picker.root.classList.remove('open');
  }

  function closeAllPickers() {
    Object.keys(pickers).forEach(closePicker);
  }

  /**
   * Filter models in a picker based on search input
   */
  function filterModels(tab) {
    const picker = pickers[tab];
    if (!picker) return;

    const query = picker.search.value.toLowerCase().trim();
    const modelKey = tab === 'screenshot' ? 'vision' : tab;
    const models = availableModels[modelKey] || [];

    const filtered = query
      ? models.filter(m => m.name.toLowerCase().includes(query) || m.id.toLowerCase().includes(query) || (m.provider || '').toLowerCase().includes(query))
      : models;

    renderPickerList(tab, filtered);
  }

  /**
   * Render the model list in a picker
   */
  function renderPickerList(tab, models) {
    const picker = pickers[tab];
    if (!picker) return;

    if (!models.length) {
      picker.list.innerHTML = '<li class="ai-model-picker-empty">No models found</li>';
      return;
    }

    picker.list.innerHTML = models.map(m => {
      const isSelected = selectedModels[tab] === m.id;
      return `<li class="ai-model-picker-item${isSelected ? ' selected' : ''}" data-value="${escapeHtml(m.id)}" role="option" aria-selected="${isSelected}">
        <span class="ai-model-picker-item-name">${escapeHtml(m.name)}</span>
        <span class="ai-model-picker-item-provider">${escapeHtml(m.provider || '')}</span>
      </li>`;
    }).join('');

    // Bind click on each item
    picker.list.querySelectorAll('.ai-model-picker-item').forEach(item => {
      item.addEventListener('click', (e) => {
        e.stopPropagation();
        selectModel(tab, item.dataset.value);
      });
    });
  }

  /**
   * Select a model for a tab
   */
  function selectModel(tab, modelId) {
    const modelKey = tab === 'screenshot' ? 'vision' : tab;
    const models = availableModels[modelKey] || [];
    const model = models.find(m => m.id === modelId);

    selectedModels[tab] = modelId;

    // Update button label
    const picker = pickers[tab];
    if (picker && model) {
      picker.label.textContent = model.name;
    }

    // Persist to localStorage
    try {
      localStorage.setItem(STORAGE_PREFIX + tab, modelId);
    } catch (e) {
      // localStorage not available
    }

    closePicker(tab);
  }

  /**
   * Get the currently selected model ID for a tab
   */
  function getSelectedModel(tab) {
    return selectedModels[tab] || null;
  }

  /**
   * Handle keyboard navigation inside picker
   */
  function handlePickerKeydown(e, tab) {
    const picker = pickers[tab];
    if (!picker) return;

    if (e.key === 'Escape') {
      closePicker(tab);
      picker.btn.focus();
    } else if (e.key === 'Enter') {
      e.preventDefault();
      const first = picker.list.querySelector('.ai-model-picker-item');
      if (first) selectModel(tab, first.dataset.value);
    }
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

      populateModelPickers(data.default_text, data.default_image, data.default_vision);
    } catch (error) {
      console.error('AI Panel: Failed to load models', error);
    }
  }

  /**
   * Populate model pickers with loaded data, restoring last-used from localStorage
   */
  function populateModelPickers(defaultText, defaultImage, defaultVision) {
    const defaults = { text: defaultText, image: defaultImage, screenshot: defaultVision };
    const modelKeys = { text: 'text', image: 'image', screenshot: 'vision' };

    ['text', 'image', 'screenshot'].forEach(tab => {
      const models = availableModels[modelKeys[tab]] || [];
      if (!models.length) return;

      // Determine which model to select: localStorage > server default > first
      let saved = null;
      try { saved = localStorage.getItem(STORAGE_PREFIX + tab); } catch (e) {}

      const serverDefault = defaults[tab];
      const modelIds = models.map(m => m.id);

      let chosen = null;
      if (saved && modelIds.includes(saved)) {
        chosen = saved;
      } else if (serverDefault && modelIds.includes(serverDefault)) {
        chosen = serverDefault;
      } else {
        chosen = modelIds[0];
      }

      selectedModels[tab] = chosen;

      // Update picker label
      const picker = pickers[tab];
      if (picker) {
        const model = models.find(m => m.id === chosen);
        picker.label.textContent = model ? model.name : chosen;
        renderPickerList(tab, models);
      }
    });
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

  // ==================== Main Generation Functions ====================

  /**
   * Generate text content using SSE streaming
   */
  async function generateText() {
    if (isGenerating || !elements.textPrompt?.value.trim()) return;

    const prompt = elements.textPrompt.value.trim();
    const model = getSelectedModel('text');

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
      if (isDirectMode()) {
        await generateTextDirect(prompt, model, currentHtml);
      } else {
        // Server mode (existing behavior)
        const endpoints = window.ActiveCanvasEditor.config.aiEndpoints;
        if (!endpoints?.chat) return;

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
      }
    } catch (error) {
      if (error.name !== 'AbortError') {
        console.error('AI Text Generation Error:', error);
        // Detect Anthropic CORS issues
        if (isDirectMode() && error instanceof TypeError && error.message.includes('Failed to fetch')) {
          const provider = getModelProvider(model);
          if (provider === 'anthropic') {
            showOutputError(elements.textOutput, 'Direct mode not available for Anthropic. Try server mode or check browser settings.');
          } else {
            showOutputError(elements.textOutput, error.message);
          }
        } else {
          showOutputError(elements.textOutput, error.message);
        }
      }
    } finally {
      setGenerating(false);
      abortController = null;
    }
  }

  /**
   * Process SSE stream and update output (server mode)
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

    const prompt = elements.imagePrompt.value.trim();
    const model = getSelectedModel('image');

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
      if (isDirectMode()) {
        const imageUrl = await generateImageDirect(prompt, model);
        elements.imageOutput.innerHTML = `<img src="${imageUrl}" alt="AI Generated: ${escapeHtml(prompt)}" />`;
        elements.imageOutput.dataset.imageUrl = imageUrl;
      } else {
        // Server mode (existing behavior)
        const endpoints = window.ActiveCanvasEditor.config.aiEndpoints;
        if (!endpoints?.image) return;

        abortController = new AbortController();
        const timeoutId = setTimeout(() => abortController.abort(), 180000);

        const response = await fetch(endpoints.image, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': getCSRFToken()
          },
          body: JSON.stringify({ prompt, model }),
          signal: abortController.signal
        });

        clearTimeout(timeoutId);

        const data = await response.json();

        if (!response.ok) {
          throw new Error(data.error || 'Image generation failed');
        }

        // Display generated image
        elements.imageOutput.innerHTML = `<img src="${data.url}" alt="AI Generated: ${escapeHtml(prompt)}" />`;
        elements.imageOutput.dataset.imageUrl = data.url;
      }
    } catch (error) {
      if (error.name === 'AbortError') {
        elements.imageOutput.innerHTML = '<div class="ai-error">Request timed out. Please try again.</div>';
      } else {
        console.error('AI Image Generation Error:', error);
        elements.imageOutput.innerHTML = `<div class="ai-error">${escapeHtml(error.message)}</div>`;
      }
    } finally {
      setGenerating(false);
      abortController = null;
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

    const additionalPrompt = elements.screenshotPrompt?.value.trim();
    const model = getSelectedModel('screenshot');

    setGenerating(true);

    if (elements.screenshotOutputWrapper) {
      elements.screenshotOutputWrapper.style.display = 'block';
    }

    if (elements.screenshotOutput) {
      elements.screenshotOutput.innerHTML = '<div class="ai-loading-indicator"><div class="ai-loading-dots"><span></span><span></span><span></span></div><span>Converting screenshot...</span></div>';
    }

    try {
      if (isDirectMode()) {
        await convertScreenshotDirect(imageData, model, additionalPrompt);
      } else {
        // Server mode (existing behavior)
        const endpoints = window.ActiveCanvasEditor.config.aiEndpoints;
        if (!endpoints?.screenshot) return;

        abortController = new AbortController();
        const timeoutId = setTimeout(() => abortController.abort(), 180000);

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
          }),
          signal: abortController.signal
        });

        clearTimeout(timeoutId);

        const data = await response.json();

        if (!response.ok) {
          throw new Error(data.error || 'Conversion failed');
        }

        elements.screenshotOutput.textContent = data.html;
      }
    } catch (error) {
      if (error.name === 'AbortError') {
        elements.screenshotOutput.innerHTML = '<div class="ai-error">Request timed out. Please try again.</div>';
      } else {
        console.error('AI Screenshot Conversion Error:', error);
        // Detect Anthropic CORS issues
        if (isDirectMode() && error instanceof TypeError && error.message.includes('Failed to fetch')) {
          const provider = getModelProvider(model);
          if (provider === 'anthropic') {
            showOutputError(elements.screenshotOutput, 'Direct mode not available for Anthropic. Try server mode or check browser settings.');
          } else {
            elements.screenshotOutput.innerHTML = `<div class="ai-error">${escapeHtml(error.message)}</div>`;
          }
        } else {
          elements.screenshotOutput.innerHTML = `<div class="ai-error">${escapeHtml(error.message)}</div>`;
        }
      }
    } finally {
      setGenerating(false);
      abortController = null;
    }
  }

  // ==================== Insert & Utility Functions ====================

  /**
   * Insert text content into editor
   */
  function insertTextContent() {
    const html = elements.textOutput?.textContent;
    if (html) {
      insertHtmlToEditor(html, elements.textInsertBtn);
    }
  }

  /**
   * Insert image content into editor
   */
  function insertImageContent() {
    const imageUrl = elements.imageOutput?.dataset.imageUrl;
    if (imageUrl) {
      const html = `<img src="${imageUrl}" alt="AI Generated Image" style="max-width: 100%; height: auto;" />`;
      insertHtmlToEditor(html, elements.imageInsertBtn);
    }
  }

  /**
   * Insert screenshot content into editor
   */
  function insertScreenshotContent() {
    const html = elements.screenshotOutput?.textContent;
    if (html) {
      insertHtmlToEditor(html, elements.screenshotInsertBtn);
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
  function insertHtmlToEditor(html, insertButton) {
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
          selected.components().forEach(c => stripAutoStyles(editor, c));
          showToast('Content updated', 'success');
        } else {
          const wrapper = editor.getWrapper();
          const added = wrapper.append(html);
          added.forEach(c => stripAutoStyles(editor, c));
          showToast('Content added to page', 'success');
        }
      } else {
        const wrapper = editor.getWrapper();
        const added = wrapper.append(html);
        added.forEach(c => stripAutoStyles(editor, c));
        showToast('Content added to page', 'success');
      }

      // Apply cooldown to prevent double-insertion
      if (insertButton) {
        startInsertCooldown(insertButton);
      }
    } catch (error) {
      console.error('Insert error:', error);
      showToast('Failed to insert content', 'error');
    }
  }

  /**
   * Remove auto-generated CSS rules that GrapeJS adds for component-type defaults
   * (e.g. #isx3 { min-height: 100px; padding: 2rem; } on sections)
   */
  function stripAutoStyles(editor, component) {
    const id = component.getId();
    if (id) {
      const rule = editor.Css.getRule(`#${id}`);
      if (rule) {
        editor.Css.remove(rule);
      }
    }
    component.components().forEach(c => stripAutoStyles(editor, c));
  }

  /**
   * Start cooldown on insert button to prevent accidental double-insertion
   */
  function startInsertCooldown(button) {
    if (!button) return;

    const originalText = button.innerHTML;
    const cooldownSeconds = 20;
    let remaining = cooldownSeconds;

    button.disabled = true;
    button.classList.add('cooldown');
    button.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg> Inserted (${remaining}s)`;

    const interval = setInterval(() => {
      remaining--;
      if (remaining > 0) {
        button.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg> Inserted (${remaining}s)`;
      } else {
        clearInterval(interval);
        button.disabled = false;
        button.classList.remove('cooldown');
        button.innerHTML = originalText;
      }
    }, 1000);
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
