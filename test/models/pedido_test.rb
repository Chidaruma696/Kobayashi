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
