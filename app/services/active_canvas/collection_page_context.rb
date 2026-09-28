module ActiveCanvas
  # Builds the implicit Liquid assigns for a collection's template pages
  # (Part 4 "Implicit assigns"): the reserved `item`/`collection` names for a
  # show page, and `items`/`collection`/`pagination` for an index page.
  # Callers merge the result into `TemplateRenderer.new(page, context: ...)`,
  # where it wins over any binding the page's author added under the same
  # name. Shared by the public show/index actions, the draft preview and the
  # editor's live-data view (Tasks 4/5).
  class CollectionPageContext
    class PageOutOfRange < StandardError; end

    def self.show(item, data: :published)
      new(item.collection).show(item, data: data)
    end

    def self.index(collection, page: 1)
      new(collection).index(page: page)
    end

    def initialize(collection)
      @collection = collection
      @source = CollectionSource.new(collection)
    end

    def show(item, data: :published)
      {
        "item" => @source.row_for(item, data: data),
        "collection" => collection_hash
      }
    end

    def index(page: 1)
      per_page = clamped_per_page
      total_items = @collection.items.published.count
      total_pages = total_items.zero? ? 1 : (total_items.to_f / per_page).ceil
      page_number = page.to_i

      raise PageOutOfRange if page_number < 1 || page_number > total_pages

      items = @collection.items.published
        .order(published_at: :desc, id: :desc)
        .offset((page_number - 1) * per_page)
        .limit(per_page)
        .to_a

      {
        "items" => @source.rows_for(items, data: :published),
        "collection" => collection_hash,
        "pagination" => {
          "page" => page_number,
          "per_page" => per_page,
          "total_pages" => total_pages,
          "total_items" => total_items,
          "prev_url" => prev_url(page_number),
          "next_url" => next_url(page_number, total_pages)
        }
      }
    end

    private

    def clamped_per_page
      per_page = @collection.per_page.to_i
      per_page.positive? ? per_page : 1
    end

    def collection_hash
      {
        "name" => escape(@collection.name),
        "slug" => escape(@collection.slug),
        "url" => escape(@source.index_url)
      }
    end

    def prev_url(page_number)
      return nil if page_number <= 1

      page_url(page_number - 1)
    end

    def next_url(page_number, total_pages)
      return nil if page_number >= total_pages

      page_url(page_number + 1)
    end

    def page_url(number)
      escape(number <= 1 ? @source.index_url : "#{@source.index_url}?page=#{number}")
    end

    def escape(value)
      ERB::Util.html_escape(value.to_s)
    end
  end
end
