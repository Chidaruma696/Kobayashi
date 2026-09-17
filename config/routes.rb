Rails.application.routes.draw do
  root "inicio#index"

  get "entrar", to: "sesiones#new", as: :entrar
  post "entrar", to: "sesiones#create"
  delete "salir", to: "sesiones#destroy", as: :salir

  get "inventario", to: "inventario#index", as: :inventario
  get "inventario/kardex", to: "inventario#kardex", as: :kardex_inventario
  get "inventario/movimiento/nuevo", to: "inventario#nuevo_movimiento", as: :nuevo_movimiento_inventario
  post "inventario/movimiento", to: "inventario#crear_movimiento", as: :movimientos_inventario

  resources :pedidos, only: %i[index new create show] do
    member { post :cancelar }
    resources :lineas, only: [], controller: "pedido_lineas" do
      member do
        post :surtido
        post :no_surtir
        post :reabrir
      end
    end
  end

  resources :producciones, only: %i[index new create show] do
    member { post :cerrar }
  end

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
