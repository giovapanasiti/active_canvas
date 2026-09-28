module ActiveCanvas
  module Mcp
    module Tools
      module Pages
        class ListPages < BaseTool
          tool_name "list_pages"
          description "List pages (metadata only, no content). Excludes a collection's template pages by default -- pass collection_id to list that collection's templates instead. Filter by published, page_type_key, or a case-insensitive query matched against title/slug. Each item includes public_url and editor_url; call get_page for full content."
          input_schema(properties: {
            collection_id: { type: "integer" },
            published: { type: "boolean" },
            page_type_key: { type: "string" },
            query: { type: "string" },
            limit: { type: "integer" },
            offset: { type: "integer" }
          })
          annotations(read_only_hint: true)
          required_scope :read

          def perform(args)
            relation = ActiveCanvas::Page.includes(:page_type)
            relation = filter_by_collection(relation, args)
            relation = filter_by_published(relation, args)
            relation = filter_by_page_type(relation, args)
            relation = filter_by_query(relation, args)

            page = paginate(relation.order(:id), args)
            homepage_page_id = ActiveCanvas::Setting.homepage_page_id
            page.merge(items: page[:items].map { |p| Serializers.page_summary(p, homepage_page_id: homepage_page_id) })
          end

          private

          # No collection_id: regular pages only (a collection's template pages are
          # never routed by slug and would otherwise clutter this list -- Page.regular).
          # A collection_id instead lists just that collection's own template pages.
          def filter_by_collection(relation, args)
            return relation.where(collection_id: args[:collection_id]) if args[:collection_id].present?

            relation.regular
          end

          def filter_by_published(relation, args)
            return relation unless args.key?(:published)
            relation.where(published: ActiveModel::Type::Boolean.new.cast(args[:published]))
          end

          def filter_by_page_type(relation, args)
            return relation if args[:page_type_key].blank?
            page_type = ActiveCanvas::PageType.find_by(key: args[:page_type_key])
            page_type ? relation.where(page_type_id: page_type.id) : relation.none
          end

          # `LIKE` is case-insensitive on SQLite but case-sensitive on Postgres/MySQL; Arel's
          # `matches` compiles to each adapter's case-insensitive operator (`ILIKE` on Postgres),
          # so the query behaves the same regardless of the underlying DB.
          def filter_by_query(relation, args)
            return relation if args[:query].blank?
            term = "%#{ActiveRecord::Base.sanitize_sql_like(args[:query])}%"
            table = ActiveCanvas::Page.arel_table
            relation.where(table[:title].matches(term).or(table[:slug].matches(term)))
          end
        end
      end
    end
  end
end
