require "test_helper"

class SalidaTest < ActiveSupport::TestCase
  setup do
    @matriz = sucursales(:matriz)
    @tienda = sucursales(:tienda)
    @admin = usuarios(:admin)
    @super = usuarios(:supervisora)
    @linea = pedido_lineas(:pechuga_5)
    Inventario.mover!(sucursal: @matriz, producto: productos(:pechuga), tipo: "entrada", cantidad: 20, usuario: @admin)
    Inventario.mover!(sucursal: @matriz, producto: productos(:catsup), tipo: "entrada", cantidad: 20, usuario: @admin)
    @p1 = paquete("2.000")
    @p2 = paquete("3.000")
    @caja = Etiqueta.cerrar_caja!([ @p1, @p2 ], usuario: @admin)
    @catsup = Etiqueta.create!(tipo: "caja", producto: productos(:catsup), cantidad: 10, sucursal: @matriz, usuario: @admin, pedido_linea: pedido_lineas(:catsup_10))
    @salida = Salida.nueva!(origen: @matriz, destino: @tienda, usuario: @admin)
  end

  def paquete(cantidad)
    Etiqueta.create!(tipo: "paquete", producto: productos(:pechuga), cantidad: cantidad, sucursal: @matriz, usuario: @admin, pedido_linea: @linea)
  end

  test "surtir expande cajas y tarimas a sus hojas y no deja una etiqueta en dos salidas" do
    assert_equal 2, @salida.agregar!(@caja)
    assert_equal 1, @salida.agregar!(@catsup)
    assert_equal({ productos(:pechuga) => BigDecimal("5"), productos(:catsup) => BigDecimal("10") }, @salida.contenido)
    assert_raises(ArgumentError) { @salida.agregar!(@p1) }
    otra = Salida.nueva!(origen: @matriz, destino: @tienda, usuario: @admin)
    assert_raises(ArgumentError) { otra.agregar!(@caja) }
    assert_equal 2, @salida.quitar!(@caja)
    assert_equal 1, @salida.salida_etiquetas.count
  end

  test "verifica otra persona, se sella, se envía: baja el origen, viajan las etiquetas y cierra el pedido" do
    @salida.agregar!(@caja)
    @salida.agregar!(@catsup)
    assert_raises(ArgumentError) { @salida.sellar!(usuario: @super) }
    assert_raises(ArgumentError) { @salida.verificar!(@caja, usuario: @admin) }
    @salida.verificar!(@caja, usuario: @super)
    @salida.verificar!(@catsup, usuario: @super)
    @salida.sellar!(usuario: @super)
    assert @salida.sellada?
    assert_raises(ArgumentError) { @salida.agregar!(paquete(1)) }
    @salida.enviar!(usuario: @admin)
    assert @salida.enviada?
    assert_equal BigDecimal("15"), Existencia.de(@matriz, productos(:pechuga))
    assert_equal BigDecimal("10"), Existencia.de(@matriz, productos(:catsup))
    assert_equal @tienda, @p1.reload.sucursal
    assert_equal @tienda, @caja.reload.sucursal
    assert @p1.en_transito?
    assert_equal "cerrado", pedidos(:abierto).reload.estado
    assert_equal BigDecimal("0"), Existencia.de(@tienda, productos(:pechuga))
  end

  test "recibir paquete por paquete, la caja no vale, la tarima entera sí, y lo que falta se reporta" do
    @salida.agregar!(@caja)
    @salida.agregar!(@catsup)
    @salida.verificar!(@caja, usuario: @super)
    @salida.verificar!(@catsup, usuario: @super)
    @salida.sellar!(usuario: @super)
    @salida.enviar!(usuario: @admin)

    assert_raises(ArgumentError) { @salida.recibir!(@caja.reload, usuario: @super) }
    assert_equal 1, @salida.recibir!(@p1.reload, usuario: @super)
    assert_equal BigDecimal("2"), Existencia.de(@tienda, productos(:pechuga))
    assert_not @p1.reload.en_transito?
    assert_raises(ArgumentError) { @salida.recibir!(@p1, usuario: @super) }
    assert_equal 1, @salida.recibir!(@catsup.reload, usuario: @super)
    assert_nil @p1.reload.padre_id
    assert @caja.reload.viva?, "la caja sigue viva mientras le quede un paquete"
    assert_raises(ArgumentError) { @salida.cerrar_recepcion!(usuario: @super) }
    @salida.cerrar_recepcion!(usuario: @super, motivo_pendientes: "llegó sin etiqueta")
    assert_equal "recibida", @salida.estado
    assert_equal "baja", @p2.reload.estado
    assert_equal "faltante", @salida.salida_etiquetas.find_by(etiqueta: @p2).estado
    assert_equal "baja", @caja.reload.estado
    assert_equal BigDecimal("2"), Existencia.de(@tienda, productos(:pechuga))
    assert_equal BigDecimal("10"), Existencia.de(@tienda, productos(:catsup))
  end

  test "una tarima se recibe entera" do
    tarima = Etiqueta.armar_tarima!([ @caja, @catsup ], usuario: @admin)
    assert_equal 3, @salida.agregar!(tarima)
    @salida.verificar!(tarima, usuario: @super)
    @salida.sellar!(usuario: @super)
    @salida.enviar!(usuario: @admin)
    assert_equal 3, @salida.recibir!(tarima.reload, usuario: @super)
    assert_equal BigDecimal("5"), Existencia.de(@tienda, productos(:pechuga))
    @salida.cerrar_recepcion!(usuario: @super)
    assert_equal "recibida", @salida.estado
  end

  test "devolución de tienda a matriz con etiquetas o manual justificada, y en tránsito no se vende" do
    @salida.agregar!(@caja)
    @salida.verificar!(@caja, usuario: @super)
    @salida.sellar!(usuario: @super)
    @salida.enviar!(usuario: @admin)
    cortes(:tienda_abierto)
    assert_raises(Caja::Error) { Caja.cobrar!(sucursal: @tienda, usuario: usuarios(:cajera), clave: "z", lineas: [ { etiqueta_id: @p1.id } ], pagos: [ { forma: "efectivo", monto_centavos: 100_000 } ]) }
    @salida.recibir!(@p1.reload, usuario: @super)
    @salida.cerrar_recepcion!(usuario: @super, motivo_pendientes: "roto")

    assert_raises(ActiveRecord::RecordInvalid) { Salida.nueva!(origen: @tienda, destino: @matriz, usuario: @super) }
    dev = Salida.nueva!(origen: @tienda, destino: @matriz, usuario: @super, motivo: "no se vende")
    assert dev.devolucion?
    assert dev.folio.start_with?("DV-")
    assert_equal 1, dev.agregar!(@p1.reload)
    assert_raises(ArgumentError) { @salida.agregar_manual!(producto: productos(:pechuga), cantidad: 1, motivo: "x", autorizado_por: @admin) }
    Inventario.mover!(sucursal: @tienda, producto: productos(:catsup), tipo: "entrada", cantidad: 4, usuario: @super)
    dev.agregar_manual!(producto: productos(:catsup), cantidad: 4, motivo: "sin etiqueta, se despegó", autorizado_por: @admin)
    dev.verificar!(@p1, usuario: usuarios(:cajera))
    dev.sellar!(usuario: usuarios(:cajera))
    dev.enviar!(usuario: @super)
    assert_equal BigDecimal("0"), Existencia.de(@tienda, productos(:pechuga))
    assert_equal BigDecimal("0"), Existencia.de(@tienda, productos(:catsup))
    dev.recibir!(@p1.reload, usuario: @admin)
    dev.cerrar_recepcion!(usuario: @admin)
    assert_equal BigDecimal("17"), Existencia.de(@matriz, productos(:pechuga))
    assert_equal BigDecimal("24"), Existencia.de(@matriz, productos(:catsup))
  end

  test "cancelar libera las etiquetas" do
    @salida.agregar!(@caja)
    @salida.cancelar!
    assert_equal "cancelada", @salida.estado
    otra = Salida.nueva!(origen: @matriz, destino: @tienda, usuario: @admin)
    assert_equal 2, otra.agregar!(@caja)
  end
end
