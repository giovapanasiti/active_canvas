module ActiveCanvas
  # Every binding source the editor's Data panel (and the `list_data_sources`
  # MCP tool) can offer: the literal pseudo-source first, then registered
  # ActiveCanvas::DataSources, then collections with their fields.
  class DataSourceCatalog
    LITERAL = {
      name: "_literal", kind: "literal", label: "Literal", item_name: "item", list: false,
      params: { value: { type: :string, default: nil, range: nil, allowed: nil } }
    }.freeze

    def self.call
      [ LITERAL ] + registered_sources + collections
    end

    def self.registered_sources
      ActiveCanvas::DataSources.registered_names.map do |name|
        source = ActiveCanvas::DataSources.lookup(name)
        {
          name: name, kind: "source", label: name.to_s.humanize,
          item_name: ActiveCanvas::DataSources.item_name(name), list: source.list?,
          params: source.param_schema
        }
      end
    end
    private_class_method :registered_sources

    def self.collections
      ActiveCanvas::Collection.order(:name).map do |collection|
        {
          name: collection.slug, kind: "collection", label: collection.name,
          item_name: collection.item_name, list: true,
          fields: collection.fields.map { |f| f.slice("id", "label", "type", "options") },
          params: collection.param_schema
        }
      end
    end
    private_class_method :collections
  end
end
