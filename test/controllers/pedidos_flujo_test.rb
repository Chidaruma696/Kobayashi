require "test_helper"

# Flujo completo: la tienda pide, la matriz abre producción para el pedido, etiqueta, cierra.
class PedidosFlujoTest < ActionDispatch::IntegrationTest
  test "la tienda pide y la matriz produce y surte sobre el pedido" do
    post entrar_path, params: { usuario: "cajera", password: "secreto1" }
    post pedidos_path, params: { pedido: { notas: "urgente", lineas_attributes: { "0" => { producto_id: productos(:pechuga).id, cantidad: "8" }, "1" => { producto_id: "", cantidad: "" } } } }
    pedido = Pedido.last
    assert_redirected_to pedido_path(pedido)
    assert_equal sucursales(:matriz), pedido.sucursal_origen
    assert_equal sucursales(:tienda), pedido.sucursal_destino
    assert_equal 1, pedido.lineas.count
    # La tienda que pide ve los suyos (sin surtir / surtidos), no la cola de la matriz.
    get pedidos_path
    assert_response :ok
    assert_select "h1", /Pedidos de Tienda 1/
    assert_select "h1", { text: /por surtir/, count: 0 }
    assert_select "td", /#{pedido.folio}/
    get hoja_pedido_path(pedido)
    assert_select "strong", /PEDIDO #{pedido.folio}/
    get pendientes_pedidos_path
    assert_response :forbidden

    delete salir_path
    post entrar_path, params: { usuario: "admin", password: "secreto1" }
    get pedidos_path
    assert_select "td", /#{pedido.folio}/
    assert_select "a[href=?]", new_etiqueta_path(pedido: pedido.id)
    get pendientes_pedidos_path
    assert_select "strong", /Pechuga de pollo/
    assert_match "13,000 kg", response.body, "5 del pedido de prueba + 8 de este, consolidados"
    pollo = Producto.create!(clave: "POLLO", nombre: "Pollo entero", unidad: "kg", precio: 60)
    Inventario.mover!(sucursal: sucursales(:matriz), producto: pollo, tipo: "entrada", cantidad: 20, usuario: usuarios(:admin))

    post producciones_path, params: { pedido_id: pedido.id, producto_id: pollo.id, cantidad: "20" }
    produccion = Produccion.last
    assert_redirected_to new_etiqueta_path(produccion_id: produccion.id)
    follow_redirect!
    assert_select "div", /Producción #{produccion.folio}/

    linea = pedido.lineas.first
    post etiquetas_path, params: { produccion_id: produccion.id, producto_id: productos(:pechuga).id, tipo: "paquete", cantidad: "8" }
    assert_equal linea, Etiqueta.last.pedido_linea
    assert_equal "surtido", linea.reload.estado
    assert_equal "surtiendo", pedido.reload.estado
    post etiquetas_path, params: { produccion_id: produccion.id, producto_id: productos(:pechuga).id, tipo: "paquete", cantidad: "13" }
    assert_match "más de lo que entró", flash[:alert]

    post cerrar_produccion_path(produccion)
    assert_redirected_to produccion_path(produccion)
    assert_equal BigDecimal("12"), produccion.reload.merma
    assert_equal BigDecimal("8"), Existencia.de(sucursales(:matriz), productos(:pechuga))
    get produccion_path(produccion)
    assert_select "span", /cerrada/
  end

  test "sin pedido la producción lleva motivo y sin PIN; el no surtir exige motivo" do
    post entrar_path, params: { usuario: "admin", password: "secreto1" }
    pollo = Producto.create!(clave: "POLLO", nombre: "Pollo entero", unidad: "kg", precio: 60)
    Inventario.mover!(sucursal: sucursales(:matriz), producto: pollo, tipo: "entrada", cantidad: 5, usuario: usuarios(:admin))
    get new_produccion_path
    assert_select "input[name=pin]", 0, "el PIN se descartó: sin pedido va con motivo y a revisión"
    post producciones_path, params: { producto_id: pollo.id, cantidad: "5" }
    assert_redirected_to new_produccion_path
    assert_match "motivo", flash[:alert]
    assert_equal 0, Produccion.count
    post producciones_path, params: { producto_id: pollo.id, cantidad: "5", justificacion: "mostrador" }
    assert_equal usuarios(:admin), Produccion.last.autorizado_por
    assert_equal 0, Revision.count, "el admin tiene el permiso: queda a su nombre, nada que revisar"

    linea = pedido_lineas(:catsup_10)
    post no_surtir_pedido_linea_path(linea.pedido, linea), params: { motivo: "" }
    assert_match "motivo", flash[:alert]
    post no_surtir_pedido_linea_path(linea.pedido, linea), params: { motivo: "no hay" }
    assert_equal "no_surtir", linea.reload.estado
    post reabrir_pedido_linea_path(linea.pedido, linea)
    assert_equal "pendiente", linea.reload.estado
  end
end
