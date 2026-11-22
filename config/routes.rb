Rails.application.routes.draw do
  devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks" }

  root "home#index"

  get "search", to: "search#index"
  patch "preferences", to: "preferences#update"

  resources :tags, only: :index
  resources :users, only: :show do
    get :autocomplete, on: :collection
  end

  resources :inventories, only: %i[show create] do
    delete :bulk_destroy, on: :collection
    member do
      patch :autosave
      post :custom_id_preview
      get :export
    end

    resources :items, only: %i[new create show update] do
      delete :bulk_destroy, on: :collection
      resource :like, only: %i[create destroy]
    end
    resources :posts, only: %i[index create]
    resources :accesses, only: :create do
      delete :bulk_destroy, on: :collection
    end
  end

  namespace :admin do
    resources :users, only: :index do
      patch :bulk, on: :collection
    end
  end

  get "up", to: proc { [200, { "content-type" => "text/plain" }, ["ok"]] }
end
