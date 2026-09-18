require "test_helper"

class ConteosTableroTest < ActionDispatch::IntegrationTest
  setup do
    @tienda = sucursales(:tienda)
    post entrar_path, params: { usuario: "supervisora", password: "secreto1" }
    Inventario.mover!(sucursal: @tienda, producto: productos(:catsup), tipo: "entrada", cantidad: 5, usuario: usuarios(:supervisora))
    @p = Etiqueta.create!(tipo: "paquete", producto: productos(:pechuga), cantidad: "1.500", sucursal: @tienda, usuario: usuarios(:supervisora), autorizado_por: usuarios(:admin), justificacion: "x")
    Inventario.mover!(sucursal: @tienda, producto: productos(:pechuga), tipo: "entrada", cantidad: "1.5", usuario: usuarios(:supervisora))
  end

  test "conteo por pantalla: abrir, escanear, teclear, cerrar y ver el cargo" do
    post conteos_path, params: { responsable_id: usuarios(:cajera).id }
    conteo = Conteo.last
    assert_redirected_to conteo_path(conteo)
    post escanear_conteo_path(conteo), params: { codigo: @p.codigo }
    post manual_conteo_path(conteo), params: { producto_id: productos(:catsup).id, cantidad: "4" }
    get conteo_path(conteo)
    assert_select "td", /Cátsup/
    post cerrar_conteo_path(conteo)
    assert_equal 4_200, conteo.reload.faltante_centavos
    get cargos_path
    assert_select "td", /Cajera/
    post resolver_cargo_path(Cargo.last, estado: "cobrado")
    assert_equal "cobrado", Cargo.last.reload.estado
    get conteos_path
    assert_select "td", /#{conteo.folio}/
  end

  test "el inicio es el tablero y ventas por producto con CSV; sin permiso, bienvenida" do
    Caja.cobrar!(sucursal: @tienda, usuario: usuarios(:cajera), clave: "tb", lineas: [ { producto_id: productos(:catsup).id, cantidad: 2 } ], pagos: [ { forma: "efectivo", monto_centavos: 10_000 } ])
    get root_path
    assert_response :ok
    assert_match "$84.00", response.body
    get ventas_por_producto_path
    assert_select "td", /Cátsup/
    get ventas_por_producto_path(format: :csv)
    assert_match "CATS;", response.body
    delete salir_path
    post entrar_path, params: { usuario: "cajera", password: "secreto1" }
    get root_path
    assert_response :ok
    assert_no_match "$84.00", response.body
    assert_match "Cajera", response.body
    get ventas_por_producto_path
    assert_response :forbidden
  end
end
