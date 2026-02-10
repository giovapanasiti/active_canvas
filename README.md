# ActiveCanvas

A mountable Rails engine that turns any Rails app into a full-featured CMS. Includes a visual drag-and-drop editor (GrapeJS), AI-powered content generation, Tailwind CSS compilation, media management, page versioning, and SEO controls -- all behind an admin interface that works out of the box.

## Features

- **Visual Editor** -- Drag-and-drop page builder powered by GrapeJS
- **AI Content Generation** -- Text, images, and screenshot-to-code via OpenAI, Anthropic, or OpenRouter
- **Tailwind CSS Compilation** -- Per-page compiled CSS for production (no CDN dependency)
- **Media Library** -- Upload and manage images/files with Active Storage
- **Page Versioning** -- Automatic version history with diffs and rollback
- **Header & Footer Partials** -- Reusable components, togglable per page
- **SEO** -- Meta tags, Open Graph, Twitter Cards, JSON-LD structured data
- **Page Types** -- Categorize pages (blog posts, landing pages, etc.)
- **Authentication** -- Pluggable auth (Devise, custom, or HTTP Basic)
- **Isolated Namespace** -- No conflicts with your host application

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

The GrapeJS editor provides:

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

## Page Versioning

Every content change creates a version automatically. View the version history from the page admin to see:

- What changed (before/after diffs)
- Who made the change
- When it was made
- Content size differences

Configure the maximum versions kept per page (default: 50, set to 0 for unlimited).

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
