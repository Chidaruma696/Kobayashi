require "test_helper"

class PermisosTest < ActionDispatch::IntegrationTest
  # Una acción protegida de mentira para probar autorizar! sin depender de un módulo real.
  class PruebaController < ApplicationController
    def index
      autorizar!("admin.usuarios")
      render plain: "ok"
    end
  end

  # Añade la ruta de prueba sin borrar las demás (la cinta del layout las necesita).
  setup do
    Rails.application.routes.disable_clear_and_finalize = true
    Rails.application.routes.draw { get "prueba", to: "permisos_test/prueba#index" }
  end

  teardown do
    Rails.application.routes.disable_clear_and_finalize = false
    Rails.application.reload_routes!
  end

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
