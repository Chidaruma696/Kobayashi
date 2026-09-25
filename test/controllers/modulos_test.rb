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

  test "apagar una base que otro necesita se rechaza nombrándolo; la pantalla enseña qué necesita cada uno" do
    Modulo.guardar!(%w[compras retornables pedidos salidas rutas], comprobar: false)
    e = assert_raises(ArgumentError) { Modulo.guardar!(%w[compras retornables salidas rutas]) }
    assert_match "Pedidos", e.message
    assert_match "Rutas", e.message
    assert Modulo.activo?("pedidos")
    Modulo.guardar!(%w[retornables pedidos salidas rutas], comprobar: false)
    assert Modulo.activo?("retornables"), "retornables vive con rutas aunque compras esté apagado"
    e = assert_raises(ArgumentError) { Modulo.guardar!(%w[retornables pedidos salidas]) }
    assert_match "Retornables", e.message, "sin compras ni rutas se queda sin base"
    Modulo.guardar!([], comprobar: false)
    Modulo.guardar!(%w[retornables], comprobar: false)
    assert_equal %w[compras retornables], Modulo.activos, "encender retornables solo arrastra la primera base"
    Modulo.guardar!(%w[compras retornables pedidos salidas rutas], comprobar: false)
    Modulo.guardar!(%w[pedidos salidas], comprobar: false)
    assert_equal %w[pedidos salidas], Modulo.activos, "apagar la base junto con quien la necesita sí pasa"
    get ajustes_seccion_path("modulos")
    assert_select "input[data-modulo=rutas][data-necesita='pedidos salidas']"
    assert_select "input[data-modulo=retornables][data-alguno='compras rutas']"
    assert_select "span", /Necesita al menos Compras \/ Rutas/
    assert_select "input[data-modulo=pedidos][data-dependientes=rutas]"
    assert_select "span", /Necesita Pedidos, Salidas y recepción/
    assert_select "span", /Lo necesita Rutas/
    patch ajustes_sistema_path, params: { modulos: %w[compras rutas], volver: "modulos" }
    Current.modulos = nil # lo memorizado en el hilo del test no ve lo que guardó la petición
    assert_equal %w[compras pedidos salidas rutas], Modulo.activos, "encender rutas arrastra pedidos y salidas"
    patch ajustes_sistema_path, params: { modulos: %w[compras pedidos rutas], volver: "modulos" }
    assert_match "Salidas", flash[:alert]
    Current.modulos = nil
    assert Modulo.activo?("salidas")
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
