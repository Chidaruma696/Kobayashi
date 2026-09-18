require "test_helper"

# El ciclo completo de una ruta: armar el viaje, despachar, la parada del chofer
# (entregar escaneando, rechazar, cobrar, pedido para la próxima), y la liquidación con cargo.
class RutasTest < ActionDispatch::IntegrationTest
  setup do
    @matriz = sucursales(:matriz)
    @admin = usuarios(:admin)
    @chofer = usuarios(:chofer)
    @taqueria = clientes(:taqueria)
    @fonda = Cliente.create!(nombre: "Fonda Doña Mary", ruta: rutas(:norte), orden: 2, direccion: "Calle 5")
    Inventario.mover!(sucursal: @matriz, producto: productos(:pechuga), tipo: "entrada", cantidad: 10, usuario: @admin)
    Inventario.mover!(sucursal: @matriz, producto: productos(:catsup), tipo: "entrada", cantidad: 5, usuario: @admin)
    @p1 = Etiqueta.create!(tipo: "paquete", producto: productos(:pechuga), cantidad: "4.000", sucursal: @matriz, usuario: @admin, pedido_linea: pedido_lineas(:pechuga_5))
    @p2 = Etiqueta.create!(tipo: "paquete", producto: productos(:catsup), cantidad: "2", sucursal: @matriz, usuario: @admin, pedido_linea: pedido_lineas(:catsup_10))
    @p3 = Etiqueta.create!(tipo: "paquete", producto: productos(:pechuga), cantidad: "3.000", sucursal: @matriz, usuario: @admin, pedido_linea: pedido_lineas(:pechuga_5))
    @corte = Corte.abrir!(sucursal: @matriz, usuario: @admin, fondo_centavos: 0)
    usuarios(:supervisora).update!(sucursal: @matriz)
  end

  def salida_sellada(cliente, *etiquetas)
    post entrar_path, params: { usuario: "admin", password: "secreto1" }
    post salidas_path, params: { destino: "cliente:#{cliente.id}" }
    salida = Salida.last
    etiquetas.each { |e| post agregar_salida_path(salida), params: { codigo: e.codigo } }
    post entrar_path, params: { usuario: "supervisora", password: "secreto1" }
    etiquetas.each { |e| post verificar_salida_path(salida), params: { codigo: e.codigo } }
    post sellar_salida_path(salida)
    assert salida.reload.sellada?
    salida
  end

  test "viaje completo: armar, despachar, parada del chofer con rechazo y cobro, no entregado, liquidar con cargo" do
    s1 = salida_sellada(@taqueria, @p1, @p2)
    s2 = salida_sellada(@fonda, @p3)

    # --- la oficina arma el viaje: los repartos sellados de la ruta suben solos
    post entrar_path, params: { usuario: "admin", password: "secreto1" }
    post viajes_path, params: { ruta_id: rutas(:norte).id, fecha: Date.current.to_s }
    viaje = Viaje.last
    assert_redirected_to viaje_path(viaje)
    assert_equal @chofer, viaje.chofer, "sin chofer explícito toma el de la ruta"
    assert_equal [ s1, s2 ], viaje.paradas
    get viaje_path(viaje)
    assert_select "td", /Taquería/
    get hoja_viaje_path(viaje)
    assert_match "ORDEN DE REPARTO", response.body

    post salir_viaje_path(viaje)
    assert_nil flash[:alert]
    assert viaje.reload.en_ruta?
    assert s1.reload.venta.por_cobrar?
    assert_equal BigDecimal("3"), Existencia.de(@matriz, productos(:pechuga))
    assert_equal 51_600 + 8_400, s1.venta.total_centavos

    # --- el chofer en su celular
    post entrar_path, params: { usuario: "chofer", password: "secreto1" }
    get viajes_path
    assert_response :forbidden
    get reparto_path
    assert_select "a", { text: "Entregar", count: 2 }
    get reparto_parada_path(s1)
    assert_select "h1", /Taquería/

    # pedido para la próxima visita, desde la parada
    post pedidos_path, params: { volver: reparto_parada_path(s1), pedido: { destino: "cliente:#{@taqueria.id}", lineas_attributes: { "0" => { producto_id: productos(:pechuga).id, cantidad: "6" } } } }
    assert_redirected_to reparto_parada_path(s1)
    assert_equal @taqueria, Pedido.last.cliente
    assert_equal @chofer, Pedido.last.usuario

    # entrega escaneando la pechuga; la cátsup no la quiso; cobra en efectivo con cambio
    post reparto_entregar_path(s1), params: { codigo: @p1.codigo }
    assert_match "1 bulto entregado", flash[:notice]
    post reparto_cerrar_path(s1), params: { efectivo: "600" }
    assert_match "sin entregar", flash[:alert], "con pendientes hace falta el motivo del rechazo"
    post reparto_cerrar_path(s1), params: { motivo_rechazo: "no quiso la cátsup", efectivo: "600" }
    assert_redirected_to reparto_path
    assert s1.reload.entregada?
    venta1 = s1.venta.reload
    assert venta1.cobrada?
    assert venta1.en_ruta
    assert_equal 8_400, venta1.total_devuelto_centavos
    assert_equal 51_600, venta1.saldo_centavos
    assert_equal 8_400, venta1.cambio_centavos
    assert @p2.reload.viva?, "lo rechazado vuelve a estar vivo en la matriz"
    assert_equal BigDecimal("5"), Existencia.de(@matriz, productos(:catsup))
    assert_equal 0, @corte.reload.efectivo_esperado_centavos, "lo cobrado en ruta no está en la gaveta hasta liquidar"

    # segunda parada: no se entregó
    post reparto_no_entregado_path(s2), params: { motivo: "cerrado" }
    assert s2.reload.rechazada?
    assert_equal "devuelta", s2.venta.reload.estado
    assert @p3.reload.viva?
    assert_equal BigDecimal("6"), Existencia.de(@matriz, productos(:pechuga))

    # gasto del chofer
    post gasto_viaje_path(viaje), params: { concepto: "gasolina", monto: "100" }
    assert_equal 41_600, viaje.reload.efectivo_por_entregar_centavos
    get reparto_path
    assert_select "a", { text: "Entregar", count: 0 }

    # --- la oficina liquida: entrega 400 en vez de 416 → cargo de 16 al chofer
    post entrar_path, params: { usuario: "admin", password: "secreto1" }
    get viaje_path(viaje)
    assert_select "h2", /Liquidar el viaje/
    post liquidar_viaje_path(viaje), params: { entregado: "400" }
    assert_match "cargo de $16.00", flash[:notice]
    viaje.reload
    assert viaje.liquidado?
    assert_equal 41_600, viaje.efectivo_esperado_centavos
    assert_equal(-1_600, viaje.diferencia_centavos)
    cargo = Cargo.last
    assert_equal @chofer, cargo.usuario
    assert_equal 1_600, cargo.monto_centavos
    assert_equal viaje, cargo.viaje
    assert_not venta1.reload.en_ruta
    assert_equal @corte, venta1.corte
    assert_equal 41_600, @corte.reload.efectivo_esperado_centavos, "efectivo 600 − cambio 84 − gasto 100 como retiro"
    assert_equal 1, @corte.retiros.count
    get cargos_path
    assert_select "td", /Chofer Beto/
    get viajes_path
    assert_select "td", /liquidado/
  end

  test "no sale con repartos sin sellar, y una parada ajena no se toca" do
    post entrar_path, params: { usuario: "admin", password: "secreto1" }
    post salidas_path, params: { destino: "cliente:#{@taqueria.id}" }
    abierta = Salida.last
    post viajes_path, params: { ruta_id: rutas(:norte).id }
    viaje = Viaje.last
    assert_equal 0, viaje.salidas.count, "solo suben solos los sellados"
    post agregar_viaje_path(viaje, salida_id: abierta.id)
    assert_equal viaje, abierta.reload.viaje
    post salir_viaje_path(viaje)
    assert_match "faltan por sellar", flash[:alert]
    assert viaje.reload.armando?
    # una salida en un viaje no se cobra en oficina
    post entrar_path, params: { usuario: "chofer", password: "secreto1" }
    get reparto_parada_path(abierta)
    assert_response :forbidden, "el chofer no entra a una parada de un viaje que no salió... salvo que el viaje sea suyo"
  end

  test "entregar todo sin escanear queda por revisar a nombre del chofer" do
    s1 = salida_sellada(@taqueria, @p1)
    post entrar_path, params: { usuario: "admin", password: "secreto1" }
    post viajes_path, params: { ruta_id: rutas(:norte).id }
    post salir_viaje_path(Viaje.last)
    post entrar_path, params: { usuario: "chofer", password: "secreto1" }
    post reparto_entregar_todo_path(s1), params: { motivo: "se mojó la etiqueta" }
    assert_equal 0, s1.pendientes_de_entrega.count
    r = Revision.last
    assert_equal @chofer, r.usuario
    assert_equal s1, r.revisable
    assert_equal 51_600, r.valor_centavos
    post reparto_cerrar_path(s1), params: { efectivo: "516" }
    assert s1.reload.entregada?
  end
end
