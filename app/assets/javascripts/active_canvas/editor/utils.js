/**
 * ActiveCanvas Editor - Utility Functions
 */

(function() {
  'use strict';

  window.ActiveCanvasEditor = window.ActiveCanvasEditor || {};

  /**
   * Show a toast notification
   * @param {string} message - The message to display
   * @param {string} type - 'success' or 'error'
   */
  function showToast(message, type) {
    const toast = document.getElementById('editor-toast');
    if (!toast) return;

    toast.textContent = message;
    toast.className = 'editor-toast show ' + type;

    setTimeout(() => {
      toast.classList.remove('show');
    }, 3000);
  }

  /**
   * Show or hide the loading overlay
   * @param {boolean} show - Whether to show the loading overlay
   */
  function showLoading(show) {
    const loading = document.getElementById('editor-loading');
    if (!loading) return;

    if (show) {
      loading.classList.remove('hidden');
    } else {
      loading.classList.add('hidden');
    }
  }

  /**
   * Get CSRF token from meta tag
   * @returns {string} The CSRF token
   */
  function getCsrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]');
    return meta ? meta.getAttribute('content') : '';
  }

  // Expose utilities
  window.ActiveCanvasEditor.showToast = showToast;
  window.ActiveCanvasEditor.showLoading = showLoading;
  window.ActiveCanvasEditor.getCsrfToken = getCsrfToken;

})();
