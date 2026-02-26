Kazhat::Engine.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :conversations, only: [:index, :create, :show] do
        resources :messages, only: [:index, :create] do
          post :read, on: :collection, action: :mark_as_read
        end
      end

      resources :calls, only: [:index, :show, :create] do
        get :stats, on: :collection
      end
    end
  end

  resources :conversations, only: [:index, :show]
  resources :calls, only: [:index, :show]

  root to: "conversations#index"
end
