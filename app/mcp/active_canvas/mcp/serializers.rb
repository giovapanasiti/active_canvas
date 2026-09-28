module ActiveCanvas
  module Mcp
    # Converts ActiveCanvas records to plain Hashes for MCP tool responses.
    # Every method here is a module function; later tasks add one method per
    # domain (page, collection, media, ...).
    module Serializers
      module_function

      # `pages_count:` lets a list caller preload every row's count in one query
      # (`left_joins`/`group`/count or a `group(:page_type_id).count` Hash) instead of
      # `pt.pages.count` firing once per row; omitted, it falls back to the per-record query.
      def page_type(pt, pages_count: nil)
        {
          id: pt.id,
          name: pt.name,
          key: pt.key,
          pages_count: pages_count.nil? ? pt.pages.count : pages_count,
          created_at: pt.created_at,
          updated_at: pt.updated_at
        }
      end

      # `homepage_page_id:` lets a list caller fetch `Setting.homepage_page_id` once and pass
      # it to every row instead of each row re-reading it; omitted, it falls back to reading
      # the setting itself (still a single query per request - `Setting.get` is
      # request-memoized via `Current.settings_cache` - but naming it explicitly here keeps a
      # list of N pages from making N method calls into `Setting`).
      def page_summary(page, homepage_page_id: nil)
        url_helpers = ActiveCanvas::Engine.routes.url_helpers
        homepage_page_id = ActiveCanvas::Setting.homepage_page_id if homepage_page_id.nil?
        {
          id: page.id,
          title: page.title,
          slug: page.slug,
          published: page.published,
          template_enabled: page.template_enabled,
          page_type_key: page.page_type.key,
          show_header: page.show_header?,
          show_footer: page.show_footer?,
          updated_at: page.updated_at,
          current_version_number: page.current_version_number,
          is_homepage: homepage_page_id == page.id,
          public_url: page.slug.present? ? url_helpers.public_page_path(page.slug, only_path: true) : nil,
          editor_url: url_helpers.editor_admin_page_path(page.id, only_path: true)
        }
      end

      def page(page)
        page_summary(page).merge(
          meta_title: page.meta_title,
          meta_description: page.meta_description,
          canonical_url: page.canonical_url,
          meta_robots: page.meta_robots,
          og_title: page.og_title,
          og_description: page.og_description,
          og_image: page.og_image,
          twitter_card: page.twitter_card,
          twitter_title: page.twitter_title,
          twitter_description: page.twitter_description,
          twitter_image: page.twitter_image,
          structured_data: page.structured_data,
          content: page.content,
          content_css: page.content_css,
          content_js: page.content_js,
          bindings: page.bindings
        )
      end

      def page_version_summary(version)
        {
          version_number: version.version_number,
          changed_by: version.changed_by,
          change_summary: version.change_summary,
          created_at: version.created_at,
          content_size_before: version.content_size_before,
          content_size_after: version.content_size_after
        }
      end

      def page_version(version)
        page_version_summary(version).merge(
          content_before: version.content_before,
          content_after: version.content_after,
          css_before: version.css_before,
          css_after: version.css_after,
          bindings_before: version.bindings_before,
          bindings_after: version.bindings_after,
          content_diff: version.content_diff
        )
      end

      def form_submission(submission)
        {
          id: submission.id,
          page_id: submission.page_id,
          page_title: submission.page.title,
          form_key: submission.form_key,
          data: submission.data,
          ip: submission.ip,
          user_agent: submission.user_agent,
          created_at: submission.created_at
        }
      end

      # `items_count:` lets a list caller preload every row's count in one query
      # (`group(:collection_id).count` Hash) instead of `c.items.count` firing once per row;
      # omitted, it falls back to the per-record query.
      def collection(c, items_count: nil)
        {
          id: c.id,
          name: c.name,
          slug: c.slug,
          fields: c.fields,
          items_count: items_count.nil? ? c.items.count : items_count,
          created_at: c.created_at,
          updated_at: c.updated_at
        }
      end

      # First 4 schema fields' values from effective_data, keyed by field id.
      def collection_item_summary(item)
        leading_ids = item.collection.fields.first(4).map { |f| f["id"] }
        {
          id: item.id,
          slug: item.slug,
          status: item.status,
          published_at: item.published_at,
          pending_changes: item.pending_changes?,
          fields: item.effective_data.slice(*leading_ids)
        }
      end

      def collection_item(item)
        {
          id: item.id,
          collection_id: item.collection_id,
          slug: item.slug,
          status: item.status,
          published_at: item.published_at,
          pending_changes: item.pending_changes?,
          data: item.data,
          draft_data: item.draft_data,
          created_at: item.created_at,
          updated_at: item.updated_at
        }
      end

      def collection_item_version(version)
        {
          version_number: version.version_number,
          changed_by: version.changed_by,
          change_summary: version.change_summary,
          data: version.data,
          created_at: version.created_at
        }
      end

      def site_settings
        {
          homepage_page_id: ActiveCanvas::Setting.homepage_page_id,
          css_framework: ActiveCanvas::Setting.css_framework,
          global_css: ActiveCanvas::Setting.global_css,
          global_js: ActiveCanvas::Setting.global_js,
          custom_head_html: ActiveCanvas::Setting.custom_head_html,
          tailwind_config: ActiveCanvas::Setting.tailwind_config,
          tailwind_available: ActiveCanvas::TailwindCompiler.available?
        }
      end

      # Media ids plus their resolved URLs (nil when unset or the Media row was
      # deleted), so a caller never has to make a second `get_media` round trip
      # just to show/link the current favicon or default OG image.
      def seo_settings
        {
          site_name: ActiveCanvas::Setting.seo_site_name,
          title_template: ActiveCanvas::Setting.seo_title_template,
          default_meta_description: ActiveCanvas::Setting.seo_default_meta_description,
          favicon_media_id: ActiveCanvas::Setting.seo_favicon_media_id,
          favicon_url: ActiveCanvas::Seo.favicon_url,
          default_og_image_media_id: ActiveCanvas::Setting.seo_default_og_image_media_id,
          default_og_image_url: ActiveCanvas::Seo.default_og_image_url,
          google_site_verification: ActiveCanvas::Setting.seo_google_site_verification,
          bing_site_verification: ActiveCanvas::Setting.seo_bing_site_verification,
          robots_txt: ActiveCanvas::Setting.seo_robots_txt,
          sitemap_enabled: ActiveCanvas::Setting.seo_sitemap_enabled?
        }
      end

      # API keys are always masked (last 4 chars only, via Setting.masked_api_key);
      # the full key is never included in a tool response.
      def ai_settings
        {
          openai_api_key: ActiveCanvas::Setting.masked_api_key("ai_openai_api_key"),
          anthropic_api_key: ActiveCanvas::Setting.masked_api_key("ai_anthropic_api_key"),
          openrouter_api_key: ActiveCanvas::Setting.masked_api_key("ai_openrouter_api_key"),
          openai_configured: ActiveCanvas::Setting.api_key_configured?("ai_openai_api_key"),
          anthropic_configured: ActiveCanvas::Setting.api_key_configured?("ai_anthropic_api_key"),
          openrouter_configured: ActiveCanvas::Setting.api_key_configured?("ai_openrouter_api_key"),
          default_text_model: ActiveCanvas::Setting.ai_default_text_model,
          default_image_model: ActiveCanvas::Setting.ai_default_image_model,
          default_vision_model: ActiveCanvas::Setting.ai_default_vision_model,
          connection_mode: ActiveCanvas::Setting.ai_connection_mode,
          text_enabled: ActiveCanvas::Setting.ai_text_enabled?,
          image_enabled: ActiveCanvas::Setting.ai_image_enabled?,
          screenshot_enabled: ActiveCanvas::Setting.ai_screenshot_enabled?
        }
      end

      def partial(p)
        {
          id: p.id,
          name: p.name,
          partial_type: p.partial_type,
          active: p.active,
          content: p.content,
          content_css: p.content_css,
          content_js: p.content_js,
          content_components: p.content_components,
          compiled_css: p.compiled_css,
          created_at: p.created_at,
          updated_at: p.updated_at
        }
      end

      # media.as_json_for_editor already computes `src` from `media.url`, which
      # can raise outside a request context (no host for the blob URL helpers).
      # Never let that turn a tool call into a 500: fall back to "" for src.
      def media(m)
        base =
          begin
            m.as_json_for_editor
          rescue StandardError
            { id: m.id, src: "", name: m.filename, type: m.content_type, width: m.metadata["width"], height: m.metadata["height"] }
          end
        src = base[:src].to_s

        base.merge(
          src: src,
          url: src,
          filename: base[:name],
          byte_size: m.byte_size,
          content_type: m.content_type,
          created_at: m.created_at,
          html_snippet: %(<img src="#{ERB::Util.h(src)}" data-ac-media-id="#{m.id}" alt="">)
        )
      end
    end
  end
end
