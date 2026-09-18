require "test_helper"

class RepartoTest < ActiveSupport::TestCase
  setup do
    @matriz = sucursales(:matriz)
    @admin = usuarios(:admin)
    @super = usuarios(:supervisora)
    @cliente = clientes(:taqueria)
    Corte.abrir!(sucursal: @matriz, usuario: @admin, fondo_centavos: 100_000)
    Inventario.mover!(sucursal: @matriz, producto: productos(:pechuga), tipo: "entrada", cantidad: 20, usuario: @admin)
    @pedido = Pedido.create!(sucursal_origen: @matriz, cliente: @cliente, usuario: @admin, lineas_attributes: [ { producto_id: productos(:pechuga).id, cantidad: 5 } ])
    @a = Etiqueta.create!(tipo: "paquete", producto: productos(:pechuga), cantidad: "2.000", sucursal: @matriz, usuario: @admin, pedido_linea: @pedido.lineas.first)
    @b = Etiqueta.create!(tipo: "paquete", producto: productos(:pechuga), cantidad: "3.000", sucursal: @matriz, usuario: @admin, pedido_linea: @pedido.lineas.first)
    @caja = Etiqueta.cerrar_caja!([ @a, @b ], usuario: @admin)
  end

  test "un pedido va a una tienda o a un cliente, no a los dos ni a ninguno" do
    assert_not Pedido.new(sucursal_origen: @matriz, usuario: @admin, lineas_attributes: [ { producto_id: productos(:pechuga).id, cantidad: 1 } ]).valid?
    assert_not Pedido.new(sucursal_origen: @matriz, cliente: @cliente, sucursal_destino: sucursales(:tienda), usuario: @admin, lineas_attributes: [ { producto_id: productos(:pechuga).id, cantidad: 1 } ]).valid?
    assert_equal @cliente, @pedido.destino
  end

  test "reparto de contado: al enviar se cierra la nota por cobrar, el chofer vuelve y se cobra" do
    salida = Salida.nueva!(origen: @matriz, destino: @cliente, usuario: @admin)
    assert salida.reparto?
    assert salida.folio.start_with?("R-")
    assert_equal rutas(:norte), salida.ruta
    salida.agregar!(@caja)
    salida.verificar!(@caja, usuario: @super)
    salida.sellar!(usuario: @super)
    corte = Corte.abierto_en(@matriz)
    salida.enviar!(usuario: @admin)
    venta = salida.reload.venta
    assert venta.por_cobrar?
    assert_equal @cliente, venta.cliente
    assert_equal 5 * 12_900, venta.total_centavos
    assert_equal BigDecimal("15"), Existencia.de(@matriz, productos(:pechuga))
    assert_equal "vendida", @a.reload.estado
    assert_equal "cerrado", @pedido.reload.estado
    assert_equal 100_000, corte.efectivo_esperado_centavos, "por cobrar no cuenta en la gaveta"
    assert_raises(ArgumentError) { salida.recibir!(@a, usuario: @admin) }
    assert_raises(Caja::Error) { salida.cobrar_entrega!(pagos: [ { forma: "efectivo", monto_centavos: 1 } ], usuario: @admin) }
    salida.cobrar_entrega!(pagos: [ { forma: "efectivo", monto_centavos: 70_000 } ], usuario: @admin)
    assert_equal "entregada", salida.reload.estado
    assert venta.reload.cobrada?
    assert_equal 5_500, venta.cambio_centavos
    assert_equal 164_500, corte.efectivo_esperado_centavos
    assert_raises(ArgumentError) { salida.cobrar_entrega!(pagos: [], usuario: @admin) }
    # lo que el cliente rechazó vuelve como devolución con el ticket
    dev = Caja.devolver!(venta: venta, lineas: [ { venta_linea_id: venta.lineas.first.id, cantidad: "2.000" } ], motivo: "rechazó una bolsa", usuario: @admin)
    assert_equal 25_800, dev.total_centavos
    assert_equal BigDecimal("17"), Existencia.de(@matriz, productos(:pechuga))
    assert_equal "viva", @a.reload.estado
  end

  test "sin caja abierta no se envía un reparto" do
    Corte.abierto_en(@matriz).update!(estado: "cerrado")
    salida = Salida.nueva!(origen: @matriz, destino: @cliente, usuario: @admin)
    salida.agregar!(@caja)
    salida.verificar!(@caja, usuario: @super)
    salida.sellar!(usuario: @super)
    assert_raises(Caja::Error) { salida.enviar!(usuario: @admin) }
    assert_equal "sellada", salida.reload.estado
  end
end
