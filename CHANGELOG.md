# Changelog

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
