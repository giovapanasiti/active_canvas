Rails.application.routes.draw do
  # Host-app route used only to prove ActiveCanvas does not turn the host's own
  # native ActionText/Trix usage into Lexxy (see admin_collection_items_lexxy_test.rb).
  get "host/rich_text_form", to: "host_forms#show"

  mount ActiveCanvas::Engine => "/canvas"
end
