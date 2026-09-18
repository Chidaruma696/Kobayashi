require "test_helper"

class SalidasControllerTest < ActionDispatch::IntegrationTest
  setup do
    @matriz = sucursales(:matriz)
    @tienda = sucursales(:tienda)
    Inventario.mover!(sucursal: @matriz, producto: productos(:pechuga), tipo: "entrada", cantidad: 10, usuario: usuarios(:admin))
    @p = Etiqueta.create!(tipo: "paquete", producto: productos(:pechuga), cantidad: "4.000", sucursal: @matriz, usuario: usuarios(:admin), pedido_linea: pedido_lineas(:pechuga_5))
  end

  test "flujo completo por pantalla: abrir, surtir, verificar, sellar, enviar, recibir y cerrar" do
    post entrar_path, params: { usuario: "admin", password: "secreto1" }
    post salidas_path, params: { destino: "sucursal:#{@tienda.id}" }
    salida = Salida.last
    assert_redirected_to salida_path(salida)
    post agregar_salida_path(salida), params: { codigo: @p.codigo }
    assert_equal 1, salida.salida_etiquetas.count
    post agregar_salida_path(salida), params: { codigo: "0000000000000" }
    assert_match "no se encontró", flash[:alert]
    post verificar_salida_path(salida), params: { codigo: @p.codigo }
    assert_match "propia carga", flash[:alert]
    delete salir_path

    post entrar_path, params: { usuario: "supervisora", password: "secreto1" }
    post verificar_salida_path(salida), params: { codigo: @p.codigo }
    post sellar_salida_path(salida)
    assert_equal "sellada", salida.reload.estado
    post enviar_salida_path(salida)
    assert_redirected_to salidas_path
    assert_equal "enviada", salida.reload.estado
    assert_equal BigDecimal("6"), Existencia.de(@matriz, productos(:pechuga))
    delete salir_path

    post entrar_path, params: { usuario: "cajera", password: "secreto1" }
    get recibir_salidas_path
    assert_select "td", /#{salida.folio}/
    get salida_path(salida)
    assert_select "h2", /Recibir/
    post recibir_etiqueta_salida_path(salida), params: { codigo: @p.codigo }
    assert_equal BigDecimal("4"), Existencia.de(@tienda, productos(:pechuga))
    post cerrar_recepcion_salida_path(salida)
    assert_redirected_to recibir_salidas_path
    assert_equal "recibida", salida.reload.estado
  end

  test "reparto por pantalla: abrir para un cliente, enviar y cobrar la entrega" do
    post entrar_path, params: { usuario: "admin", password: "secreto1" }
    Corte.abrir!(sucursal: @matriz, usuario: usuarios(:admin), fondo_centavos: 0)
    post salidas_path, params: { destino: "cliente:#{clientes(:taqueria).id}" }
    salida = Salida.last
    assert salida.reparto?
    post agregar_salida_path(salida), params: { codigo: @p.codigo }
    delete salir_path
    usuarios(:supervisora).update!(sucursal: @matriz) # quien verifica trabaja en la matriz
    post entrar_path, params: { usuario: "supervisora", password: "secreto1" }
    post verificar_salida_path(salida), params: { codigo: @p.codigo }
    post sellar_salida_path(salida)
    post enviar_salida_path(salida)
    assert_nil flash[:alert]
    assert salida.reload.venta.por_cobrar?
    get salida_path(salida)
    assert_select "h2", /Cobrar la entrega/
    post cobrar_entrega_salida_path(salida), params: { efectivo: "516.00" }
    assert_equal "entregada", salida.reload.estado
    assert salida.venta.reload.cobrada?
  end

  test "la tienda no toca las salidas de otros" do
    post entrar_path, params: { usuario: "cajera", password: "secreto1" }
    otra = Sucursal.create!(codigo: "T02", nombre: "Tienda 2")
    salida = Salida.nueva!(origen: @matriz, destino: otra, usuario: usuarios(:admin))
    get salida_path(salida)
    assert_response :not_found
  end

  test "una salida que nace de un pedido va a quien pidió, sin escoger destino" do
    post entrar_path, params: { usuario: "admin", password: "secreto1" }
    pedido = Pedido.create!(sucursal_origen: sucursales(:matriz), sucursal_destino: @tienda, usuario: usuarios(:admin),
                            lineas_attributes: [ { producto_id: productos(:pechuga).id, cantidad: 1 } ])
    get new_salida_path(pedido_id: pedido.id)
    assert_select "select[name=destino]", 0
    assert_select "p", /surte el pedido/
    post salidas_path, params: { pedido_id: pedido.id, destino: "cliente:#{clientes(:taqueria).id}" }
    assert_equal @tienda, Salida.last.destino
  end
end
