require "test_helper"

class CajaControllerTest < ActionDispatch::IntegrationTest
  setup do
    post entrar_path, params: { usuario: "cajera", password: "secreto1" }
    @tienda = sucursales(:tienda)
    Inventario.mover!(sucursal: @tienda, producto: productos(:catsup), tipo: "entrada", cantidad: 5, usuario: usuarios(:cajera))
    @etiqueta = Etiqueta.create!(tipo: "paquete", producto: productos(:pechuga), cantidad: "2.000", sucursal: @tienda, usuario: usuarios(:cajera), autorizado_por: usuarios(:admin), justificacion: "prueba")
    Inventario.mover!(sucursal: @tienda, producto: productos(:pechuga), tipo: "entrada", cantidad: 2, usuario: usuarios(:cajera))
  end

  test "la cajera baja un precio sin permiso: se cobra igual y el renglón queda por revisar con lo que dejó de cobrar" do
    post caja_cobrar_path, params: { clave: "rebaja", lineas: [ { producto_id: productos(:catsup).id, cantidad: 2, precio_centavos: 3_000 } ].to_json,
                                     pagos: [ { forma: "efectivo", monto_centavos: 6_000 } ].to_json }, headers: { "Accept" => "application/json" }
    assert_response :ok
    venta = Venta.find_by!(clave: "rebaja")
    assert_nil venta.lineas.first.autorizado_por
    r = Revision.last
    assert_equal venta.lineas.first, r.revisable
    assert_equal 2_400, r.valor_centavos, "2 × (42.00 − 30.00)"
    assert_match "Precio bajado", r.descripcion
    get revisiones_path
    assert_response :forbidden, "la cajera no revisa"
    delete salir_path
    post entrar_path, params: { usuario: "admin", password: "secreto1" }
    get revisiones_path(sucursal_id: "todas")
    assert_select "td", /Precio bajado en B-/
  end

  test "vender: escanea, cobra por JSON, imprime ticket y aparece en ventas" do
    get caja_path
    assert_select "input[data-pos-target=codigo]"
    get caja_escanear_path(codigo: @etiqueta.codigo), headers: { "Accept" => "application/json" }
    assert_equal @etiqueta.id, response.parsed_body["etiqueta_id"]
    get caja_escanear_path(codigo: "CATS"), headers: { "Accept" => "application/json" }
    assert_equal "pieza", response.parsed_body["unidad"]
    get caja_escanear_path(codigo: "nada"), headers: { "Accept" => "application/json" }
    assert_response :not_found

    post caja_cobrar_path, params: { clave: "abc", lineas: [ { etiqueta_id: @etiqueta.id }, { producto_id: productos(:catsup).id, cantidad: 1 } ].to_json,
                                     pagos: [ { forma: "efectivo", monto_centavos: 50_000 } ].to_json }, headers: { "Accept" => "application/json" }
    assert_response :ok
    venta = Venta.last
    assert_equal 30_000, venta.total_centavos
    assert_equal caja_ticket_path(venta, imprimir: 1), response.parsed_body["url"]
    get caja_ticket_path(venta)
    assert_select "svg"
    assert_match "TOTAL", response.body
    get caja_ventas_path
    assert_select "td", /#{venta.folio}/
  end

  test "sin caja abierta no cobra y el corte se abre, se retira (por revisar) y se cierra" do
    cortes(:tienda_abierto).update!(estado: "cerrado")
    post caja_cobrar_path, params: { clave: "x", lineas: [ { producto_id: productos(:catsup).id, cantidad: 1 } ].to_json, pagos: [ { forma: "efectivo", monto_centavos: 5_000 } ].to_json }, headers: { "Accept" => "application/json" }
    assert_response :unprocessable_entity
    assert_match "no hay caja abierta", response.parsed_body["error"]
    post caja_abrir_path, params: { fondo: "500.00" }
    assert_redirected_to caja_path
    corte = Corte.abierto_en(@tienda)
    assert_equal 50_000, corte.fondo_centavos
    post caja_retirar_path, params: { monto: "100", motivo: "caja fuerte" }
    assert_equal 1, corte.retiros.count, "la cajera no tiene caja.retirar: se retira igual y queda por revisar"
    assert_nil corte.retiros.last.autorizado_por
    assert_equal 10_000, Revision.last.valor_centavos
    post caja_retirar_path, params: { monto: "100", motivo: "caja fuerte" }
    assert_equal 20_000, corte.retiros.sum(:monto_centavos)
    assert_equal 2, Revision.count, "cada retiro sin permiso queda por revisar"
    post caja_cerrar_path, params: { contado: "300.00" }
    assert_redirected_to caja_corte_path
    assert_equal 0, corte.reload.diferencia_centavos
    get caja_corte_path
    assert_select "td", /#{corte.folio}/
  end

  test "devolución solo con ticket o etiqueta" do
    venta = Caja.cobrar!(sucursal: @tienda, usuario: usuarios(:cajera), clave: "v1", lineas: [ { etiqueta_id: @etiqueta.id } ], pagos: [ { forma: "efectivo", monto_centavos: 30_000 } ])
    get caja_devolucion_path(codigo: "0000000000000")
    assert_match "Sin ticket ni etiqueta", response.body
    get caja_devolucion_path(codigo: @etiqueta.codigo)
    assert_select "strong", venta.folio
    linea = venta.lineas.first
    post caja_devolver_path, params: { venta_id: venta.id, lineas: { linea.id => "2" }, motivo: "" }
    assert_redirected_to caja_devolucion_path(codigo: nil)
    post caja_devolver_path, params: { venta_id: venta.id, lineas: { linea.id => "2" }, motivo: "mal olor" }
    assert_redirected_to caja_ventas_path
    assert_equal "devuelta", venta.reload.estado
    assert_equal "viva", @etiqueta.reload.estado
  end
end
