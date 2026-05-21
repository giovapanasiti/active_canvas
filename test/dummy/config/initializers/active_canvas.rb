Rails.application.config.after_initialize do
  ActiveCanvas::DataSources.register(:latest_articles) do
    param :limit,    type: :integer, default: 5,  range: 1..50
    param :category, type: :string,  default: nil, allowed: %w[news blog tutorials]

    fetch do |limit:, category:|
      scope = Article.published.order(created_at: :desc)
      scope = scope.where(category: category) if category
      scope.limit(limit)
    end

    auto_drop attributes: %i[id title slug excerpt published_at]
  end
end
