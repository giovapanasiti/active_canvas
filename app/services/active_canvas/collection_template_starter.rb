module ActiveCanvas
  # Starter HTML for a collection's two template pages (Part 4 "Model"),
  # generated once by `Collection#ensure_templates!`. Uses only the implicit
  # assign names (`item`/`items`/`collection`/`pagination`, see
  # CollectionPageContext) so it renders correctly the moment public pages are
  # turned on, and is built to pass strict `TemplateValidation` against those
  # implicit values. Authors reshape it afterwards in the GrapesJS editor like
  # any other page; this is only the seed.
  class CollectionTemplateStarter
    def self.html_for(collection, role)
      new(collection).html_for(role)
    end

    def initialize(collection)
      @collection = collection
    end

    def html_for(role)
      case role.to_s
      when "index" then index_html
      when "show"  then show_html
      else raise ArgumentError, "unknown template role #{role.inspect}"
      end
    end

    private

    def index_html
      <<~HTML
        <section class="ac-collection-index">
          <h1>{{ collection.name }}</h1>
          <div class="ac-collection-grid">
            <article class="ac-collection-card" data-ac-for="entry in items">
              <a href="{{ entry.url }}">{{ entry.seo.title }}</a>
            </article>
          </div>
          <p data-ac-if="pagination.total_items == 0">No items yet.</p>
          <nav class="ac-pagination">
            <a class="ac-pagination-prev" data-ac-if="pagination.prev_url" href="{{ pagination.prev_url }}">Previous</a>
            <a class="ac-pagination-next" data-ac-if="pagination.next_url" href="{{ pagination.next_url }}">Next</a>
          </nav>
        </section>
      HTML
    end

    def show_html
      <<~HTML
        <article class="ac-collection-show">
          <h1>{{ item.#{title_field_id} }}</h1>
          #{field_blocks}
          <p><a href="{{ collection.url }}">Back to {{ collection.name }}</a></p>
        </article>
      HTML
    end

    def title_field_id
      @collection.title_field.presence || "slug"
    end

    def field_blocks
      Array(@collection.fields).map { |field| field_block(field) }.join("\n  ")
    end

    def field_block(field)
      id = field["id"] || field[:id]
      type = field["type"] || field[:type]
      case type.to_s
      when "media"     then %(<img src="{{ item.#{id} }}" alt="">)
      when "rich_text" then %(<div>{{ item.#{id} }}</div>)
      else %(<p>{{ item.#{id} }}</p>)
      end
    end
  end
end
