Rails.application.routes.draw do
  root "inicio#index"

  get "entrar", to: "sesiones#new", as: :entrar
  post "entrar", to: "sesiones#create"
  delete "salir", to: "sesiones#destroy", as: :salir

  get "inventario", to: "inventario#index", as: :inventario
  get "inventario/kardex", to: "inventario#kardex", as: :kardex_inventario
  get "inventario/movimiento/nuevo", to: "inventario#nuevo_movimiento", as: :nuevo_movimiento_inventario
  post "inventario/movimiento", to: "inventario#crear_movimiento", as: :movimientos_inventario

  resources :etiquetas, only: %i[index new create show] do
    collection do
      get :buscar
      post :cerrar_caja
      post :armar_tarima
    end
    member { post :baja }
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
