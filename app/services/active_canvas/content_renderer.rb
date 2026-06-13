module ActiveCanvas
  # Resolves persisted media references (<img data-ac-media-id="N">) to fresh
  # URLs at render time. We persist a stable id, never a time-limited URL, so
  # saved content never rots.
  class ContentRenderer
    def self.resolve(html)
      return html if html.blank?

      fragment = Nokogiri::HTML5.fragment(html)
      nodes = fragment.css("img[data-ac-media-id]")
      return html if nodes.empty?

      ids = nodes.map { |n| n["data-ac-media-id"] }.uniq
      media_by_id = Media.where(id: ids)
                         .includes(file_attachment: :blob)
                         .index_by { |m| m.id.to_s }

      nodes.each do |node|
        media = media_by_id[node["data-ac-media-id"].to_s]
        fresh_url = media&.url
        node["src"] = fresh_url if fresh_url # unknown id or orphaned media: leave the node as-is
      end

      fragment.to_html
    end
  end
end
