require "test_helper"

class AjustesTest < ActionDispatch::IntegrationTest
  test "cada quien guarda idioma, tema, densidad y letra, y el sistema se ve en su idioma" do
    post entrar_path, params: { usuario: "cajera", password: "secreto1" }
    get ajustes_path
    assert_response :ok
    assert_select "h1", "Ajustes"
    assert_select "h2", { text: "Sistema", count: 0 }, "la cajera no administra"
    patch ajustes_preferencias_path, params: { usuario: { idioma: "en", tema: "oscuro", densidad: "compacta", letra: "grande" } }
    assert_redirected_to ajustes_path
    u = usuarios(:cajera).reload
    assert_equal %w[en oscuro compacta grande], [ u.idioma, u.tema, u.densidad, u.letra ]
    follow_redirect!
    assert_select "html[lang=en][data-theme=oscuro][data-densidad=compacta][data-letra=grande]"
    assert_select "h1", "Settings"
    patch ajustes_preferencias_path, params: { usuario: { idioma: "de" } }
    follow_redirect!
    assert_select "h1", "Einstellungen"
    patch ajustes_preferencias_path, params: { usuario: { idioma: "xx" } }
    assert_match "Sprache", flash[:alert]
    patch ajustes_sistema_path, params: { ajuste: { "negocio.nombre" => "X" } }
    assert_response :forbidden
  end

  test "el administrador cambia lo del sistema y se nota en el ticket, la etiqueta y el piso de precio" do
    post entrar_path, params: { usuario: "admin", password: "secreto1" }
    patch ajustes_sistema_path, params: { ajuste: { "negocio.nombre" => "Carnes Selectas", "negocio.pie_ticket" => "Vuelva pronto", "etiqueta.ancho" => "80", "etiqueta.alto" => "40", "caja.piso_precio" => "80" } }
    assert_redirected_to ajustes_seccion_path("modulos")
    assert_equal "Carnes Selectas", Ajuste["negocio.nombre"]
    assert_equal 80, Ajuste.entero("etiqueta.ancho")
    assert_equal "55", Ajuste::DEFAULTS["etiqueta.ancho"], "el default no cambia"
    get imprimir_etiquetas_path(codigo: "750100012345", n: 1, nombre: "Cátsup")
    assert_match "size: 80mm 40mm", response.body
    patch ajustes_sistema_path, params: { ajuste: { "etiqueta.ancho" => "" } }
    assert_equal 55, Ajuste.entero("etiqueta.ancho"), "vacío vuelve al default"
    patch ajustes_sistema_path, params: { ajuste: { "etiqueta.alto" => "abc" } }
    assert_match "entero", flash[:alert]

    # Piso de precio al 80 %: una rebaja al 70 % ya no pasa ni con permiso.
    Inventario.mover!(sucursal: sucursales(:tienda), producto: productos(:catsup), tipo: "entrada", cantidad: 5, usuario: usuarios(:admin))
    e = assert_raises(Caja::Error) do
      Caja.cobrar!(sucursal: sucursales(:tienda), usuario: usuarios(:supervisora), clave: "p1", lineas: [ { producto_id: productos(:catsup).id, cantidad: 1, precio_centavos: 2_940 } ],
                   pagos: [ { forma: "efectivo", monto_centavos: 5_000 } ], autorizador: usuarios(:supervisora))
    end
    assert_match "80 %", e.message
  end
end

class MonedaTest < ActionDispatch::IntegrationTest
  test "el símbolo de la moneda lo pone el negocio y sale en servidor, caja y ticket" do
    assert_equal "$1,234.50", Dinero.pesos(123_450)
    post entrar_path, params: { usuario: "admin", password: "secreto1" }
    patch ajustes_sistema_path, params: { ajuste: { "negocio.moneda" => "GTQ", "negocio.simbolo" => "Q" } }
    Current.reset # en los tests cada petición trae su propio Current y al terminar se restaura el del test
    assert_equal "Q1,234.50", Dinero.pesos(123_450)
    assert_equal "−Q0.50", Dinero.pesos(-50)
    get caja_path
    assert_match 'window.MONEDA = {"simbolo":"Q","codigo":"GTQ"}', response.body
    get ajustes_seccion_path("negocio")
    assert_select "iframe[srcdoc*='Q214.50']"
    patch ajustes_sistema_path, params: { ajuste: { "negocio.moneda" => "", "negocio.simbolo" => "" } }
    Current.reset
    assert_equal "$1.00", Dinero.pesos(100), "vacío vuelve al peso"
  end
end
