require "test_helper"

class SesionesControllerTest < ActionDispatch::IntegrationTest
  test "sin sesión manda a entrar" do
    get root_path
    assert_redirected_to entrar_path
  end

  test "entra con usuario y contraseña correctos" do
    post entrar_path, params: { usuario: "Cajera", password: "secreto1" }
    assert_redirected_to root_path
    follow_redirect!
    assert_select "nav", /Tienda 1/
    assert_select "li", /Vender en caja/
  end

  test "rechaza contraseña incorrecta y usuarios inactivos" do
    post entrar_path, params: { usuario: "cajera", password: "mal" }
    assert_response :unprocessable_entity
    post entrar_path, params: { usuario: "inactivo", password: "secreto1" }
    assert_response :unprocessable_entity
  end

  test "salir cierra la sesión" do
    post entrar_path, params: { usuario: "admin", password: "secreto1" }
    delete salir_path
    get root_path
    assert_redirected_to entrar_path
  end
end
