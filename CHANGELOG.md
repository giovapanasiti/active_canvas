# Changelog

## Unreleased

### Dynamic content
- **Editor keeps the Liquid source.** The canvas no longer loads rendered HTML; `{{ }}` tags are lossless chips, loops and conditions are `data-ac-for` / `data-ac-if` attributes set through the Settings tab, and tags inside attributes, tables and nested loops survive every save.
- **Escaping at the boundary.** Every string entering Liquid is HTML-escaped (`auto_drop ... html: %i[body]` opts an attribute out). Plain Ruby objects and records nested in hashes are refused.
- **Soft-fail public rendering.** An undefined variable, unknown filter or raising node renders empty instead of blanking the page; every other error falls back to the comment and is reported through `Rails.error`. `on_error :silent` is honored.
- **Validation and feedback.** `Page` validates its bindings payload (422 instead of 500). The editor checks the template after edits and shows a banner with the line. A Data-tab switch turns dynamic rendering on and off. Each binding has a "Sample data" peek.
- **Collections in the Data panel.** Grouped source picker with labels, typed limit / sort / filter controls built from the collection's fields, filter values from select options.
- **Collections admin.** Publish while published (pending changes), grid badge and row actions, history shows removed fields, required fields enforced on publish, publish is row-locked and re-sanitizes rich text, the draft is normalized on publish. Reserved field ids (`id`, `slug`, `published_at`) are rejected; generated ids are always valid; a blank slug derives from the name. Media for the item form is loaded once.
- **Security.** Preview iframe is sandboxed. `Current.editor` replaces both thread-local editor accessors and records the user's name or email.
- **Bindings editable in place.** A literal binding shows its value in a text box on its card; every card has a pencil that reopens the form prefilled to change the source or parameters.
- **Live data in the canvas.** A header switch shows the real value of every chip, every item of a loop (the other items as dimmed, view-only copies, up to 10) and whether a condition shows its element, while editing; the saved source is never touched. New `chip_values` endpoint.
- **Sanitizer keeps Liquid.** `ContentSanitizer` masks Liquid tags before parsing, so `{{ url }}` inside an `href` is no longer percent-encoded and `{% if a < b %}` is no longer read as markup.
- **Tests.** Opt-in Selenium system test for the editor round trip (`AC_SYSTEM=1`).

### Breaking
- `render_preview` endpoint replaced by `validate_template` (no HTML returned) and `sample_data`.
- `DataSources.registered_names` no longer includes `_literal`.
- `auto_drop` string attributes are escaped by default. Sources that returned HTML must list those attributes in `html:`.
- `data_sources` JSON: every entry has `kind`, `label`, `item_name`, `list`; `range` is `[min, max]`; collection params are typed.
- `Page.current_editor` and `CollectionItem.current_editor` are gone; use `ActiveCanvas::Current.editor`.

## 0.0.3

Fixes from 0.0.2 beta-tester feedback.

### Fixed
- **Expiring image URLs baked into saved pages (#1):** media are now stored as
  stable `data-ac-media-id` references and resolved to fresh URLs at render time
  via `ContentRenderer`. A migration backfills existing pages (best-effort; pages
  whose underlying blob was deleted cannot be recovered).
- **SVG uploads invisible in the library (#2):** the `images` scope now uses
  `effective_allowed_content_types`.
- **Programmatic Media create failing (#3):** `filename`/`content_type`/`byte_size`
  are derived `before_validation on: :create`.
- **public_uploads silent degradation (#4):** logs a warning when enabled but the
  service is not `public?`; docs clarify the `public: true` service requirement.
- **S3 public ACLs (#5):** documented that public media require a bucket policy,
  not per-object ACLs.
- **SVG stored-XSS (#6):** uploaded SVGs are served with
  `Content-Disposition: attachment` on the signed-URL path. Note: this does not
  cover `public_uploads` + a public service (the SVG is served inline from the
  public origin) — use a separate origin/bucket for public SVG serving.
- **Duplicate content types (#7):** `effective_allowed_content_types` is de-duped.
- **Interactive-only install generator (#8):** added `--defaults` (CI-safe) and
  `--skip-route`.
- **Unresolvable relative asset paths (#9):** the editor now warns authors.

### Migration notes
Run `bin/rails active_canvas:install:migrations && bin/rails db:migrate` to apply
the media-reference backfill. The backfill is idempotent and logs any `<img>` it
cannot match.
