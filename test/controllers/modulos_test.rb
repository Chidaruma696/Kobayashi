require "test_helper"

class ModulosTest < ActionDispatch::IntegrationTest
  setup { post entrar_path, params: { usuario: "admin", password: "secreto1" } }

  test "de fábrica todo está encendido y se ve en la cinta" do
    get root_path
    assert_select "aside[data-lateral-target=panel] div", /Rutas/
    assert_select "aside[data-lateral-target=panel] div", /Etiquetas/
  end

  test "apagar rutas la quita de la cinta, del catálogo, de los roles y sus pantallas lo dicen" do
    patch ajustes_sistema_path, params: { modulos: [ "etiquetas", "pedidos", "salidas", "conteos" ] }
    assert_redirected_to ajustes_seccion_path("modulos")
    assert_not Modulo.activo?("rutas")
    assert Modulo.activo?("etiquetas")

    get root_path
    assert_select "aside[data-lateral-target=panel] div", { text: /Rutas/, count: 0 }
    assert_select "aside[data-lateral-target=panel] a", { text: /Clientes/, count: 0 }
    get viajes_path
    assert_response :not_found
    assert_select "h1", /Rutas/
    get admin_clientes_path
    assert_response :not_found
    get new_admin_rol_path
    assert_select "input[value='rutas.repartir']", count: 0
    assert_select "input[value='caja.vender']"
    get new_salida_path
    assert_select "optgroup[label=?]", I18n.t("salidas.clientes_de_ruta"), count: 0
  end

  test "un abarrote tiene caja, inventario, compras y administración; rutas enciende pedidos y salidas" do
    Modulo.aplicar_giro!("abarrotes")
    assert_equal %w[compras], Modulo.activos
    get root_path
    assert_select "aside[data-lateral-target=panel] div", /Caja/
    assert_select "aside[data-lateral-target=panel] div", { text: /Etiquetas|Pedidos|Salidas|Rutas|Conteos/, count: 0 }
    Modulo.guardar!(%w[rutas])
    assert_equal %w[pedidos salidas rutas], Modulo.activos
  end

  test "no se apaga un módulo con trabajo abierto" do
    assert Pedido.abiertos.exists?, "el fixture trae un pedido abierto"
    e = assert_raises(ArgumentError) { Modulo.guardar!(%w[etiquetas salidas conteos]) }
    assert_match "Pedidos", e.message
    assert Modulo.activo?("pedidos")
    Modulo.guardar!(%w[etiquetas pedidos salidas conteos], comprobar: false)
    assert_not Modulo.activo?("rutas"), "sin comprobar se apaga aunque haya trabajo"
  end
end
