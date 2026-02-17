ActiveCanvas::Engine.routes.draw do
  namespace :admin do
    resources :pages do
      member do
        get :content
        patch :update_content
        get :editor
        patch :save_editor
        get :versions
      end
      resources :versions, only: [:show], controller: "page_versions"
    end
    resources :page_types
    resources :partials, only: [:index, :edit, :update] do
      member do
        get :editor
        patch :save_editor
      end
    end
    resources :media, only: [:index, :show, :create, :destroy]
    resource :settings, only: [:show, :update] do
      patch :update_global_css
      patch :update_global_js
      patch :update_ai
      post :sync_ai_models
      patch :toggle_ai_model
      patch :bulk_toggle_ai_models
      post :create_ai_model
      delete :destroy_ai_model
      patch :update_tailwind_config
      post :recompile_tailwind
    end

    namespace :ai do
      post :chat
      post :image
      post :screenshot_to_code
      get :models
      get :status
    end

    root to: "pages#index"
  end

  root to: "pages#home"
  get ":slug", to: "pages#show", as: :public_page,
    constraints: ->(req) { ActiveCanvas::Page.published.exists?(slug: req.params[:slug]) }
end
