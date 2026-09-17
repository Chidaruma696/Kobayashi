Rails.application.routes.draw do
  root "inicio#index"

  get "entrar", to: "sesiones#new", as: :entrar
  post "entrar", to: "sesiones#create"
  delete "salir", to: "sesiones#destroy", as: :salir

  get "up" => "rails/health#show", as: :rails_health_check
end
