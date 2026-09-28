module ActiveCanvas
  # Editor integration for a collection's template pages (Part 4 "Editor").
  # Two things an editor needs, both derived from the same implicit assigns
  # (CollectionPageContext) a template page renders with in public:
  #
  # - `live(page)`: the actual context to merge into a Liquid render (via
  #   TemplateRenderer's `context:`), so the editor's validate/chip-values/
  #   preview endpoints resolve `{{ item.x }}` / `{{ entry.x }}` /
  #   `{{ pagination.x }}` the same way the public page eventually will.
  #   "Live data" (Part 4 "Editor"): show uses the first published item, else
  #   the first item's draft data; index always previews page 1.
  # - `schema(page)`: the field ids available under each implicit name, with
  #   no data lookup, so the Data panel can list them read-only and offer
  #   chips before any item exists.
  #
  # A regular (non-template) page has neither: both return {}.
  class TemplateEditorContext
    COLLECTION_FIELD_IDS = %w[name slug url].freeze
    PAGINATION_FIELD_IDS = %w[page per_page total_pages total_items prev_url next_url].freeze
    ITEM_BASE_FIELD_IDS = %w[id slug published_at].freeze
    ITEM_EXTRA_FIELD_IDS = %w[url seo].freeze
    # The loop variable name the starter design (CollectionTemplateStarter)
    # uses for `items`; the Data panel suggests the same name in its chips.
    ITEMS_LOOP_VARIABLE = "entry".freeze

    def self.live(page)
      new(page).live
    end

    def self.schema(page)
      new(page).schema
    end

    def initialize(page)
      @page = page
    end

    def live
      return {} unless @page.template?

      case @page.collection_role
      when "show"  then live_show
      when "index" then ActiveCanvas::CollectionPageContext.index(@page.collection, page: 1)
      else {}
      end
    end

    def schema
      return {} unless @page.template?

      case @page.collection_role
      when "show"  then show_schema
      when "index" then index_schema
      else {}
      end
    end

    private

    # No items yet is still a valid state to design/validate a show template
    # in: an unsaved item (blank fields, nil slug) keeps `{{ item.x }}` and
    # `item.url`/`item.seo` resolvable instead of raising "undefined
    # variable" in strict (preview) mode.
    def live_show
      collection = @page.collection
      item = collection.items.published.first || collection.items.first || ActiveCanvas::CollectionItem.new(collection: collection)
      data = item.persisted? && item.status == "published" ? :published : :draft
      ActiveCanvas::CollectionPageContext.show(item, data: data)
    end

    def show_schema
      { "item" => { "fields" => item_field_specs }, "collection" => { "fields" => collection_field_specs } }
    end

    def index_schema
      {
        "items" => { "item_name" => ITEMS_LOOP_VARIABLE, "fields" => item_field_specs },
        "collection" => { "fields" => collection_field_specs },
        "pagination" => { "fields" => field_specs(PAGINATION_FIELD_IDS) }
      }
    end

    def item_field_specs
      defs = collection_field_defs
      field_ids = defs.map { |f| f["id"] }
      field_specs(ITEM_BASE_FIELD_IDS) + defs + field_specs(ITEM_EXTRA_FIELD_IDS - field_ids)
    end

    def collection_field_specs
      field_specs(COLLECTION_FIELD_IDS)
    end

    def collection_field_defs
      Array(@page.collection.fields).map { |f| { "id" => f["id"], "label" => f["label"], "type" => f["type"] } }
    end

    def field_specs(ids)
      ids.map { |id| { "id" => id, "label" => id.humanize } }
    end
  end
end
