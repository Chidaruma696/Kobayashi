require "test_helper"

class InstalacionTest < ActionDispatch::IntegrationTest
  test "sin ningún usuario activo todo manda a instalar, y ahí se crea el administrador y entra" do
    Usuario.update_all(activo: false)
    get root_path
    assert_redirected_to instalar_path
    get entrar_path
    assert_redirected_to instalar_path

    get instalar_path
    assert_response :success
    assert_select "input[name='instalacion[usuario]'][value=admin]"

    post instalar_path, params: { instalacion: { negocio: "Carnes Selectas", sucursal: "Planta", codigo: "pl1", nombre: "Doña Rosa", usuario: "Rosa", password: "secreto123", idioma: "es" } }
    assert_redirected_to root_path
    rosa = Usuario.find_by!(usuario: "rosa")
    assert_equal "Doña Rosa", rosa.nombre
    assert rosa.puede?("admin.usuarios"), "el primer usuario es administrador"
    assert_equal "PL1", rosa.sucursal.codigo
    assert rosa.sucursal.matriz?
    assert_equal "Carnes Selectas", Ajuste["negocio.nombre"]
    assert_equal "es", rosa.idioma

    follow_redirect!
    assert_response :success, "queda con la sesión iniciada"
    assert_select "html[lang=es]"
  end

  test "con usuarios la pantalla de instalar ya no existe" do
    get instalar_path
    assert_redirected_to root_path
    post instalar_path, params: { instalacion: { nombre: "X", usuario: "x", password: "secreto123" } }
    assert_redirected_to root_path
    assert_nil Usuario.find_by(usuario: "x")
  end

  test "con datos malos lo dice y no deja nada a medias" do
    Usuario.update_all(activo: false)
    post instalar_path, params: { instalacion: { sucursal: "Planta", codigo: "PL1", nombre: "", usuario: "rosa", password: "secreto123" } }
    assert_response :unprocessable_entity
    assert_nil Usuario.find_by(usuario: "rosa")
    assert_nil Sucursal.find_by(codigo: "PL1"), "la transacción se deshace entera"
  end
end
