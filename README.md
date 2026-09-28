# ActiveCanvas

![Live data in the ActiveCanvas editor: the switch flips between rendered values and Liquid source](docs/images/active-canvas-live-data.gif)

*The Live data switch: every chip shows the value it renders, loops show every item, conditions dim what they hide. Switch it off to see the Liquid source. The saved page always keeps the source.*

A mountable Rails engine that turns any Rails app into a full-featured CMS. Includes a visual drag-and-drop editor (GrapesJS), AI-powered content generation, Tailwind CSS compilation, media management, page versioning, and SEO controls -- all behind an admin interface that works out of the box.

## Features

- **Visual Editor** -- Drag-and-drop page builder powered by GrapesJS
- **AI Content Generation** -- Text, images, and screenshot-to-code via OpenAI, Anthropic, or OpenRouter
- **Tailwind CSS Compilation** -- Per-page compiled CSS for production (no CDN dependency)
- **Media Library** -- Upload and manage images/files with Active Storage
- **Page Versioning** -- Automatic version history with diffs and rollback
- **Header & Footer Partials** -- Reusable components, togglable per page
- **SEO** -- Meta tags, Open Graph, Twitter Cards, JSON-LD structured data
- **Page Types** -- Categorize pages (blog posts, landing pages, etc.)
- **Dynamic Content** -- Bind host-app data sources or admin-managed collections, repeat and show elements with attributes, see real data while editing ([docs](docs/dynamic_content.md))
- **Collections** -- Typed content lists (text, rich text, number, boolean, date, media, select) with draft and published versions, editable in the admin without code
- **Authentication** -- Pluggable auth (Devise, custom, or HTTP Basic)
- **Isolated Namespace** -- No conflicts with your host application

## A look inside

**A page built from collections.** Cards, pricing with a featured badge, FAQs, filters, loop modifiers and conditions, all from data the admin edits.

![The public Showcase page: a hero from literal bindings and one card per team member](docs/images/showcase-public.jpg)

**Bindings edited in place.** The Data tab lists every binding. A literal shows its value in a text box, a collection shows its parameters, and the canvas updates as you type.

![The editor with the Data tab open next to the canvas showing the team cards](docs/images/editor-data-panel.jpg)

**Collections in the admin.** Typed fields, a draft and a published version per item, publish and unpublish, and a history of every publish.

![The Plans collection items grid with status, publish and history actions](docs/images/collections-items.jpg)

**Version history.** Every save is a version with size deltas, a quick diff and a full view.

![The version history of a page with quick diff and view details actions](docs/images/version-history.jpg)

## Requirements

- Ruby 3.1+
- Rails 8.0+

## Installation

Add to your Gemfile:

```ruby
gem "active_canvas"
```

Run the install generator:

```bash
bundle install
bin/rails generate active_canvas:install
```

The interactive installer will:
- Copy and run database migrations
- Create `config/initializers/active_canvas.rb` with configuration options
- Mount the engine in your routes (default: `/canvas`)
- Prompt you to choose a CSS framework (Tailwind, Bootstrap 5, or none)
- Optionally configure AI API keys

Then visit `/canvas/admin` to start building pages.

## Quick Start

1. Go to `/canvas/admin`
2. Create a **Page Type** (e.g., "Landing Page")
3. Create a **Page**, then click **Editor** to open the visual builder
4. Drag blocks, use AI to generate content, upload images
5. Publish the page -- it's live at `/canvas/your-slug`

## Visual Editor

The GrapesJS editor provides:

- Drag-and-drop blocks (text, images, columns, forms, etc.)
- Code editor panel for direct HTML/CSS editing
- Asset manager integrated with the media library
- AI assistant panel for content generation
- Component-level AI toolbar (edit, rewrite, expand)
- Auto-save (configurable interval, default: 60s)

## AI Integration

