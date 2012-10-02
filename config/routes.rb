OmniAuthDemo::Application.routes.draw do

  resources :identities

  get "sessions/new"
  get "sessions/create"
  get "sessions/destroy"
  get "sessions/failure"

  match '/auth/:provider/callback', :to => 'sessions#create'
  match '/auth/failure', :to => 'sessions#failure'
  match '/logout', :to => 'sessions#destroy', :as => 'logout'

  root :to => 'sessions#new'

end
