require "test_helper"

# Zonas y orden de reparto, canastillas y convenio de precio con tope semanal.
class RepartoExtrasTest < ActionDispatch::IntegrationTest
  setup do
    @matriz = sucursales(:matriz)
    @admin = usuarios(:admin)
    @chofer = usuarios(:chofer)
    @ruta = rutas(:norte)
    @taqueria = clientes(:taqueria)
    Inventario.mover!(sucursal: @matriz, producto: productos(:pechuga), tipo: "entrada", cantidad: 50, usuario: @admin)
    @corte = Corte.abrir!(sucursal: @matriz, usuario: @admin, fondo_centavos: 0)
    usuarios(:supervisora).update!(sucursal: @matriz)
    post entrar_path, params: { usuario: "admin", password: "secreto1" }
  end

  def paquete(kg)
    Etiqueta.create!(tipo: "paquete", producto: productos(:pechuga), cantidad: kg, sucursal: @matriz, usuario: @admin, pedido_linea: pedido_lineas(:pechuga_5))
  end

  def reparto_sellado(cliente, *bultos)
    post entrar_path, params: { usuario: "admin", password: "secreto1" }
    post salidas_path, params: { destino: "cliente:#{cliente.id}" }
    salida = Salida.last
    bultos.each { |e| post agregar_salida_path(salida), params: { codigo: e.codigo } }
    yield salida if block_given?
    post entrar_path, params: { usuario: "supervisora", password: "secreto1" }
    bultos.each { |e| post verificar_salida_path(salida), params: { codigo: e.codigo } }
    post sellar_salida_path(salida)
    post entrar_path, params: { usuario: "admin", password: "secreto1" }
    salida.reload
  end

  test "zonas y orden de reparto: las paradas se generan por zona y orden, y se pueden mover" do
    patch admin_ruta_path(@ruta), params: { ruta: { nombre: @ruta.nombre, activa: "1", zonas_attributes: { "0" => { nombre: "Centro", orden: 1 }, "1" => { nombre: "Salida a carretera", orden: 2 } } } }
    assert_equal %w[Centro], [ @ruta.zonas.en_orden.first.nombre ]
    centro, carretera = @ruta.zonas.en_orden.to_a
    lejos = Cliente.create!(nombre: "Lejos", ruta: @ruta, zona: carretera, orden: 1)
    cerca = Cliente.create!(nombre: "Cerca", ruta: @ruta, zona: centro, orden: 2)
    post orden_admin_ruta_path(@ruta), params: { clientes: { @taqueria.id => { zona_id: centro.id, orden: 1 } } }
    assert_equal centro, @taqueria.reload.zona
    get orden_admin_ruta_path(@ruta)
    assert_select "td", /Taquería/
    assert_equal [ @taqueria, cerca, lejos ], @ruta.clientes_en_orden
    otra = Zona.create!(ruta: Ruta.create!(nombre: "Sur"), nombre: "X")
    assert_not @taqueria.tap { |t| t.zona = otra }.valid?, "una zona de otra ruta no vale"

    s_lejos = reparto_sellado(lejos, paquete("1.000"))
    s_cerca = reparto_sellado(cerca, paquete("1.000"))
    s_taq = reparto_sellado(@taqueria, paquete("1.000"))
    post viajes_path, params: { ruta_id: @ruta.id }
    viaje = Viaje.last
    assert_equal [ s_taq, s_cerca, s_lejos ], viaje.paradas, "orden generado: zona Centro (1, 2) y luego carretera"
    assert_equal [ 1, 2, 3 ], viaje.paradas.map(&:parada)
    post mover_viaje_path(viaje, salida_id: s_lejos.id, paso: -1)
    assert_equal [ s_taq, s_lejos, s_cerca ], viaje.paradas
    get hoja_viaje_path(viaje)
    assert_match "ORDEN DE REPARTO", response.body
    assert_match "2. Lejos", response.body
    post quitar_viaje_path(viaje, salida_id: s_taq.id)
    assert_equal [ 1, 2 ], viaje.paradas.map(&:parada)
  end

  test "canastillas: carga al salir, entrega en la parada, devolución del cliente, descarga al liquidar, saldos y ajustes" do
    rejilla = TipoCanastilla.create!(nombre: "Rejilla", color: "negra")
    s1 = reparto_sellado(@taqueria, paquete("2.000")) do |salida|
      post canastillas_salida_path(salida), params: { tipo_canastilla_id: rejilla.id, cantidad: 3 }
      assert_equal 3, salida.canastillas.sum(:cantidad)
    end
    post viajes_path, params: { ruta_id: @ruta.id }
    viaje = Viaje.last
    post salir_viaje_path(viaje)
    assert_equal({ rejilla.id => 3 }, Canastillas.saldo_chofer(@chofer), "cargó 3")

    post entrar_path, params: { usuario: "chofer", password: "secreto1" }
    post reparto_canastillas_path(s1), params: { tipo_canastilla_id: rejilla.id, cantidad: 1 }
    assert_equal({ rejilla.id => -1 }, Canastillas.saldo_cliente(@taqueria), "devolvió una que debía de antes")
    post reparto_entregar_path(s1), params: { codigo: Etiqueta.last.codigo }
    post reparto_cerrar_path(s1), params: { efectivo: "258" }
    assert s1.reload.entregada?
    assert_equal({ rejilla.id => 2 }, Canastillas.saldo_cliente(@taqueria), "se llevó 3, había devuelto 1")
    assert_equal({ rejilla.id => 1 }, Canastillas.saldo_chofer(@chofer), "3 cargadas − 3 entregadas + 1 devuelta")
    assert_equal({ rejilla.id => 1 }, viaje.canastillas_a_bordo)

    post entrar_path, params: { usuario: "admin", password: "secreto1" }
    get viaje_path(viaje)
    assert_select "label", /Rejilla negra que regresan/
    post liquidar_viaje_path(viaje), params: { entregado: "258", canastillas: { rejilla.id => 1 } }
    assert viaje.reload.liquidado?
    assert_equal({}, Canastillas.saldo_chofer(@chofer), "descargó lo que traía")

    get canastillas_path
    assert_select "td", /Taquería/
    assert_select "aside[data-lateral-target=panel] div", /Retornables/
    Modulo.guardar!(Modulo::OPCIONALES - %w[retornables], comprobar: false)
    get canastillas_path
    assert_response :not_found, "las canastillas cuelgan de retornables"
    get viaje_path(viaje)
    assert_select "h3", { text: /Canastillas/, count: 0 }
    Modulo.guardar!(Modulo::OPCIONALES, comprobar: false)
    post canastillas_devolucion_path, params: { cliente_id: @taqueria.id, tipo_canastilla_id: rejilla.id, cantidad: 1 }
    assert_equal({ rejilla.id => 1 }, Canastillas.saldo_cliente(@taqueria))
    post canastillas_ajuste_path, params: { cliente_id: @taqueria.id, tipo_canastilla_id: rejilla.id, cantidad: -1, motivo: "se perdonó" }
    assert_equal({}, Canastillas.saldo_cliente(@taqueria))
    post canastillas_ajuste_path, params: { chofer_id: @chofer.id, tipo_canastilla_id: rejilla.id, cantidad: 2, motivo: "" }
    assert_match "motivo", flash[:alert]
    get admin_tipos_canastilla_path
    assert_select "td", /Rejilla/
  end

  test "convenio: precio fijo hasta el tope semanal de cajas, el resto a lista, acumulado entre notas" do
    get new_admin_convenio_path
    assert_response :ok
    post admin_convenios_path, params: { convenio: { cliente_id: @taqueria.id, lineas: "Pollo", tope_cajas: "2", precio: "100", activo: "1" } }
    conv = Convenio.last
    assert conv.aplica?(productos(:pechuga))
    assert_not conv.aplica?(productos(:catsup))
    # tres cajas de 2 paquetes de 1 kg: 6 kg de pechuga (lista $129/kg)
    cajas = 3.times.map { Etiqueta.cerrar_caja!([ paquete("1.000"), paquete("1.000") ], usuario: @admin) }
    s1 = reparto_sellado(@taqueria, *cajas)
    post viajes_path, params: { ruta_id: @ruta.id }
    post salir_viaje_path(Viaje.last)
    venta = s1.reload.venta
    # 2 cajas (4 kg) a $100 y 1 caja (2 kg) a $129 = 400 + 258
    assert_equal 65_800, venta.total_centavos
    assert_equal BigDecimal("2"), venta.lineas.sum(:convenio_cajas)
    assert_equal BigDecimal("2"), conv.cajas_usadas(Date.current)
    # la siguiente nota de la semana ya no tiene tope: todo a lista
    post entrar_path, params: { usuario: "chofer", password: "secreto1" }
    cajas.each { |c| post reparto_entregar_path(s1), params: { codigo: c.codigo } }
    post reparto_cerrar_path(s1), params: { efectivo: "658" }
    assert s1.reload.entregada?
    post entrar_path, params: { usuario: "admin", password: "secreto1" }
    post liquidar_viaje_path(Viaje.last), params: { entregado: "658" }
    s2 = reparto_sellado(@taqueria, Etiqueta.cerrar_caja!([ paquete("1.000") ], usuario: @admin))
    post viajes_path, params: { ruta_id: @ruta.id }
    post salir_viaje_path(Viaje.last)
    assert_equal 12_900, s2.reload.venta.total_centavos
    # un paquete suelto no cuenta como caja: a lista aunque haya tope
    conv.update!(tope_cajas: 10)
    s3 = reparto_sellado(@taqueria, paquete("1.000"))
    post viajes_path, params: { ruta_id: @ruta.id }
    post salir_viaje_path(Viaje.last)
    assert_equal 12_900, s3.reload.venta.total_centavos
    get admin_convenios_path
    assert_select "td", /Taquería/
  end
end