ActiveCanvas uses [RubyLLM](https://github.com/crmne/ruby_llm) to provide AI features directly in the editor.

### Capabilities

| Feature | Description | Supported Models |
|---------|-------------|-----------------|
| **Chat** | Generate and edit HTML content with streaming | GPT-4o, Claude Sonnet 4, Claude 3.5 Haiku |
| **Image Generation** | Create images from text prompts | DALL-E 3, GPT Image 1 |
| **Screenshot to Code** | Upload a screenshot, get HTML/CSS | GPT-4o, Claude Sonnet 4 (vision models) |

### Setup

Add your API keys via environment variables or Rails credentials:

```ruby
# config/initializers/active_canvas.rb
Rails.application.config.after_initialize do
  # Via environment variables
  ActiveCanvas::Setting.ai_openai_api_key = ENV["OPENAI_API_KEY"]
  ActiveCanvas::Setting.ai_anthropic_api_key = ENV["ANTHROPIC_API_KEY"]
  ActiveCanvas::Setting.ai_openrouter_api_key = ENV["OPENROUTER_API_KEY"]

  # Or via Rails credentials
  credentials = Rails.application.credentials.active_canvas || {}
  ActiveCanvas::Setting.ai_openai_api_key = credentials[:openai_api_key]
end
```

You can also configure API keys from the admin UI at `/canvas/admin/settings` (AI tab).

Once configured, sync available models:

```bash
bin/rails active_canvas:sync_models
```

Or use the **Sync Models** button in admin settings.

### Server Timeout

AI requests (especially image generation and screenshot-to-code) can take longer than typical web requests. If you're running Puma in clustered mode (multiple workers), increase the worker timeout to avoid requests being killed mid-flight:

```ruby
# config/puma.rb
worker_timeout 180
```

Or via environment variable:

```bash
PUMA_WORKER_TIMEOUT=180
```

If you're behind a reverse proxy (Nginx, Apache), also increase its read timeout for the ActiveCanvas routes:

```nginx
location /canvas {
  proxy_read_timeout 180s;
  proxy_send_timeout 180s;
}
```

## Tailwind CSS Compilation

ActiveCanvas can compile Tailwind CSS at runtime so your public pages don't need the Tailwind CDN.

### How it works

- **In the editor**: Uses Tailwind CDN for instant live preview
- **On save**: Compiles only the CSS classes used on that page
- **Public pages**: Serves compiled CSS inline (fast, no CDN)

### Setup

Add the `tailwindcss-ruby` gem (optional -- falls back to CDN if missing):

```ruby
gem "tailwindcss-ruby", ">= 4.0"
```

Select "Tailwind CSS" as the CSS framework in your initializer or admin settings. That's it -- CSS compiles automatically when you save pages.

You can customize the Tailwind theme (colors, fonts) from admin settings, and trigger a bulk recompile of all pages when needed.

## Media Library

Upload and manage images directly from the admin or from within the editor's asset manager.

- Supports JPEG, PNG, GIF, WebP, AVIF, and PDF
- SVG uploads available (disabled by default for security)
- Configurable max file size (default: 10MB)
- Works with any Active Storage backend (local, S3, GCS, etc.)
- Public or signed URL modes

## Media & storage

### Stable media references

Images inserted via the editor are stored as `data-ac-media-id` attribute references in page content rather than raw URLs. At render time, `ContentRenderer` resolves each reference to a fresh URL, so time-limited signed URLs are never persisted in the database. Existing pages gain this behaviour automatically after running the backfill migration:

```bash
bin/rails active_canvas:install:migrations
bin/rails db:migrate
```

Note: blobs that were already deleted from Active Storage cannot be recovered by the backfill.

### public_uploads (#4)

Setting `config.public_uploads = true` only takes effect when the Active Storage service is **also** declared `public: true` in `config/storage.yml`. If the service is not public, ActiveCanvas logs a warning and falls back to signed URLs automatically.

For a public Disk service used outside a request context (e.g. background jobs), you must set:

```ruby
Rails.application.routes.default_url_options[:host] = "https://yourapp.example.com"
```

### Public S3 buckets (#5)

For S3, make the bucket publicly readable via a **bucket policy**, not per-object ACLs. Modern S3 buckets have Object Ownership set to "Bucket owner enforced" and Block Public Access enabled, which means per-object `public-read` ACLs are silently ignored. A bucket policy that allows `s3:GetObject` for `"Principal": "*"` is the supported path.

Declare the service `public: true` in `config/storage.yml` and set `config.storage_service` to its name -- that combination is what ActiveCanvas checks before switching to public URLs.

### SVG uploads (#6)

SVG uploads are disabled by default because SVGs can contain `<script>` tags and event-handler attributes (stored-XSS).

When you enable them with `config.allow_svg_uploads = true`, ActiveCanvas serves uploaded SVGs with `Content-Disposition: attachment` on the **signed-URL path**, which causes browsers to download the file rather than render it, neutralizing top-level execution.

**Known limitation:** this disposition is **not** applied when `public_uploads` is `true` and the storage service is public. In that configuration the SVG is served inline directly from the public bucket/origin, bypassing the disposition header. If you need SVG uploads with `public_uploads`, serve media uploads from a **separate origin or bucket** (a different domain from your application) so that any injected scripts cannot access your app's cookies or local storage.

Also note: the admin "Open Original" link will trigger a download (not an inline display) for SVG files because of the `attachment` disposition.

## Page Versioning

Every content change creates a version automatically. View the version history from the page admin to see:

- What changed (before/after diffs)
- Who made the change
- When it was made
- Content size differences

Configure the maximum versions kept per page (default: 50, set to 0 for unlimited).

## Site-wide SEO

The admin Settings area has an **SEO** tab for the site-wide options that sit above per-page meta tags:

- Site name and a title template (`%{title} | %{site_name}`) used as the fallback `<title>` for every page.
- Default meta description and default Open Graph image, used when a page doesn't set its own.
- Favicon, picked from the Media library.
- Google / Bing search-engine verification tags.
- An auto-generated XML sitemap at `/sitemap.xml`, built from published pages (drafts and pages with `noindex` in their `meta_robots` are excluded). It can be turned off from the SEO tab.
- `robots.txt` at `/robots.txt`, either a custom body you provide or a generated default that allows all crawlers and links the sitemap.

Both `/sitemap.xml` and `/robots.txt` are served relative to wherever the engine is mounted, so they still work if you mount ActiveCanvas somewhere other than the root. If you need them at the domain root, mount the engine at `/` or reverse-proxy those two paths.

## MCP server (agents)

ActiveCanvas exposes an [MCP](https://modelcontextprotocol.io) server so a coding agent can manage pages, partials, collections, media, forms and settings the same way an admin would in the UI -- roughly 50 tools covering everything from `list_pages` to `update_page_content` to `publish_collection_item`.

For a step-by-step walkthrough with screenshots, see [Using ActiveCanvas from Claude Code](docs/mcp-claude-code.md).

### Enabling it

MCP is on by default. Turn it off with:

```ruby
ActiveCanvas.configure do |config|
  config.enable_mcp = false          # /canvas/mcp returns 404 when disabled
  config.mcp_rate_limit_per_minute = 120  # per token
end
```

Access tokens are stored in a new table, so run the engine's migrations first:

```bash
bin/rails active_canvas:install:migrations
bin/rails db:migrate
```

### Creating a token

Open **Settings → API tokens** in the admin, give it a name and an access level (Read only / Read & write / Full incl. publish), and create it. The plaintext token is shown once -- copy it immediately, it cannot be shown again.

### Connecting an agent

The settings page shows your MCP endpoint URL and ready-to-copy snippets for each client. For example, with an endpoint of `https://yourapp.example.com/canvas/mcp`:

**Claude Code**

```bash
claude mcp add --transport http active-canvas https://yourapp.example.com/canvas/mcp --header "Authorization: Bearer <YOUR_TOKEN>"
```

**Codex** (`~/.codex/config.toml`)

```toml
[mcp_servers.active_canvas]
url = "https://yourapp.example.com/canvas/mcp"
bearer_token_env_var = "ACTIVE_CANVAS_TOKEN"
```

Export the token before launching Codex: `export ACTIVE_CANVAS_TOKEN=<YOUR_TOKEN>`.

**OpenCode** (`opencode.json`)

```json
{
  "mcp": {
    "active-canvas": {
      "type": "remote",
      "url": "https://yourapp.example.com/canvas/mcp",
      "headers": { "Authorization": "Bearer <YOUR_TOKEN>" }
    }
  }
}
```

### Scopes

| Scope | Grants |
|---|---|
| `read` | Every read-only tool: list/get pages, versions, page types, partials, media, forms, collections, collection items, settings, AI status. |
| `write` | Adds: create/update/delete pages, page types, collections and collection items **while unpublished**; media upload/delete; form submission delete; `generate_image`. |
| `publish` | Adds: any mutation of an already-published page or collection item (update, update content, delete, restore version, publish/unpublish); `update_partial` (header/footer are live on every page); `update_site_settings`, `recompile_tailwind`; every AI settings tool (`update_ai_settings`, `sync_ai_models`, `set_ai_models_active`, `create_ai_model`, `delete_ai_model`). |

`write` implies `read`; `publish` implies `write`. A token only ever sees the tools its scopes grant.

### Security notes

- Tokens are stored as a SHA-256 digest only -- the plaintext is shown once and never persisted.
- Revoke a token any time from the API tokens tab; access is lost on its next request. Tokens can also carry an optional expiry date.
- Requests are rate limited per token (`config.mcp_rate_limit_per_minute`, default 120/minute).
- Changing already-published content always requires the `publish` scope, even for a token that otherwise has `write`.

### Upgrading

- Run `bin/rails active_canvas:install:migrations && bin/rails db:migrate` before using MCP -- the API tokens table is added by an engine migration, not by upgrading the gem alone.
- A page whose slug is `mcp` is shadowed by the `/canvas/mcp` endpoint (the route is matched first) and will never be reachable at its public URL. Avoid that slug.
- If your host app adds an `inflect.acronym "MCP"` (or `"AI"`) inflection rule in `config/initializers/inflections.rb`, constant loading for `ActiveCanvas::Mcp` (and `ActiveCanvas::Ai*`) will break -- Zeitwerk expects `mcp_controller.rb` to resolve to `McpController`, not `MCPController`. Don't add those acronyms, or open an issue if you need to.

## Authentication

**The admin interface is open by default.** Configure authentication before deploying to production.

### With Devise

```ruby
ActiveCanvas.configure do |config|
  config.authenticate_admin = :authenticate_user!
end
```

### With a custom controller

```ruby
ActiveCanvas.configure do |config|
  config.admin_parent_controller = "Admin::ApplicationController"
end
```

### With HTTP Basic Auth

```ruby
ActiveCanvas.configure do |config|
  config.authenticate_admin = :http_basic_auth
  config.http_basic_user = "admin"
  config.http_basic_password = Rails.application.credentials.active_canvas_password
end
```

### With custom logic

```ruby
ActiveCanvas.configure do |config|
  config.authenticate_admin = -> {
    unless current_user&.admin?
      redirect_to main_app.root_path, alert: "Access denied"
    end
  }
end
```

## Configuration

Full configuration reference:

```ruby
# config/initializers/active_canvas.rb
ActiveCanvas.configure do |config|
  # === Authentication ===
  config.authenticate_admin = :authenticate_user!  # method name, lambda, or :http_basic_auth
  config.authenticate_public = nil                 # nil = public access
  config.current_user_method = :current_user       # for version tracking & AI features

  # === CSS Framework ===
  config.css_framework = :tailwind                 # :tailwind, :bootstrap5, or :none

  # === Media Uploads ===
  config.enable_uploads = true
  config.max_upload_size = 10.megabytes
  config.allow_svg_uploads = false
  config.storage_service = nil                     # Active Storage service name
  config.public_uploads = false                    # false = signed URLs

  # === Editor ===
  config.enable_ai_features = true
  config.enable_code_editor = true
  config.enable_asset_manager = true
  config.autosave_interval = 60                    # seconds (0 = disabled)

  # === Pages ===
  config.max_versions_per_page = 50                # 0 = unlimited

  # === Security ===
  config.sanitize_content = true
  config.ai_rate_limit_per_minute = 30
end
```

## Customization

### Mount path

```ruby
# config/routes.rb
mount ActiveCanvas::Engine => "/pages"   # or "/cms", "/blog", "/"
```

### Override views

Copy any view into your app to customize it:

```
app/views/active_canvas/pages/show.html.erb
app/views/active_canvas/admin/pages/index.html.erb
app/views/layouts/active_canvas/admin/application.html.erb
```

### Extend models

```ruby
ActiveCanvas::Page.class_eval do
  validates :content, presence: true

  def excerpt
    content.to_s.truncate(200)
  end
end
```

## Rake Tasks

```bash
bin/rails active_canvas:sync_models    # Sync AI models from configured providers
bin/rails active_canvas:list_models    # List all synced AI models
```

## Development

```bash
git clone https://github.com/giovapanasiti/active_canvas.git
cd active_canvas
bundle install
bin/rails db:migrate
bin/rails test
```

Start the dummy app:

```bash
bin/rails server
```

Then visit `http://localhost:3000/canvas/admin`.

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes
4. Push to the branch (`git push origin feature/my-feature`)
5. Create a Pull Request

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
