# ActiveCanvas

A mountable Rails engine that provides a simple CMS for creating and managing static pages. Features an admin interface for content management and public routes for displaying pages.

## Features

- **Page Management**: Create, edit, and delete pages with HTML content
- **Page Types**: Categorize pages (e.g., "Page", "Blog Post", "Landing Page")
- **Slug Support**: Custom slugs or auto-generated ones (`active_canvas_id_#{id}`)
- **Draft/Published Status**: Control page visibility
- **Admin Interface**: Clean, built-in admin UI (no external dependencies)
- **Visual Editor**: Drag-and-drop page builder powered by GrapeJS
- **CSS Framework Support**: Tailwind CSS, Bootstrap 5, or custom CSS
- **Tailwind Compilation**: Compile Tailwind CSS per-page for production (no CDN)
- **Isolated Namespace**: No conflicts with your host application

## Requirements

- Ruby 3.1+
- Rails 8.0+

## Installation

Add ActiveCanvas to your Gemfile:

```ruby
gem "active_canvas"
```

Run the install generator:

```bash
bundle install
bin/rails generate active_canvas:install
bin/rails active_canvas:install:migrations
bin/rails db:migrate
```

This will:
- Create `config/initializers/active_canvas.rb` with configuration options
- Mount the engine at `/canvas` in your routes
- Copy the database migrations

## Usage

### Admin Interface

Access the admin interface at `/canvas/admin` to:

1. **Create Page Types** - Define categories for your pages
2. **Create Pages** - Add new pages with:
   - Title (required)
   - Slug (optional, auto-generated if blank)
   - Content (HTML)
   - Page Type
   - Published status
3. **Configure Settings** - Set the homepage and other options

### Public Pages

Published pages are accessible at `/canvas/:slug`:

```
/canvas/about-us
/canvas/contact
/canvas/active_canvas_id_42  # Auto-generated slug
```

Only published pages are visible. Draft pages return a 404.

### Homepage

Set a homepage in **Settings** to display a specific page when visiting the root URL (`/canvas/`). Only published pages can be set as the homepage.

### Customizing the Mount Path

You can mount the engine at any path:

```ruby
# Pages at /pages/:slug, admin at /pages/admin
mount ActiveCanvas::Engine => "/pages"

# Or at root level
mount ActiveCanvas::Engine => "/"
```

## Models

### ActiveCanvas::Page

```ruby
# Attributes
page.title      # String, required
page.slug       # String, unique, auto-generated if blank
page.content    # Text, HTML content
page.published  # Boolean, default: false

# Associations
page.page_type  # belongs_to

# Scopes
ActiveCanvas::Page.published  # Only published pages
ActiveCanvas::Page.draft      # Only draft pages

# Methods
page.rendered_content  # Returns HTML-safe content
```

### ActiveCanvas::PageType

```ruby
# Attributes
page_type.name  # String, required (e.g., "Blog Post")
page_type.key   # String, unique, auto-generated from name

# Associations
page_type.pages  # has_many

# Class Methods
ActiveCanvas::PageType.default  # Returns or creates the default "Page" type
```

### ActiveCanvas::Setting

```ruby
# Class Methods
ActiveCanvas::Setting.get("key")           # Get a setting value
ActiveCanvas::Setting.set("key", "value")  # Set a setting value
ActiveCanvas::Setting.homepage             # Get the homepage Page object
ActiveCanvas::Setting.homepage_page_id     # Get/set the homepage page ID
```

## Tailwind CSS Compilation

ActiveCanvas can compile Tailwind CSS at runtime, generating optimized per-page stylesheets instead of loading the full Tailwind CDN.

### Setup

1. Add the `tailwindcss-ruby` gem to your Gemfile:

```ruby
gem "tailwindcss-ruby", ">= 4.0"
```

Any 4.x version works - the engine only uses the stable `Tailwindcss::Ruby.executable` API.

2. Run the migration to add compilation columns:

```bash
bin/rails active_canvas:install:migrations
bin/rails db:migrate
```

