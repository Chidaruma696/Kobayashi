require "test_helper"

class PedidoTest < ActiveSupport::TestCase
  setup do
    @pedido = pedidos(:abierto)
    @linea = pedido_lineas(:pechuga_5)
    @admin = usuarios(:admin)
  end

  def etiquetar(cantidad, linea: @linea)
    Etiqueta.create!(tipo: "paquete", producto: linea.producto, cantidad: cantidad, sucursal: sucursales(:matriz), usuario: @admin, pedido_linea: linea)
  end

  test "el pedido sugerido pide lo que falta para llegar al máximo, descontando lo ya pedido, solo por debajo del mínimo" do
    tienda = sucursales(:tienda)
    pechuga = productos(:pechuga)
    catsup = productos(:catsup)
    assert_empty Pedido.sugerido(tienda), "sin mínimos no hay sugerencia"
    pechuga.fijar_minimo!(tienda, "10", "25")
    catsup.fijar_minimo!(tienda, "16", nil)
    assert_raises(ActiveRecord::RecordInvalid) { catsup.fijar_minimo!(tienda, "16", "5") }
    Inventario.mover!(sucursal: tienda, producto: pechuga, tipo: "entrada", cantidad: "4.5", usuario: @admin)
    Inventario.mover!(sucursal: tienda, producto: catsup, tipo: "entrada", cantidad: 6, usuario: @admin)
    # Lo que ya pidió y sigue pendiente cuenta como si ya lo tuviera (el pedido de prueba trae 5 de pechuga).
    assert_equal [ [ pechuga, BigDecimal("15.5") ] ], Pedido.sugerido(tienda), "25 − 4.5 − 5; catsup con 6 más 10 pendientes está justo en el mínimo: no se pide"
    Pedido.create!(sucursal_origen: sucursales(:matriz), sucursal_destino: tienda, usuario: @admin, lineas_attributes: [ { producto_id: pechuga.id, cantidad: 3 } ])
    assert_empty Pedido.sugerido(tienda), "4.5 más 8 pendientes ya pasan el mínimo de 10: no se vuelve a pedir"
    Inventario.mover!(sucursal: tienda, producto: catsup, tipo: "venta", cantidad: 1, usuario: @admin)
    assert_equal [ [ catsup, BigDecimal("1") ] ], Pedido.sugerido(tienda), "sin máximo se pide hasta el mínimo; piezas enteras"
    pechuga.fijar_minimo!(tienda, "", "")
    assert_equal 1, MinimoSucursal.count
  end

  test "lo surtido se suma de las etiquetas vivas y el renglón se cierra solo al llegar" do
    assert_equal BigDecimal("0"), @linea.cantidad_surtida
    etiquetar("2.000")
    assert_equal "surtiendo", @pedido.reload.estado
    assert_equal BigDecimal("3"), @linea.reload.faltante
    assert @linea.pendiente?
    e = etiquetar("3.000")
    assert_equal "surtido", @linea.reload.estado
    e.dar_de_baja!(motivo: "se rompió", usuario: @admin)
    assert_equal "pendiente", @linea.reload.estado
    assert_equal BigDecimal("2"), @linea.cantidad_surtida
  end

  test "las cajas que agrupan no cuentan dos veces" do
    a = etiquetar("2.000")
    b = etiquetar("3.000")
    Etiqueta.cerrar_caja!([ a, b ], usuario: @admin)
    assert_equal BigDecimal("5"), @linea.reload.cantidad_surtida
  end

  test "no surtir aparta el renglón y reabrir lo recalcula" do
    @linea.no_surtir!("no hay pechuga")
    etiquetar("5.000")
    assert_equal "no_surtir", @linea.reload.estado
    @linea.reabrir!
    assert_equal "surtido", @linea.reload.estado
    assert_raises(ArgumentError) { @linea.no_surtir!("") }
  end

  test "un pedido necesita renglones, destino distinto y folio por sucursal que surte" do
    p = Pedido.new(sucursal_origen: sucursales(:matriz), sucursal_destino: sucursales(:matriz), usuario: @admin)
    assert_not p.valid?
    assert p.errors[:sucursal_destino].any?
    assert p.errors[:lineas].any?
    p = Pedido.create!(sucursal_origen: sucursales(:matriz), sucursal_destino: sucursales(:tienda), usuario: @admin,
                       lineas_attributes: [ { producto_id: productos(:pechuga).id, cantidad: 1 } ])
    assert_match(/\AP-\d{5}\z/, p.folio)
    assert_not_equal @pedido.folio, p.folio
  end

  test "solo se cancela sin nada surtido" do
    etiquetar("1.000")
    assert_raises(ArgumentError) { @pedido.reload.cancelar! }
    p = Pedido.create!(sucursal_origen: sucursales(:matriz), sucursal_destino: sucursales(:tienda), usuario: @admin,
                       lineas_attributes: [ { producto_id: productos(:pechuga).id, cantidad: 1 } ])
    p.cancelar!
    assert_equal "cancelado", p.estado
  end
end
