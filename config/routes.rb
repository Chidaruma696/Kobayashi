Rails.application.routes.draw do
  root "inicio#index"
  get "ventas-por-producto", to: "inicio#ventas", as: :ventas_por_producto
  resources :revisiones, only: %i[index] do
    member { post :resolver }
  end

  get "entrar", to: "sesiones#new", as: :entrar
  post "entrar", to: "sesiones#create"
  delete "salir", to: "sesiones#destroy", as: :salir

  scope "caja", controller: "caja", as: "caja" do
    get "/", action: :index
    get "escanear", action: :escanear
    post "cobrar", action: :cobrar
    get "ventas", action: :ventas
    get "ventas/:id/ticket", action: :ticket, as: :ticket
    get "corte", action: :corte
    post "corte/abrir", action: :abrir, as: :abrir
    post "corte/cerrar", action: :cerrar, as: :cerrar
    post "corte/retirar", action: :retirar, as: :retirar
    get "devolucion", action: :devolucion
    post "devolucion", action: :devolver, as: :devolver
  end

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

  resources :salidas, only: %i[index new create show] do
    collection { get :recibir, action: :por_recibir }
    member do
      post :agregar
      post :quitar
      post :manual
      post :verificar
      post :sellar
      post :enviar
      post :recibir_etiqueta
      post :reportar
      post :cerrar_recepcion
      post :cobrar_entrega
      post :cancelar
    end
  end

  resources :conteos, only: %i[index new create show] do
    member do
      post :escanear
      post :manual
      post :cerrar
    end
  end
  resources :cargos, only: %i[index] do
    member { post :resolver }
  end

  resources :producciones, only: %i[index new create show] do
    member { post :cerrar }
  end

  resources :etiquetas, only: %i[index new create show] do
    collection do
      get :buscar
      get :productos
      get :imprimir
      post :lote
      post :cerrar_caja
      post :armar_tarima
    end
    member { post :baja }
  end

  namespace :admin do
    resources :productos, except: %i[show destroy] do
      resources :codigos, only: %i[create destroy], controller: "codigos_barras"
    end
    resources :promociones, except: %i[show]
    resources :clientes, except: %i[show destroy]
    resources :rutas, except: %i[show destroy]
    resources :usuarios, except: %i[show destroy]
    resources :roles, except: %i[show destroy]
    resources :sucursales, except: %i[show destroy]
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
