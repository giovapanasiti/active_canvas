module ActiveCanvas
  module Mcp
    module Tools
      module Pages
        class UpdatePage < BaseTool
          METADATA_KEYS = %i[
            title slug show_header show_footer
            meta_title meta_description canonical_url meta_robots
            og_title og_description og_image
            twitter_card twitter_title twitter_description twitter_image
            structured_data
          ].freeze

          tool_name "update_page"
          description "Update a page's metadata and SEO fields (not content; use update_page_content for that). Requires the 'publish' scope in addition to 'write' when the page is currently published. Changing slug on a published page creates a redirect from the old slug."
          input_schema(
            properties: {
              id: { type: "integer" },
              title: { type: "string" },
              slug: { type: "string" },
              page_type_key: { type: "string" },
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
            required: [ "id" ]
          )
          required_scope :write

          def perform(args)
            page = ActiveCanvas::Page.find(args[:id])
            require_publish_if_published!(page, "page")

            attrs = args.slice(*METADATA_KEYS)
            if args.key?(:page_type_key)
              page_type = ActiveCanvas::PageType.find_by(key: args[:page_type_key])
              fail!("Page type '#{args[:page_type_key]}' not found") unless page_type
              attrs[:page_type_id] = page_type.id
            end

            page.update!(attrs)
            Serializers.page(page)
          end
        end
      end
    end
  end
end
