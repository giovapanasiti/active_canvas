ActiveCanvas::Engine.routes.draw do
  namespace :admin do
    resources :pages do
      member do
        get :content
        patch :update_content
        get :editor
        patch :save_editor
      end
    end
    resources :page_types
    resources :media, only: [:index, :create, :destroy]
    resource :settings, only: [:show, :update]

    root to: "pages#index"
  end

  root to: "pages#home"
  get ":slug", to: "pages#show", as: :public_page
end
