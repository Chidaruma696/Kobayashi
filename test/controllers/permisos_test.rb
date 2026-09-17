require "test_helper"

class PermisosTest < ActionDispatch::IntegrationTest
  # Una acción protegida de mentira para probar autorizar! sin depender de un módulo real.
  class PruebaController < ApplicationController
    def index
      autorizar!("admin.usuarios")
      render plain: "ok"
    end
  end

  setup do
    Rails.application.routes.draw do
      get "prueba", to: "permisos_test/prueba#index"
      get "entrar", to: "sesiones#new", as: :entrar
      post "entrar", to: "sesiones#create"
      delete "salir", to: "sesiones#destroy", as: :salir
      root "inicio#index"
    end
  end

  teardown { Rails.application.reload_routes! }

  test "sin el permiso responde 403 con la clave" do
    post "/entrar", params: { usuario: "cajera", password: "secreto1" }
    get "/prueba"
    assert_response :forbidden
    assert_match "admin.usuarios", response.body
  end

  test "con el permiso pasa" do
    post "/entrar", params: { usuario: "admin", password: "secreto1" }
    get "/prueba"
    assert_response :ok
  end
end
