require "test_helper"

# Crédito de ruta: nota a crédito en la parada, bloqueo por regla, abono que desbloquea,
# abono en ruta que entra al liquidar; y mandar sin escanear (renglón manual, sellar sin verificar).
class CobranzaTest < ActionDispatch::IntegrationTest
  setup do
    @matriz = sucursales(:matriz)
    @admin = usuarios(:admin)
    @chofer = usuarios(:chofer)
    @taqueria = clientes(:taqueria)
    @taqueria.update!(credito: "nota_x_nota")
    Inventario.mover!(sucursal: @matriz, producto: productos(:pechuga), tipo: "entrada", cantidad: 10, usuario: @admin)
    Inventario.mover!(sucursal: @matriz, producto: productos(:catsup), tipo: "entrada", cantidad: 5, usuario: @admin)
    @p1 = Etiqueta.create!(tipo: "paquete", producto: productos(:pechuga), cantidad: "4.000", sucursal: @matriz, usuario: @admin, pedido_linea: pedido_lineas(:pechuga_5))
    @corte = Corte.abrir!(sucursal: @matriz, usuario: @admin, fondo_centavos: 0)
    usuarios(:supervisora).update!(sucursal: @matriz)
  end

  def viaje_en_ruta(*etiquetas)
    post entrar_path, params: { usuario: "admin", password: "secreto1" }
    post salidas_path, params: { destino: "cliente:#{@taqueria.id}" }
    salida = Salida.last
    etiquetas.each { |e| post agregar_salida_path(salida), params: { codigo: e.codigo } }
    yield salida if block_given?
    post entrar_path, params: { usuario: "supervisora", password: "secreto1" }
    etiquetas.each { |e| post verificar_salida_path(salida), params: { codigo: e.codigo } }
    post sellar_salida_path(salida)
    post entrar_path, params: { usuario: "admin", password: "secreto1" }
    post viajes_path, params: { ruta_id: rutas(:norte).id }
    post salir_viaje_path(Viaje.last)
    assert Viaje.last.en_ruta?
    salida.reload
  end

  test "nota por nota: se lleva la primera a crédito, la segunda se bloquea, abona y se abre; el abono en ruta entra al liquidar" do
    s1 = viaje_en_ruta(@p1)
    post entrar_path, params: { usuario: "chofer", password: "secreto1" }
    get reparto_parada_path(s1)
    assert_select "div", /puede llevarse la nota a crédito/
    post reparto_entregar_path(s1), params: { codigo: @p1.codigo }
    post reparto_cerrar_path(s1), params: { efectivo: "100" }
    assert_match "a crédito", flash[:alert], "sin marcar crédito y con dinero de menos no cierra"
    post reparto_cerrar_path(s1), params: { efectivo: "100", a_credito: "1" }
    assert_redirected_to reparto_path
    venta = s1.reload.venta
    assert venta.a_credito?
    assert venta.en_ruta
    assert_equal 10_000, venta.pagado_centavos
    assert_equal 41_600, venta.credito_centavos
    assert_equal 41_600, @taqueria.saldo_centavos
    assert @taqueria.estado_credito.bloqueado, "nota por nota con adeudo"

    # liquida: los 100 en efectivo entran al corte, la nota sigue a crédito
    post entrar_path, params: { usuario: "admin", password: "secreto1" }
    post liquidar_viaje_path(Viaje.last), params: { entregado: "100" }
    assert_equal 10_000, @corte.reload.efectivo_esperado_centavos
    assert venta.reload.a_credito?
    assert_not venta.en_ruta

    # segunda visita: bloqueado, solo contado
    p2 = Etiqueta.create!(tipo: "paquete", producto: productos(:catsup), cantidad: "1", sucursal: @matriz, usuario: @admin, pedido_linea: pedido_lineas(:catsup_10))
    s2 = viaje_en_ruta(p2)
    post entrar_path, params: { usuario: "chofer", password: "secreto1" }
    get reparto_parada_path(s2)
    assert_select "div", /BLOQUEADO/
    post reparto_entregar_path(s2), params: { codigo: p2.codigo }
    post reparto_cerrar_path(s2), params: { efectivo: "0", a_credito: "1" }
    assert_match "bloqueado", flash[:alert]
    # el cliente abona en la parada lo que debía: se abre solo, y la nueva nota puede ir a crédito
    post reparto_abonar_path(s2), params: { monto: "416", forma: "efectivo" }
    assert_equal 0, @taqueria.saldo_centavos
    assert_not @taqueria.estado_credito.bloqueado
    post reparto_cerrar_path(s2), params: { a_credito: "1" }
    assert s2.reload.entregada?
    assert_equal 4_200, @taqueria.saldo_centavos
    viaje = Viaje.last
    assert_equal 41_600, viaje.efectivo_por_entregar_centavos, "el abono en ruta lo trae el chofer"
    post entrar_path, params: { usuario: "admin", password: "secreto1" }
    post liquidar_viaje_path(viaje), params: { entregado: "416" }
    assert_equal 10_000 + 41_600, @corte.reload.efectivo_esperado_centavos
    assert_equal @corte, Abono.last.reload.corte

    # cobranza en oficina: estado de cuenta, abono, bloqueo manual
    get cobranza_path
    assert_select "td", /Taquería/
    get cobranza_cliente_path(@taqueria)
    assert_select "td", /Nota B-/
    post cobranza_abonar_path(@taqueria), params: { monto: "42", forma: "transferencia" }
    assert_equal 0, @taqueria.saldo_centavos
    post cobranza_bloquear_path(@taqueria), params: { accion: "bloquear", motivo: "cheque devuelto" }
    assert @taqueria.reload.estado_credito.bloqueado
    assert @taqueria.estado_credito.manual
    post cobranza_bloquear_path(@taqueria), params: { accion: "quitar" }
    assert_not @taqueria.reload.estado_credito.bloqueado
  end

  test "reglas: límite, semanal, contado abonando y contado" do
    hoy = Date.new(2026, 9, 16) # miércoles
    c = Cliente.create!(nombre: "Lonchería", credito: "limite", limite_credito_centavos: 50_000)
    c.movimientos_credito.create!(tipo: "cargo", monto_centavos: 30_000, fecha: hoy - 3, usuario: @admin)
    assert_not Credito.evaluar(c, hoy: hoy).bloqueado
    c.movimientos_credito.create!(tipo: "cargo", monto_centavos: 20_000, fecha: hoy - 1, usuario: @admin)
    assert Credito.evaluar(c, hoy: hoy).bloqueado

    s = Cliente.create!(nombre: "Semanal", credito: "semanal")
    s.movimientos_credito.create!(tipo: "cargo", monto_centavos: 10_000, fecha: hoy - 1, usuario: @admin)
    assert_not Credito.evaluar(s, hoy: hoy).bloqueado, "deuda de esta semana no bloquea"
    s.movimientos_credito.create!(tipo: "cargo", monto_centavos: 5_000, fecha: hoy - 8, usuario: @admin)
    e = Credito.evaluar(s, hoy: hoy)
    assert e.bloqueado
    assert_equal 5_000, e.vencido_centavos
    s.movimientos_credito.create!(tipo: "abono", monto_centavos: -5_000, fecha: hoy, usuario: @admin)
    assert_not Credito.evaluar(s, hoy: hoy).bloqueado, "el abono mata primero el cargo más viejo"
    s.update!(dia_corte: 4) # viernes: el corte vigente es el viernes pasado
    s.movimientos_credito.create!(tipo: "cargo", monto_centavos: 7_000, fecha: hoy - 6, usuario: @admin) # jueves pasado
    assert Credito.evaluar(s, hoy: hoy).bloqueado

    a = Cliente.create!(nombre: "Abonando", credito: "contado_abonando")
    a.movimientos_credito.create!(tipo: "cargo", monto_centavos: 10_000, fecha: hoy - 20, usuario: @admin)
    a.movimientos_credito.create!(tipo: "abono", monto_centavos: -1_000, fecha: hoy - 3, usuario: @admin)
    assert_not Credito.evaluar(a, hoy: hoy).bloqueado
    assert Credito.evaluar(a, hoy: hoy + 5).bloqueado

    assert_not @taqueria.tap { |t| t.update!(credito: "contado") }.estado_credito.permite_credito?
    assert_equal({ "0-30" => 9_000, "31-60" => 0, "61-90" => 0, "90+" => 0 }, Credito.aging(a, hoy: hoy))
  end

  test "mandar sin escanear: renglón manual en un reparto va en la nota y se puede rechazar; sellar sin verificar queda por revisar" do
    s1 = viaje_en_ruta(@p1) do |salida|
      post manual_salida_path(salida), params: { producto_id: productos(:catsup).id, cantidad: "2", motivo: "sin etiqueta, urgía" }
      assert_equal 1, salida.lineas.count
    end
    assert_equal 51_600 + 8_400, s1.venta.total_centavos
    assert_equal BigDecimal("3"), Existencia.de(@matriz, productos(:catsup))
    post entrar_path, params: { usuario: "chofer", password: "secreto1" }
    post reparto_entregar_path(s1), params: { codigo: @p1.codigo }
    post reparto_cerrar_path(s1), params: { efectivo: "516", motivo_rechazo: "no quiso la cátsup", rechazar_lineas: [ s1.lineas.first.id ] }
    assert_redirected_to reparto_path
    assert s1.reload.entregada?
    assert s1.lineas.first.rechazada
    assert_equal 51_600, s1.venta.saldo_centavos
    assert_equal BigDecimal("5"), Existencia.de(@matriz, productos(:catsup))

    # sellar sin el segundo escaneo
    p2 = Etiqueta.create!(tipo: "paquete", producto: productos(:pechuga), cantidad: "1.000", sucursal: @matriz, usuario: @admin, pedido_linea: pedido_lineas(:pechuga_5))
    post entrar_path, params: { usuario: "admin", password: "secreto1" }
    post salidas_path, params: { destino: "cliente:#{@taqueria.id}" }
    s2 = Salida.last
    post agregar_salida_path(s2), params: { codigo: p2.codigo }
    post sellar_salida_path(s2)
    assert_match "por verificar", flash[:alert]
    post sellar_salida_path(s2), params: { motivo_sin_verificar: "no había nadie más" }
    assert s2.reload.sellada?
    r = Revision.last
    assert_equal s2, r.revisable
    assert_equal 12_900, r.valor_centavos
    assert_match "sin verificar", r.motivo
  end
end
