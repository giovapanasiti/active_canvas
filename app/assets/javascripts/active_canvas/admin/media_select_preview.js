(function() {
  document.querySelectorAll('select[data-media-select]').forEach(function(select) {
    const preview = select.parentElement.querySelector('.ac-media-preview');
    if (!preview) return;
    select.addEventListener('change', function() {
      const url = select.options[select.selectedIndex].dataset.url;
      if (url) { preview.src = url; preview.style.display = ''; }
      else { preview.removeAttribute('src'); preview.style.display = 'none'; }
    });
  });
})();
