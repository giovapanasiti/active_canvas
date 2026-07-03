(function() {
  const builder = document.getElementById('ac-field-builder');
  if (!builder) return;

  const list = document.getElementById('ac-fields-list');
  const template = document.getElementById('ac-field-row-template');
  const hidden = document.getElementById('ac-fields-json');
  const form = builder.closest('form');

  function addRow(field) {
    const row = template.content.firstElementChild.cloneNode(true);
    if (field) {
      row.querySelector('[data-field="id"]').value = field.id || '';
      row.querySelector('[data-field="label"]').value = field.label || '';
      row.querySelector('[data-field="type"]').value = field.type || 'text';
      row.querySelector('[data-field="required"]').checked = !!field.required;
      row.querySelector('[data-field="options"]').value = (field.options || []).join(', ');
    }
    toggleOptions(row);
    wireRow(row);
    list.appendChild(row);
    return row;
  }

  function wireRow(row) {
    row.querySelector('[data-field="type"]').addEventListener('change', () => toggleOptions(row));
    row.querySelector('[data-remove]').addEventListener('click', () => {
      const existing = row.querySelector('[data-field="id"]').value.trim() !== '';
      if (existing && !confirm('Remove this field? Existing item data for it is kept but no longer shown.')) return;
      row.remove();
    });
    row.querySelector('[data-move="up"]').addEventListener('click', () => {
      if (row.previousElementSibling) list.insertBefore(row, row.previousElementSibling);
    });
    row.querySelector('[data-move="down"]').addEventListener('click', () => {
      if (row.nextElementSibling) list.insertBefore(row.nextElementSibling, row);
    });
  }

  function toggleOptions(row) {
    const isSelect = row.querySelector('[data-field="type"]').value === 'select';
    row.querySelector('[data-field="options"]').hidden = !isSelect;
  }

  function serialize() {
    const rows = Array.from(list.querySelectorAll('.ac-field-row'));
    const fields = rows.map(row => {
      const id = row.querySelector('[data-field="id"]').value.trim();
      const type = row.querySelector('[data-field="type"]').value;
      const options = row.querySelector('[data-field="options"]').value
        .split(',').map(s => s.trim()).filter(s => s.length > 0);
      const field = {
        label: row.querySelector('[data-field="label"]').value.trim(),
        type: type,
        required: row.querySelector('[data-field="required"]').checked,
        options: type === 'select' ? options : []
      };
      if (id) field.id = id;
      return field;
    });
    hidden.value = JSON.stringify(fields);
  }

  document.getElementById('ac-add-field-btn').addEventListener('click', () => addRow(null).querySelector('[data-field="label"]').focus());
  if (form) form.addEventListener('submit', serialize);

  const initial = JSON.parse(document.getElementById('ac-fields-data').textContent || '[]');
  initial.forEach(addRow);
})();