3. Select "Tailwind CSS" in admin settings (`/canvas/admin/settings`)

### How It Works

- **Editor**: Uses Tailwind CDN for instant live preview while editing
- **On Save**: Compiles only the CSS classes used on that page
- **Public Pages**: Serves compiled CSS inline (no CDN dependency)

When you save a page, the compiled CSS is stored in the database. Public pages load this compiled CSS instead of the 300KB+ Tailwind CDN script, resulting in faster page loads.

### Graceful Degradation

If `tailwindcss-ruby` is not installed, ActiveCanvas falls back to CDN loading automatically.

See [docs/tailwind_compilation.md](docs/tailwind_compilation.md) for detailed documentation.

## Authentication

**Important:** The admin interface is open by default. Configure authentication in your initializer.

### With Devise

```ruby
# config/initializers/active_canvas.rb
ActiveCanvas.configure do |config|
  config.authenticate_admin = :authenticate_user!
end
```

### With Custom Logic

```ruby
# config/initializers/active_canvas.rb
ActiveCanvas.configure do |config|
  config.authenticate_admin = -> {
    unless current_user&.admin?
      redirect_to main_app.root_path, alert: "Access denied"
    end
  }
end
```

### Configuration Options

```ruby
ActiveCanvas.configure do |config|
  # Authentication for admin pages (required for production!)
  config.authenticate_admin = :authenticate_user!

  # Authentication for public pages (optional, nil = public access)
  config.authenticate_public = nil

  # Current user method name (for AI features, etc.)
  config.current_user_method = :current_user
end
```

## Customization

### Custom Layouts

Override the admin layout by creating:

```
app/views/layouts/active_canvas/admin/application.html.erb
```

### Custom Views

Override any view by copying it to your app:

```
app/views/active_canvas/admin/pages/index.html.erb
app/views/active_canvas/pages/show.html.erb
```

### Extending Models

```ruby
# config/initializers/active_canvas.rb
ActiveCanvas::Page.class_eval do
  validates :content, presence: true

  def excerpt
    content.to_s.truncate(200)
  end
end
```

## Routes

```
# Admin Routes
GET    /canvas/admin                    # Admin root (pages list)
GET    /canvas/admin/pages              # List pages
POST   /canvas/admin/pages              # Create page
GET    /canvas/admin/pages/new          # New page form
GET    /canvas/admin/pages/:id          # Show page
GET    /canvas/admin/pages/:id/edit     # Edit page form
PATCH  /canvas/admin/pages/:id          # Update page
DELETE /canvas/admin/pages/:id          # Delete page

GET    /canvas/admin/page_types         # List page types
POST   /canvas/admin/page_types         # Create page type
GET    /canvas/admin/page_types/new     # New page type form
GET    /canvas/admin/page_types/:id     # Show page type
GET    /canvas/admin/page_types/:id/edit# Edit page type form
PATCH  /canvas/admin/page_types/:id     # Update page type
DELETE /canvas/admin/page_types/:id     # Delete page type

GET    /canvas/admin/settings           # Settings page
PATCH  /canvas/admin/settings           # Update settings

# Public Routes
GET    /canvas/                         # Homepage (configured page)
GET    /canvas/:slug                    # View published page
```

## Documentation

Additional documentation is available in the `docs/` directory:

- [CSS Framework Support](docs/css_framework_support.md) - Tailwind, Bootstrap, and custom CSS setup
- [Tailwind Compilation](docs/tailwind_compilation.md) - Runtime Tailwind CSS compilation
- [Editor Panels Guide](docs/editor_panels_guide.md) - GrapeJS editor customization

## Development

Clone the repository and run:

```bash
bundle install
bin/rails db:migrate
bin/rails test
```

Start the dummy app:

```bash
bin/rails server
```

Visit:
- http://localhost:3000/canvas/admin - Admin interface
- http://localhost:3000/canvas/:slug - Public pages

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -am 'Add my feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Create a Pull Request

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
