module ActiveCanvas
  module Mcp
    # Server instructions returned to the client at `initialize`.
    module Instructions
      TEXT = <<~TEXT.freeze
        ActiveCanvas is a content management engine. Content lives in three kinds
        of records:
        - Pages: standalone URLs (title, slug, SEO fields, HTML/CSS/JS content).
          Each page belongs to a page type, a category such as "blog post"
          (list_page_types / create_page_type / update_page_type / delete_page_type).
        - Partials: the site-wide header and footer, shared by every page
          (list_partials / get_partial / update_partial).
        - Collections: typed content lists (e.g. "Team", "Plans") with a field
          schema per collection and draft/published items inside them
          (list_collections / create_collection / ... and
          list_collection_items / ...).

        ## Scopes and the publish rule

        Every token has 'read', 'write' and/or 'publish'. 'write' implies 'read';
        'publish' implies 'write'. tools/list only shows tools your token can
        call. Creating something (a page, a collection item, a media file) is
        always allowed under 'write' and always starts life unpublished/draft.
        Mutating anything that is already live — a published page, a published
        collection item, a partial (header/footer render on every page), or
        site/AI settings — requires 'publish', even when the same tool also
        handles the unpublished case under 'write'. A call missing 'publish'
        fails with: "This <noun> is published; changing it requires the
        'publish' scope." Publishing/unpublishing itself (set_page_published,
        publish_collection_item, unpublish_collection_item) always requires
        'publish'.

        ## Content

        A page's or partial's content is three fields: `content` (HTML),
        `content_css`, `content_js`. When the site's CSS framework is Tailwind
        (check `get_settings.css_framework`), Tailwind utility classes written
        into `content` are compiled automatically after every save — there is
        no separate stylesheet to maintain for them.

        ## Images

        Upload with `upload_media` (base64 data); it returns an `html_snippet`
        like `<img data-ac-media-id="42" src="...">`. Always reference images
        this way, never with a raw URL: `data-ac-media-id` is the persisted,
        stable reference, and `src` is only a preview — the real URL is
        re-resolved at render time, so the id, not the src, is what must
        survive edits.

        ## Forms

        Any `<form>` in a page's content is armed automatically at render time
        (anti-spam token, honeypot, success/error feedback) — no extra markup
        or tool call is needed to make a form work. Submissions appear in
        `list_form_submissions` / `get_form_submission`;
        `export_form_submissions_csv` returns a CSV of them;
        `delete_form_submission` removes one.

        ## Dynamic (data-bound) pages

        Set a page's `template_enabled: true` to render its content as Liquid
        against data bound to it, instead of static HTML. `bindings` is a JSON
        object: each key is the name used in Liquid. A source or collection
        binding is `{ "source": "<name>", "params": { ... } }`, where `<name>`
        is a source returned by `list_data_sources` (a host-registered data
        source, or a collection by its slug). The `_literal` source is the
        exception: it takes a top-level `"value"`, not `params.value`
        (`list_data_sources` still describes that value under `params` in its
        schema, for the editor's form — but the binding itself stores
        `"value"` directly next to `"source"`). Example:

          {
            "hero": { "source": "_literal", "value": "Welcome" },
            "team": { "source": "team", "params": { "limit": 6 } }
          }

        Access a binding's fields in Liquid with `{{ name.field }}`, e.g.
        `{{ hero }}` or `{{ team.first.name }}`. Repeat an element once per
        item of a list binding by adding `data-ac-for="item in team"` to it
        (expands to `{% for item in team %}...{% endfor %}` around the
        element); inside the loop reference fields as `{{ item.field }}`. Show
        or hide an element with `data-ac-if="team.size > 0"` (expands to
        `{% if %}...{% endif %}`). Both attributes can be on the same element;
        the loop wraps outside the condition. Example:

          <div data-ac-for="member in team" data-ac-if="team.size > 0">
            <h3>{{ member.name }}</h3>
          </div>

        Recommended flow for writing or changing dynamic content:
        `list_data_sources` (see what's available) → `sample_binding_data` (see
        real field names/values for a binding before writing `{{ }}` against
        it) → write the content and bindings → `validate_template` (catches a
        Liquid syntax or reference error before saving; returns
        `{ ok: true }` or `{ ok: false, error: { message, line, column } }`) →
        `render_page_preview` (see the fully rendered page: layout, partials,
        CSS) → `update_page_content` (save). `preview_template_values` is a
        lighter check: what each `{{ }}`/loop/condition currently evaluates to,
        without a full render.

        ## Versions

        Versions exist for pages only. Every page content save
        (content/CSS/bindings) creates a version automatically — versions are
        never created explicitly. `list_page_versions` / `get_page_version`
        show history and diffs; `restore_page_version` copies an earlier
        version's content back as a new version (history is append-only;
        nothing is deleted). Restoring a published page's content still
        requires the 'publish' scope. A partial's content (`update_partial`)
        has no version history: a change takes effect live immediately and
        cannot be undone via restore.

        ## Practical notes

        - `list_*` tools return `{ items, total, limit, offset }` (limit
          default 50, max 200); use the matching `get_*` tool for the full
          content of one record.
        - `create_page` never publishes; call `set_page_published` afterwards.
        - `homepage_page_id` is a site setting (`update_site_settings`), not a
          page field.
        - Changing the slug of a published page creates a redirect from the
          old slug automatically.
      TEXT
    end
  end
end
