module ActiveCanvas
  module Mcp
    module Tools
      module Pages
        class CreatePage < BaseTool
          METADATA_KEYS = %i[
            title slug show_header show_footer
            meta_title meta_description canonical_url meta_robots
            og_title og_description og_image
            twitter_card twitter_title twitter_description twitter_image
            structured_data
          ].freeze
          CONTENT_KEYS = %i[content content_css content_js template_enabled bindings].freeze

          tool_name "create_page"
          description "Create a page. Always created unpublished (there is no `published` argument here; use set_page_published to publish it). content/content_css/content_js are HTML; setting template_enabled makes content Liquid, validated when content is given. Defaults to PageType.default when page_type_key is omitted."
          input_schema(
            properties: {
              title: { type: "string" },
              slug: { type: "string" },
              page_type_key: { type: "string" },
              content: { type: "string" },
              content_css: { type: "string" },
              content_js: { type: "string" },
              template_enabled: { type: "boolean" },
              bindings: {},
              show_header: { type: "boolean" },
              show_footer: { type: "boolean" },
              meta_title: { type: "string" },
              meta_description: { type: "string" },
              canonical_url: { type: "string" },
              meta_robots: { type: "string" },
              og_title: { type: "string" },
              og_description: { type: "string" },
              og_image: { type: "string" },
              twitter_card: { type: "string" },
              twitter_title: { type: "string" },
              twitter_description: { type: "string" },
              twitter_image: { type: "string" },
              structured_data: { type: "string" }
            },
            required: [ "title" ]
          )
          required_scope :write

          def perform(args)
            page_type = resolve_page_type(args[:page_type_key])

            ActiveCanvas::Page.transaction do
              page = ActiveCanvas::Page.create!(args.slice(*METADATA_KEYS).merge(page_type: page_type, published: false))

              if CONTENT_KEYS.any? { |key| args.key?(key) }
                result = ActiveCanvas::PageContentUpdate.call(page, args.slice(*CONTENT_KEYS))
                fail!(content_update_error(result)) unless result.success?
              end

              Serializers.page(page.reload)
            end
          end

          private

          def resolve_page_type(key)
            return ActiveCanvas::PageType.default if key.blank?
            ActiveCanvas::PageType.find_by(key: key) || fail!("Page type '#{key}' not found")
          end
        end
      end
    end
  end
end
