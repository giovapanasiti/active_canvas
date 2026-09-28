module ActiveCanvas
  module Mcp
    module Tools
      module Collections
        class UpdateCollection < BaseTool
          ATTRIBUTES = %i[name slug fields has_pages per_page show_in_sidebar title_field description_field image_field].freeze
          # On a live collection (has_pages with published items) these change
          # public URLs or what the public pages show.
          LIVE_ATTRIBUTES = %i[slug per_page title_field].freeze

          tool_name "update_collection"
          description "Update a collection's name, slug, fields and/or public-pages options (has_pages, per_page, show_in_sidebar, title_field, description_field, image_field). `fields`, when given, replaces the whole array. Flipping `has_pages` requires the 'publish' scope in addition to 'write' when the collection has published items, since it changes what's live on the site; so does changing `slug`, `per_page` or `title_field` of a collection with public pages and published items (its public URLs/pages change)."
          input_schema(
            properties: {
              id: { type: "integer" },
              name: { type: "string" },
              slug: { type: "string" },
              fields: { type: "array", items: { type: "object" } },
              has_pages: { type: "boolean" },
              per_page: { type: "integer" },
              show_in_sidebar: { type: "boolean" },
              title_field: { type: "string" },
              description_field: { type: "string" },
              image_field: { type: "string" }
            },
            required: [ "id" ]
          )
          required_scope :write

          def perform(args)
            collection = ActiveCanvas::Collection.find(args[:id])
            check_has_pages_toggle!(collection, args)
            check_live_changes!(collection, args)

            collection.update!(args.slice(*ATTRIBUTES))
            Serializers.collection(collection)
          end

          private

          # Toggling has_pages either way changes what's live on the site once the
          # collection has published items -- a fresh index/show page appears, or an
          # existing one disappears -- so it needs 'publish' on top of 'write', the
          # same rule delete_collection applies to destroying published items.
          def check_has_pages_toggle!(collection, args)
            return unless args.key?(:has_pages)

            new_value = ActiveModel::Type::Boolean.new.cast(args[:has_pages])
            return if new_value == collection.has_pages?
            return unless collection.items.published.exists?

            require_scope!(:publish, "This collection has published items; toggling has_pages requires the 'publish' scope.")
          end

          def check_live_changes!(collection, args)
            return unless collection.has_pages?

            changed = LIVE_ATTRIBUTES.select do |attribute|
              args.key?(attribute) && live_value(collection, attribute, args) != collection.public_send(attribute)
            end
            return if changed.empty?
            return unless collection.items.published.exists?

            require_scope!(:publish, "This collection has public pages with published items; changing " \
              "#{changed.join(", ")} changes the live site and requires the 'publish' scope.")
          end

          # The value the attribute will have once saved (Collection
          # parameterizes its slug, falling back to the name).
          def live_value(collection, attribute, args)
            case attribute
            when :slug then (args[:slug].presence || args[:name].presence || collection.name).to_s.parameterize
            when :per_page then ActiveModel::Type::Integer.new.cast(args[:per_page])
            else args[attribute].presence
            end
          end
        end
      end
    end
  end
end
