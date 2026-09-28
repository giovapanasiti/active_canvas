module ActiveCanvas
  # Applies SEO settings changes: site name/title template, default meta
  # description, favicon + default OG image (Media references), verification
  # tags, robots.txt override, and the sitemap toggle. Used by
  # Admin::SettingsController#update_seo and the `update_site_settings` MCP
  # tool (publish scope), so both go through the same validation.
  #
  # `params` only needs #key? and #[]; an ActionController::Parameters or a
  # plain Hash both work. Every field is optional and applied only when its
  # key is present, so a partial MCP update never clobbers the rest.
  class SeoSettingsUpdate
    KEYS = %i[
      seo_site_name seo_title_template seo_default_meta_description
      seo_favicon_media_id seo_default_og_image_media_id
      seo_google_site_verification seo_bing_site_verification
      seo_robots_txt seo_sitemap_enabled
    ].freeze

    MEDIA_KEYS = %i[seo_favicon_media_id seo_default_og_image_media_id].freeze

    def self.call(params)
      new(params).call
    end

    def initialize(params)
      @params = params
    end

    def call
      validate_media_ids!
      KEYS.each { |key| Setting.public_send("#{key}=", @params[key]) if @params.key?(key) }

      true
    end

    private

    # Raises ActiveRecord::RecordNotFound (caller-visible as "Media <id> not
    # found") when a given media id doesn't reference an existing Media row.
    # A blank value (clearing the favicon/OG image) is always allowed.
    def validate_media_ids!
      MEDIA_KEYS.each do |key|
        next unless @params.key?(key)

        value = @params[key]
        Media.find(value) if value.present?
      end
    end
  end
end
